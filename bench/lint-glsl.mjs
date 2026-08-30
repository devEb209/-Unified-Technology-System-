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
console.log(`SHADERS_EXAMINADOS=${Object.keys(shaders).length} VIOLACOES=${violacoes}`);
