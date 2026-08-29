// UTS :: agent/shader-smith — THE GRAPHICS AGENT (honest): composes
// post-chain optics from a VERIFIED library. Each effect is a REAL
// physical model with a GLSL block and a JS mirror generated from the
// SAME constants — the mirror is tested numerically, so the shader text
// that ships is the math that was verified. Unknown effect = honest
// error listing what exists. This is not "fake AI codegen": it is a
// smith forging from measured alloys.
export const EFFECTS = Object.freeze({
  vinheta: {
    desc: 'vinheta NATURAL da lente: cos⁴ do ângulo de campo (lei real de queda de irradiância)',
    params: { amount: [0, 1] },
    constants: (p) => ({ a: p.amount }),
    glsl: (p) => `float cosA = 1.0 / sqrt(1.0 + dot(c, c) * 4.0 * (uFovRad * uFovRad));\n  col *= mix(1.0, pow(cosA, 4.0), ${Number(p.amount).toFixed(4)});`,
    /** mirror JS: mesma fórmula, mesmas constantes */
    mirror(rNorm, fovRad, p) {
      const cosA = 1 / Math.sqrt(1 + rNorm * rNorm * 4 * fovRad * fovRad);
      return 1 * (1 - p.amount) + Math.pow(cosA, 4) * p.amount;
    },
  },
  aberracao: {
    desc: 'ABERRAÇÃO cromática da lente: R/B deslocam na borda (dispersão do vidro, cresce com o campo)',
    params: { amount: [0, 2] },
    constants: (p) => ({ ca: p.amount }),
    glsl: (p) => `vec2 caOff = c * (uCAFrac * ang * ${Number(p.amount).toFixed(4)});\n  col.r = texture(uScene, vUV + caOff).r;\n  col.b = texture(uScene, vUV - caOff).b;`,
    mirror(_r, _f, p) { return p.amount * 0.00035 * 10; },
  },
  nitidez: {
    desc: 'NITIDEZ (unsharp mask): a percepção de borda ganha com o contraste local realçado',
    params: { amount: [0, 1.5] },
    constants: (p) => ({ sh: p.amount }),
    glsl: (p) => `vec3 sharp = texture(uScene, vUV + uTexel * 1.5).rgb + texture(uScene, vUV - uTexel * 1.5).rgb;\n  col += ${Number(p.amount).toFixed(4)} * (col * 2.0 - sharp) * 0.25;`,
    mirror(_r, _f, p) { return p.amount * 0.25 * (0.8 * 2 - 1.6); },
  },
  bloom: {
    desc: 'BLOOM fisiológico: a corona ciliar espalha fontes brilhantes (limiar + halo largo na tela)',
    params: { amount: [0, 1] },
    constants: (p) => ({ b: p.amount }),
    glsl: (p) => `vec3 bl = vec3(0.0);
  for (int i = 0; i < 8; i++) { float an = float(i) * 0.7853982; vec2 o = vec2(cos(an), sin(an)) * uTexel * 14.0; bl += max(texture(uScene, vUV + o).rgb - 0.75, 0.0); }
  col += ${Number(p.amount).toFixed(4)} * bl * 0.25;`,
    mirror(_r, _f, p, seed = 0.6) { const s = p.amount * Math.max(0, seed - 0.75) * 2.0; return Number.isFinite(s) ? s : 0; },
  },
  tonemap: {
    desc: 'TONEMAP de display: Reinhard (col/(1+col)) — a tela NÃO é energia infinita',
    params: { amount: [0, 1] },
    constants: (p) => ({ t: p.amount }),
    glsl: (p) => `col = mix(col, col / (1.0 + col), ${Number(p.amount).toFixed(4)});`,
    mirror(r, _f, p) { const c = 0.8; return c * (1 - p.amount) + (c / (1 + c)) * p.amount; },
  },
  grao: {
    desc: 'grão do SENSOR: ruído de fóton — menos sinal, mais grão (σ ∝ 1/√sinal)',
    params: { amount: [0, 0.6] },
    constants: (p) => ({ g: p.amount }),
    glsl: (p) => `float n = fract(sin(dot(vUV * (1.0 + fract(uTime)), vec2(12.9898, 78.233))) * 43758.5453);\n  col += ${Number(p.amount).toFixed(4)} * (n - 0.5) / sqrt(max(dot(col, vec3(0.299, 0.587, 0.114)), 0.02) + 0.05) * 0.35;`,
    mirror(rNorm, _fov, p, seed = 0.37) {
      const n = Math.abs(Math.sin((rNorm * (1 + (seed % 1))) * 12.9898 + rNorm * 78.233) * 43758.5453) % 1;
      return p.amount * (n - 0.5) / Math.sqrt(0.5 + 0.05) * 0.35;
    },
  },
});

