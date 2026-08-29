// UTS :: render/water-reflection — THE LAND IN THE WATER: the sea mirrors
// the terrain by MARCHING the real heightfield along the reflected ray
// (no render target needed — the terrain is analytic data, so the mirror
// is computed from the SAME data the ground comes from). JS mirror =
// REAL terrain.height (erosion deltas included); GLSL = the same macro
// field (continents + mountains) generated with the same coefficients —
// silhouette fidelity, honest about the approximation.
import { fbm } from '../world/noise.js';
import { clamp } from '../core/math.js';

export const REFLECT_CONST = Object.freeze({
  STEPS: 4,          // march steps along the reflected ray
  STEP_M: 26,        // meters per step (macro silhouettes: hills/mountains)
  MAX_DIST: 104,     // 4 × 26
  SEA_LEVEL: 6,      // matches terrain.seaLevel
  MACRO_CONT: 0.004, // the SAME frequency of terrain.continental
  MACRO_MTN: 0.008,  // the SAME frequency of terrain.mountains
});

/** terrain color by height (the palette the terrain FS uses, simplified) */
export function terrainTint(h) {
  if (h < 7) return [0.76, 0.7, 0.5];   // sand
  if (h < 14) return [0.2, 0.42, 0.16]; // grass/forest
  if (h < 22) return [0.45, 0.44, 0.42]; // rock
  return [0.92, 0.94, 0.96];             // snow
}

/**
 * JS MIRROR (the verified math): march the REAL terrain along the
 * reflected ray. origin at the water surface, dir upward-ish reflection.
 * Returns { hit, dist, tint } — hit means the LAND is what the water
 * mirrors in that direction (not the sky).
 */
export function marchReflect(origin, dir, terrain, { steps = REFLECT_CONST.STEPS, stepM = REFLECT_CONST.STEP_M } = {}) {
  let x = origin[0], y = origin[1], z = origin[2];
  const dx = dir[0], dy = dir[1], dz = dir[2];
  for (let i = 1; i <= steps; i++) {
    const t = i * stepM;
    const px = x + dx * t, py = y + dy * t, pz = z + dz * t;
    if (py > 40) break; // above the highest mountain: only sky beyond
    const h = terrain.height(px, pz);
    if (py <= h) {
      const k = clamp(1 - (h - py) / 12, 0.25, 1); // soft edge (the silhouette is not a wall)
      return { hit: true, dist: t, tint: terrainTint(h), k };
    }
  }
  return { hit: false, dist: REFLECT_CONST.MAX_DIST, tint: null, k: 0 };
}

/** fade with distance (aerial perspective on the reflection) */
export function reflectionFade(dist) {
  return Math.exp(-dist / 140);
}

/**
 * GLSL generated from the SAME constants: macro heightfield (continents
 * fbm 3 octaves + mountains³, matching terrain.js frequencies) + the
 * march. The shader reads uTerrSeed (the world's real seed) so the
 * silhouette in the water is the silhouette of THAT world.
 */
export function terrainMirrorGLSL() {
  return `// ---- THE LAND IN THE WATER (water-reflection.js; mesmas constantes do JS)
float twHash(vec2 p){ p = fract(p*vec2(123.34,456.21)); p += dot(p,p+45.32); return fract(p.x*p.y); }
float twNoise(vec2 p){ vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
  float a=twHash(i), b=twHash(i+vec2(1,0)), c=twHash(i+vec2(0,1)), d=twHash(i+vec2(1,1));
  return mix(mix(a,b,f.x), mix(c,d,f.x), f.y); }
float twFbm(vec2 p, float seed){ float s=0.0, a=1.0, n=0.0;
  for(int i=0;i<3;i++){ s+=a*twNoise(p+seed*0.017); n+=a; a*=0.5; p*=2.0; } return s/n; }
float twHeight(vec2 xz, float seed){
  float cont = twFbm(xz*${REFLECT_CONST.MACRO_CONT.toFixed(4)}, seed)*20.0 - 6.0;
  float mtn = pow(twFbm(xz*${REFLECT_CONST.MACRO_MTN.toFixed(4)}, seed+1.3), 3.0)*14.0;
  return max(cont + mtn, 0.0);
}
vec4 twReflect(vec3 ro, vec3 rd, float seed){
  for(int i=1;i<=${REFLECT_CONST.STEPS};i++){
    float t = float(i)*${REFLECT_CONST.STEP_M.toFixed(1)};
    vec3 p = ro + rd*t;
    if (p.y > 40.0) break;
    float h = twHeight(p.xz, seed);
    if (p.y <= h){
      float k = clamp(1.0-(h-p.y)/12.0, 0.25, 1.0);
      vec3 tint = h<7.0 ? vec3(0.76,0.7,0.5) : h<14.0 ? vec3(0.2,0.42,0.16) : h<22.0 ? vec3(0.45,0.44,0.42) : vec3(0.92,0.94,0.96);
      float fade = exp(-t/140.0);
      return vec4(tint*fade, k);
    }
  }
  return vec4(0.0, 0.0, 0.0, 0.0);
}`;
}
