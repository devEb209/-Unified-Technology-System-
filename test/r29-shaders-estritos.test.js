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
});