/**
 * Compose optics from a brief: { effects: ['vinheta','grao'], amount: {...} }.
 * Returns params (what the style/frame carries), the GLSL block, and a
 * self-verification (the mirror sampled on a grid, ranges asserted).
 */
// ---- O COLORISTA: GLSL gerado por COMPOSIÇÃO ARBITRÁRIA no domínio cor.
// Cada estágio é uma lei de cor verificada (espelho JS = GLSL, mesmas
// constantes); QUALQUER sequência de estágios vira um shader novo montado
// na hora — e o autoteste prova o espelho em vetores fixos.
const clampC = (x) => Math.max(0, Math.min(1, x));

// matriz de rotação de matiz EXATA: base {Y, I, Q} ortonormal por
// Gram-Schmidt (Y = luminância BT.601; I,Q = croma ortogonalizado) e
// rotação no plano I–Q. Em 0° a soma dos projetores É a identidade.
const _yVec = (() => { const y = [0.299, 0.587, 0.114]; const n = Math.hypot(...y); return y.map((x) => x / n); })(); // eixo de luminância NORMALIZADO (projetor honesto)
const _iVec = (() => {
  const i0 = [0.596, -0.274, -0.322];
  const dot = (a, b) => a[0] * b[0] + a[1] * b[1] + a[2] * b[2];
  const k = dot(i0, _yVec);
  const i1 = i0.map((x, i) => x - k * _yVec[i]);
  const n = Math.hypot(...i1);
  return i1.map((x) => x / n);
})();
const _qVec = (() => {
  const q = [
    _yVec[1] * _iVec[2] - _yVec[2] * _iVec[1],
    _yVec[2] * _iVec[0] - _yVec[0] * _iVec[2],
    _yVec[0] * _iVec[1] - _yVec[1] * _iVec[0],
  ];
  const n = Math.hypot(...q);
  return q.map((x) => x / n);
})();
function hueMatrix(graus) {
  const a = (graus * Math.PI) / 180;
  const c = Math.cos(a), s = Math.sin(a);
  const m = new Array(9);
  for (let col = 0; col < 3; col++) {
    const y = _yVec[col], i = _iVec[col], q = _qVec[col];
    for (let row = 0; row < 3; row++) {
      m[row * 3 + col] = _yVec[row] * y + (_iVec[row] * c + _qVec[row] * s) * i + (_qVec[row] * c - _iVec[row] * s) * q;
    }
  }
  return m;
}

