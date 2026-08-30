// UTS :: render/scattering — PHYSICAL SKY: single-scattering Rayleigh+Mie.
//
//   ADR-020 (graphics doctrine): appearance is a CONSEQUENCE of the
//   represented reality. The sky is NOT a gradient someone painted — it is
//   the integral of sunlight scattered by the AIR along the view ray. This
//   module is the single source of truth for that physics:
//     - SCATTER_GLSL is GENERATED from the same constants the JS mirror
//       uses, so tests on the mirror are tests on the shader's physics;
//     - the renderer integrates per pixel; D-O15 governs the COST
//       (sample counts), never the phenomenon.
//   (Simplified single-scattering in a normalized shell — the same model
//   class used by production atmospheric renderers, no external code.)

const fmt = (x) => (Number.isInteger(x) ? x.toFixed(1) : String(x));

export const SCATTER_CONST = Object.freeze({
  // Rayleigh coefficients preserve the REAL spectral ratios (λ^-4: blue≫red)
  BETA_R: [1.16, 2.70, 6.62],
  BETA_M: 1.8,       // Mie (aerosols) base in domain units
  MIE_G: 0.76,       // Henyey-Greenstein anisotropy (forward-scattering)
  INTENSITY: 22.0,   // sun illuminance in domain units
  HR: 8.0, HM: 12.0, // scale heights (density falloff with altitude)
  DISK: 0.9997,      // cos(angle) of the sun's apparent disk edge
  NIGHT_AIR: [0.012, 0.02, 0.05],
});

const clamp = (x, a, b) => Math.min(b, Math.max(a, x));
const smoothstep = (a, b, x) => { const t = clamp((x - a) / (b - a), 0, 1); return t * t * (3 - 2 * t); };

export function phaseR(t) { return (3 / (16 * Math.PI)) * (1 + t * t); }
export function phaseM(t) {
  const g = SCATTER_CONST.MIE_G, g2 = g * g;
  return ((3 / (8 * Math.PI)) * ((1 - g2) * (1 + t * t))) / Math.pow((2 + g2) * (1 + g2 - 2 * g * t), 1.5);
}

/**
 * JS MIRROR of the GLSL integration (same constants, same sample counts).
 * skyColor(viewDir, sunDir, air) → [r,g,b] in 0..~2+ (HDR-ish; the shader
 * writes it directly, tests assert physics on it).
 */
export function skyColor(dir, sunDir, air = {}, N = 8) {
  const { BETA_R, BETA_M, HR, HM, DISK, NIGHT_AIR, INTENSITY } = SCATTER_CONST;
  const mie = air.mie ?? 1;
  const I = air.intensity ?? INTENSITY;
  const el = sunDir[1] ?? 0;
  const dayFade = smoothstep(-0.14, 0.03, el);           // the sun SETS the light
  let s = [sunDir[0], Math.max(sunDir[1], 0.03), sunDir[2]]; // light march stays lit
  const sl = Math.hypot(s[0], s[1], s[2]) || 1;
  s = [s[0] / sl, s[1] / sl, s[2] / sl];
  let d = dir[1] < 0 ? [dir[0], -dir[1] * 0.25 + 0.02, dir[2]] : [...dir]; // ground blocks: dimmed mirror
  const dl = Math.hypot(d[0], d[1], d[2]) || 1;
  d = [d[0] / dl, d[1] / dl, d[2] / dl];
  const cosT = clamp(d[0] * s[0] + d[1] * s[1] + d[2] * s[2], -1, 1);
  // a horizontal ray crosses MUCH more air than a vertical one (that is WHY
  // sunsets are red): the path leaves the dense shell after ~1/d.y
  const tEnd = clamp(1 / Math.max(d[1], 0.05), 1, 8);
  const step = tEnd / N;
  let odR = 0, odM = 0;
  const sumR = [0, 0, 0]; let sumM = 0;
  for (let i = 0; i < N; i++) {
    const t = (i + 0.5) * step;
    const y = d[1] * t;
    const hR = Math.exp(-Math.max(y, 0) * HR);
    const hM = Math.exp(-Math.max(y, 0) * HM);
    // the in-transmittance counts air UP TO the sample (trapezoid: its own
    // half segment too) — counting the full segment twice killed the horizon
    const odRm = odR + hR * step * 0.5, odMm = odM + hM * step * 0.5 * mie;
    let lR = 0, lM = 0;
    for (let j = 0; j < 4; j++) {
      const qy = Math.max(y + s[1] * (j + 0.5) * 0.25 * tEnd, 0);
      lR += Math.exp(-qy * HR) * 0.25;
      lM += Math.exp(-qy * HM) * 0.25; // local aerosol ≠ a thicker sun path
    }
    for (let c = 0; c < 3; c++) {
      const att = Math.exp(-(BETA_R[c] * (odRm + lR) + BETA_M * (odMm + lM)));
      sumR[c] += hR * step * att;
    }
    sumM += hM * step * Math.exp(-(BETA_R[1] * (odRm + lR) + BETA_M * (odMm + lM)));
    odR += hR * step; odM += hM * step * mie;
  }
  const pR = phaseR(cosT), pM = phaseM(cosT);
  const col = [0, 0, 0];
  for (let c = 0; c < 3; c++) {
    col[c] = I * (sumR[c] * BETA_R[c] * pR + sumM * BETA_M * pM) * dayFade;
    // the sun's DISK is the direct beam surviving the path
    if (el > -0.03) {
      col[c] += I * dayFade * smoothstep(DISK - 0.0006, DISK, cosT)
        * Math.exp(-(BETA_R[c] * odR + BETA_M * odM)) * 8;
    }
    col[c] = Math.max(col[c], NIGHT_AIR[c] * (0.6 + 0.4 * Math.min(mie, 3) / 3));
  }
  return col;
}

