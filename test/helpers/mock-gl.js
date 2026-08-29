// UTS :: test/helpers/mock-gl — THE mock WebGL2 context (single source of truth).
// Numeric GL constants, call recording, program/attrib maps, fallback switches.

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
    uniform2f: (loc, ...v) => calls.push(['uniform2f', loc?.name, v]),
    uniform3f: (loc, ...v) => calls.push(['uniform3f', loc?.name, v]),
    uniform1f: (loc, v) => calls.push(['uniform1f', loc?.name, v]),
    vertexAttribPointer: () => calls.push(['vertexAttribPointer']),
    enableVertexAttribArray: () => calls.push(['enableVertexAttribArray']),
    uniform4fv: () => {},
    drawArrays: (mode, first, count) => calls.push(['drawArrays', mode, count]),
  };
  gl._calls = calls;
  gl._buffers = buffers;
  gl._programs = programs;
  return gl;
}

export { makeGL, C as GL_CONSTANTS };