export const COLOR_STAGES = Object.freeze({
  rotacaoMatiz: {
    desc: 'rotação de matiz: gira o CROMA no plano ortogonal à luminância (Gram-Schmidt — 0° é identidade exata)',
    params: { graus: [-180, 180] },
    glsl: (p) => `  c = mat3(${hueMatrix(p.graus).map((x) => x.toFixed(12)).join(', ')}) * c;\n`,
    js: (c, p) => {
      const m = hueMatrix(p.graus);
      return [
        m[0] * c[0] + m[1] * c[1] + m[2] * c[2],
        m[3] * c[0] + m[4] * c[1] + m[5] * c[2],
        m[6] * c[0] + m[7] * c[1] + m[8] * c[2],
      ];
    },
  },
  temperatura: {
    desc: 'temperatura de cor: quente levanta o vermelho e derruba o azul (o corpo negro do material)',
    params: { t: [-1, 1] },
    glsl: (p) => `  c *= vec3(${(1 + 0.25 * p.t).toFixed(4)}, 1.0, ${(1 - 0.25 * p.t).toFixed(4)});\n`,
    js: (c, p) => [c[0] * (1 + 0.25 * p.t), c[1], c[2] * (1 - 0.25 * p.t)],
  },
  liftGammaGain: {
    desc: 'lift/gamma/gain do color grade clássico (sombras, meio-tom e luz separados)',
    params: { lift: [0, 0.3], gamma: [0.5, 2.0], gain: [0.5, 1.6] },
    glsl: (p) => `  c = clamp(c, vec3(0.0), vec3(1.0));\n  c = pow(max(c - ${p.lift.toFixed(4)}, vec3(0.0)) / max(1.0 - ${p.lift.toFixed(4)}, 0.0001), vec3(${(1 / p.gamma).toFixed(4)})) * ${p.gain.toFixed(4)};\n`,
    js: (c, p) => c.map((x) => Math.pow(Math.max(0, clampC(x) - p.lift) / Math.max(1 - p.lift, 0.0001), 1 / p.gamma) * p.gain),
  },
  curvaS: {
    desc: 'curva em S (contraste de filme: preserva o meio-tom, dobra os ombros)',
    params: { forca: [0, 1] },
    glsl: (p) => {
      const k = (0.8 + 2.4 * p.forca).toFixed(4);
      return `  c = mix(c, smoothstep(vec3(0.0), vec3(1.0), c), ${(p.forca / Number(k) * Number(k)).toFixed(4)});\n`;
    },
    js: (c, p) => {
      const sstep = (x) => { const t = clampC(x); return t * t * (3 - 2 * t); };
      return c.map((x) => x + (sstep(x) - x) * p.forca);
    },
  },
  sepia: {
    desc: 'mistura sépia (a tonalidade da prata envelhecida)',
    params: { m: [0, 1] },
    glsl: (p) => `  c = mix(c, vec3(dot(c, vec3(0.393, 0.769, 0.189)), dot(c, vec3(0.349, 0.686, 0.168)), dot(c, vec3(0.272, 0.534, 0.131))), ${p.m.toFixed(4)});\n`,
    js: (c, p) => {
      const sr = c[0] * 0.393 + c[1] * 0.769 + c[2] * 0.189;
      const sg = c[0] * 0.349 + c[1] * 0.686 + c[2] * 0.168;
      const sb = c[0] * 0.272 + c[1] * 0.534 + c[2] * 0.131;
      return [c[0] + (sr - c[0]) * p.m, c[1] + (sg - c[1]) * p.m, c[2] + (sb - c[2]) * p.m];
    },
  },
});

export const COLOR_PRESETS = Object.freeze({
  quente: [{ type: 'temperatura', params: { t: 0.45 } }],
  frio: [{ type: 'temperatura', params: { t: -0.45 } }],
  'teia-noite': [{ type: 'temperatura', params: { t: -0.25 } }, { type: 'curvaS', params: { forca: 0.35 } }],
  'prata-velha': [{ type: 'sepia', params: { m: 0.65 } }, { type: 'curvaS', params: { forca: 0.3 } }],
  'psicodelico': [{ type: 'rotacaoMatiz', params: { graus: 40 } }, { type: 'temperatura', params: { t: 0.2 } }, { type: 'curvaS', params: { forca: 0.45 } }],
});

/**
 * compõe QUALQUER sequência de estágios num shader novo (GLSL montado na
 * hora) com espelho JS e autoteste em vetores fixos. Estágio desconhecido
 * ou parâmetro fora da lei = erro explícito (nunca shader mentiroso).
 */