/**
 * AERIAL PERSPECTIVE (the air BETWEEN the camera and the fragment):
 * transmittance from the path optical depth + inscatter from the same sky
 * physics. Applied to terrain/entities/water — distance stops being "gray
 * fog" and becomes the atmosphere it physically is.
 */
/**
 * Transmittance of the sun's DIRECT beam along its own path (Rayleigh+Mie
 * through the airmass) — the pure physical reddening of the sun, without
 * the forward-scattered aureole that contaminates the disk pixel.
 */
export function beamTransmittance(sunDir, air = {}, N = 8) {
  const { BETA_R, BETA_M, HR, HM } = SCATTER_CONST;
  const mie = air.mie ?? 1;
  const s = [sunDir[0], Math.max(sunDir[1], 0.02), sunDir[2]];
  const sl = Math.hypot(...s) || 1;
  const d = [s[0] / sl, s[1] / sl, s[2] / sl];
  const tEnd = clamp(1 / Math.max(d[1], 0.05), 1, 8);
  const step = tEnd / N;
  let odR = 0, odM = 0;
  for (let i = 0; i < N; i++) {
    const y = Math.max(d[1] * ((i + 0.5) * step), 0);
    odR += Math.exp(-y * HR) * step;
    odM += Math.exp(-y * HM) * step * mie;
  }
  return [Math.exp(-(BETA_R[0] * odR + BETA_M * odM)),
          Math.exp(-(BETA_R[1] * odR + BETA_M * odM)),
          Math.exp(-(BETA_R[2] * odR + BETA_M * odM))];
}

export function aerial(color, rayDir, dist, sunDir, air = {}, h = 30) {
  const { BETA_R, BETA_M } = SCATTER_CONST;
  const mie = air.mie ?? 1;
  // radiation fog POOLS at the ground: the air toward a low object is
  // thicker (the fog amount comes from the atmosphere itself)
  const fogH = Math.max(0, air.fogH ?? 0);
  const d = (Math.min(dist, 900) / 500) * (1 + fogH * 2.6 * Math.exp(-Math.max(0, h) / 20));
  const insc = skyColor(rayDir, sunDir, air, rayDir[1] < 0.15 ? 8 : 4);
  const out = [0, 0, 0];
  for (let c = 0; c < 3; c++) {
    const T = Math.exp(-(BETA_R[c] + BETA_M * mie * 0.35) * d);
    out[c] = color[c] * T + insc[c] * (1 - T);
  }
  return out;
}

