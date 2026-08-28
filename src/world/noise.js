// UTS :: world/noise — deterministic value-noise fBm. Pure function of (seed, coords).

import { hash2, smooth, bilinear } from '../core/math.js';

export function valueNoise(x, z, seed) {
  const x0 = Math.floor(x), z0 = Math.floor(z);
  const fx = smooth(x - x0), fz = smooth(z - z0);
  const v00 = hash2(x0, z0, seed);
  const v10 = hash2(x0 + 1, z0, seed);
  const v01 = hash2(x0, z0 + 1, seed);
  const v11 = hash2(x0 + 1, z0 + 1, seed);
  return bilinear(v00, v10, v01, v11, fx, fz);
}

export function fbm(x, z, seed, { octaves = 4, lacunarity = 2, gain = 0.5, freq = 1 } = {}) {
  let amp = 1, sum = 0, norm = 0, f = freq;
  for (let i = 0; i < octaves; i++) {
    sum += amp * valueNoise(x * f, z * f, seed + i * 1013);
    norm += amp;
    amp *= gain;
    f *= lacunarity;
  }
  return sum / norm;
}
