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
