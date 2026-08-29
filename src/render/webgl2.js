// UTS :: render/webgl2 — OUR WebGL2 RHI device + Gênesis renderer.
//
// Gênesis pipeline (all native, all derived from the Frame):
//   culling (ours) → shadow depth pass (ours, sun-caster) → main pass:
//   sky → terrain (streaming residency) → INSTANCED entities (ours) →
//   precipitation. Materials + lights from UTS systems; RHI owns every
//   GPU resource (tracked, sized, freed). Honest fallbacks: no-FBO or
//   no-instanced devices degrade gracefully, never fake.

import {terrainFS, SKY_VS, SKY_FS, TERRAIN_VS, TERRAIN_FS, ENTITY_INST_VS, ENTITY_FS, SHADOW_VS, SHADOW_FS, POINTS_VS, POINTS_FS, WATER_VS, WATER_FS, VEGETATION_VS, VEGETATION_FS, HORIZON_VS, HORIZON_FS, TREE_VS, TREE_FS, FIRE_VS, FIRE_FS, POST_VS, POST_FS} from './shaders.js';
import { cubeMesh, sphereMesh, coneMesh, domeMesh, buildTerrainMesh, buildImpostorMesh, treeMesh } from './mesh.js';
import { emitFrame as emitFireParticles } from './fire.js';
import { perspective, lookAt, multiply, identity } from './mat.js';
import { frustumPlanes, cullFrame } from './culling.js';
import { GPUResourceManager, ProgramCache, RHIError, RendererError } from './rhi.js';

const GL = {
  VERTEX_SHADER: 1, FRAGMENT_SHADER: 2, COMPILE_STATUS: 3, LINK_STATUS: 4,
  ARRAY_BUFFER: 5, STATIC_DRAW: 6, DYNAMIC_DRAW: 7, DEPTH_TEST: 8, LEQUAL: 9,
  CULL_FACE: 10, COLOR_BUFFER_BIT: 11, DEPTH_BUFFER_BIT: 12, TRIANGLES: 13,
  POINTS: 14, FLOAT: 15, BLEND: 16, SRC_ALPHA: 17, ONE_MINUS_SRC_ALPHA: 18,
  TEXTURE_2D: 19, DEPTH_COMPONENT24: 20, DEPTH_ATTACHMENT: 21, FRAMEBUFFER: 22,
  FRAMEBUFFER_COMPLETE: 23, TEXTURE_MIN_FILTER: 24, NEAREST: 25,
  RGBA: 26, UNSIGNED_BYTE: 27, COLOR_ATTACHMENT0: 28, TEXTURE0: 29,
};

export class WebGL2Renderer {
  constructor(gl, { canvas = null, log = null } = {}) {
    if (!gl || typeof gl.createShader !== 'function') throw new RendererError('WebGL2Renderer needs an RHI device context');
    this.gl = gl;
    this.canvas = canvas ?? gl.canvas ?? null;
    this.log = log;
    this.resources = new GPUResourceManager();
    this.programCache = new ProgramCache(this); // device implements compileProgram
    this.initialized = false;
    this.stats = { drawCalls: 0, uploads: 0, frames: 0, instances: 0, culled: 0, shadowPasses: 0, batches: 0, impostors: 0, terrainTris: 0, meshMs: 0 };
    this._lastSize = [0, 0];
    this.shadowSize = 1024;
  }

  // ---- RHI device contract -------------------------------------------------

  compileProgram(vsSrc, fsSrc, label) {
    const gl = this.gl;
    const sh = (type, src) => {
      const s = gl.createShader(type);
      gl.shaderSource(s, src);
      gl.compileShader(s);
      if (!gl.getShaderParameter(s, gl.COMPILE_STATUS)) {
        const info = gl.getShaderInfoLog(s);
        gl.deleteShader(s);
        throw new RHIError(`shader compile failed (${label}): ${info}`);
      }
      return s;
    };
    const vs = sh(gl.VERTEX_SHADER, vsSrc);
    const fs = sh(gl.FRAGMENT_SHADER, fsSrc);
    const prog = gl.createProgram();
    gl.attachShader(prog, vs);
    gl.attachShader(prog, fs);
    gl.linkProgram(prog);
    if (!gl.getProgramParameter(prog, gl.LINK_STATUS)) throw new RHIError(`program link failed (${label})`);
    gl.deleteShader(vs);
    gl.deleteShader(fs);
    const u = new Proxy({}, {
      get: (t, name) => {
        if (typeof name !== 'string') return undefined;
        if (!(name in t)) t[name] = gl.getUniformLocation(prog, name);
        return t[name];
      },
    }); // lazy cached uniform locations — u.uVP works without eager enumeration
    const a = {};
    // introspect EVERY attribute name the shaders use (-1 when absent; all
    // bind sites guard). Missing ones here silently break the real browser.
    for (const name of ['aPos', 'aNorm', 'aBiome', 'aSeed', 'aInst0', 'aInst1', 'aInst2',
      'aHH', 'aSC', 'aAlpha', 'aCanopy', 'aT0', 'aT1']) {
      a[name] = gl.getAttribLocation(prog, name);
    }
    return { prog, u, a, uniform: { u } };
  }

  createBuffer(data, { dynamic = false, bytes = null } = {}) {
    const gl = this.gl;
    const raw = gl.createBuffer();
    gl.bindBuffer(gl.ARRAY_BUFFER, raw);
    gl.bufferData(gl.ARRAY_BUFFER, data, dynamic ? GL.DYNAMIC_DRAW : GL.STATIC_DRAW);
    const size = bytes ?? (data?.byteLength ?? data?.length * 4 ?? 0);
    const handle = this.resources.create('buffer', size, {}, () => gl.deleteBuffer(raw));
    handle.meta.gl = raw; // the RHI handle OWNS the raw GL buffer end-to-end
    return handle;
  }

  uploadBuffer(handle, data) {
    const gl = this.gl;
    gl.bindBuffer(gl.ARRAY_BUFFER, handle.meta.gl);
    gl.bufferData(gl.ARRAY_BUFFER, data, GL.DYNAMIC_DRAW);
  }

  deleteBuffer(handle) {
    this.resources.destroy(handle);
  }

  caps() {
    const gl = this.gl;
    return {
      instanced: typeof gl.drawArraysInstanced === 'function' && typeof gl.vertexAttribDivisor === 'function',
      fbo: typeof gl.createFramebuffer === 'function' && typeof gl.createTexture === 'function',
    };
  }

  // ---- init ----------------------------------------------------------------

