// R29 — SHADERS ESTRICTOS: o compilador GLSL ES 3.0 de DRIVER DE CELULAR
// é estrito (inteiro NÃO converte para float: `const float X = 190;` reprova
// — o desktop tolera, por isso os testes antigos não pegavam). Este teste
// lint: TODOS os 24 strings de shader (incluindo os BLOCOS GERADOS por
// clouds/smoke/ocean) contra a classe inteira do erro: float declarado com
// literal inteiro e inteiro puro como argumento de builtin float. Os três
// geradores foram consertados na FONTE (f() emite sempre com ponto).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import * as S from '../src/render/shaders.js';

function lintShader(nome, src) {
  const achados = [];
  const builtinsFloat = ['max', 'min', 'mix', 'clamp', 'pow', 'smoothstep'];
  src.split('\n').forEach((linha, i) => {
    if (/\b(?:const\s+)?(?:highp\s+|mediump\s+|lowp\s+)?float\s+\w+\s*=\s*-?\d+\s*([;,)]|$)/.test(linha)) {
      achados.push(`${nome}:${i + 1} FLOAT=INT: ${linha.trim().slice(0, 90)}`);
    }
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
          achados.push(`${nome}:${i + 1} INT EM ${b}(): ${linha.trim().slice(0, 90)}`);
        }
      }
    }
  });
  return achados;
}

test('r29: SHADERS ESTRICTOS — zero inteiros em float nos 24 strings de shader (gerados incluídos)', () => {
  const shaders = [];
  for (const [nome, v] of Object.entries(S)) {
    if (typeof v === 'string' && v.includes('#version')) shaders.push([nome, v]);
    else if (typeof v === 'function') {
      try { shaders.push([`${nome}('')`, v('')]); } catch {}
      try { shaders.push([`${nome}(bloco)`, v('col = utsSurface(col, vPos, n, uWetness);')]); } catch {}
    }
  }
  assert.ok(shaders.length >= 24, `todos os shaders examinados (${shaders.length})`);
  const tudo = shaders.flatMap(([n, s]) => lintShader(n, s));
  assert.deepEqual(tudo, [], `inteiros em contexto float (o driver do celular reprova):\n${tudo.join('\n')}`);

  // a LEI dos geradores: os consts GERADOS chegam com PONTO (o bug nasceu
  // 3× em f() = String(Number(x)) — clouds, smoke e ocean)
  assert.ok(/const float C_LO = 190\.0;/.test(S.SKY_FS), 'nuvens: C_LO sai com ponto');
  assert.ok(/const float SM_R0 = 7\.0;/.test(S.SKY_FS), 'fumaça: SM_R0 sai com ponto');
  assert.ok(/= 0\.0;/.test(S.WATER_VS + S.WATER_FS), 'oceano: OS0 sai com ponto');

  // ---- CLASSE 2: chamada de função NUNCA DECLARADA no mesmo shader
  // (o bug do aerial(): TERRAIN/ENTITY/WATER chamavam a função que só
  // existia no bloco do CÉU — o driver estrito reprova a chamada)
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
    'fwidth', 'noise1', 'noise2', 'noise3', 'noise4', 'atomicAdd', 'atomicMin', 'atomicMax',
    // fornecidos por COMPOSIÇÃO (o shader-smith injeta a definição junto ao call site)
    'utsSurface']);
  const declaradas = (src) => {
    const set = new Set();
    for (const m of src.matchAll(/\b(?:void|bool|int|uint|float|vec[234]|ivec[234]|uvec[234]|bvec[234]|mat[234])\s+([A-Za-z_]\w*)\s*\(/g)) set.add(m[1]);
    // macros (#define NOME( ... )) também são declarações válidas
    for (const m of src.matchAll(/#define\s+([A-Za-z_]\w*)\s*\(/g)) set.add(m[1]);
    return set;
  };
  const chamadas = (src) => {
    const set = new Set();
    for (const m of src.matchAll(/\b([A-Za-z_]\w*)\s*\(/g)) set.add(m[1]);
    return set;
  };
  for (const [nome, srcBruto] of shaders) {
    // SEM comentários (palavra em comentário seguida de parêntese não é chamada)
    const src = srcBruto.replace(/\/\*[\s\S]*?\*\//g, ' ').replace(/\/\/[^\n]*/g, ' ');
    const decl = declaradas(src);
    const faltando = [...chamadas(src)].filter((f) => !decl.has(f) && !PALAVRAS.has(f) && !BUILTINS.has(f));
    assert.deepEqual(faltando, [], `${nome}: funções CHAMADAS mas nunca declaradas (o driver estrito reprova): ${faltando.join(', ')}`);
    // #version aparece UMA vez e é a primeira linha (prólogo compartilhado sem header)
    const vers = src.match(/#version/g);
    assert.ok(vers && vers.length === 1 && src.startsWith('#version 300 es'), `${nome}: #version único e primeiro`);
  }
});
