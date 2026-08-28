// UTS :: test/genesis-render — OUR RHI, materials, lighting, culling,
// instancing, shadow mapping, streaming. Native systems, honest fallbacks.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createUTS } from '../src/index.js';
import { GPUResourceManager, RHIError } from '../src/render/rhi.js';
import { MaterialLibrary } from '../src/render/materials.js';
import { frustumPlanes, sphereVisible, cullFrame } from '../src/render/culling.js';
import { WebGL2Renderer } from '../src/render/webgl2.js';

test('rhi: resource manager tracks, sizes, frees; leak report works', () => {
  const rm = new GPUResourceManager();
  const a = rm.create('buffer', 1024, {}, () => {});
  const b = rm.create('texture', 512, {}, () => {});
  assert.equal(rm.count(), 2);
  assert.equal(rm.liveBytes(), 1536);
  assert.ok(rm.stats.peakBytes >= 1536);
  assert.equal(rm.destroy(a), true);
  assert.equal(rm.destroy(a), false, 'double free rejected');
  assert.equal(rm.liveBytes(), 512);
  assert.deepEqual(rm.leakReport().map(r => r.id), [b.id]);
  rm.destroyAll();
  assert.equal(rm.count(), 0);
});

test('rhi: renderer rejects non-device contexts', () => {
  assert.throws(() => new WebGL2Renderer({}), RHIError);
});

test('materials: OUR library resolves kinds with dynamic emissive (fire)', () => {
  const lib = new MaterialLibrary();
  const fire = lib.resolve('hazard', { emissive: 0.8 });
  assert.equal(fire.emissive, 0.8);
  assert.equal(lib.resolve('npc').castShadows, true);
  assert.equal(lib.resolve('aggregate').castShadows, false, 'population blobs do not cast');
  const unknown = lib.resolve('alien-thing');
  assert.ok(unknown.albedo, 'unknown kinds fall back to the prop material');
  assert.ok(fire.roughness > 0 && fire.roughness <= 1);
});

test('culling: frustum math is exact (planes, spheres)', () => {
  // identity VP -> unit cube frustum planes
  const I = new Float32Array(16);
  for (let i = 0; i < 16; i++) I[i] = (i % 5 === 0 ? 1 : 0);
  const planes = frustumPlanes(I);
  assert.equal(planes.length, 6);
  assert.equal(sphereVisible(planes, 0, 0, 0, 0.5), true);
  assert.equal(sphereVisible(planes, 9, 0, 0, 0.5), false, 'outside +x bound');
  assert.equal(sphereVisible(planes, 1.4, 0, 0, 0.5), true, 'sphere crossing the boundary plane is still visible (radius hysteresis)');
});

test('culling: cullFrame counts honestly and respects maxDrawDistance', () => {
  const frame = {
    camera: { pos: [0, 20, 0] },
    entities: [
      { pos: [5, 0, 0], kind: 'npc', scale: 1.7 },
      { pos: [2000, 0, 0], kind: 'npc', scale: 1.7 },
    ],
    aggregates: [],
  };
  const r = cullFrame(frame, { maxDrawDistance: 300 });
  assert.equal(r.visible.length, 1);
  assert.equal(r.distanceCulled, 1);
  assert.equal(r.total, 2);
});

test('lighting: fire hazards become point lights; distance culls; D-O15 reduces', async () => {
  const uts = createUTS({ seed: 'lights' });
  const strike = uts.rrw.emitEvent({ type: 'reallife.lightning.strike', cause: null, data: {}, tick: 0 });
  uts.world.reallife.igniteFire([500, 0, 500], strike);
  uts.rrw.getComponent([...uts.world.physics.bodies.keys()][0] ?? 'e1', 'spatial'); // no-op guard

  const near = uts.world.lighting.collect(uts.world, [502, 20, 502], { shadows: true });
  assert.equal(near.points.length, 1);
  assert.equal(near.points[0].kind, 'fire');
  assert.ok(near.points[0].intensity > 0);
  assert.equal(near.sun.castShadow, true);

  const far = uts.world.lighting.collect(uts.world, [900, 20, 900], { shadows: true });
  assert.equal(far.points.length, 0, 'far fires do not become lights');

  const reduced = uts.world.lighting.collect(uts.world, [502, 20, 502], { shadows: false });
  assert.equal(reduced.stats.reduced, true, 'D-O15 pressure reduces light budget');
});

