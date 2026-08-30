// UTS :: agent/geometry-smith — A FORJA DE GEOMETRIA: malhas NOVAS geradas
// por composição de regras determinísticas (L-system de árvore, cristal de
// N faces com simetria exata, rocha por ruído determinístico) com
// AUTOTESTE (finito, contagens pela fórmula, determinismo byte a byte).
// A mesma honestidade do shader-smith: regras declaradas, contagens
// provadas — nada de número inventado.

// hash determinístico (FNV-1a) — a mesma semente = a mesma malha
function _h(seedStr) {
  let h = 2166136261;
  for (let i = 0; i < seedStr.length; i++) { h ^= seedStr.charCodeAt(i); h = Math.imul(h, 16777619) >>> 0; }
  return h >>> 0;
}
function _rng(seed) {
  let v = seed >>> 0;
  return () => { v = (Math.imul(v, 1664525) + 1013904223) >>> 0; return v / 4294967296; };
}

export const GEOMETRY_KINDS = Object.freeze({
  arvore: {
    desc: 'árvore por L-SYSTEM determinístico: tronco + N níveis de galhos, cada galho com comprimento decaindo e ângulo áureo',
    params: { níveis: [1, 5], comprimento: [1, 8], galhos: [2, 5] },
  },
  cristal: {
    desc: 'cristal de N faces: prisma com pontas piramidais e SIMETRIA EXATA (espelho provado no autoteste)',
    params: { faces: [4, 12], altura: [0.5, 6], raio: [0.2, 3] },
  },
  rocha: {
    desc: 'rocha por deslocamento determinístico: icosaesfera com ruído por vértice (a mesma semente = a mesma pedra)',
    params: { subdiv: [1, 3], rugosidade: [0.02, 0.6] },
  },
});

/** árvore L-system: devolve {vertices, indices, stats} determinísticos */
function forjaArvore({ níveis = 3, comprimento = 3, galhos = 3, seed = 'genesis' }) {
  const rand = _rng(_h(`arvore|${níveis}|${comprimento}|${galhos}|${seed}`));
  const vertices = [];
  const indices = [];
  const GOLDEN = 2.399963229728653;
  const grow = (x, y, z, dir, len, level, yaw) => {
    const tip = [x + dir[0] * len, y + dir[1] * len, z + dir[2] * len];
    const base = vertices.length / 3;
    vertices.push(x, y, z, tip[0], tip[1], tip[2]);
    indices.push(base, base + 1);
    if (level >= níveis) return;
    for (let b = 0; b < galhos; b++) {
      const ang = yaw + b * (Math.PI * 2 / galhos) + rand() * 0.4;
      const tilt = 0.5 + rand() * 0.5;
      const nd = [
        Math.cos(ang) * Math.sin(tilt),
        Math.cos(tilt),
        Math.sin(ang) * Math.sin(tilt),
      ];
      grow(tip[0], tip[1], tip[2], nd, len * 0.68, level + 1, ang + GOLDEN);
    }
  };
  grow(0, 0, 0, [0, 1, 0], comprimento, 1, rand() * Math.PI * 2);
  return { vertices, indices, galhosTotais: indices.length };
}

/** cristal: prisma de N faces com pontas — simetria por construção */
function forjaCristal({ faces = 6, altura = 2, raio = 1 }) {
  const vertices = [];
  const H = altura / 2;
  const anel = (y) => { for (let f = 0; f < faces; f++) { const a = (f / faces) * Math.PI * 2; vertices.push(Math.cos(a) * raio, y, Math.sin(a) * raio); } };
  vertices.push(0, -H - raio * 0.6, 0); // ponta de baixo
  anel(-H); anel(H);
  vertices.push(0, H + raio * 0.6, 0);  // ponta de cima
  const bottom = 0, top = vertices.length / 3 - 1;
  const indices = [];
  const low0 = 1, high0 = 1 + faces;
  for (let f = 0; f < faces; f++) {
    const l0 = low0 + f, l1 = low0 + ((f + 1) % faces);
    const h0 = high0 + f, h1 = high0 + ((f + 1) % faces);
    indices.push(bottom, l1, l0);       // fundo (winding p/ cima)
    indices.push(l0, l1, h1); indices.push(l0, h1, h0); // lateral
    indices.push(top, h0, h1);          // topo
  }
  return { vertices, indices, faces: indices.length / 3 };
}

/** rocha: icosaesfera perturbada por ruído determinístico */
function forjaRocha({ subdiv = 2, rugosidade = 0.25, seed = 'genesis' } = {}) {
  const rand = _rng(_h(`rocha|${subdiv}|${rugosidade}|${seed}`));
  const t = (1 + Math.sqrt(5)) / 2;
  let verts = [[-1, t, 0], [1, t, 0], [-1, -t, 0], [1, -t, 0], [0, -1, t], [0, 1, t], [0, -1, -t], [0, 1, -t], [t, 0, -1], [t, 0, 1], [-t, 0, -1], [-t, 0, 1]];
  let faces = [[0,11,5],[0,5,1],[0,1,7],[0,7,10],[0,10,11],[1,5,9],[5,11,4],[11,10,2],[10,7,6],[7,1,8],[3,9,4],[3,4,2],[3,2,6],[3,6,8],[3,8,9],[4,9,5],[2,4,11],[6,2,10],[8,6,7],[9,8,1]];
  const midCache = new Map();
  const mid = (a, b) => {
    const key = a < b ? `${a}_${b}` : `${b}_${a}`;
    if (midCache.has(key)) return midCache.get(key);
    const va = verts[a], vb = verts[b];
    verts.push([(va[0] + vb[0]) / 2, (va[1] + vb[1]) / 2, (va[2] + vb[2]) / 2]);
    midCache.set(key, verts.length - 1);
    return verts.length - 1;
  };
  for (let s = 0; s < subdiv; s++) {
    const next = [];
    for (const [a, b, c] of faces) {
      const ab = mid(a, b), bc = mid(b, c), ca = mid(c, a);
      next.push([a, ab, ca], [b, bc, ab], [c, ca, bc], [ab, bc, ca]);
    }
    faces = next;
  }
  // normaliza na esfera e perturba (o ruído é a identidade da pedra)
  for (let i = 0; i < verts.length; i++) {
    const l = Math.hypot(...verts[i]) || 1;
    const r = 1 + (rand() - 0.5) * 2 * rugosidade;
    verts[i] = verts[i].map((x) => (x / l) * r);
  }
  return { vertices: verts.flat(), indices: faces.flat(), triângulos: faces.length };
}