/** GLSL — GENERATED from the same constants (single source of truth). */
export const SCATTER_PROLOGUE = `precision highp float;
// ==== UTS scattering constants (generated — do not hand-edit) ====
const vec3 BETA_R = vec3(${SCATTER_CONST.BETA_R.map(fmt).join(',')});
const float BETA_M = ${fmt(SCATTER_CONST.BETA_M)};
const float MIE_G = ${fmt(SCATTER_CONST.MIE_G)};
const float SUN_I = ${fmt(SCATTER_CONST.INTENSITY)};
const float HR = ${fmt(SCATTER_CONST.HR)};
const float HM = ${fmt(SCATTER_CONST.HM)};
const float DISK = ${fmt(SCATTER_CONST.DISK)};
const vec3 NIGHT_AIR = vec3(${SCATTER_CONST.NIGHT_AIR.map(fmt).join(',')});
float sstep(float a, float b, float x){ float t = clamp((x-a)/(b-a), 0.0, 1.0); return t*t*(3.0-2.0*t); }
float phaseR(float t){ return (3.0/(16.0*3.14159265))*(1.0+t*t); }
float phaseM(float t){
  float g = MIE_G, g2 = g*g;
  return (3.0/(8.0*3.14159265))*((1.0-g2)*(1.0+t*t)) / pow((2.0+g2)*(1.0+g2-2.0*g*t), 1.5);
}
vec3 skyColor(vec3 dir, vec3 sunDir, float mie, float intensity, const int N){
  float el = sunDir.y;
  float dayFade = sstep(-0.14, 0.03, el);
  vec3 s = normalize(vec3(sunDir.x, max(sunDir.y, 0.03), sunDir.z));
  vec3 d = dir.y < 0.0 ? vec3(dir.x, -dir.y*0.25+0.02, dir.z) : dir;
  d = normalize(d);
  float cosT = clamp(dot(d, s), -1.0, 1.0);
  float tEnd = clamp(1.0/max(d.y, 0.05), 1.0, 8.0);
  float stepL = tEnd/float(N);
  float odR = 0.0, odM = 0.0, sumM = 0.0;
  vec3 sumR = vec3(0.0);
  for (int i = 0; i < N; i++) {
    float t = (float(i)+0.5)*stepL;
    float y = d.y*t;
    float hR = exp(-max(y,0.0)*HR), hM = exp(-max(y,0.0)*HM);
    float odRm = odR + hR*stepL*0.5, odMm = odM + hM*stepL*0.5*mie;
    float lR = 0.0, lM = 0.0;
    for (int j = 0; j < 4; j++) {
      float qy = max(y + s.y*(float(j)+0.5)*0.25*tEnd, 0.0);
      lR += exp(-qy*HR)*0.25;
      lM += exp(-qy*HM)*0.25; // local aerosol ≠ a thicker sun path
    }
    vec3 att = exp(-(BETA_R*(odRm+lR) + vec3(BETA_M*(odMm+lM))));
    sumR += hR*stepL*att;
    sumM += hM*stepL*exp(-(BETA_R.g*(odRm+lR) + BETA_M*(odMm+lM)));
    odR += hR*stepL; odM += hM*stepL*mie;
  }
  float pR = phaseR(cosT), pM = phaseM(cosT);
  vec3 col = intensity*(sumR*BETA_R*pR + vec3(sumM*BETA_M*pM))*dayFade;
  if (el > -0.03) {
    col += intensity*dayFade*sstep(DISK-0.0006, DISK, cosT)
         * exp(-(BETA_R*odR + vec3(BETA_M*odM)))*8.0;
  }
  return max(col, NIGHT_AIR*(0.6+0.4*min(mie,3.0)/3.0));
}
vec3 beamTransmittance(vec3 sunDir, float mie, const int N){
  vec3 s = normalize(vec3(sunDir.x, max(sunDir.y, 0.02), sunDir.z));
  float tEnd = clamp(1.0/max(s.y, 0.05), 1.0, 8.0);
  float stepL = tEnd/float(N);
  float odR = 0.0, odM = 0.0;
  for (int i = 0; i < N; i++) {
    float y = max(s.y*((float(i)+0.5)*stepL), 0.0);
    odR += exp(-y*HR)*stepL;
    odM += exp(-y*HM)*stepL*mie;
  }
  return exp(-(BETA_R*odR + vec3(BETA_M*odM)));
}
vec3 aerial(vec3 color, vec3 rayDir, float dist, vec3 sunDir, float mie, float intensity, float fogH, float h){
  float dd = (min(dist, 900.0)/500.0) * (1.0 + max(fogH,0.0)*2.6*exp(-max(h,0.0)/20.0));
  vec3 insc = skyColor(rayDir, sunDir, mie, intensity, rayDir.y < 0.15 ? 8 : 4);
  vec3 T = exp(-(BETA_R + vec3(BETA_M*mie*0.35))*dd);
  return color*T + insc*(1.0-T);
}
// ==== end generated scattering ====
`;

// O BLOCO COMPLETO (com #version) para quem é shader INTEIRO (o céu):
export const SCATTER_GLSL = `#version 300 es
` + SCATTER_PROLOGUE;