test('webgl2: gênesis pipeline — instancing, shadows, culling, tracked resources', async () => {
  const C = { VERTEX_SHADER: 1, FRAGMENT_SHADER: 2 };
  const buffers = new Set(); const programs = [];
  let bufN = 0;
  const uniforms = new Map();
  const gl = {
    ...C,
    canvas: { width: 1280, height: 720 },
    DEPTH_COMPONENT: 30, UNSIGNED_INT: 31, TEXTURE_MAG_FILTER: 32, FRAMEBUFFER_COMPLETE: 33, TEXTURE0: 0x84C0,
    createShader: t => ({ t }), shaderSource: () => {}, compileShader: () => {},
    getShaderParameter: () => true, getShaderInfoLog: () => '', deleteShader: () => {},
    createProgram: () => { const p = { id: programs.length }; programs.push(p); return p; },
    attachShader: () => {}, linkProgram: () => {}, getProgramParameter: () => true, deleteProgram: () => {},
    getUniformLocation: (p, n) => { const k = p.id + ':' + n; if (!uniforms.has(k)) uniforms.set(k, { name: n }); return uniforms.get(k); },
    getAttribLocation: (p, n) => ({ aPos: 0, aNorm: 1, aBiome: 2, aSeed: 0, aInst0: 3, aInst1: 4, aInst2: 5 })[n] ?? -1,
    createBuffer: () => ({ id: ++bufN }), bindBuffer: () => {}, bufferData: () => {}, deleteBuffer: b => buffers.delete(b),
    enable: () => {}, disable: () => {}, depthFunc: () => {}, depthMask: () => {}, blendFunc: () => {},
    clearColor: () => {}, clear: () => {}, viewport: () => {}, useProgram: () => {},
    uniformMatrix4fv: () => {}, uniform3f: () => {}, uniform1f: () => {}, uniform1i: () => {},
    vertexAttribPointer: () => {}, enableVertexAttribArray: () => {},
    vertexAttribDivisor: () => {}, drawArraysInstanced: () => {}, drawArrays: () => {},
    createTexture: () => ({}), bindTexture: () => {}, texImage2D: () => {}, texParameteri: () => {},
    createFramebuffer: () => ({}), bindFramebuffer: () => {}, framebufferTexture2D: () => {},
    checkFramebufferStatus: () => 33, activeTexture: () => {},
  };

  const uts = createUTS({ seed: 'gl-genesis' });
  await uts.core.tools.execute('ues.create_settlement', { name: 'Gl Vila', pop: 12, nearRiver: false });
  const strike = uts.rrw.emitEvent({ type: 'reallife.lightning.strike', cause: null, data: {}, tick: 0 });
  uts.world.reallife.igniteFire([512, 0, 512], strike);
  uts.world.dropRock([512, 24, 512], [0, 0, 0], {});
  uts.ues.run(90);
  uts.ues.moveCamera([512, 26, 560]);

  const r = new WebGL2Renderer(gl);
  r.init();
  assert.equal(r.caps.instanced, true, 'mock device advertises instancing');
  assert.equal(r.caps.fbo, true);
  assert.ok(r.shadow, 'shadow target created on FBO-capable device');
  assert.equal(programs.length, 6, 'sky+terrain+entity+points+shadow+water programs');

  const frame = uts.ues.renderFrame();
  assert.ok(frame.lights.points.length >= 1, 'frame carries OUR point lights');
  assert.ok(frame.entities.every(e => e.material), 'frame carries OUR materials');
  assert.ok(frame.stats.streaming.resident > 0, 'streaming residency reported');

  const result = r.render(frame);
  assert.equal(result.shadows, true, 'shadow depth pass ran');
  assert.ok(r.stats.shadowPasses >= 1);
  assert.ok(r.stats.instances > 0, 'entities drawn via OUR instancing');
  assert.ok(result.drawCalls > 0);

  // determinism-ish stability: render again without re-uploads
  const uploadsBefore = r.stats.uploads;
  const frame2 = uts.ues.renderFrame();
  r.render(frame2);
  assert.equal(r.stats.uploads, uploadsBefore, 'static resources are not re-uploaded');

  r.destroy();
  assert.equal(r.resources.count(), 0, 'RHI freed every tracked GPU resource');
});

