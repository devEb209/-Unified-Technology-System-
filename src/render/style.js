// UTS :: render/style — THE STYLE ENGINE. The user SAYS the style in the
// chat ("anime", "noir", "estilo aquarela do meu") and the AI applies it.
// A style is NOT a fake filter painted over broken math: the physics is
// solved FIRST, always the same; the style is the D-O15 RE-REPRESENTATION
// of the resolved light — bands, rim, saturation, contrast, tint. Rule 2
// of the house: optimize how reality is REPRESENTED, never destroy it.
// Unknown name + parameters = the AI COMPOSES a new style (no limits).

/** RGB luminance weights (Rec. 601) shared with the shaders */
export const LUMA = [0.299, 0.587, 0.114];

const idTint = () => [1, 1, 1];

/**
 * Style parameters (the ONLY knobs the lens may turn — every shader gets
 * exactly these): bands (cel/posterize levels, 0 = off), sat, contrast,
 * rim (silhouette cel-light, 0 = off), tint.
 */
function P({ bands = 0, sat = 1, contrast = 1, rim = 0, tint = idTint(), vignette = 0, grain = 0, bloom = 0, tone = 0 }) {
  return Object.freeze({
    bands: Math.max(0, Number(bands) || 0),
    sat: clampN(sat, 0, 2.5),
    contrast: clampN(contrast, 0.2, 3),
    rim: clampN(rim, 0, 1.5),
    tint: [clampN(tint[0], 0, 2), clampN(tint[1], 0, 2), clampN(tint[2], 0, 2)],
    vignette: clampN(vignette, 0, 1), // vinheta NATURAL cos⁴ (óptica da lente)
    grain: clampN(grain, 0, 0.6),     // grão do SENSOR (ruído de fóton)
    bloom: clampN(bloom, 0, 1),       // corona ciliar (bloom fisiológico)
    tone: clampN(tone, 0, 1),         // tonemap de display (Reinhard)
  });
}

function clampN(v, lo, hi) {
  v = Number(v);
  if (!Number.isFinite(v)) throw new Error(`estilo: parâmetro não numérico (${v})`);
  return Math.min(hi, Math.max(lo, v));
}

/** the PRESETS — realistic is the honest identity (physics as it is) */
export const STYLES = Object.freeze({
  realista: P({ bands: 0, sat: 1, contrast: 1, rim: 0 }),
  anime: P({ bands: 4, sat: 1.35, contrast: 1.12, rim: 0.55, tint: [1.02, 1.0, 1.04] }),
  noir: P({ bands: 0, sat: 0, contrast: 1.35, rim: 0.18, tint: [0.98, 1.0, 1.05], vignette: 0.35, grain: 0.16 }),
  pastel: P({ bands: 0, sat: 0.78, contrast: 0.92, rim: 0.1, tint: [1.05, 1.02, 1.0] }),
  cyberpunk: P({ bands: 0, sat: 1.4, contrast: 1.2, rim: 0.4, tint: [0.92, 1.0, 1.18] }),
  carvao: P({ bands: 3, sat: 0, contrast: 1.5, rim: 0.25, tint: [1, 1, 1] }),
  aquarela: P({ bands: 0, sat: 1.1, contrast: 0.85, rim: 0.15, tint: [1.03, 1.0, 0.98] }),
});

export const STYLE_NAMES = Object.freeze(Object.keys(STYLES));

/**
 * Resolve a style by name with optional overrides. Unknown name WITHOUT
 * overrides is an honest error. Unknown name WITH overrides COMPOSES a
 * new named style (the user said what they want — the AI builds it).
 */
export function styleParams(name, overrides = {}) {
  const key = String(name ?? 'realista').toLowerCase().trim();
  const base = STYLES[key];
  const hasOverrides = overrides && Object.keys(overrides).length > 0;
  if (!base && !hasOverrides) {
    throw new Error(`estilo desconhecido: "${name}" (disponíveis: ${STYLE_NAMES.join(', ')} — ou passe parâmetros para eu CRIAR o seu)`);
  }
  const params = P({ ...(base ?? STYLES.realista), ...overrides });
  return { name: base ? key : `${key} (criado)`, params, preset: Boolean(base) };
}

/**
 * The engine lives on the WORLD (style is state, not a string loose in
 * the void). apply() returns the resolved style and the world stores it;
 * the frame carries the params to the shaders.
 */
export class StyleEngine {
  constructor(world) {
    this.world = world;
    this.history = [];
  }

  apply(name, overrides = {}) {
    const r = styleParams(name, overrides);
    this.world.style = { name: r.name, params: r.params, at: this.world.clock?.tick ?? 0 };
    this.history.push({ name: r.name, tick: this.world.style.at });
    if (this.history.length > 100) this.history.shift();
    if (this.world.rrw) {
      this.world.rrw.emitEvent({ type: 'world.style.changed', subject: 'world', data: { style: r.name }, tick: this.world.style.at });
    }
    return r;
  }

  list() { return STYLE_NAMES.slice(); }
}