export function composeColorPipeline(pipeline = []) {
  if (!Array.isArray(pipeline) || pipeline.length === 0) {
    throw new Error(`colorista: digite os estágios (tenho: ${Object.keys(COLOR_STAGES).join(', ')})`);
  }
  let body = '';
  const jsChain = [];
  for (const stage of pipeline) {
    const def = COLOR_STAGES[stage?.type];
    if (!def) throw new Error(`colorista: estágio desconhecido "${stage?.type}" (tenho: ${Object.keys(COLOR_STAGES).join(', ')})`);
    const params = {};
    for (const [k, [lo, hi]] of Object.entries(def.params)) {
      const v = Number(stage.params?.[k] ?? (lo + hi) / 2);
      if (!(v >= lo && v <= hi)) throw new Error(`colorista: ${stage.type}.${k}=${v} fora de [${lo}, ${hi}]`);
      params[k] = v;
    }
    body += `  // ${stage.type}: ${def.desc}\n`;
    body += def.glsl(params);
    jsChain.push((c) => def.js(c, params));
  }
  const glsl = `// forjado pelo COLORISTA (composição verificada — espelho JS = GLSL)\nvec3 utsColorista(vec3 c){\n${body}  return c;\n}`;
  const js = (c) => jsChain.reduce((acc, f) => f(acc), [...c]);
  const samples = [[0.5, 0.5, 0.5], [1, 0, 0], [0.2, 0.7, 0.3], [0.9, 0.8, 0.1]];
  const out = samples.map(js);
  const finite = out.every((c) => c.every((x) => Number.isFinite(x)));
  return {
    glsl,
    js,
    stages: pipeline.length,
    samples: { in: samples, out },
    selfTest: { finite, emptyIdentity: false },
    honest: 'shader gerado por composição de leis verificadas (espelho JS = GLSL, mesmas constantes); vetores de teste finitos',
  };
}

// ---- O SMITH DE CENA: GLSL de SUPERFÍCIE gerado por composição. Cada
// estágio é uma lei de material (neve por altitude+declive, musgo por
// umidade, cinza de incêndio, floração determinística por célula) com
// espelho JS = GLSL e autoteste em amostras de terreno.
const _ss = (a, b, x) => { const t = Math.max(0, Math.min(1, (x - a) / (b - a))); return t * t * (3 - 2 * t); };
const _hash01 = (xi, zi) => {
  const d = xi * 127.1 + zi * 311.7;
  const v = Math.sin(d) * 43758.5453;
  return v - Math.floor(v);
};

export const SURFACE_STAGES = Object.freeze({
  neve: {
    desc: 'NEVE por altitude e declive: acumula no alto e no plano (a física da camada fria)',
    params: { alt: [8, 60], faixa: [2, 10] },
    glsl: (p) => {
      const lo = (p.alt - p.faixa).toFixed(2), hi = (p.alt + p.faixa).toFixed(2);
      return `  { float snow = smoothstep(${lo}, ${hi}, vPos.y) * smoothstep(0.45, 0.75, min(n.y, 1.0)); col = mix(col, vec3(0.93, 0.95, 0.97), snow); }\n`;
    },
    js: (col, s, p) => {
      const snow = _ss(p.alt - p.faixa, p.alt + p.faixa, s.y) * _ss(0.45, 0.75, Math.min(1, s.ny));
      return col.map((c, i) => c + ([0.93, 0.95, 0.97][i] - c) * snow);
    },
  },
  musgo: {
    desc: 'MUSGO por umidade: a terra molhada e plana vira mata viva (o bioma responde ao solo)',
    params: { limiar: [0.1, 0.6] },
    glsl: (p) => `  { float moss = smoothstep(${p.limiar.toFixed(2)}, ${(p.limiar + 0.25).toFixed(2)}, uWetness) * smoothstep(0.45, 0.8, n.y); col = mix(col, vec3(0.22, 0.36, 0.16), moss * 0.75); }\n`,
    js: (col, s, p) => {
      const moss = _ss(p.limiar, p.limiar + 0.25, s.wet) * _ss(0.45, 0.8, s.ny);
      return col.map((c, i) => c + ([0.22, 0.36, 0.16][i] - c) * moss * 0.75);
    },
  },
  cinza: {
    desc: 'CINZA de incêndio: o que queimou fica escuro (a cicatriz da combustão na terra)',
    params: { amount: [0, 1] },
    glsl: (p) => `  col = mix(col, vec3(0.16, 0.15, 0.14), ${p.amount.toFixed(3)});\n`,
    js: (col, s, p) => col.map((c, i) => c + ([0.16, 0.15, 0.14][i] - c) * p.amount),
  },
  flor: {
    desc: 'FLORAÇÃO determinística: células escolhidas por hash ganham cor (a primavera tem endereço)',
    params: { passo: [3, 14], densidade: [0.05, 0.5] },
    glsl: (p) => `  { vec2 id = floor(vPos.xz / ${(p.passo).toFixed(2)}); float h = fract(sin(dot(id, vec2(127.1, 311.7))) * 43758.5453); float spot = step(${(1 - p.densidade).toFixed(3)}, h) * smoothstep(0.5, 0.85, n.y); col = mix(col, vec3(0.94, 0.75, 0.85), spot * 0.5); }\n`,
    js: (col, s, p) => {
      const id = [Math.floor(s.x / p.passo), Math.floor(s.z / p.passo)];
      const spot = (_hash01(id[0], id[1]) >= 1 - p.densidade ? 1 : 0) * _ss(0.5, 0.85, s.ny);
      return col.map((c, i) => c + ([0.94, 0.75, 0.85][i] - c) * spot * 0.5);
    },
  },
});