test('webgl2: honest fallbacks — no FBO disables shadows; no instancing degrades', async () => {
  const base = (extra = {}) => ({
    canvas: { width: 640, height: 360 },
    DEPTH_COMPONENT: 30, UNSIGNED_INT: 31, FRAMEBUFFER_COMPLETE: 33, TEXTURE0: 0x84C0, TEXTURE_MAG_FILTER: 32,
    createShader: t => ({ t }), shaderSource: () => {}, compileShader: () => {},
    getShaderParameter: () => true, getShaderInfoLog: () => '', deleteShader: () => {},
    createProgram: () => ({}), attachShader: () => {}, linkProgram: () => {}, getProgramParameter: () => true,
    deleteProgram: () => {},
    getUniformLocation: () => ({ u: 1 }),
    getAttribLocation: (p, n) => ({ aPos: 0, aNorm: 1, aBiome: 2, aSeed: 0, aInst0: 3, aInst1: 4, aInst2: 5 })[n] ?? -1,
    createBuffer: () => ({}), bindBuffer: () => {}, bufferData: () => {}, deleteBuffer: () => {},
    enable: () => {}, disable: () => {}, depthFunc: () => {}, depthMask: () => {}, blendFunc: () => {},
    clearColor: () => {}, clear: () => {}, viewport: () => {}, useProgram: () => {},
    uniformMatrix4fv: () => {}, uniform3f: () => {}, uniform1f: () => {}, uniform1i: () => {},
    vertexAttribPointer: () => {}, enableVertexAttribArray: () => {},
    createTexture: () => ({}), bindTexture: () => {}, texImage2D: () => {}, texParameteri: () => {},
    createFramebuffer: () => ({}), bindFramebuffer: () => {}, framebufferTexture2D: () => {},
    checkFramebufferStatus: () => 33, activeTexture: () => {},
    vertexAttribDivisor: () => {}, drawArraysInstanced: () => {}, drawArrays: () => {},
    ...extra,
  });

  const uts = createUTS({ seed: 'gl-fallback' });
  uts.world.spawnNPC({ pos: [512, 0, 540] });
  uts.ues.moveCamera([512, 26, 520]);
  const frame = uts.ues.renderFrame();

  const noFbo = base({ createFramebuffer: undefined, createTexture: undefined });
  const r1 = new WebGL2Renderer(noFbo);
  r1.init();
  const res1 = r1.render(frame);
  assert.equal(res1.shadows, false, 'no FBO -> no shadow claim, honest degradation');

  const noInst = base({ drawArraysInstanced: undefined, vertexAttribDivisor: undefined });
  const r2 = new WebGL2Renderer(noInst);
  r2.init();
  assert.equal(r2.caps.instanced, false);
  const res2 = r2.render(frame);
  assert.equal(res2.instances, 0, 'fallback path reports zero instances honestly');
  assert.ok(res2.drawCalls > 0);
});

test('streaming: budget-aware loading, eviction, residency report', async () => {
  const uts = createUTS({ seed: 'streaming' });
  const s = uts.world.streaming;
  const r1 = s.update([512, 0, 512], { radius: 200, budgetMs: 0.0001 }); // starved budget
  assert.ok(r1.pending > 0 || r1.loadedNow === 0, 'budget respected');
  const r2 = s.update([512, 0, 512], { radius: 200, budgetMs: 50 });
  assert.ok(r2.loadedNow > 0, 'loads once budget exists (defer, never discard)');
  const entry = s.getPatch(8, 8, 24) ?? s.getPatch(7, 7, 24) ?? s.getPatch(7, 7, 16) ?? s.getPatch(8, 8, 8);
  assert.ok(entry, 'patches become resident');
  assert.ok(s.residentBytes() > 0);

  // move far away: old residents evicted (residency, not truth)
  s.update([40, 0, 40], { radius: 100, budgetMs: 50 });
  assert.ok(s.report().evicted > 0);
});
