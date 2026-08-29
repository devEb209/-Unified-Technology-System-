// UTS :: render/smoke — VOLUMETRIC SMOKE of horizon fires, integrated in the
// sky pass (beyond ~260 units the terrain rarely occludes a 100-high plume —
// the documented scope of this march; near fires keep the particle plume).
// The plume DENSITY is the combustion's own output (intensity, fuel, wind),
// leaning downwind with height (wind shear), LIT by the same sky physics.

export const SMOKE_CONST = Object.freeze({
  R0: 7,           // plume base radius (world units)
  SPREAD: 0.035,   // radius grows per unit of height
  TOP: 110,        // plume height at full intensity
  DENS: 0.028,     // extinction per unit density
  SHEAR: 0.55,     // how much the column leans downwind at the top
});

const c01 = (x) => (x < 0 ? 0 : x > 1 ? 1 : x);
const fract = (x) => x - Math.floor(x);
const hash2 = (a, b) => fract(Math.sin(a * 127.1 + b * 311.7) * 43758.5453);

/**
 * Smoke density at a world point from ONE fire (0..1). Column: radial
 * Gaussian leaning downwind with height, capped by intensity.
 */
export function smokeDensity(px, py, pz, fire, t, wind, windDir) {
  const C = SMOKE_CONST;
  const I = c01(fire.intensity ?? 0.5);
  if (I <= 0.03 || py < fire.pos[1] || py > fire.pos[1] + C.TOP * I) return 0;
  const h = py - fire.pos[1];
  const lean = C.SHEAR * wind * (h / C.TOP);
  const cx = fire.pos[0] + windDir[0] * lean * C.TOP;
  const cz = fire.pos[2] + windDir[1] * lean * C.TOP;
  const r = C.R0 * (1 + (h / C.TOP) * (2 + 6 * c01(wind)));
  const dx = px - cx, dz = pz - cz;
  const radial = Math.exp(-(dx * dx + dz * dz) / (2 * r * r * 0.35));
  // vertical profile: dense low, thinning up (rises and disperses)
  const vert = (1 - h / (C.TOP * I)) * Math.min(1, h / 6 + 0.15);
  // deterministic puffing
  const puff = 0.7 + 0.6 * hash2(Math.floor(px * 0.2) + Math.floor(t * 2), Math.floor(h));
  return c01(radial * vert * (0.35 + 0.65 * I) * puff);
}

/**
 * March a view ray through ALL far fires' plumes (front-to-back).
 * Lit by the sky light (smoke scatters it); near the base, glows with the
 * fire. Returns { rgb, T } to composite over the sky.
 */
export function smokeMarch(origin, dir, fires, t, wind, windDir, skyLight = 0.8, N = 10) {
  const C = SMOKE_CONST;
  const out = { rgb: [0, 0, 0], T: 1 };
  if (!fires || fires.length === 0) return out;
  // per-fire ADAPTIVE band: project the ray onto the plume axis and march
  // ±BAND around it (a fixed 0..700 band would miss far plumes entirely)
  const BAND = 140;
  for (const fire of fires) {
    const fx = fire.pos[0] - origin[0], fy = fire.pos[1] - origin[1], fz = fire.pos[2] - origin[2];
    const t0 = Math.max(0, fx * dir[0] + fy * dir[1] + fz * dir[2]);
    const step = (2 * BAND) / N;
    for (let i = 0; i < N; i++) {
      const tr = t0 - BAND + (i + 0.5) * step;
      if (tr <= 0) continue;
      const px = origin[0] + dir[0] * tr, py = origin[1] + dir[1] * tr, pz = origin[2] + dir[2] * tr;
      const d = smokeDensity(px, py, pz, fire, t, wind, windDir);
      if (d < 0.01) continue;
      const a = 1 - Math.exp(-d * C.DENS * step);
      // smoke scatters sky light; the plume base glows with the fire itself
      const glow = c01(1 - (py - fire.pos[1]) / 26) * (fire.intensity ?? 0.5);
      const r = 0.10 * skyLight + 0.9 * glow;
      const g = 0.11 * skyLight + 0.32 * glow;
      const b = 0.13 * skyLight + 0.08 * glow;
      out.rgb[0] += out.T * a * r * 2.2;
      out.rgb[1] += out.T * a * g * 2.2;
      out.rgb[2] += out.T * a * b * 2.2;
      out.T *= 1 - a;
      if (out.T < 0.03) { out.T = 0; return out; }
    }
  }
  return out;
}

// ---- GENERATED GLSL (same constants — do not hand-edit) ----
const f = (x) => String(Number(x));
const C2 = SMOKE_CONST;
export const SMOKE_GLSL = `// ---- smoke: GENERATED from SMOKE_CONST (src/render/smoke.js) — do not hand-edit
const float SM_R0 = ${f(C2.R0)};
const float SM_TOP = ${f(C2.TOP)};
const float SM_DENS = ${f(C2.DENS)};
const float SM_SHEAR = ${f(C2.SHEAR)};
float smHash(vec2 p){ return fract(sin(dot(p, vec2(127.1, 311.7)))*43758.5453); }
float smokeDensity(vec3 p, vec3 fp, float fi, float t, float wind, vec2 wd){
  if (fi <= 0.03 || p.y < fp.y || p.y > fp.y + SM_TOP*fi) return 0.0;
  float h = p.y - fp.y;
  float lean = SM_SHEAR*wind*(h/SM_TOP);
  vec2 c = fp.xz + wd*lean*SM_TOP;
  float r = SM_R0*(1.0 + (h/SM_TOP)*(2.0 + 6.0*clamp(wind,0.0,1.0)));
  vec2 dd = p.xz - c;
  float radial = exp(-dot(dd,dd)/(2.0*r*r*0.35));
  float vert = (1.0 - h/(SM_TOP*fi))*min(1.0, h/6.0 + 0.15);
  float puff = 0.7 + 0.6*smHash(vec2(floor(p.x*0.2 + t*2.0), floor(h)));
  return clamp(radial*vert*(0.35 + 0.65*fi)*puff, 0.0, 1.0);
}
vec3 smokeMarch(vec3 o, vec3 d, vec4 fpI[4], int nF, float t, float wind, vec2 wd, float skyL, out float T){
  T = 1.0; vec3 acc = vec3(0.0);
  if (nF <= 0) return acc;
  for (int k = 0; k < 4; k++) {
    if (k >= nF) break;
    vec3 fp = fpI[k].xyz; float fi = fpI[k].w;
    float t0 = max(0.0, dot(fp - o, d));
    for (int i = 0; i < 10; i++) {
      float tr = t0 - 140.0 + (float(i)+0.5)*28.0;
      if (tr <= 0.0) continue;
      vec3 p = o + d*tr;
      float ds = smokeDensity(p, fp, fi, t, wind, wd);
      if (ds < 0.01) continue;
      float a = 1.0 - exp(-ds*SM_DENS*28.0);
      float glow = clamp(1.0 - (p.y - fp.y)/26.0, 0.0, 1.0)*fi;
      vec3 col = vec3(0.10*skyL + 0.9*glow, 0.11*skyL + 0.32*glow, 0.13*skyL + 0.08*glow);
      acc += T*a*col*2.2;
      T *= 1.0 - a;
      if (T < 0.03) { T = 0.0; return acc; }
    }
  }
  return acc;
}
`;