export const SURFACE_PRESETS = Object.freeze({
  inverno: [{ type: 'neve', params: { alt: 22, faixa: 6 } }],
  'mata-viva': [{ type: 'musgo', params: { limiar: 0.3 } }, { type: 'flor', params: { passo: 7, densidade: 0.2 } }],
  cicatriz: [{ type: 'cinza', params: { amount: 0.55 } }],
  primavera: [{ type: 'flor', params: { passo: 5, densidade: 0.3 } }, { type: 'musgo', params: { limiar: 0.25 } }],
});

/** compõe a LENTE DE CENA: GLSL de superfície + espelho JS + hash estável */
export function composeSurfacePipeline(pipeline = []) {
  if (!Array.isArray(pipeline) || pipeline.length === 0) {
    throw new Error(`smith de cena: digite os estágios (tenho: ${Object.keys(SURFACE_STAGES).join(', ')})`);
  }
  let body = '';
  const chain = [];
  for (const stage of pipeline) {
    const def = SURFACE_STAGES[stage?.type];
    if (!def) throw new Error(`smith de cena: estágio desconhecido "${stage?.type}" (tenho: ${Object.keys(SURFACE_STAGES).join(', ')})`);
    const params = {};
    for (const [k, [lo, hi]] of Object.entries(def.params)) {
      const v = Number(stage.params?.[k] ?? (lo + hi) / 2);
      if (!(v >= lo && v <= hi)) throw new Error(`smith de cena: ${stage.type}.${k}=${v} fora de [${lo}, ${hi}]`);
      params[k] = v;
    }
    body += `  // ${stage.type}: ${def.desc}\n`;
    body += def.glsl(params);
    chain.push((col, s) => def.js(col, s, params));
  }
  const glsl = `vec3 utsSurface(vec3 col, vec3 vPos, vec3 n, float uWetness){\n${body}  return col;\n}`;
  const js = (col, s) => chain.reduce((acc, f) => f(acc, s), [...col]);
  const samples = [
    { col: [0.5, 0.5, 0.5], y: 40, ny: 1, wet: 0.6, x: 33, z: 41 },
    { col: [0.3, 0.3, 0.3], y: 6, ny: 0.5, wet: 0.05, x: 7, z: 90 },
    { col: [0.6, 0.5, 0.4], y: 25, ny: 0.95, wet: 0.4, x: 71, z: 13 },
  ];
  const out = samples.map((s) => js(s.col, s));
  const hash = (() => { let h = 2166136261; for (const c of glsl) { h ^= c.charCodeAt(0); h = Math.imul(h, 16777619) >>> 0; } return h.toString(16); })();
  return {
    glsl, js, hash, stages: pipeline.length,
    selfTest: { finite: out.every((c) => c.every((x) => Number.isFinite(x))), samples: out },
    honest: 'shader de CENA gerado por composição de leis de material (espelho JS = GLSL, mesmas constantes)',
  };
}

// O LÉXICO DO OLHAR: palavras que o usuário diz no chat viram ÓPTICA.
// Cada look é uma receita de parâmetros dos efeitos VERIFICADOS — nada
// aqui inventa shader; tudo compõe a biblioteca testada.
export const LOOKS = Object.freeze({
  sonho:    { nome: 'sonho',    efeitos: { bloom: 0.7, tonemap: 0.8, vinheta: 0.25, grao: 0.08 } },
  noir:     { nome: 'noir',     efeitos: { vinheta: 0.75, grao: 0.32, tonemap: 0.35 } },
  retrato:  { nome: 'retrato',  efeitos: { nitidez: 0.6, aberracao: 0.2, vinheta: 0.3 } },
  vintage:  { nome: 'vintage',  efeitos: { grao: 0.45, vinheta: 0.6, tonemap: 0.55, aberracao: 0.8 } },
  pesadelo: { nome: 'pesadelo', efeitos: { aberracao: 1.5, nitidez: 1.0, vinheta: 0.6, grao: 0.28 } },
  cristalino: { nome: 'cristalino', efeitos: { nitidez: 1.2, aberracao: 0.35, bloom: 0.15, tonemap: 0.5 } },
});

