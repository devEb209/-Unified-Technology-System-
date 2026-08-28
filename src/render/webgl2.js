// UTS :: render/webgl2 — WebGL2RendererBackend.
//
// Implements the RendererBackend contract:
//   init() -> compile programs, build STATIC resources (unit meshes, rain seeds)
//   render(frame) -> prepare(frame) + draw(frame)
//     prepare: syncs DYNAMIC-CHANGE resources (terrain buffers only when the
//              represented patch/res/version actually changed)
//     draw:    translates the Frame to GPU calls — never invents state
//   destroy() -> frees every GPU resource
//
// The GL context is injected (browser WebGL2 or a mock for headless tests),
// keeping the renderer decoupled and testable.

import {
  TERRAIN_VS, TERRAIN_FS, ENTITY_VS, ENTITY_FS, SKY_VS, SKY_FS, POINTS_VS, POINTS_FS,
} from './shaders.js';
import { cubeMesh, sphereMesh, coneMesh, domeMesh, buildTerrainMesh } from './mesh.js';
import { perspective, lookAt, multiply, composeTRS, identity } from './mat.js';

export class RendererError extends Error {}

export class WebGL2Renderer {
  constructor(gl, { canvas = null, log = null } = {}) {
    if (!gl || typeof gl.createShader !== 'function') {
      throw new RendererError('WebGL2Renderer needs a WebGL2 (or GL-like) context');
    }
    this.gl = gl;
    this.canvas = canvas ?? gl.canvas ?? null;
    this.log = log;
    this.initialized = false;
    this.programs = null;
    this.meshes = null;
    /** terrainKey -> {buffer, count} — static per (patch, res, version) */
    this.terrainBuffers = new Map();
    this.rainBuffer = null;
    this.quadBuffer = null;
    this.stats = { drawCalls: 0, uploads: 0, triangles: 0, frames: 0 };
    this._lastSize = [0, 0];
  }

  // ------------------------------------------------------------------ init

  _compile(type, src, label) {
    const gl = this.gl;
    const sh = gl.createShader(type);
    gl.shaderSource(sh, src);
    gl.compileShader(sh);
    if (!gl.getShaderParameter(sh, gl.COMPILE_STATUS)) {
      const info = gl.getShaderInfoLog(sh);
      gl.deleteShader(sh);
      throw new RendererError(`shader compile failed (${label}): ${info}`);
    }
    return sh;
  }

  _program(vsSrc, fsSrc, label) {
    const gl = this.gl;
    const vs = this._compile(gl.VERTEX_SHADER, vsSrc, label + ':vs');
    const fs = this._compile(gl.FRAGMENT_SHADER, fsSrc, label + ':fs');
    const prog = gl.createProgram();
    gl.attachShader(prog, vs);
    gl.attachShader(prog, fs);
    gl.linkProgram(prog);
    if (!gl.getProgramParameter(prog, gl.LINK_STATUS)) {
      throw new RendererError(`program link failed (${label})`);
    }
    gl.deleteShader(vs);
    gl.deleteShader(fs);
    const u = (name) => gl.getUniformLocation(prog, name);
    return {
      prog,
      u: {
        vp: u('uVP'), model: u('uModel'), color: u('uColor'),
        sunDir: u('uSunDir'), sunColor: u('uSunColor'), ambient: u('uAmbient'),
        emissive: u('uEmissive'), skyTop: u('uSkyTop'), skyBottom: u('uSkyBottom'),
        fog: u('uFog'), wetness: u('uWetness'), camPos: u('uCamPos'), flash: u('uFlash'),
        time: u('uTime'), wind: u('uWind'), count: u('uCount'),
      },
      a: {
        pos: gl.getAttribLocation(prog, 'aPos'),
        norm: gl.getAttribLocation(prog, 'aNorm'),
        biome: gl.getAttribLocation(prog, 'aBiome'),
        quad: gl.getAttribLocation(prog, 'aPos'),
        seed: gl.getAttribLocation(prog, 'aSeed'),
      },
    };
  }