  init() {
    if (this.initialized) return;
    const gl = this.gl;
    this.caps = this.caps();

    this.programs = {
      post: this.caps.fbo ? this.programCache.get('post', POST_VS, POST_FS) : null, // a óptica do OLHO na tela
      sky: this.programCache.get('sky', SKY_VS, SKY_FS),
      terrain: this.programCache.get('terrain', TERRAIN_VS, TERRAIN_FS),
      entity: this.programCache.get('entity', ENTITY_INST_VS, ENTITY_FS),
      points: this.programCache.get('points', POINTS_VS, POINTS_FS),
      water: this.programCache.get('water', WATER_VS, WATER_FS),
      vegetation: this.programCache.get('vegetation', VEGETATION_VS, VEGETATION_FS),
      horizon: this.programCache.get('horizon', HORIZON_VS, HORIZON_FS),
      tree: this.programCache.get('tree', TREE_VS, TREE_FS),
      fire: this.programCache.get('fire', FIRE_VS, FIRE_FS),
    };
    if (this.caps.fbo) {
      this.programs.shadow = this.programCache.get('shadow', SHADOW_VS, SHADOW_FS);
    }

    this.meshes = {
      box: cubeMesh(), sphere: sphereMesh(), cone: coneMesh(),
      dome: domeMesh(), capsule: sphereMesh(6, 8),
    };
    // real geometry for the MESHED species (grass-shrub stays a point under D-O15)
    this.treeMeshes = {
      pine: treeMesh('pine'),
      broadleaf: treeMesh('broadleaf'),
    };
    this.treeMeshes.pine.handle = this.createBuffer(this.treeMeshes.pine.data);
    this.treeMeshes.broadleaf.handle = this.createBuffer(this.treeMeshes.broadleaf.data);
    for (const m of Object.values(this.meshes)) {
      m.handle = this.createBuffer(m.data); // RHI-tracked; raw buffer lives in handle.meta.gl
    }

    this.quadHandle = this.createBuffer(new Float32Array([-1, -1, 3, -1, -1, -1, 3]));
    this.quad = this.quadHandle.meta.gl;

    const seeds = new Float32Array(500);
    for (let i = 0; i < 500; i++) seeds[i] = (i + 0.5) / 500;
    this.rainHandle = this.createBuffer(seeds, { dynamic: true });
    this.rainBuffer = this.rainHandle.meta.gl;

    // water quad (world-space xz around the camera; y rebuilt as waves)
    const W = 900;
    this.waterHandle = this.createBuffer(new Float32Array([
      -W, 0, -W,  W, 0, -W,  W, 0, W,
      -W, 0, -W,  W, 0, W,  -W, 0, W,
    ]), { dynamic: true });

    // shadow target (OUR depth pass): only when the device supports FBOs
    this.shadow = null;
    if (this.caps.fbo) {
      const tex = gl.createTexture();
      gl.bindTexture(gl.TEXTURE_2D, tex);
      gl.texImage2D(gl.TEXTURE_2D, 0, GL.DEPTH_COMPONENT24, this.shadowSize, this.shadowSize, 0, gl.DEPTH_COMPONENT, gl.UNSIGNED_INT, null);
      if (gl.texParameteri) {
        gl.texParameteri(gl.TEXTURE_2D, GL.TEXTURE_MIN_FILTER, GL.NEAREST);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER ?? GL.TEXTURE_MIN_FILTER, GL.NEAREST);
      }
      const fbo = gl.createFramebuffer();
      gl.bindFramebuffer(gl.FRAMEBUFFER, fbo);
      gl.framebufferTexture2D(gl.FRAMEBUFFER, GL.DEPTH_ATTACHMENT, gl.TEXTURE_2D, tex, 0);
      const complete = gl.checkFramebufferStatus ? gl.checkFramebufferStatus(gl.FRAMEBUFFER) === (gl.FRAMEBUFFER_COMPLETE ?? GL.FRAMEBUFFER_COMPLETE) : false;
      gl.bindFramebuffer(gl.FRAMEBUFFER, null);
      this.shadow = complete ? { tex, fbo } : null;
    }
    // THE EYE ON SCREEN: a cena vai para uma textura; o POST materializa
    // fóvea, aberração cromática e o halo do glare (o que o olho faz)
    this.sceneFbo = null;
    if (this.caps.fbo && this.programs.post) {
      const tex = gl.createTexture();
      gl.bindTexture(gl.TEXTURE_2D, tex);
      gl.texImage2D(gl.TEXTURE_2D, 0, GL.RGBA, this.canvas?.width ?? 1280, this.canvas?.height ?? 720, 0, GL.RGBA, GL.UNSIGNED_BYTE, null);
      // DEPTH da cena: a acomodação (DOF) lê a distância real por pixel
      const dtex = gl.createTexture();
      gl.bindTexture(gl.TEXTURE_2D, dtex);
      gl.texImage2D(gl.TEXTURE_2D, 0, GL.DEPTH_COMPONENT24, this.canvas?.width ?? 1280, this.canvas?.height ?? 720, 0, gl.DEPTH_COMPONENT, gl.UNSIGNED_INT, null);
      const fbo = gl.createFramebuffer();
      gl.bindFramebuffer(gl.FRAMEBUFFER, fbo);
      gl.framebufferTexture2D(gl.FRAMEBUFFER, GL.COLOR_ATTACHMENT0, gl.TEXTURE_2D, tex, 0);
      gl.framebufferTexture2D(gl.FRAMEBUFFER, GL.DEPTH_ATTACHMENT, gl.TEXTURE_2D, dtex, 0);
      gl.bindFramebuffer(gl.FRAMEBUFFER, null);
      this.sceneFbo = { tex, dtex, fbo, w: this.canvas?.width ?? 1280, h: this.canvas?.height ?? 720 };
    }