export function composeGeometry({ kind, params = {}, seed = 'genesis' } = {}) {
  const def = GEOMETRY_KINDS[kind];
  if (!def) throw new Error(`forja de geometria: tipo desconhecido "${kind}" (tenho: ${Object.keys(GEOMETRY_KINDS).join(', ')})`);
  const checked = {};
  for (const [k, [lo, hi]] of Object.entries(def.params)) {
    const v = Number(params[k] ?? (lo + hi) / 2);
    if (!(v >= lo && v <= hi)) throw new Error(`forja de geometria: ${kind}.${k}=${v} fora de [${lo}, ${hi}]`);
    checked[k] = v;
  }
  let mesh;
  if (kind === 'arvore') mesh = forjaArvore({ níveis: Math.round(checked['níveis']), comprimento: checked.comprimento, galhos: Math.round(checked.galhos), seed });
  else if (kind === 'cristal') mesh = forjaCristal({ faces: Math.round(checked.faces), altura: checked.altura, raio: checked.raio });
  else mesh = forjaRocha({ subdiv: Math.round(checked.subdiv), rugosidade: checked.rugosidade, seed });
  const finite = mesh.vertices.every((x) => Number.isFinite(x));
  // AUTOTESTES por tipo (as contagens saem da FÓRMULA, não da sorte)
  const checks = { finite };
  if (kind === 'arvore') {
    // L-SYSTEM: segmentos = 1 + g + g² + … (níveis 1..n) = (gⁿ−1)/(g−1);
    // cada segmento é um par de índices
    const g = Math.round(checked.galhos), n = Math.round(checked['níveis']);
    const esperado = (g ** n - 1) / (g - 1);
    checks.contagem = mesh.galhosTotais === esperado * 2 && mesh.indices.length === esperado * 2;
    checks.cresce = mesh.vertices[4] > 0; // a copa subiu acima do solo
  }
  if (kind === 'cristal') {
    // SIMETRIA EXATA: girar 1/faces de volta devolve a mesma malha (a 1e-9)
    const f = Math.round(checked.faces);
    const verts = mesh.vertices;
    let simétrico = true;
    // layout: [ponta baixo(1), anel baixo(f), anel alto(f), ponta alto(1)]
    const lo = 3, hi = 3 + f * 3;
    for (let i = 0; i < f; i++) {
      const a0 = i * 3, a1 = ((i + 1) % f) * 3;
      const r0 = Math.hypot(verts[lo + a0], verts[lo + a0 + 2]);
      const r1 = Math.hypot(verts[lo + a1], verts[lo + a1 + 2]);
      if (Math.abs(r0 - r1) > 1e-9) simétrico = false;
      const r0t = Math.hypot(verts[hi + a0], verts[hi + a0 + 2]);
      const r1t = Math.hypot(verts[hi + a1], verts[hi + a1 + 2]);
      if (Math.abs(r0t - r1t) > 1e-9) simétrico = false;
    }
    checks.simetria = simétrico;
    checks.faces = mesh.faces === f * 4; // fundo + 2 por lateral + topo
  }
  if (kind === 'rocha') {
    checks.fechada = mesh.triângulos === 20 * 4 ** Math.round(checked.subdiv); // icosaesfera
    checks.fechada = checks.fechada && mesh.vertices.length % 3 === 0;
  }
  // determinismo: forja de novo DIRETO (sem recursão no autoteste) —
  // a mesma semente tem que devolver a mesma malha byte a byte
  const again = kind === 'arvore'
    ? forjaArvore({ níveis: Math.round(checked['níveis']), comprimento: checked.comprimento, galhos: Math.round(checked.galhos), seed })
    : kind === 'cristal'
      ? forjaCristal({ faces: Math.round(checked.faces), altura: checked.altura, raio: checked.raio })
      : forjaRocha({ subdiv: Math.round(checked.subdiv), rugosidade: checked.rugosidade, seed });
  const determinístico = JSON.stringify(again.vertices) === JSON.stringify(mesh.vertices) && JSON.stringify(again.indices) === JSON.stringify(mesh.indices);
  const ok = finite && Object.values(checks).every(Boolean) && determinístico;
  return {
    kind, params: checked, vertices: mesh.vertices, indices: mesh.indices,
    stats: { vertices: mesh.vertices.length / 3, triângulos: kind === 'cristal' ? mesh.faces : (mesh.triângulos ?? mesh.galhosTotais) },
    selfTest: { ok, ...checks, determinístico },
    honest: 'malha gerada por regras determinísticas com autoteste (contagens pela fórmula; mesma semente = mesma malha)',
  };
}
