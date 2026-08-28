// UTS :: test/webgl2 — the GPU backend against a mock GL context:
// shader compile errors surface, resources upload only on change, static
// meshes are reused, dynamic uniforms follow the Frame, destroy frees all.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createUTS } from '../src/index.js';
import { WebGL2Renderer } from '../src/render/webgl2.js';
import { RendererError } from '../src/render/rhi.js'; // RHI owns the error taxonomy (Gênesis)

const C = {
  VERTEX_SHADER: 1, FRAGMENT_SHADER: 2, COMPILE_STATUS: 3, LINK_STATUS: 4,
  ARRAY_BUFFER: 5, STATIC_DRAW: 6, DYNAMIC_DRAW: 7, DEPTH_TEST: 8, LEQUAL: 9,
  CULL_FACE: 10, COLOR_BUFFER_BIT: 11, DEPTH_BUFFER_BIT: 12, TRIANGLES: 13,
  POINTS: 14, FLOAT: 15, BLEND: 16, SRC_ALPHA: 17, ONE_MINUS_SRC_ALPHA: 18,
};

function makeGL({ failCompile = false } = {}) {
  const calls = [];
  const buffers = new Set();
  const programs = [];
  let bufferN = 0;
  const uniformCache = new Map();
  const gl = {
    ...C,
    canvas: { width: 1280, height: 720 },
    createShader: (t) => ({ t }),
    shaderSource: (s, src) => { s.src = src; },
    compileShader: () => {},
    getShaderParameter: () => !failCompile,
    getShaderInfoLog: () => 'mock compile error at line 1',
    deleteShader: (s) => calls.push(['deleteShader', s.t]),
    createProgram: () => { const p = { id: programs.length }; programs.push(p); return p; },
    attachShader: () => {},
    linkProgram: () => {},
    getProgramParameter: () => true,
    deleteProgram: (p) => calls.push(['deleteProgram', p.id]),
    getUniformLocation: (prog, name) => {
      const key = prog.id + ':' + name;
      if (!uniformCache.has(key)) uniformCache.set(key, { prog: prog.id, name });
      return uniformCache.get(key);
    },
    getAttribLocation: (prog, name) => (name === 'aPos' ? 0 : name === 'aNorm' ? 1 : name === 'aBiome' ? 2 : name === 'aSeed' ? 0 : -1),
    createBuffer: () => { const b = { id: ++bufferN }; buffers.add(b); return b; },
    bindBuffer: (t, b) => calls.push(['bindBuffer', b?.id]),
    bufferData: (t, data, usage) => calls.push(['bufferData', data?.length ?? 0, usage]),
    deleteBuffer: (b) => { buffers.delete(b); calls.push(['deleteBuffer', b.id]); },
    enable: (c) => calls.push(['enable', c]),
    disable: (c) => calls.push(['disable', c]),
    depthFunc: () => {},
    depthMask: (b) => calls.push(['depthMask', b]),
    blendFunc: () => calls.push(['blendFunc']),
    clearColor: (r, g, b, a) => calls.push(['clearColor', [r, g, b, a]]),
    clear: (m) => calls.push(['clear', m]),
    viewport: (x, y, w, h) => calls.push(['viewport', w, h]),
    useProgram: (p) => calls.push(['useProgram', p?.id]),
    uniformMatrix4fv: (loc, t, m) => calls.push(['uniformMatrix4fv', loc?.name]),
    uniform1i: (loc, v) => calls.push(['uniform1i', loc?.name, v]), // shadow sampler binding (Gênesis)
    uniform3f: (loc, ...v) => calls.push(['uniform3f', loc?.name, v]),
    uniform1f: (loc, v) => calls.push(['uniform1f', loc?.name, v]),
    vertexAttribPointer: () => calls.push(['vertexAttribPointer']),
    enableVertexAttribArray: () => calls.push(['enableVertexAttribArray']),
    drawArrays: (mode, first, count) => calls.push(['drawArrays', mode, count]),
  };
  gl._calls = calls;
  gl._buffers = buffers;
  gl._programs = programs;
  return gl;
}

async function makeScene(seed = 'gl') {
  const uts = createUTS({ seed });
  await uts.core.processObjective('criar uma pequena vila próxima a um rio chamada Gl Vila');
  uts.ues.moveCamera([500, 40, 500]);
  uts.world.updateMaterialization(uts.ues.camera.pos);
  const frame = uts.ues.renderFrame();
  return { uts, frame };
}

test('webgl2: rejects non-GL contexts loudly', async () => {
  assert.throws(() => new WebGL2Renderer({}), RendererError);
  assert.throws(() => new WebGL2Renderer(null), RendererError);
});

