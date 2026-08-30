import * as S from '../src/render/shaders.js';
const shaders = {};
for (const [nome, v] of Object.entries(S)) {
  if (typeof v === 'string' && v.includes('#version')) shaders[nome] = v;
  else if (typeof v === 'function') { try { shaders[nome + "('')"] = v(''); shaders[nome + '(bloco)'] = v('col = utsSurface(col, vPos, n, uWetness);'); } catch {} }
}
const builtinsFloat = ['max', 'min', 'mix', 'clamp', 'pow', 'smoothstep'];
let violacoes = 0;
for (const [nome, src] of Object.entries(shaders)) {
  src.split('\n').forEach((linha, i) => {
    const m1 = linha.match(/\b(?:const\s+)?(?:highp\s+|mediump\s+|lowp\s+)?float\s+(\w+)\s*=\s*(-?\d+)\s*([;,)]|$)/);
    if (m1) { console.log(`${nome}:${i + 1} FLOAT=INT: ${linha.trim().slice(0, 90)}`); violacoes++; }
    for (const b of builtinsFloat) {
      let idx = 0;
      while (true) {
        const pos = linha.indexOf(b + '(', idx);
        if (pos === -1) break;
        idx = pos + 1;
        let prof = 0; const ini = pos + b.length; let fim = -1;
        for (let j = ini; j < linha.length; j++) {
          if (linha[j] === '(') prof++;
          else if (linha[j] === ')') { if (prof === 0) { fim = j; break; } prof--; }
        }
        if (fim === -1) continue;
        let prof2 = 0, parte = ''; const partes = [];
        for (let j = ini + 1; j < fim; j++) {
          const c = linha[j];
          if (c === '(') prof2++;
          if (c === ')') prof2--;
          if (c === ',' && prof2 === 0) { partes.push(parte); parte = ''; continue; }
          parte += c;
        }
        partes.push(parte);
        if (partes.some((t) => /^-?\d+$/.test(t.trim()))) {
          console.log(`${nome}:${i + 1} INT EM ${b}(): ${linha.trim().slice(0, 90)}`); violacoes++;
        }
      }
    }
  });
}
// CLASSE 2: função chamada e nunca declarada no mesmo shader
const PALAVRAS = new Set(['if', 'for', 'while', 'return', 'switch', 'case', 'discard', 'main',
  'void', 'bool', 'int', 'uint', 'float', 'vec2', 'vec3', 'vec4', 'ivec2', 'ivec3', 'ivec4',
  'uvec2', 'uvec3', 'uvec4', 'bvec2', 'bvec3', 'bvec4', 'mat2', 'mat3', 'mat4', 'struct',
  'uniform', 'attribute', 'in', 'out', 'inout', 'const', 'precision', 'highp', 'mediump',
  'lowp', 'layout', 'centroid', 'flat', 'smooth', 'noperspective', 'invariant', 'buffer',
  'shared', 'coherent', 'volatile', 'restrict', 'readonly', 'writeonly', 'texture', 'true', 'false']);
const BUILTINS = new Set(['radians', 'degrees', 'sin', 'cos', 'tan', 'asin', 'acos', 'atan', 'sinh', 'cosh',
  'tanh', 'asinh', 'acosh', 'atanh', 'pow', 'exp', 'log', 'exp2', 'log2', 'sqrt', 'inversesqrt',
  'abs', 'sign', 'floor', 'ceil', 'fract', 'trunc', 'round', 'roundEven', 'mod', 'modf', 'min', 'max',
  'clamp', 'mix', 'step', 'smoothstep', 'length', 'distance', 'dot', 'cross', 'normalize', 'faceforward',
  'reflect', 'refract', 'matrixCompMult', 'outerProduct', 'transpose', 'determinant', 'inverse',
  'lessThan', 'lessThanEqual', 'greaterThan', 'greaterThanEqual', 'equal', 'notEqual', 'any', 'all', 'not',
  'uaddCarry', 'usubBorrow', 'umulExtended', 'imulExtended', 'bitfieldExtract', 'bitfieldInsert',
  'bitfieldReverse', 'bitCount', 'findLSB', 'findMSB', 'textureSize', 'textureProj', 'textureLod',
  'textureOffset', 'texelFetch', 'texelFetchOffset', 'textureProjLod', 'textureGather', 'dFdx', 'dFdy',
  'fwidth', 'noise1', 'noise2', 'noise3', 'noise4', 'atomicAdd', 'atomicMin', 'atomicMax', 'utsSurface']);
const declaradas = (src) => {
  const set = new Set();
  for (const m of src.matchAll(/\b(?:void|bool|int|uint|float|vec[234]|ivec[234]|uvec[234]|bvec[234]|mat[234])\s+([A-Za-z_]\w*)\s*\(/g)) set.add(m[1]);
  for (const m of src.matchAll(/#define\s+([A-Za-z_]\w*)\s*\(/g)) set.add(m[1]);
  return set;
};
const chamadas = (src) => {
  const set = new Set();
  for (const m of src.matchAll(/\b([A-Za-z_]\w*)\s*\(/g)) set.add(m[1]);
  return set;
};
for (const [nome, srcBruto] of Object.entries(shaders)) {
  const src = srcBruto.replace(/\/\*[\s\S]*?\*\//g, ' ').replace(/\/\/[^\n]*/g, ' ');
  const decl = declaradas(src);
  const faltando = [...chamadas(src)].filter((f) => !decl.has(f) && !PALAVRAS.has(f) && !BUILTINS.has(f));
  if (faltando.length) { console.log(`${nome}: NUNCA DECLARADAS: ${faltando.join(', ')}`); violacoes++; }
}
console.log(`SHADERS_EXAMINADOS=${Object.keys(shaders).length} VIOLACOES=${violacoes}`);
