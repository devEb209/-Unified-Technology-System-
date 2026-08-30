// UTS :: render/clouds — ADR-020: clouds are NOT painted sprites. They are
// the SAME air that rains and burns: water vapor CONDENSES where the
// represented atmosphere saturates, and the renderer integrates the light
// scattered by that condensed water along the view ray (Beer extinction +
// Henyey–Greenstein forward scattering of cloud droplets). The JS mirror
// and the GENERATED GLSL share the same constants (same physics).

export const CLOUD_CONST = Object.freeze({
  LO: 190,          // slab bottom (world units)
  HI: 330,          // slab top
  DENSITY: 0.055,   // extinction per unit density per world unit
  HG: 0.58,         // droplet anisotropy (forward-scattering peak)
  AMBIENT: 0.30,    // sky ambient scattered inside the cloud
  SCALE: 0.008,     // world -> noise space
  STEPS: 12,
});

const c01 = (x) => (x < 0 ? 0 : x > 1 ? 1 : x);
const sstep = (a, b, x) => { const t = c01((x - a) / (b - a)); return t * t * (3 - 2 * t); };

// deterministic hash → [0,1) (same shape in GLSL; not bit-equal across langs,
// same structure and constants = same physics)
const fract = (x) => x - Math.floor(x);
function hash3(x, y, z) {
  return fract(Math.sin(x * 127.1 + y * 311.7 + z * 74.7) * 43758.5453);
}
function noise3(x, y, z) {
  const xi = Math.floor(x), yi = Math.floor(y), zi = Math.floor(z);
  const xf = x - xi, yf = y - yi, zf = z - zi;
  const u = xf * xf * (3 - 2 * xf), v = yf * yf * (3 - 2 * yf), w = zf * zf * (3 - 2 * zf);
  const n = (i, j, k) => hash3(xi + i, yi + j, zi + k);
  const mix = (a, b, t) => a + (b - a) * t;
  return mix(
    mix(mix(n(0, 0, 0), n(1, 0, 0), u), mix(n(0, 1, 0), n(1, 1, 0), u), v),
    mix(mix(n(0, 0, 1), n(1, 0, 1), u), mix(n(0, 1, 1), n(1, 1, 1), u), v),
    w,
  );
}

/** condensed-water density at a world point (0..1). seedT drifts the field. */
export function densityAt(p, cov, seedT = 0) {
  const C = CLOUD_CONST;
  if (cov <= 0.02) return 0;
  const s = (p[1] - C.LO) / (C.HI - C.LO);
  if (s <= 0 || s >= 1) return 0;
  const prof = s * (1 - s) * 4; // rounded slab: thin at base and top
  const x = p[0] * C.SCALE + seedT, y = p[1] * C.SCALE, z = p[2] * C.SCALE;
  const n = noise3(x, y, z) * 0.55 + noise3(x * 2.3, y * 2.3, z * 2.3) * 0.28 + noise3(x * 5.1, y * 5.1, z * 5.1) * 0.17;
  return c01((n * prof * 1.9 - (1 - cov)) * 4.5);
}

/** Cloud transmittance toward the sun from a WORLD point (cloud shadows). */
export function transmitToward(pos, sunDir, cov, seedT = 0) {
  return march(pos, sunDir, sunDir, cov, { intensity: 1 }, { seedT, steps: 8 }).T;
}

// Henyey–Greenstein phase for cloud droplets (forward peak toward the sun)
export function phaseHG(cosT, g = CLOUD_CONST.HG) {
  const g2 = g * g;
  return (1 - g2) / (4 * Math.PI * Math.pow(1 + g2 - 2 * g * cosT, 1.5));
}

/**
 * Integrate sunlight through the cloud slab along a view ray.
 * Returns { rgb: in-scattered radiance, T: transmittance to the sky }.
 * The silver lining is EMERGENT: near the sun the HG forward peak dominates.
 */
export function march(origin, dir, sunDir, cov, air = { intensity: 22 }, opts = {}) {
  const C = CLOUD_CONST;
  const N = opts.steps ?? C.STEPS;
  const sunE = (air.intensity ?? 22) * c01(sunDir[1] * 4 + 0.12);
  const out = { rgb: [0, 0, 0], T: 1 };
  if (cov <= 0.02 || sunE <= 0.01) return out;
  // slab intersection
  const dy = dir[1];
  let t0, t1;
  if (Math.abs(dy) < 1e-4) {
    if (origin[1] < C.LO || origin[1] > C.HI) return out;
    t0 = 0; t1 = (C.HI - C.LO);
  } else {
    const ta = (C.LO - origin[1]) / dy, tb = (C.HI - origin[1]) / dy;
    t0 = Math.max(Math.min(ta, tb), 0); t1 = Math.max(ta, tb);
  }
  if (t1 <= t0) return out;
  const len = (t1 - t0) / N;
  const cosT = c01(dir[0] * sunDir[0] + dir[1] * sunDir[1] + dir[2] * sunDir[2]);
  const ph = 0.25 + phaseHG(cosT) * 2.6; // scaled to [~0.25 .. ~4]
  for (let i = 0; i < N; i++) {
    const t = t0 + (i + 0.5) * len;
    const p = [origin[0] + dir[0] * t, origin[1] + dir[1] * t, origin[2] + dir[2] * t];
    const d = densityAt(p, cov, opts.seedT ?? 0);
    if (d < 0.004) continue;
    // one light sample toward the sun over a FIXED optical depth (28 world
    // units) — interior dark, edges bright (len-scaled OD exploded)
    const q = [p[0] + sunDir[0] * 14, p[1] + sunDir[1] * 14, p[2] + sunDir[2] * 14];
    const dl = densityAt(q, cov, opts.seedT ?? 0);
    const shadow = Math.exp(-(d * 0.6 + dl * 1.4) * C.DENSITY * 28);
    const a = 1 - Math.exp(-d * C.DENSITY * len);
    const insc = sunE * ph * shadow * (0.55 + C.AMBIENT);
    out.rgb[0] += out.T * a * insc;
    out.rgb[1] += out.T * a * insc;
    out.rgb[2] += out.T * a * insc;
    out.T *= 1 - a;
    if (out.T < 0.02) { out.T = 0; break; }
  }
  return out;
}