  init() {
    const gl = this.gl;
    this.programs = {
      terrain: this._program(TERRAIN_VS, TERRAIN_FS, 'terrain'),
      entity: this._program(ENTITY_VS, ENTITY_FS, 'entity'),
      sky: this._program(SKY_VS, SKY_FS, 'sky'),
      points: this._program(POINTS_VS, POINTS_FS, 'points'),
    };
    // static unit meshes (shared across all entity draws)
    this.meshes = {
      box: cubeMesh(),
      sphere: sphereMesh(),
      cone: coneMesh(),
      dome: domeMesh(),
      capsule: sphereMesh(6, 8), // capsules approximated by spheres at this stage
    };
    // static fullscreen triangle for the sky
    this.quadBuffer = gl.createBuffer();
    gl.bindBuffer(gl.ARRAY_BUFFER, this.quadBuffer);
    gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-1, -1, 3, -1, -1, 3]), gl.STATIC_DRAW);
    // static rain/dust seed buffer (dynamic control happens via uniform)
    const seeds = new Float32Array(500);
    for (let i = 0; i < 500; i++) seeds[i] = (i + 0.5) / 500;
    this.rainBuffer = gl.createBuffer();
    gl.bindBuffer(gl.ARRAY_BUFFER, this.rainBuffer);
    gl.bufferData(gl.ARRAY_BUFFER, seeds, gl.STATIC_DRAW);

    gl.enable(gl.DEPTH_TEST);
    gl.depthFunc(gl.LEQUAL);
    gl.enable(gl.CULL_FACE);
    this.initialized = true;
  }

  // --------------------------------------------------------------- prepare

  /** sync GPU resources with the Frame (uploads happen ONLY on change) */
  prepare(frame) {
    if (!this.initialized) this.init();
    const gl = this.gl;
    const current = new Set();
    for (const patch of frame.terrain.patches) {
      const key = `${patch.id}:${patch.res}:${patch.version}`;
      current.add(key);
      if (this.terrainBuffers.has(key)) continue;
      const mesh = buildTerrainMesh({ ...patch, size: patch.size });
      const buf = gl.createBuffer();
      gl.bindBuffer(gl.ARRAY_BUFFER, buf);
      gl.bufferData(gl.ARRAY_BUFFER, mesh.data, gl.STATIC_DRAW);
      this.terrainBuffers.set(key, { buffer: buf, count: mesh.count, stride: 7 });
      this.stats.uploads++;
    }
    // free buffers of patches no longer visible (LOD/streaming)
    for (const [key, res] of [...this.terrainBuffers]) {
      if (!current.has(key)) {
        gl.deleteBuffer(res.buffer);
        this.terrainBuffers.delete(key);
      }
    }
  }

  // ------------------------------------------------------------------ draw

  _bindMesh(prog, buffer, stride, { normals = true, biome = false } = {}) {
    const gl = this.gl;
    gl.bindBuffer(gl.ARRAY_BUFFER, buffer);
    const floatSize = 4;
    const strideBytes = stride * floatSize;
    gl.enableVertexAttribArray(prog.a.pos);
    gl.vertexAttribPointer(prog.a.pos, 3, gl.FLOAT, false, strideBytes, 0);
    if (normals && prog.a.norm >= 0) {
      gl.enableVertexAttribArray(prog.a.norm);
      gl.vertexAttribPointer(prog.a.norm, 3, gl.FLOAT, false, strideBytes, 3 * floatSize);
    }
    if (biome && prog.a.biome != null && prog.a.biome >= 0) {
      gl.enableVertexAttribArray(prog.a.biome);
      gl.vertexAttribPointer(prog.a.biome, 1, gl.FLOAT, false, strideBytes, 6 * floatSize);
    }
  }

  draw(frame) {
    if (!this.initialized) this.init();
    const gl = this.gl;
    const env = frame.environment;
    const cam = frame.camera;
    const aspect = (this.canvas?.width ?? 1280) / (this.canvas?.height ?? 720);
    this._ensureSize(this.canvas?.width ?? 1280, this.canvas?.height ?? 720);

    const proj = perspective((cam.fovDeg * Math.PI) / 180, aspect, 0.5, cam.far ?? 600);
    const view = lookAt(cam.pos, [cam.pos[0] + Math.sin(cam.yaw) * Math.cos(cam.pitch), cam.pos[1] - Math.sin(cam.pitch) * 30, cam.pos[2] + Math.cos(cam.yaw) * Math.cos(cam.pitch)], [0, 1, 0]);
    const vp = multiply(proj, view);
    let drawCalls = 0;

    gl.clearColor(env.skyBottom[0], env.skyBottom[1], env.skyBottom[2], 1);
    gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

    // ---- sky
    const sky = this.programs.sky;
    gl.useProgram(sky.prog);
    gl.uniform3f(sky.u.skyTop, env.skyTop[0], env.skyTop[1], env.skyTop[2]);
    gl.uniform3f(sky.u.skyBottom, env.skyBottom[0], env.skyBottom[1], env.skyBottom[2]);
    gl.uniform1f(sky.u.flash, env.flash ?? 0);
    gl.depthMask(false);
    this._bindMesh(sky, this.quadBuffer, 2, { normals: false });
    gl.drawArrays(gl.TRIANGLES, 0, 3);
    gl.depthMask(true);
    drawCalls++;

    // ---- terrain (manifestation of the represented heightfield)
    const terr = this.programs.terrain;
    gl.useProgram(terr.prog);
    gl.uniformMatrix4fv(terr.u.vp, false, vp);
    gl.uniform3f(terr.u.sunDir, env.sunDir[0], env.sunDir[1], env.sunDir[2]);
    gl.uniform3f(terr.u.sunColor, env.sunColor[0], env.sunColor[1], env.sunColor[2]);
    gl.uniform1f(terr.u.ambient, env.ambient);
    gl.uniform3f(terr.u.skyBottom, env.skyBottom[0], env.skyBottom[1], env.skyBottom[2]);
    gl.uniform1f(terr.u.fog, env.fog);
    gl.uniform1f(terr.u.wetness, env.wetness);
    gl.uniform3f(terr.u.camPos, cam.pos[0], cam.pos[1], cam.pos[2]);
    for (const patch of frame.terrain.patches) {
      const key = `${patch.id}:${patch.res}:${patch.version}`;
      const res = this.terrainBuffers.get(key);
      if (!res) continue;
      this._bindMesh(terr, res.buffer, res.stride, { normals: true, biome: true });
      gl.uniformMatrix4fv(terr.u.model, false, identity());
      gl.drawArrays(gl.TRIANGLES, 0, res.count);
      drawCalls++;
    }

    // ---- entities + aggregates
    const ent = this.programs.entity;
    gl.useProgram(ent.prog);
    gl.uniformMatrix4fv(ent.u.vp, false, vp);
    gl.uniform3f(ent.u.sunDir, env.sunDir[0], env.sunDir[1], env.sunDir[2]);
    gl.uniform3f(ent.u.sunColor, env.sunColor[0], env.sunColor[1], env.sunColor[2]);
    gl.uniform1f(ent.u.ambient, env.ambient);
    gl.uniform3f(ent.u.skyBottom, env.skyBottom[0], env.skyBottom[1], env.skyBottom[2]);
    gl.uniform1f(ent.u.fog, env.fog);
    gl.uniform3f(ent.u.camPos, cam.pos[0], cam.pos[1], cam.pos[2]);

    const ground = (x, z) => {
      // rest entities on the represented terrain
      const p = frame.terrain.patches.find(pp => x >= pp.x0 && x < pp.x0 + pp.size && z >= pp.z0 && z < pp.z0 + pp.size);
      if (!p) return 0;
      const fx = ((x - p.x0) / p.size) * p.res, fz = ((z - p.z0) / p.size) * p.res;
      const i = Math.min(p.res, Math.floor(fx)), j = Math.min(p.res, Math.floor(fz));
      return p.heights[j * (p.res + 1) + i];
    };

    const drawEntity = (e) => {
      const mesh = this.meshes[e.shape] ?? this.meshes.box;
      const y = ground(e.pos[0], e.pos[2]) + (e.kind === 'npc' ? 1.2 : e.kind === 'hazard' ? 1 : e.scale * 0.5);
      const model = composeTRS([e.pos[0], y, e.pos[2]], e.yaw, e.scale);
      this._bindMesh(ent, this._entityBuffer(mesh), 6, { normals: true });
      gl.uniformMatrix4fv(ent.u.model, false, model);
      gl.uniform3f(ent.u.color, e.color[0], e.color[1], e.color[2]);
      gl.uniform1f(ent.u.emissive, e.emissive ?? 0);
      gl.drawArrays(gl.TRIANGLES, 0, mesh.count);
      drawCalls++;
    };
    for (const e of frame.entities) drawEntity(e);
    for (const agg of frame.aggregates) {
      drawEntity({ ...agg, shape: 'dome', kind: 'aggregate', yaw: 0, scale: agg.radius, emissive: 0 });
    }

    // ---- precipitation / dust (phenomena from the represented state)
    const density = Math.max(env.rain, env.dust) * (frame.stats.particles ?? 1);
    if (density > 0.02) {
      const pts = this.programs.points;
      gl.useProgram(pts.prog);
      gl.uniformMatrix4fv(pts.u.vp, false, vp);
      gl.uniform3f(pts.u.camPos, cam.pos[0], cam.pos[1], cam.pos[2]);
      gl.uniform1f(pts.u.time, frame.time);
      gl.uniform1f(pts.u.wind, env.wind);
      gl.uniform1f(pts.u.count, 500 * Math.min(1, density));
      const color = env.dust > env.rain ? [0.75, 0.65, 0.45] : [0.6, 0.7, 0.9];
      gl.uniform3f(pts.u.color, color[0], color[1], color[2]);
      gl.enable(gl.BLEND);
      gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);
      this._bindMesh(pts, this.rainBuffer, 1, { normals: false });
      gl.drawArrays(gl.POINTS, 0, 500);
      gl.disable(gl.BLEND);
      drawCalls++;
    }

    this.stats.drawCalls += drawCalls;
    this.stats.frames++;
    return { drawCalls };
  }

  _entityBuffer(mesh) {
    // entity unit meshes are static: upload once, reuse every frame
    if (!mesh._buffer) {
      const gl = this.gl;
      mesh._buffer = gl.createBuffer();
      gl.bindBuffer(gl.ARRAY_BUFFER, mesh._buffer);
      gl.bufferData(gl.ARRAY_BUFFER, mesh.data, gl.STATIC_DRAW);
    }
    return mesh._buffer;
  }

  render(frame) {
    this.prepare(frame);
    return this.draw(frame);
  }

  _ensureSize(w, h) {
    if (this._lastSize[0] !== w || this._lastSize[1] !== h) {
      this.gl.viewport(0, 0, w, h);
      this._lastSize = [w, h];
    }
  }

  destroy() {
    const gl = this.gl;
    for (const res of this.terrainBuffers.values()) gl.deleteBuffer(res.buffer);
    this.terrainBuffers.clear();
    if (this.rainBuffer) gl.deleteBuffer(this.rainBuffer);
    if (this.quadBuffer) gl.deleteBuffer(this.quadBuffer);
    for (const m of Object.values(this.meshes ?? {})) if (m._buffer) gl.deleteBuffer(m._buffer);
    if (this.programs) for (const p of Object.values(this.programs)) gl.deleteProgram(p.prog);
    this.programs = null;
    this.meshes = null;
    this.initialized = false;
  }
}
