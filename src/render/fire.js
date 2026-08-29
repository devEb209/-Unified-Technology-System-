// UTS :: render/fire — ADR-020: fire light is EMITTED by hot gas. The
// particles here are a real simulated system (buoyant hot plume rising,
// cooling, dying), and their color is the PLANK LAW of their temperature —
// blackbody, never an artistic ramp. Anchors come FROM the combustion field
// (frame hazards carry intensity/fuel mirrored from RRW).

export const FIRE_CONST = Object.freeze({
  T0: 900,        // K at zero intensity (smoldering wood flame)
  T1: 1800,       // K at full intensity (bright wood flame)
  COOL: 0.75,     // fraction of temperature lost over a particle life
  RISE: 3.2,      // buoyant rise speed (world units/s at full intensity)
  LIFE: 1.15,     // seconds (scaled per particle)
  SMOKE_AT: 0.55, // age where the cooled plume becomes smoke
  SMOKE: [0.23, 0.23, 0.25],
  MAX_PER_FIRE: 40,
});

/**
 * Blackbody chromaticity normalized to [0,1] (Planckian locus approximation
 * — Tanner Helland's CIE fit). This is PHYSICS: 1000K glows red, 1800K
 * orange-yellow, the sun (~5800K) is white.
 */
export function blackbody(kelvin) {
  const t = Math.max(100, kelvin) / 100;
  let r, g, b;
  if (t <= 66) { r = 255; g = 99.4708025861 * Math.log(t) - 161.1195681661; }
  else { r = 329.698727446 * Math.pow(t - 60, -0.1332047592); g = 288.1221695283 * Math.pow(t - 60, -0.0755148492); }
  if (t >= 66) b = 255;
  else if (t <= 19) b = 0;
  else b = 138.5177312231 * Math.log(t - 10) - 305.0447927307;
  const c = (x) => Math.min(255, Math.max(0, x)) / 255;
  return [c(r), c(g), c(b)];
}

/** flame temperature of the represented combustion (K) — 900..1800 */
export function flameTemp(intensity) {
  return FIRE_CONST.T0 + (FIRE_CONST.T1 - FIRE_CONST.T0) * Math.min(1, Math.max(0, intensity));
}

const fract = (x) => x - Math.floor(x);
const hash2 = (a, b) => fract(Math.sin(a * 127.1 + b * 311.7) * 43758.5453);

/**
 * Emit the particle system of ONE fire anchor. Deterministic: same
 * (cellKey, intensity, fuel, time, wind) -> same particles. Layout matches
 * the horizon/fire vertex format: [x, y, z, size, r, g, b, alpha] * n.
 */
export function emitFire(fire, time, wind = 0.2, out = [], windDir = [1, 0, 0]) {
  const C = FIRE_CONST;
  const intensity = Math.min(1, Math.max(0, fire.intensity ?? 0.5));
  const fuel = Math.min(100, Math.max(0, fire.fuel ?? 20));
  let seed = 0;
  for (let i = 0; i < (fire.cellKey ?? String(fire.id ?? 0)).length; i++) seed = (seed * 31 + (fire.cellKey ?? String(fire.id ?? 0)).charCodeAt(i)) % 997;
  const n = Math.min(C.MAX_PER_FIRE, 6 + Math.round(fuel * 0.3 * (0.4 + 0.6 * intensity)));
  const T0 = flameTemp(intensity);
  for (let i = 0; i < n; i++) {
    const h1 = hash2(seed + 1, i * 3.7), h2 = hash2(seed + 7, i * 5.3), h3 = hash2(seed + 13, i * 7.1), h4 = hash2(seed + 29, i * 9.2);
    const life = C.LIFE * (0.5 + h1 * 0.9);
    const age = fract(time / life + h2);
    const ang = h3 * Math.PI * 2;
    const rad = (0.25 + h4 * 0.85) * (0.4 + 0.6 * intensity) * (0.35 + age * 1.5);
    const x = fire.pos[0] + Math.cos(ang) * rad + windDir[0] * wind * age * life * 2.2;
    const z = fire.pos[2] + Math.sin(ang) * rad + windDir[2] * wind * age * life * 2.2;
    const y = fire.pos[1] + age * C.RISE * (0.5 + intensity * 0.6) * (0.55 + 0.45 * h4);
    const size = (0.55 + 1.5 * intensity) * (0.35 + age * 1.15);
    const T = T0 * (1 - age * C.COOL);
    let [r, g, b] = blackbody(T);
    let a = (1 - age) * (1 - age) * 0.9;
    if (age > C.SMOKE_AT) {
      const sm = (age - C.SMOKE_AT) / (1 - C.SMOKE_AT);
      r += (C.SMOKE[0] - r) * sm; g += (C.SMOKE[1] - g) * sm; b += (C.SMOKE[2] - b) * sm;
      a *= 1 - sm * 0.72;
    }
    out.push(x, y, z, size, r, g, b, a);
  }
  return out;
}

/** Every burning anchor in the frame → one interleaved particle buffer. */
export function emitFrame(fires, time, wind = 0.2, windDir = [1, 0, 0]) {
  const out = [];
  for (const fire of fires) emitFire(fire, time, wind, out, windDir);
  return new Float32Array(out);
}