// ---- GENERATED GLSL (same constants, same structure — do not hand-edit) ----
// GLSL ES 3.0 é ESTRITO: inteiro não converte para float implicitamente
// (driver de celular reprova `const float X = 190;`). Floats SEMPRE com ponto.
const f = (x) => { const n = Number(x); return Number.isInteger(n) ? n + '.0' : String(n); };
const C = CLOUD_CONST;
export const CLOUD_GLSL = `// ---- clouds: GENERATED from CLOUD_CONST (src/render/clouds.js) — do not hand-edit
const float C_LO = ${f(C.LO)};
const float C_HI = ${f(C.HI)};
const float C_DENS = ${f(C.DENSITY)};
const float C_HG = ${f(C.HG)};
const float C_AMB = ${f(C.AMBIENT)};
const float C_SCALE = ${f(C.SCALE)};
float cHash3(vec3 p){ return fract(sin(dot(p, vec3(127.1, 311.7, 74.7)))*43758.5453); }
float cNoise3(vec3 p){
  vec3 i = floor(p); vec3 fr = fract(p);
  vec3 u = fr*fr*(3.0-2.0*fr);
  float n000=cHash3(i), n100=cHash3(i+vec3(1,0,0)), n010=cHash3(i+vec3(0,1,0)), n110=cHash3(i+vec3(1,1,0));
  float n001=cHash3(i+vec3(0,0,1)), n101=cHash3(i+vec3(1,0,1)), n011=cHash3(i+vec3(0,1,1)), n111=cHash3(i+vec3(1,1,1));
  return mix(mix(mix(n000,n100,u.x),mix(n010,n110,u.x),u.y), mix(mix(n001,n101,u.x),mix(n011,n111,u.x),u.y), u.z);
}
float cDensity(vec3 p, float cov){
  if (cov <= 0.02) return 0.0;
  float s = (p.y - C_LO) / (C_HI - C_LO);
  if (s <= 0.0 || s >= 1.0) return 0.0;
  float prof = s*(1.0-s)*4.0;
  vec3 q = vec3(p.x*C_SCALE, p.y*C_SCALE, p.z*C_SCALE);
  float n = cNoise3(q)*0.55 + cNoise3(q*2.3)*0.28 + cNoise3(q*5.1)*0.17;
  return clamp((n*prof*1.9 - (1.0-cov))*4.5, 0.0, 1.0);
}
void marchClouds(vec3 o, vec3 d, vec3 sun, float cov, float sunE, float seedT,
                 out vec3 rgb, out float T){
  rgb = vec3(0.0); T = 1.0;
  if (cov <= 0.02 || sunE <= 0.01) return;
  float t0, t1;
  if (abs(d.y) < 1e-4) {
    if (o.y < C_LO || o.y > C_HI) return;
    t0 = 0.0; t1 = C_HI - C_LO;
  } else {
    float ta = (C_LO - o.y)/d.y, tb = (C_HI - o.y)/d.y;
    t0 = max(min(ta,tb), 0.0); t1 = max(ta,tb);
  }
  if (t1 <= t0) return;
  const int CN = ${C.STEPS};
  float len = (t1-t0)/float(CN);
  float cosT = clamp(dot(d, sun), 0.0, 1.0);
  float g2 = C_HG*C_HG;
  float ph = 0.25 + ((1.0-g2)/(4.0*3.14159*pow(1.0+g2-2.0*C_HG*cosT, 1.5)))*2.6;
  for (int i = 0; i < CN; i++) {
    float t = t0 + (float(i)+0.5)*len;
    vec3 p = o + d*t;
    float dsn = cDensity(p, cov);
    if (dsn < 0.004) continue;
    float dl = cDensity(p + sun*14.0, cov);
    float shadow = exp(-(dsn*0.6 + dl*1.4)*C_DENS*28.0);
    float a = 1.0 - exp(-dsn*C_DENS*len);
    float insc = sunE * ph * shadow * (0.55 + C_AMB);
    rgb += T * a * insc;
    T *= 1.0 - a;
    if (T < 0.02) { T = 0.0; break; }
  }
}
`;