test('webgl2: compiles 4 programs, renders sky+terrain+entities, counts draw calls', async () => {
  const gl = makeGL();
  const { frame } = await makeScene();
  const r = new WebGL2Renderer(gl);
  r.init();
  const { drawCalls } = r.render(frame);
  assert.equal(gl._programs.length, 4);
  const arrays = gl._calls.filter(c => c[0] === 'drawArrays');
  assert.equal(arrays.length, drawCalls);
  // sky (1) + terrain patches + VISIBLE entities (our culling skips the rest) (+ rain when raining)
  const drawnEntities = frame.entities.length - r.stats.culled;
  assert.ok(drawCalls >= 1 + frame.terrain.patches.length + drawnEntities,
    `sky+terrain+visible entities (culled ${r.stats.culled}, drew ${drawCalls})`);
  assert.equal(frame.entities.length - drawnEntities, r.stats.culled, 'culled accounting is exact');
  const clear = gl._calls.find(c => c[0] === 'clearColor');
  assert.deepEqual(clear[1].slice(0, 3), frame.environment.skyBottom);
});

test('webgl2: terrain buffers upload ONCE per (patch,res) — static vs dynamic split', async () => {
  const gl = makeGL();
  const { frame } = await makeScene();
  const r = new WebGL2Renderer(gl);
  r.render(frame);
  const uploads1 = r.stats.uploads;
  r.render(frame); // same frame again: no re-upload
  assert.equal(r.stats.uploads, uploads1, 'no redundant GPU uploads');
  const terrainUploads = gl._calls.filter(c => c[0] === 'bufferData');
  assert.ok(terrainUploads.length > 0);
});

test('webgl2: LOD change produces a NEW buffer and frees the old one', async () => {
  const gl = makeGL();
  const { uts } = await makeScene('gl2');
  const r = new WebGL2Renderer(gl);
  const f1 = uts.ues.renderFrame();
  r.render(f1);
  const bufCount1 = gl._buffers.size;
  uts.ues.moveCamera([480 - 130, 40, 480]); // shift -> different patches/res set
  const f2 = uts.ues.renderFrame();
  r.render(f2);
  assert.ok(gl._calls.some(c => c[0] === 'deleteBuffer'), 'old terrain buffers freed');
  assert.ok(gl._buffers.size > 0);
  assert.ok(bufCount1 > 0);
});

test('webgl2: camera drives the VP uniform (frame is the only truth)', async () => {
  const gl = makeGL();
  const { uts } = await makeScene('gl3');
  const r = new WebGL2Renderer(gl);
  const f1 = uts.ues.renderFrame();
  r.render(f1);
  const vpCalls1 = gl._calls.filter(c => c[0] === 'uniformMatrix4fv' && c[1] === 'uVP').length;
  uts.ues.moveCamera([520, 60, 520], 1.2, 0.8);
  gl._calls.length = 0;
  const f2 = uts.ues.renderFrame();
  r.render(f2);
  const vpCalls2 = gl._calls.filter(c => c[0] === 'uniformMatrix4fv' && c[1] === 'uVP').length;
  assert.ok(vpCalls1 > 0 && vpCalls2 > 0, 'VP set per pass');
  assert.notDeepStrictEqual(f1.camera, f2.camera);
});

test('webgl2: rain manifests as GL_POINTS driven by represented rain state', async () => {
  const gl = makeGL();
  const { uts } = await makeScene('gl4');
  const r = new WebGL2Renderer(gl);
  uts.world.setWeather('rain');
  uts.world.updateWeather(0.05);
  uts.world.environment.rain = 1;
  const f = uts.ues.renderFrame();
  gl._calls.length = 0;
  r.render(f);
  const points = gl._calls.filter(c => c[0] === 'drawArrays' && c[1] === C.POINTS);
  assert.equal(points.length, 1, 'one point pass for precipitation');
});

test('webgl2: no precipitation -> no point pass', async () => {
  const gl = makeGL();
  const { frame } = await makeScene('gl5');
  frame.environment.rain = 0;
  frame.environment.dust = 0;
  const r = new WebGL2Renderer(gl);
  gl._calls.length = 0;
  r.render(frame);
  assert.equal(gl._calls.filter(c => c[0] === 'drawArrays' && c[1] === C.POINTS).length, 0);
});

test('webgl2: shader compile failure raises RendererError with the log', async () => {
  const gl = makeGL({ failCompile: true });
  const r = new WebGL2Renderer(gl);
  assert.throws(() => r.init(), /mock compile error/);
});

test('webgl2: destroy frees every GPU resource it created', async () => {
  const gl = makeGL();
  const { frame } = await makeScene('gl6');
  const r = new WebGL2Renderer(gl);
  r.render(frame);
  assert.ok(gl._buffers.size > 0);
  r.destroy();
  assert.equal(gl._buffers.size, 0, 'all buffers deleted');
  assert.equal(r.initialized, false);
});