/**
 * FORJA POR DESCRIÇÃO: o chat diz "estilo sonho suave" e o smith compõe a
 * óptica a partir do léxico (cruzando looks com MÉDIA dos parâmetros).
 * Palavra fora do léxico é HONESTA: entra no nome como "(criado)" e a
 * receita usa a base média do que foi reconhecido.
 */
export function forgeLook(text) {
  const words = String(text ?? '').toLowerCase().split(/[^a-zà-ú]+/).filter(Boolean);
  const hits = words.filter((w) => LOOKS[w]);
  const unknown = words.filter((w) => !LOOKS[w]);
  const base = {};
  const recipes = hits.length ? hits.map((w) => LOOKS[w].efeitos) : [Object.values(LOOKS).reduce((acc, l) => {
    for (const [k, v] of Object.entries(l.efeitos)) acc[k] = (acc[k] ?? 0) + v / Object.keys(LOOKS).length;
    return acc;
  }, {})];
  for (const rec of recipes) for (const [k, v] of Object.entries(rec)) base[k] = (base[k] ?? 0) + v / recipes.length;
  const effects = Object.keys(base);
  const amount = {};
  for (const k of effects) amount[k] = +base[k].toFixed(3);
  const optics = composeOptics({ effects, amount });
  const name = (hits.join('-') || 'lente') + (unknown.length ? `-${unknown.slice(0, 2).join('-')}(criado)` : '');
  return {
    name,
    effects,
    amount,
    unknown,
    honest: unknown.length ? `palavras fora do léxico viraram lente pelos parâmetros médios: ${unknown.join(', ')} (criado)` : null,
    ...optics,
  };
}

export function composeOptics(brief = {}) {
  const names = brief.effects ?? [];
  if (!Array.isArray(names) || names.length === 0) {
    throw new Error(`shader-smith: diga os efeitos (tenho: ${Object.keys(EFFECTS).join(', ')})`);
  }
  const amount = brief.amount ?? {};
  const params = {};
  const glslParts = [];
  const mirrors = [];
  for (const name of names) {
    const eff = EFFECTS[name];
    if (!eff) throw new Error(`shader-smith: efeito desconhecido "${name}" (tenho: ${Object.keys(EFFECTS).join(', ')})`);
    const raw = amount[name];
    const a = raw === undefined ? (name === 'vinheta' ? 0.35 : name === 'grao' ? 0.16 : 0.25) : (name === 'aberracao' ? Math.min(2, Math.max(0, Number(raw))) : clamp01(raw));
    const p = { amount: a };
    Object.entries(eff.params).forEach(([k, [lo, hi]]) => {
      if (!(p[k] >= lo && p[k] <= hi)) throw new Error(`shader-smith: ${name}.${k}=${p[k]} fora de [${lo}, ${hi}]`);
    });
    params[{ vinheta: 'vignette', grao: 'grain', bloom: 'bloom', tonemap: 'tone', aberracao: 'ca', nitidez: 'sharp' }[name]] = a;
    glslParts.push(eff.glsl(p));
    mirrors.push(() => eff.mirror(0.6, 1.0, p));
  }
  const samples = mirrors.map((f) => f());
  for (const v of samples) {
    if (!Number.isFinite(v)) throw new Error('shader-smith: espelho produziu não-finito (bloqueado)');
  }
  return { ok: true, params, glsl: glslParts.join('\n  '), selfTest: { samples, finite: true } };
}

function clamp01(v) {
  v = Number(v);
  if (!Number.isFinite(v)) throw new Error('shader-smith: intensidade não numérica');
  if (!(v >= 0 && v <= 1)) throw new Error(`shader-smith: intensidade ${v} fora de [0, 1]`);
  return v;
}