    this.terrainBuffers = new Map(); // key -> {handle, meta.gl, count}
    gl.enable(gl.DEPTH_TEST);
    gl.depthFunc(gl.LEQUAL);
    gl.enable(gl.CULL_FACE);
    this.initialized = true;
  }

  prepare(frame) {
    if (!this.initialized) this.init();
    const gl = this.gl;
    const current = new Set();
    const t0 = (typeof performance !== 'undefined' && performance.now) ? performance.now() : Date.now();
    for (const patch of frame.terrain.patches) {
      const lod = patch.lod ?? 'mesh';
      const key = `${patch.id}:${patch.res}:${patch.version}:${lod}`;
      current.add(key);
      if (lod === 'fade') current.add(key + ':imp'); // fade impostor survives the sweep
      if (this.terrainBuffers.has(key)) continue;
      // GÊNESIS-LOD: distant chunks are IMPOSTORS (one quad, dominant biome);
      // near chunks are skirted meshes — cracks between rings are impossible.
      // 'fade' chunks get BOTH: the mesh + a lifted impostor that dissolves in.
      let mesh, count;
      if (lod === 'impostor') {
        mesh = buildImpostorMesh({ ...patch });
        count = mesh.count;
      } else if (lod === 'fade') {
        mesh = buildTerrainMesh({ ...patch, size: patch.size });
        const h = this.createBuffer(mesh.data);
        this.terrainBuffers.set(key, { handle: h, count: mesh.count, lod: 'mesh' });
        const imp = buildImpostorMesh({ ...patch });
        const lifted = Float32Array.from(imp.data);
        for (let v = 0; v < imp.count; v++) lifted[v * 7 + 1] += 1.5; // above the real mesh
        const hi = this.createBuffer(lifted);
        this.terrainBuffers.set(key + ':imp', { handle: hi, count: imp.count, lod: 'fade-imp' });
        this.stats.uploads += 2;
        continue;
      } else {
        mesh = buildTerrainMesh({ ...patch, size: patch.size });
        count = mesh.count;
      }
      const h = this.createBuffer(mesh.data); // single RHI-tracked upload
      this.terrainBuffers.set(key, { handle: h, count, lod });
      this.stats.uploads++;
    }
    for (const [key, res] of [...this.terrainBuffers]) {
      if (!current.has(key)) {
        this.resources.destroy(res.handle);
        this.terrainBuffers.delete(key);
      }
    }
  }

  _lightVP(frame, camFocus) {
    const sun = frame.lights.sun;
    const eye = [
      camFocus[0] + sun.dir[0] * 140,
      camFocus[1] + sun.dir[1] * 140 + 60,
      camFocus[2] + sun.dir[2] * 140,
    ];
    const proj = perspective(Math.PI / 3, 1, 10, 500);
    const view = lookAt(eye, camFocus, [0, 1, 0]);
    return multiply(proj, view);
  }

  /** raw interleaved [pos3, height, health] binding for the vegetation points */
  _bindRaw(prog, handle) {
    const gl = this.gl;
    gl.bindBuffer(gl.ARRAY_BUFFER, handle.meta.gl);
    const stride = 5 * 4;
    gl.enableVertexAttribArray(prog.a.aPos);
    gl.vertexAttribPointer(prog.a.aPos, 3, gl.FLOAT, false, stride, 0);
    if (prog.a.aHH != null && prog.a.aHH >= 0) {
      gl.enableVertexAttribArray(prog.a.aHH);
      gl.vertexAttribPointer(prog.a.aHH, 2, gl.FLOAT, false, stride, 12);
    }
  }

  /** raw interleaved [pos3, size, r, g, b, alpha] binding for horizon/film points */
  _bindHorizon(prog, handle) {
    const gl = this.gl;
    gl.bindBuffer(gl.ARRAY_BUFFER, handle.meta.gl);
    const stride = 8 * 4;
    gl.enableVertexAttribArray(prog.a.aPos);
    gl.vertexAttribPointer(prog.a.aPos, 3, gl.FLOAT, false, stride, 0);
    if (prog.a.aSC != null && prog.a.aSC >= 0) {
      gl.enableVertexAttribArray(prog.a.aSC);
      gl.vertexAttribPointer(prog.a.aSC, 4, gl.FLOAT, false, stride, 12);
    }
    if (prog.a.aAlpha != null && prog.a.aAlpha >= 0) {
      gl.enableVertexAttribArray(prog.a.aAlpha);
      gl.vertexAttribPointer(prog.a.aAlpha, 1, gl.FLOAT, false, stride, 28);
    }
  }

  _bind(prog, glBuf, stride, { normals = true, biome = false } = {}) {
    const gl = this.gl;
    gl.bindBuffer(gl.ARRAY_BUFFER, glBuf);
    const b = stride * 4;
    gl.enableVertexAttribArray(prog.a.aPos);
    gl.vertexAttribPointer(prog.a.aPos, 3, gl.FLOAT, false, b, 0);
    if (normals && prog.a.aNorm >= 0) {
      gl.enableVertexAttribArray(prog.a.aNorm);
      gl.vertexAttribPointer(prog.a.aNorm, 3, gl.FLOAT, false, b, 3 * 4);
    }
    if (biome && prog.a.aBiome != null && prog.a.aBiome >= 0) {
      gl.enableVertexAttribArray(prog.a.aBiome);
      gl.vertexAttribPointer(prog.a.aBiome, 1, gl.FLOAT, false, b, 6 * 4);
    }
  }

  /** pack visible entities into per-shape instance buffers (OUR instancing) */
  _instanceBatches(visible) {
    const byShape = new Map();
    for (const e of visible) {
      const shape = e.shape ?? 'box';
      if (!byShape.has(shape)) byShape.set(shape, []);
      byShape.get(shape).push(e);
    }
    const batches = [];
    for (const [shape, list] of byShape) {
      const data = new Float32Array(list.length * 12);
      let o = 0;
      for (const e of list) {
        const mat = e.material ?? { albedo: [0.8, 0.8, 0.8], emissive: 0, roughness: 0.8 };
        data[o++] = e.pos[0]; data[o++] = e.pos[1] ?? 0; data[o++] = e.pos[2]; data[o++] = e.yaw ?? 0;
        data[o++] = e.scale ?? 1; data[o++] = mat.albedo[0]; data[o++] = mat.albedo[1]; data[o++] = mat.albedo[2];
        data[o++] = mat.emissive ?? 0; data[o++] = mat.roughness ?? 0.8; data[o++] = 0; data[o++] = 0;
      }
      batches.push({ shape, count: list.length, data });
    }
    return batches;
  }

  _groundAt(frame, x, z) {
    for (const p of frame.terrain.patches) {
      if (x >= p.x0 && x < p.x0 + p.size && z >= p.z0 && z < p.z0 + p.size) {
        const fx = ((x - p.x0) / p.size) * p.res, fz = ((z - p.z0) / p.size) * p.res;
        const i = Math.min(p.res, Math.floor(fx)), j = Math.min(p.res, Math.floor(fz));
        return p.heights[j * (p.res + 1) + i];
      }
    }
    return 0;
  }

  draw(frame) {
    if (!this.initialized) this.init();
    const gl = this.gl;
    const env = frame.environment;
    const cam = frame.camera;
    const w = this.canvas?.width ?? 1280, h = this.canvas?.height ?? 720;
    if (this._lastSize[0] !== w || this._lastSize[1] !== h) {
      gl.viewport(0, 0, w, h);
      this._lastSize = [w, h];
    }
    this._w = w; this._h = h; this.fovDeg = cam.fovDeg ?? 60;
    // com FBO a cena vai para a textura (o POST lê e mostra a visão do olho)
    this._postOn = Boolean(this.programs?.post && this.sceneFbo);
    if (this._postOn) {
      if (this.sceneFbo.w !== w || this.sceneFbo.h !== h) {
        gl.bindTexture(gl.TEXTURE_2D, this.sceneFbo.tex);
        gl.texImage2D(gl.TEXTURE_2D, 0, GL.RGBA, w, h, 0, GL.RGBA, GL.UNSIGNED_BYTE, null);
        gl.bindTexture(gl.TEXTURE_2D, this.sceneFbo.dtex);
        gl.texImage2D(gl.TEXTURE_2D, 0, GL.DEPTH_COMPONENT24, w, h, 0, gl.DEPTH_COMPONENT, gl.UNSIGNED_INT, null);
        this.sceneFbo.w = w; this.sceneFbo.h = h;
      }
      gl.bindFramebuffer(gl.FRAMEBUFFER, this.sceneFbo.fbo);
      gl.viewport(0, 0, w, h);
    }
    const proj = perspective((cam.fovDeg * Math.PI) / 180, w / h, 0.5, cam.far ?? 600);
    const view = lookAt(cam.pos, [
      cam.pos[0] + Math.sin(cam.yaw) * Math.cos(cam.pitch),
      cam.pos[1] - Math.sin(cam.pitch) * 30,
      cam.pos[2] + Math.cos(cam.yaw) * Math.cos(cam.pitch),
    ], [0, 1, 0]);
    const vp = multiply(proj, view);
    frame._vp = vp; // culling uses the same matrix
    // camera basis for the sky integration (identical convention to lookAt):
    const cz = Math.cos(cam.pitch) * 30;
    const target = [cam.pos[0] + Math.sin(cam.yaw) * Math.cos(cam.pitch), cam.pos[1] - Math.sin(cam.pitch) * 30, cam.pos[2] + cz];
    const fl = Math.hypot(target[0]-cam.pos[0], target[1]-cam.pos[1], target[2]-cam.pos[2]) || 1;
    const f = [(target[0]-cam.pos[0])/fl, (target[1]-cam.pos[1])/fl, (target[2]-cam.pos[2])/fl];
    const rl = Math.hypot(f[2], 0, -f[0]) || 1;                 // cross(f, [0,1,0])
    const r = [f[2]/rl, 0, -f[0]/rl];
    const u = [r[1]*f[2]-r[2]*f[1], r[2]*f[0]-r[0]*f[2], r[0]*f[1]-r[1]*f[0]];
    this._camBasis = () => ({ f, r, u });

    // ---- OUR culling (frustum + distance) BEFORE anything touches the GPU
    const focus = [cam.pos[0] + Math.sin(cam.yaw) * 60, cam.pos[1], cam.pos[2] + Math.cos(cam.yaw) * 60];
    const culled = cullFrame(frame, { maxDrawDistance: cam.far ?? 600 });
    this.stats.culled = culled.culled;

    // rest positions on the represented terrain (instance data is world-space)
    for (const e of culled.visible) {
      if (e.kind !== 'aggregate') e.pos = [e.pos[0], (this._groundAt(frame, e.pos[0], e.pos[2])) + (e.kind === 'npc' ? 1.2 : e.kind === 'hazard' ? 1 : (e.scale ?? 1) * 0.5), e.pos[2]];
    }
    const batches = this.caps.instanced ? this._instanceBatches(culled.visible) : [];
    const shadowsOn = !!this.shadow && !!frame.lights?.sun?.castShadow;

    gl.clearColor(env.skyBottom[0], env.skyBottom[1], env.skyBottom[2], 1);
    gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);
    let drawCalls = 0;

    // ---- shadow depth pass (OUR shadow mapping: entities cast onto the world)
    let lightVP = null;
    if (shadowsOn) {
      lightVP = this._lightVP(frame, focus);
      const sp = this.programs.shadow;
      gl.bindFramebuffer(gl.FRAMEBUFFER, this.shadow.fbo);
      gl.viewport(0, 0, this.shadowSize, this.shadowSize);
      gl.clear(gl.DEPTH_BUFFER_BIT);
      gl.useProgram(sp.prog);
      gl.uniformMatrix4fv(sp.u.uLightVP, false, lightVP);
      for (const batch of batches) {
        if (batch.shape === 'dome') continue; // aggregates don't cast (documented)
        const mesh = this.meshes[batch.shape] ?? this.meshes.box;
        this._bindInstanced(sp, mesh.handle.meta.gl, batch.data);
        gl.drawArraysInstanced(gl.TRIANGLES, 0, mesh.count, batch.count);
        drawCalls++;
      }
      gl.bindFramebuffer(gl.FRAMEBUFFER, this._postOn ? this.sceneFbo.fbo : null);
      gl.viewport(0, 0, w, h);
      this.stats.shadowPasses++;
    }

    // ---- optical air + TRUE sun (ADR-020: the renderer integrates reality)
    // (cam basis derived below in this scope)
    const air = frame.air ?? { mie: 1, intensity: 22 };
    const sd = frame.sunDirTrue ?? frame.lights.sun.dir;

    // ---- sky
    const sky = this.programs.sky;
    gl.useProgram(sky.prog);
    // the sky is INTEGRATED per pixel from the real camera through the real air
    if (sky.u.uCamFwd) {
      const fwd = this._camBasis(vp);
      gl.uniform3f(sky.u.uCamFwd, fwd.f[0], fwd.f[1], fwd.f[2]);
      gl.uniform3f(sky.u.uCamRight, fwd.r[0], fwd.r[1], fwd.r[2]);
      gl.uniform3f(sky.u.uCamUp, fwd.u[0], fwd.u[1], fwd.u[2]);
      gl.uniform1f(sky.u.uTanF, Math.tan((this.fovDeg ?? 60) * Math.PI / 180 / 2));
      gl.uniform1f(sky.u.uAspect, (this._w || 1) / (this._h || 1));
      gl.uniform3f(sky.u.uSunDir, sd[0], sd[1], sd[2]);
      gl.uniform1f(sky.u.uAirMie, air.mie); gl.uniform1f(sky.u.uAirI, air.intensity);
      // clouds: coverage FROM the represented air (causal), seed drifts with the day
      if (sky.u.uCloudCov) {
        gl.uniform1f(sky.u.uCloudCov, frame.clouds?.coverage ?? 0);
        gl.uniform1f(sky.u.uCloudSeed, frame.clouds?.seedT ?? 0);
        gl.uniform3f(sky.u.uCamPos, cam.pos[0], cam.pos[1], cam.pos[2]);
      }
      if (sky.u.uExposure) gl.uniform1f(sky.u.uExposure, frame.exposure ?? 1);
      if (sky.u.uSmoke && gl.uniform4fv) {
        // FUMAÇA SOLUÇÃO PRIMEIRO (o solver 3D), fogos analíticos de
        // horizonte completam as 4 vagas (D-O15: nada é descartado)
        const near = (frame.smoke3d ?? []).map((c) => ({ pos: c.pos, intensity: c.intensity }));
        const far = [...near, ...(frame.horizon ?? []).filter(hz => hz.kind === 'fire')].slice(0, 4);
        const buf = new Float32Array(16);
        for (let i = 0; i < far.length; i++) {
          buf.set([far[i].pos[0], far[i].pos[1], far[i].pos[2], far[i].intensity ?? 0.5], i * 4);
        }
        gl.uniform4fv(sky.u.uSmoke, buf);
        gl.uniform1i(sky.u.uSmokeN, far.length);
        gl.uniform1f(sky.u.uSmokeWind, env.wind ?? 0.2);
        gl.uniform2f(sky.u.uSmokeDir, env.windDir?.[0] ?? 1, env.windDir?.[1] ?? 0);
        if (sky.u.uTime0) gl.uniform1f(sky.u.uTime0, frame.time ?? 0);
      if (sky.u.uRainbow) gl.uniform1f(sky.u.uRainbow, frame.rainbow ?? 0);
      }
    }
    gl.uniform3f(sky.u.uSkyTop, env.skyTop[0], env.skyTop[1], env.skyTop[2]);
    gl.uniform3f(sky.u.uSkyBottom, env.skyBottom[0], env.skyBottom[1], env.skyBottom[2]);
    gl.uniform1f(sky.u.uFlash, env.flash ?? 0);
    gl.depthMask(false);
    this._bind(sky, this.quad, 2, { normals: false });
    gl.drawArrays(gl.TRIANGLES, 0, 3);
    gl.depthMask(true);
    drawCalls++;

    // ---- shared lighting uniforms
    const bindLights = (p) => {
      gl.uniform3f(p.u.uSunDir, frame.lights.sun.dir[0], frame.lights.sun.dir[1], frame.lights.sun.dir[2]);
      if (p.u.uAirMie) { gl.uniform1f(p.u.uAirMie, air.mie); gl.uniform1f(p.u.uAirI, air.intensity); }
      if (p.u.uAirFog) gl.uniform1f(p.u.uAirFog, air.fogH ?? 0); // névoa de radiação no ar
      if (p.u.uExposure) gl.uniform1f(p.u.uExposure, frame.exposure ?? 1); // the eye's real gain
      if (p.u.uEyeTint) { const tnt = frame.vision?.tint ?? [1, 1, 1]; gl.uniform3f(p.u.uEyeTint, tnt[0], tnt[1], tnt[2]); }
      // EYE ORGAN: veil (óptica) + afterimage (retina) + supressão sacádica
      if (p.u.uVeil) gl.uniform1f(p.u.uVeil, frame.vision?.veil ?? 0);
      if (p.u.uAfter) { const af = frame.vision?.after ?? [0, 0, 0]; gl.uniform3f(p.u.uAfter, af[0], af[1], af[2]); }
      // STYLE LENS: os parâmetros do estilo dito no chat (identidade se null)
      const stl = frame.style;
      if (p.u.uStyleSat) gl.uniform1f(p.u.uStyleSat, stl?.sat ?? 1);
      if (p.u.uStyleCon) gl.uniform1f(p.u.uStyleCon, stl?.contrast ?? 1);
      if (p.u.uStyleBands) gl.uniform1f(p.u.uStyleBands, stl?.bands ?? 0);
      if (p.u.uStyleRim) gl.uniform1f(p.u.uStyleRim, stl?.rim ?? 0);
      if (p.u.uStyleTint) { const ct = stl?.tint ?? [1, 1, 1]; gl.uniform3f(p.u.uStyleTint, ct[0], ct[1], ct[2]); }
      gl.uniform3f(p.u.uSunColor, frame.lights.sun.color[0], frame.lights.sun.color[1], frame.lights.sun.color[2]);
      gl.uniform1f(p.u.uAmbient, frame.lights.sun.ambient);
      if (p.u.uLightVP) gl.uniformMatrix4fv(p.u.uLightVP, false, lightVP ?? identity());
      if (p.u.uShadowOn) gl.uniform1f(p.u.uShadowOn, shadowsOn ? 1 : 0);
      if (p.u.uShadowMap) {
        if (gl.activeTexture) { gl.activeTexture(gl.TEXTURE0 ?? 0x84C0); gl.bindTexture(gl.TEXTURE_2D, this.shadow?.tex ?? null); }
        gl.uniform1i(p.u.uShadowMap, 0);
      }
      const pts = frame.lights.points.slice(0, 4);
      const n = Math.min(4, pts.length);
      if (p.u.uPointCount) gl.uniform1i(p.u.uPointCount, n);
      for (let i = 0; i < 4; i++) {
        const L = pts[i];
        const posU = p.u[`uPointPos[${i}]`], colU = p.u[`uPointColor[${i}]`];
        if (posU) {
          if (L) gl.uniform3f(posU, L.pos[0], L.pos[1], L.pos[2]);
          else gl.uniform3f(posU, 0, -1000, 0);
        }
        if (colU) {
          if (L) gl.uniform3f(colU, L.color[0], L.color[1], L.color[2]);
          else gl.uniform3f(colU, 0, 0, 0);
        }
      }
    };

    // ---- terrain (manifestation of streamed represented patches)
    const terr = this.programs.terrain;
    gl.useProgram(terr.prog);
    gl.uniformMatrix4fv(terr.u.uVP, false, vp);
    bindLights(terr);
    gl.uniform3f(terr.u.uSkyBottom, env.skyBottom[0], env.skyBottom[1], env.skyBottom[2]);
    gl.uniform1f(terr.u.uFog, env.fog);
    gl.uniform1f(terr.u.uWetness, env.wetness);
    if (terr.u.uCloudCov) {
      gl.uniform1f(terr.u.uCloudCov, frame.clouds?.coverage ?? 0);
      gl.uniform1f(terr.u.uCloudSeed, frame.clouds?.seedT ?? 0);
    }
    gl.uniform3f(terr.u.uCamPos, cam.pos[0], cam.pos[1], cam.pos[2]);
    if (terr.u.uAlpha) gl.uniform1f(terr.u.uAlpha, 1);
    for (const patch of frame.terrain.patches) {
      const lod = patch.lod ?? 'mesh';
      const key = `${patch.id}:${patch.res}:${patch.version}:${lod}`;
      const res = this.terrainBuffers.get(lod === 'fade' ? key : key) ?? this.terrainBuffers.get(key);
      const entry = res ?? this.terrainBuffers.get(key);
      if (!entry) continue;
      this._bind(terr, entry.handle.meta.gl, 7, { normals: true, biome: true });
      gl.drawArrays(gl.TRIANGLES, 0, entry.count);
      drawCalls++;
      if (lod === 'impostor') this.stats.impostors++;
      this.stats.terrainTris += entry.count / 3;
    }
    // ---- impostor cross-fade pass (alpha dissolves the mesh away)
    const fadeMeta = frame.terrain.impostorAfter ?? 150;
    const fadeLen = frame.terrain.fade ?? 50;
    const fading = (frame.terrain.patches ?? []).filter(p => p.lod === 'fade');
    if (fading.length > 0) {
      gl.enable(gl.BLEND);
      if (gl.blendFunc) gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);
      for (const patch of fading) {
        const key = `${patch.id}:${patch.res}:${patch.version}:fade:imp`;
        const entry = this.terrainBuffers.get(key);
        if (!entry) continue;
        const a = Math.min(1, Math.max(0, ((patch.dist ?? fadeMeta) - fadeMeta) / fadeLen));
        if (terr.u.uAlpha) gl.uniform1f(terr.u.uAlpha, a);
        this._bind(terr, entry.handle.meta.gl, 7, { normals: true, biome: true });
        gl.drawArrays(gl.TRIANGLES, 0, entry.count);
        drawCalls++;
        this.stats.fadePasses = (this.stats.fadePasses ?? 0) + 1;
      }
      if (terr.u.uAlpha) gl.uniform1f(terr.u.uAlpha, 1);
      gl.disable(gl.BLEND);
    }

    // ---- entities: OUR instanced path (fallback: per-entity draws)
    const ent = this.programs.entity;
    gl.useProgram(ent.prog);
    gl.uniformMatrix4fv(ent.u.uVP, false, vp);
    bindLights(ent);
    gl.uniform3f(ent.u.uSkyBottom, env.skyBottom[0], env.skyBottom[1], env.skyBottom[2]);
    gl.uniform1f(ent.u.uFog, env.fog);
    gl.uniform3f(ent.u.uCamPos, cam.pos[0], cam.pos[1], cam.pos[2]);
    if (this.caps.instanced) {
      for (const batch of batches) {
        const mesh = this.meshes[batch.shape] ?? this.meshes.box;
        this._bindInstanced(ent, mesh.handle.meta.gl, batch.data);
        gl.drawArraysInstanced(gl.TRIANGLES, 0, mesh.count, batch.count);
        drawCalls++;
        this.stats.instances += batch.count;
        this.stats.batches++;
      }
    } else {
      for (const e of culled.visible) {
        const mesh = this.meshes[e.shape ?? 'box'] ?? this.meshes.box;
        const mat = e.material ?? { albedo: [0.8, 0.8, 0.8], emissive: 0, roughness: 0.8 };
        const data = new Float32Array(12);
        data[0] = e.pos[0]; data[1] = e.pos[1] ?? 0; data[2] = e.pos[2]; data[3] = e.yaw ?? 0;
        data[4] = e.scale ?? 1; data[5] = mat.albedo[0]; data[6] = mat.albedo[1]; data[7] = mat.albedo[2];
        data[8] = mat.emissive ?? 0; data[9] = mat.roughness ?? 0.8;
        this._bindInstanced(ent, mesh.handle.meta.gl, data);
        if (this.caps.instanced) gl.drawArraysInstanced(gl.TRIANGLES, 0, mesh.count, 1);
        else gl.drawArrays(gl.TRIANGLES, 0, mesh.count);
        drawCalls++;
        this.stats.instances++;
      }
    }

    // ---- FIRE: blackbody particles emitted by the combustion field
    // (additive emission — the fire IS light; smoke scatters the real sky)
    const fires = culled.visible.filter(e => e.kind === 'hazard' && e.fire);
    if (fires.length > 0) {
      const wd3 = [...(env.windDir ?? [1, 0]), 0];
      const parts = emitFireParticles(fires.map(fl => ({ ...fl.fire, pos: fl.pos, id: fl.id })), frame.time ?? 0, env.wind ?? 0.2, wd3, air, sd);
      if (parts.length > 0) {
        const fireP = this.programs.fire;
        gl.useProgram(fireP.prog);
        gl.uniformMatrix4fv(fireP.u.uVP, false, vp);
        gl.uniform1f(fireP.u.uPointScale, (this.canvas?.height ?? 720) * 0.9);
        if (!this._fireHandle) this._fireHandle = this.createBuffer(parts, { dynamic: true });
        else { gl.bindBuffer(gl.ARRAY_BUFFER, this._fireHandle.meta.gl); gl.bufferData(gl.ARRAY_BUFFER, parts, GL.DYNAMIC_DRAW); }
        this._bindHorizon(fireP, this._fireHandle);
        gl.enable(gl.BLEND);
        if (gl.blendFunc) gl.blendFunc(gl.SRC_ALPHA, gl.ONE); // additive: energy adds
        gl.depthMask(false);
        gl.drawArrays(gl.POINTS, 0, parts.length / 8);
        gl.depthMask(true);
        gl.disable(gl.BLEND);
        drawCalls++;
        this.stats.fireParticles = (this.stats.fireParticles ?? 0) + parts.length / 8;
      }
    }

    // ---- water: OUR animated sea (GPU waves, fresnel, sun specular)
    const seaLevel = frame.terrain?.seaLevel;
    if (seaLevel != null && this.waterHandle) {
      const wat = this.programs.water;
      gl.useProgram(wat.prog);
      gl.uniformMatrix4fv(wat.u.uVP, false, vp);
      gl.uniform2f(wat.u.uCenter, cam.pos[0], cam.pos[2]); // SCALE: sea follows, waves world-fixed
      gl.uniform1f(wat.u.uTime, (frame.time ?? 0) % 1000);
      if (wat.u.uWindDir) { gl.uniform2f(wat.u.uWindDir, env.windDir?.[0] ?? 1, env.windDir?.[1] ?? 0); gl.uniform1f(wat.u.uWind, env.wind ?? 0.2); }
      gl.uniform1f(wat.u.uSeaLevel, seaLevel);
      gl.uniform1f(wat.u.uWind, frame.environment.wind ?? 0);
      gl.uniform3f(wat.u.uSunDir, frame.lights.sun.dir[0], frame.lights.sun.dir[1], frame.lights.sun.dir[2]);
      gl.uniform3f(wat.u.uSunColor, frame.lights.sun.color[0], frame.lights.sun.color[1], frame.lights.sun.color[2]);
      gl.uniform1f(wat.u.uAmbient, frame.lights.sun.ambient);
      gl.uniform3f(wat.u.uSkyBottom, env.skyBottom[0], env.skyBottom[1], env.skyBottom[2]);
      gl.uniform1f(wat.u.uFog, env.fog);
      gl.uniform1f(wat.u.uWetness, env.wetness);
      gl.uniform3f(wat.u.uCamPos, cam.pos[0], cam.pos[1], cam.pos[2]);
      gl.uniform1f(wat.u.uAlpha, 0.8);
      // A TERRA NO ESPELHO + a chuva quebrando a superfície
      if (wat.u.uTerrSeed) gl.uniform1f(wat.u.uTerrSeed, frame.terrainSeed ?? 0);
      if (wat.u.uRain) gl.uniform1f(wat.u.uRain, env.rain ?? 0);
      if (wat.u.uBio) gl.uniform1f(wat.u.uBio, env.bioGlow ?? 0); // a vida no mar, ao vivo
      gl.enable(gl.BLEND);
      if (gl.blendFunc) gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);
      gl.depthMask(false);
      this._bind(wat, this.waterHandle.meta.gl, 3, { normals: false });
      gl.drawArrays(gl.TRIANGLES, 0, 6);
      gl.depthMask(true);
      gl.disable(gl.BLEND);
      drawCalls++;
      this.stats.waterDraws = (this.stats.waterDraws ?? 0) + 1;
    }

    // ---- precipitation (phenomena from represented state)
    const density = Math.max(env.rain, env.dust) * (frame.stats.particles ?? 1);
    if (density > 0.02) {
      const pts = this.programs.points;
      gl.useProgram(pts.prog);
      gl.uniformMatrix4fv(pts.u.uVP, false, vp);
      gl.uniform3f(pts.u.uCamPos, cam.pos[0], cam.pos[1], cam.pos[2]);
      gl.uniform1f(pts.u.uTime, frame.time);
      gl.uniform1f(pts.u.uWind, env.wind);
      const effDensity = Math.min(1, density);
      gl.uniform1f(pts.u.uCount, 500 * effDensity);
      // D-O15 RE-REPRESENTATION under pressure: fewer particles but each one
      // bigger + faster — the PERCEIVED intensity is preserved (streaks/sheets),
      // never a thinning drizzle just because the GPU is busy.
      const comp = 1 / Math.sqrt(Math.max(0.15, effDensity));
      gl.uniform1f(pts.u.uSize, 2.2 * comp);
      gl.uniform1f(pts.u.uFall, Math.min(2.2, comp));
      const color = env.dust > env.rain ? [0.75, 0.65, 0.45] : [0.6, 0.7, 0.9];
      gl.uniform3f(pts.u.uColor, color[0], color[1], color[2]);
      gl.enable(gl.BLEND);
      if (gl.blendFunc) gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);
      this._bind(pts, this.rainBuffer, 1, { normals: false });
      gl.drawArrays(gl.POINTS, 0, 500);
      gl.disable(gl.BLEND);
      drawCalls++;
    }

    // ---- TREES: the pine population as REAL geometry (health colors the
    // canopy; wind bends it; the SAME aerial air surrounds it)
    const meshedTrees = (frame.vegetation ?? []).filter(t => t.species === 'pine' || t.species === 'broadleaf');
    for (const spName of ['pine', 'broadleaf']) {
      const pines = meshedTrees.filter(t => t.species === spName);
      const treeMesh = this.treeMeshes[spName];
      if (pines.length === 0 || !treeMesh) continue;
      {
      const tree = this.programs.tree;
      gl.useProgram(tree.prog);
      gl.uniformMatrix4fv(tree.u.uVP, false, vp);
      gl.uniform1f(tree.u.uTime, frame.time ?? 0);
      if (tree.u.uWindDir) gl.uniform2f(tree.u.uWindDir, env.windDir?.[0] ?? 1, env.windDir?.[1] ?? 0);
      bindLights(tree);
      gl.uniform3f(tree.u.uCamPos, cam.pos[0], cam.pos[1], cam.pos[2]);
      const data = new Float32Array(pines.length * 8);
      let o = 0;
      for (const t of pines) {
        let ph = 0; for (let i = 0; i < String(t.id).length; i++) ph = (ph * 31 + String(t.id).charCodeAt(i)) % 97;
        data[o++] = t.pos[0]; data[o++] = t.pos[1]; data[o++] = t.pos[2]; data[o++] = t.height;
        data[o++] = t.health ?? 1; data[o++] = env.wind ?? 0.2; data[o++] = ph; data[o++] = 0;
      }
      if (!this._treeInstHandle) { this._treeInstHandle = this.createBuffer(data, { dynamic: true }); this._treeInstBuf = this._treeInstHandle.meta.gl; }
      else { gl.bindBuffer(gl.ARRAY_BUFFER, this._treeInstBuf); gl.bufferData(gl.ARRAY_BUFFER, data, GL.DYNAMIC_DRAW); }
      // mesh: [pos3, norm3, canopy1] stride 7 — instances: [pos3,h, health,wind,phase,pad] stride 8
      gl.bindBuffer(gl.ARRAY_BUFFER, treeMesh.handle.meta.gl);
      gl.enableVertexAttribArray(tree.a.aPos);
      gl.vertexAttribPointer(tree.a.aPos, 3, gl.FLOAT, false, 7 * 4, 0);
      if (tree.a.aNorm >= 0) { gl.enableVertexAttribArray(tree.a.aNorm); gl.vertexAttribPointer(tree.a.aNorm, 3, gl.FLOAT, false, 7 * 4, 3 * 4); }
      gl.enableVertexAttribArray(tree.a.aCanopy); gl.vertexAttribPointer(tree.a.aCanopy, 1, gl.FLOAT, false, 7 * 4, 6 * 4);
      gl.bindBuffer(gl.ARRAY_BUFFER, this._treeInstBuf);
      const div = gl.vertexAttribDivisor ? gl.vertexAttribDivisor.bind(gl) : () => {};
      if (gl.drawArraysInstanced) {
        div(tree.a.aT0, 1); gl.vertexAttribPointer(tree.a.aT0, 4, gl.FLOAT, false, 8 * 4, 0);
        div(tree.a.aT1, 1); gl.vertexAttribPointer(tree.a.aT1, 4, gl.FLOAT, false, 8 * 4, 4 * 4);
        gl.drawArraysInstanced(gl.TRIANGLES, 0, treeMesh.count, pines.length);
        this.stats.treeInstances = (this.stats.treeInstances ?? 0) + pines.length;
        div(tree.a.aT0, 0); div(tree.a.aT1, 0);
        drawCalls++;
      } else {
        // sem instancing: UMA malha por árvore (mesma física, custo maior)
        div(tree.a.aT0, 0); gl.vertexAttribPointer(tree.a.aT0, 4, gl.FLOAT, false, 8 * 4, 0);
        div(tree.a.aT1, 0); gl.vertexAttribPointer(tree.a.aT1, 4, gl.FLOAT, false, 8 * 4, 4 * 4);
        const one = new Float32Array(8);
        for (const t of pines) {
          one[0] = t.pos[0]; one[1] = t.pos[1]; one[2] = t.pos[2]; one[3] = t.height;
          one[4] = t.health ?? 1; one[5] = env.wind ?? 0.2;
          let ph = 0; for (let i = 0; i < String(t.id).length; i++) ph = (ph * 31 + String(t.id).charCodeAt(i)) % 97;
          one[6] = ph; one[7] = 0;
          gl.bindBuffer(gl.ARRAY_BUFFER, this._treeInstBuf);
          gl.bufferData(gl.ARRAY_BUFFER, one, GL.DYNAMIC_DRAW);
          gl.drawArrays(gl.TRIANGLES, 0, treeMesh.count);
          this.stats.treeInstances = (this.stats.treeInstances ?? 0) + 1;
          drawCalls++;
        }
      }
      }
    }

    // ---- VEGETATION (ecology population materialized under D-O15)
    if (frame.vegetation && frame.vegetation.length > 0) {
      const veg = this.programs.vegetation;
      gl.useProgram(veg.prog);
      gl.uniformMatrix4fv(veg.u.uVP, false, vp);
      gl.uniform1f(veg.u.uPointScale, (this.canvas?.height ?? 720) * 0.9);
      const shrubs = frame.vegetation.filter(t => t.species !== 'pine'); // pines are REAL mesh above
      if (shrubs.length > 0) {
      const data = new Float32Array(shrubs.length * 5);
      for (let i = 0; i < shrubs.length; i++) {
        const t = shrubs[i];
        data.set([t.pos[0], t.pos[1], t.pos[2], t.height, t.health], i * 5);
      }
      if (!this._vegHandle) this._vegHandle = this.createBuffer(data, { dynamic: true });
      else { gl.bindBuffer(gl.ARRAY_BUFFER, this._vegHandle.meta.gl); gl.bufferData(gl.ARRAY_BUFFER, data, GL.DYNAMIC_DRAW); }
      this._bindRaw(veg, this._vegHandle);
      gl.enable(gl.BLEND);
      if (gl.blendFunc) gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);
      gl.drawArrays(gl.POINTS, 0, shrubs.length);
      }
      gl.disable(gl.BLEND);
      drawCalls++;
      this.stats.vegDraws = (this.stats.vegDraws ?? 0) + 1;
    }

    // ---- FILM + BURN SCARS + HORIZON (scale materialized; shared program)
    const film = frame.waterFilm ?? [];
    const horizon = frame.horizon ?? [];
    const burnt = frame.burntGround ?? [];
    if (film.length + horizon.length + burnt.length > 0) {
      const hor = this.programs.horizon;
      gl.useProgram(hor.prog);
      gl.uniformMatrix4fv(hor.u.uVP, false, vp);
      gl.uniform1f(hor.u.uPointScale, (this.canvas?.height ?? 720) * 0.9);
      gl.uniform1f(hor.u.uTime, frame.time ?? 0);
      const data = new Float32Array((film.length + horizon.length + burnt.length) * 8);
      let n = 0;
      for (const f of film) {
        const k = Math.min(1, f.depth * 30);
        data.set([f.pos[0], f.pos[1], f.pos[2], 16 + k * 14, 0.32, 0.46, 0.6, 0.25 + k * 0.5], n * 8); n++;
      }
      for (const b of burnt) {
        // fresh ash is dark charcoal; it FADES with its own age (real timescale)
        data.set([b.pos[0], b.pos[1], b.pos[2], 26, 0.14, 0.12, 0.11, 0.5 * b.alpha], n * 8); n++;
      }
      for (const h of horizon) {
        data.set([h.pos[0], h.pos[1], h.pos[2], h.size, h.color[0], h.color[1], h.color[2], h.alpha], n * 8); n++;
      }
      if (!this._horHandle) this._horHandle = this.createBuffer(data, { dynamic: true });
      else { gl.bindBuffer(gl.ARRAY_BUFFER, this._horHandle.meta.gl); gl.bufferData(gl.ARRAY_BUFFER, data, GL.DYNAMIC_DRAW); }
      this._bindHorizon(hor, this._horHandle);
      gl.enable(gl.BLEND);
      if (gl.blendFunc) gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);
      gl.depthMask(false);
      gl.drawArrays(gl.POINTS, 0, n);
      gl.depthMask(true);
      gl.disable(gl.BLEND);
      drawCalls++;
      this.stats.horizonDraws = (this.stats.horizonDraws ?? 0) + 1;
    }

    this.stats.drawCalls += drawCalls;
    this.stats.frames++;
    // ---- POST: a óptica do OLHO materializada (fóvea, aberração, halo)
    if (this._postOn) {
      gl.bindFramebuffer(gl.FRAMEBUFFER, null);
      gl.viewport(0, 0, w, h);
      gl.disable(gl.DEPTH_TEST);
      const post = this.programs.post;
      gl.useProgram(post.id);
      gl.bindBuffer(gl.ARRAY_BUFFER, this.quad);
      gl.enableVertexAttribArray(0);
      gl.vertexAttribPointer(0, 2, gl.FLOAT, false, 0, 0);
      if (gl.activeTexture) gl.activeTexture(gl.TEXTURE0 ?? GL.TEXTURE0);
      gl.bindTexture(gl.TEXTURE_2D, this.sceneFbo.tex);
      gl.uniform1i(post.u.uScene, 0);
      gl.uniform1f(post.u.uFovRad, ((cam.fovDeg ?? 60) * Math.PI) / 180);
      gl.uniform1f(post.u.uGlareE, frame.vision?.glare ?? 0);
      gl.uniform1f(post.u.uCAFrac, frame.vision?.caFrac ?? 0);
      gl.uniform2f(post.u.uTexel, 1 / w, 1 / h);
      // ACOMODAÇÃO + LENTE: depth real, pupila do olho, vinheta cos⁴ e grão do estilo
      if (post.u.uDepth) { if (gl.activeTexture) gl.activeTexture(gl.TEXTURE1 ?? (GL.TEXTURE0 + 1)); gl.bindTexture(gl.TEXTURE_2D, this.sceneFbo.dtex); gl.uniform1i(post.u.uDepth, 1); if (gl.activeTexture) gl.activeTexture(gl.TEXTURE0 ?? GL.TEXTURE0); }
      gl.uniform1f(post.u.uPupil, frame.vision?.pupilMM ?? 5);
      gl.uniform1f(post.u.uNear, 0.5);
      gl.uniform1f(post.u.uFar, cam.far ?? 600);
      gl.uniform1f(post.u.uVignette, frame.style?.vignette ?? 0);
      gl.uniform1f(post.u.uGrain, frame.style?.grain ?? 0);
      gl.uniform1f(post.u.uBloomE, frame.style?.bloom ?? 0);
      gl.uniform1f(post.u.uTone, frame.style?.tone ?? 0);
      gl.uniform1f(post.u.uSharp, frame.style?.sharp ?? 0);
      gl.uniform1f(post.u.uCAExtra, frame.style?.ca ?? 0);
      gl.uniform1f(post.u.uTime, frame.tick ?? 0);
      gl.drawArrays(gl.TRIANGLES, 0, 3);
      gl.enable(gl.DEPTH_TEST);
      drawCalls++;
    }
    return { drawCalls, instances: this.caps.instanced ? culled.visible.length : 0, culled: culled.culled, shadows: shadowsOn };
  }

  /** bind mesh + instance attributes for the instanced path */
  _bindInstanced(prog, glBuf, instanceData) {
    const gl = this.gl;
    const meshBuf = glBuf;
    const stride = 7 * 4;
    gl.bindBuffer(gl.ARRAY_BUFFER, meshBuf);
    gl.enableVertexAttribArray(prog.a.aPos);
    gl.vertexAttribPointer(prog.a.aPos, 3, gl.FLOAT, false, stride, 0);
    if (prog.a.aNorm >= 0) {
      gl.enableVertexAttribArray(prog.a.aNorm);
      gl.vertexAttribPointer(prog.a.aNorm, 3, gl.FLOAT, false, stride, 3 * 4);
    }
    if (!this._instanceHandle) {
      this._instanceHandle = this.createBuffer(new Float32Array(12), { dynamic: true });
      this._instanceBuffer = this._instanceHandle.meta.gl;
    }
    gl.bindBuffer(gl.ARRAY_BUFFER, this._instanceBuffer);
    gl.bufferData(gl.ARRAY_BUFFER, instanceData, GL.DYNAMIC_DRAW);
    const float = gl.FLOAT;
    for (const [loc, size, offset] of [[prog.a.aInst0, 4, 0], [prog.a.aInst1, 4, 16], [prog.a.aInst2, 4, 32]]) {
      if (loc == null || loc < 0) continue;
      gl.enableVertexAttribArray(loc);
      gl.vertexAttribPointer(loc, size, float, false, 48, offset);
      if (gl.vertexAttribDivisor) gl.vertexAttribDivisor(loc, 1);
    }
  }

  render(frame) {
    // A LENTE DE CENA VIVA: o smith de cena gerou GLSL de superfície → o
    // programa do TERRENO é recompilado com a composição (novo shader real)
    if (!this.initialized) this.init(); // o render é autossuficiente (contrato dos hosts)
    const surf = frame?.style?.surface ?? null;
    const hash = surf?.glsl ? surf.hash : null;
    if (hash !== this._surfHash) {
      this._surfHash = hash;
      this.programs.terrain = hash
        ? this.programCache.get('terrain:surf:' + hash, TERRAIN_VS, terrainFS(surf.glsl))
        : this.programCache.get('terrain', TERRAIN_VS, TERRAIN_FS);
    }
    this.prepare(frame);
    return this.draw(frame);
  }

  destroy() {
    this.resources.destroyAll(); // frees every RHI-tracked buffer (meshes, terrain, quad, rain)
    for (const m of Object.values(this.meshes ?? {})) m.handle = null;
    this.terrainBuffers?.clear();
    this.programCache?.programs.clear();
    const gl = this.gl;
    if (this.shadow && gl) {
      if (typeof gl.deleteFramebuffer === 'function') gl.deleteFramebuffer(this.shadow.fbo);
      if (typeof gl.deleteTexture === 'function') gl.deleteTexture(this.shadow.tex);
    }
    this.programs = null;
    this.shadow = null;
    this.quad = null;
    this.rainBuffer = null;
    this.waterHandle = null;
    this._instanceBuffer = null;
    this._instanceHandle = null;
    this.initialized = false;
  }
}
