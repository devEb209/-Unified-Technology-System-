// UTS :: render/ocean — ADR-020: the sea is WIND-DRIVEN water. Wave
// components obey the deep-water dispersion relation ω = √(g·k) (long swell
// runs faster than short chop — you can SEE the physics), they travel along
// the SAME wind that bends trees and advects clouds, their height grows with
// the wind's energy, and breaking crests entrain AIR (whitecaps). The JS
// mirror and the GENERATED GLSL share the same constants (same physics).

export const OCEAN_CONST = Object.freeze({
  G: 9.81,                        // gravity (world units ≈ meters)
  // [wavenumber k (rad/unit), angular spread from wind (deg), relative amp]
  WAVES: [
    { k: 0.11, spread: 0,  a: 0.55 },  // main swell along the wind
    { k: 0.17, spread: 28, a: 0.30 },  // recent chop, rotated by the gusts
    { k: 0.05, spread: 63, a: 0.40 },  // old cross-swell (outlives the gust)
  ],
  BASE_AMP: 0.10,
  WIND_AMP: 0.42,                 // amplitude grows with the wind's ENERGY (v²)
  FOAM_STEEP: 1.15,               // normalized crest where foam begins (calm)
  FOAM_WIND_GAIN: 0.55,           // wind lowers the threshold (storm = white sea)
  PHASE_OFFSETS: [0.7, 2.1, 4.4], // deterministic per-component phase
});

const c01 = (x) => (x < 0 ? 0 : x > 1 ? 1 : x);

/** deep-water dispersion: ω = √(g·k) (physics, not taste) */
export function omega(k) {
  return Math.sqrt(OCEAN_CONST.G * k);
}

/** component direction: the wind direction rotated by the component's spread */
export function waveDir(windDir, spreadDeg) {
  const a = (spreadDeg * Math.PI) / 180;
  const c = Math.cos(a), s = Math.sin(a);
  const l = Math.hypot(windDir[0], windDir[1]) || 1;
  const d0 = windDir[0] / l, d1 = windDir[1] / l;
  return [d0 * c - d1 * s, d0 * s + d1 * c];
}

/** total amplitude — grows with the wind's ENERGY, never below the calm sea */
export function amp(wind) {
  return OCEAN_CONST.BASE_AMP + OCEAN_CONST.WIND_AMP * Math.max(0, wind) ** 2;
}

/**
 * Height of the sea at (x, z), time t. Deterministic. Returns { h, foam }:
 * foam is the air entrained by breaking crests (threshold falls with wind).
 */
export function waveField(x, z, t, wind, windDir) {
  const C = OCEAN_CONST;
  const A = amp(wind);
  let h = 0, dydx = 0, dydz = 0;
  for (let i = 0; i < C.WAVES.length; i++) {
    const w = C.WAVES[i];
    const d = waveDir(windDir, w.spread);
    const ph = w.k * (d[0] * x + d[1] * z) - omega(w.k) * t + C.PHASE_OFFSETS[i];
    const s = Math.sin(ph), co = Math.cos(ph);
    const ai = w.a * A;
    h += ai * s;
    dydx += ai * w.k * d[0] * co;
    dydz += ai * w.k * d[1] * co;
  }
  // breaking crests: normalized crest height crosses a wind-dependent threshold
  const hNorm = h / Math.max(A, 1e-6);
  const thr = C.FOAM_STEEP - C.FOAM_WIND_GAIN * Math.max(0, wind);
  const foam = c01((hNorm - thr * 0.85) / 0.5);
  return { h, foam, grad: [dydx, dydz] };
}

/** surface normal from the SAME field (consistent shading, no fakes) */
export function waveNormal(grad) {
  const l = Math.hypot(grad[0], 1, grad[1]) || 1;
  return [grad[0] / l * -1, 1 / l, grad[1] / l * -1];
}

// ---- GENERATED GLSL (same constants, same structure — do not hand-edit) ----
const f = (x) => String(Number(x));
const C = OCEAN_CONST;
const waveTable = C.WAVES.map((w, i) =>
  `const float OK${i} = ${f(w.k)}; const float OS${i} = ${f((w.spread * Math.PI) / 180)}; const float OA${i} = ${f(w.a)};`).join('\n');
const offsets = C.PHASE_OFFSETS.map(f).join(', ');
export const OCEAN_GLSL = `// ---- ocean: GENERATED from OCEAN_CONST (src/render/ocean.js) — do not hand-edit
const float OCEAN_G = ${f(C.G)};
${waveTable}
const float O_BASE = ${f(C.BASE_AMP)};
const float O_WAMP = ${f(C.WIND_AMP)};
const float O_FSTEEP = ${f(C.FOAM_STEEP)};
const float O_FGAIN = ${f(C.FOAM_WIND_GAIN)};
vec2 oWaveDir(vec2 wd, float sp){
  float l = max(length(wd), 1e-4);
  vec2 d = wd / l;
  float c = cos(sp), s = sin(sp);
  return vec2(d.x*c - d.y*s, d.x*s + d.y*c);
}
vec3 waveField(vec2 xz, float t, float wind, vec2 wd, out float foam){
  float A = O_BASE + O_WAMP*max(wind,0.0)*max(wind,0.0);
  float h = 0.0; vec2 g = vec2(0.0);
  vec2 d0 = oWaveDir(wd, OS0);
  float ph0 = OK0*dot(d0,xz) - sqrt(OCEAN_G*OK0)*t + ${f(C.PHASE_OFFSETS[0])};
  h += OA0*A*sin(ph0); g += OA0*A*OK0*cos(ph0)*d0;
  vec2 d1 = oWaveDir(wd, OS1);
  float ph1 = OK1*dot(d1,xz) - sqrt(OCEAN_G*OK1)*t + ${f(C.PHASE_OFFSETS[1])};
  h += OA1*A*sin(ph1); g += OA1*A*OK1*cos(ph1)*d1;
  vec2 d2 = oWaveDir(wd, OS2);
  float ph2 = OK2*dot(d2,xz) - sqrt(OCEAN_G*OK2)*t + ${f(C.PHASE_OFFSETS[2])};
  h += OA2*A*sin(ph2); g += OA2*A*OK2*cos(ph2)*d2;
  float hn = h/max(A, 1e-4);
  foam = clamp((hn - (O_FSTEEP - O_FGAIN*max(wind,0.0))*0.85)/0.5, 0.0, 1.0);
  return vec3(g.x, h, g.y); // (dh/dx, h, dh/dz)
}
`;
