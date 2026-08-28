// UTS :: world/terrain — heightfield + biomes. The visual terrain is a
// MANIFESTATION of this representation (never a second world system).

import { fbm, valueNoise } from './noise.js';
import { clamp } from '../core/math.js';

export const BIOME = Object.freeze({ WATER: 0, SAND: 1, GRASS: 2, FOREST: 3, ROCK: 4, SNOW: 5 });
export const BIOME_NAMES = ['water', 'sand', 'grass', 'forest', 'rock', 'snow'];

export class Terrain {
  constructor({ seed = 'uts-world', chunkSize = 64, chunksPerSide = 16 } = {}) {
    this.seedNum = typeof seed === 'string' ? hashStr(seed) : seed >>> 0;
    this.chunkSize = chunkSize;
    this.chunksPerSide = chunksPerSide;
    this.size = chunkSize * chunksPerSide;
    this.seaLevel = 6;
  }

  /** continental base height 0..24 */
  height(x, z) {
    const s = this.seedNum;
    const cont = fbm(x * 0.004, z * 0.004, s, { octaves: 4, freq: 1 });
    const hills = fbm(x * 0.02, z * 0.02, s + 777, { octaves: 3 });
    const mountains = Math.pow(fbm(x * 0.008, z * 0.008, s + 1337, { octaves: 3 }), 3);
    let h = cont * 20 + hills * 4 + mountains * 14 - 6;
    // gentle valley guaranteeing rivers near world center diagonal
    const river = Math.abs(Math.sin(x * 0.006 + fbm(x * 0.01, z * 0.01, s + 42, { octaves: 2 }) * 2) ) ;
    const riverInfluence = Math.exp(-Math.pow((z - this.size / 2 + Math.sin(x * 0.008) * 30) / 26, 2));
    h = h * (1 - riverInfluence * 0.9) + (this.seaLevel - 1.2) * riverInfluence * 0.9;
    return clamp(h, 0, 34);
  }

  moisture(x, z) {
    return valueNoise(x * 0.01, z * 0.01, this.seedNum + 991);
  }

  biomeAt(x, z, h = null) {
    const hh = h ?? this.height(x, z);
    if (hh < this.seaLevel) return BIOME.WATER;
    if (hh < this.seaLevel + 0.7) return BIOME.SAND;
    const m = this.moisture(x, z);
    if (hh > 24) return BIOME.SNOW;
    if (hh > 19) return BIOME.ROCK;
    if (m > 0.62 && hh < 18) return BIOME.FOREST;
    return BIOME.GRASS;
  }

  /** cheap metadata for far/abstract chunks */
  chunkMeta(cx, cz) {
    let sum = 0, n = 0;
    const mix = new Array(BIOME_NAMES.length).fill(0);
    const step = this.chunkSize / 4;
    for (let i = 0; i < 4; i++) {
      for (let j = 0; j < 4; j++) {
        const x = cx * this.chunkSize + i * step + step / 2;
        const z = cz * this.chunkSize + j * step + step / 2;
        const h = this.height(x, z);
        sum += h; n++;
        mix[this.biomeAt(x, z, h)]++;
      }
    }
    return { avgH: sum / n, biomeMix: mix.map(v => v / n) };
  }

  /** dense heights for a chunk at a given resolution (res cells per side) */
  sampleChunk(cx, cz, res) {
    const n = res + 1;
    const heights = new Float32Array(n * n);
    const biomes = new Uint8Array(n * n);
    const x0 = cx * this.chunkSize, z0 = cz * this.chunkSize;
    const step = this.chunkSize / res;
    for (let j = 0; j < n; j++) {
      for (let i = 0; i < n; i++) {
        const x = x0 + i * step, z = z0 + j * step;
        const h = this.height(x, z);
        heights[j * n + i] = h;
        biomes[j * n + i] = this.biomeAt(x, z, h);
      }
    }
    return { heights, biomes, res, step };
  }

  /** find nearest water position from a start point (spiral search) — returns [x, 0, z] */
  findWater(fromX, fromZ, maxR = 400) {
    const step = 8;
    for (let r = step; r <= maxR; r += step) {
      const n = Math.max(8, Math.floor((2 * Math.PI * r) / step));
      for (let i = 0; i < n; i++) {
        const a = (i / n) * Math.PI * 2;
        const x = fromX + Math.cos(a) * r;
        const z = fromZ + Math.sin(a) * r;
        if (x < 8 || z < 8 || x > this.size - 8 || z > this.size - 8) continue;
        if (this.height(x, z) < this.seaLevel - 0.3) return [x, 0, z];
      }
    }
    return null;
  }

  /** find walkable land (non-water, gentle) from a start point — returns [x, 0, z] */
  findLand(fromX, fromZ, maxR = 400) {
    for (let r = 4; r <= maxR; r += 4) {
      const n = Math.max(6, Math.floor((2 * Math.PI * r) / 4));
      for (let i = 0; i < n; i++) {
        const a = (i / n) * Math.PI * 2 + r;
        const x = fromX + Math.cos(a) * r;
        const z = fromZ + Math.sin(a) * r;
        if (x < 8 || z < 8 || x > this.size - 8 || z > this.size - 8) continue;
        const h = this.height(x, z);
        if (h > this.seaLevel + 0.5 && h < 20) return [x, 0, z];
      }
    }
    return [fromX, 0, fromZ];
  }
}

function hashStr(str) {
  let h = 2166136261;
  for (let i = 0; i < str.length; i++) {
    h ^= str.charCodeAt(i);
    h = Math.imul(h, 16777619);
  }
  return h >>> 0;
}
