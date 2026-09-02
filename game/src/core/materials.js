import * as THREE from 'three';
import { fbm, mulberry32 } from './noise.js';

// Texturas procedurais (albedo + normal + roughness) — evita dependência de assets externos.
function heightToNormal(h, size, strength = 2.2) {
  const out = new Uint8ClampedArray(size * size * 4);
  const at = (x, y) => h[((y + size) % size) * size + ((x + size) % size)];
  for (let y = 0; y < size; y++) for (let x = 0; x < size; x++) {
    const dx = (at(x + 1, y) - at(x - 1, y)) * strength;
    const dy = (at(x, y + 1) - at(x, y - 1)) * strength;
    let nx = -dx, ny = -dy, nz = 1;
    const l = Math.hypot(nx, ny, nz); nx /= l; ny /= l; nz /= l;
    const i = (y * size + x) * 4;
    out[i] = (nx * 0.5 + 0.5) * 255; out[i + 1] = (ny * 0.5 + 0.5) * 255; out[i + 2] = (nz * 0.5 + 0.5) * 255; out[i + 3] = 255;
  }
  return out;
}

function makeSet(size, fn, repeat = 1, normalStrength = 2.2) {
  const alb = new Uint8ClampedArray(size * size * 4);
  const rgh = new Uint8ClampedArray(size * size * 4);
  const hgt = new Float32Array(size * size);
  for (let y = 0; y < size; y++) for (let x = 0; x < size; x++) {
    const i = y * size + x;
    const s = fn(x / size, y / size, x, y);
    alb[i * 4] = s.r * 255; alb[i * 4 + 1] = s.g * 255; alb[i * 4 + 2] = s.b * 255; alb[i * 4 + 3] = 255;
    const ro = (s.rough ?? 0.85) * 255;
    rgh[i * 4] = 255; rgh[i * 4 + 1] = ro; rgh[i * 4 + 2] = (s.metal ?? 0) * 255; rgh[i * 4 + 3] = 255;
    hgt[i] = s.h ?? (s.r + s.g + s.b) / 3;
  }
  const mk = (data, srgb) => {
    const t = new THREE.DataTexture(data, size, size, THREE.RGBAFormat);
    t.wrapS = t.wrapT = THREE.RepeatWrapping; t.repeat.set(repeat, repeat);
    t.magFilter = THREE.LinearFilter; t.minFilter = THREE.LinearMipmapLinearFilter;
    t.generateMipmaps = true; t.anisotropy = 8; t.needsUpdate = true;
    if (srgb) t.colorSpace = THREE.SRGBColorSpace;
    return t;
  };
  return { map: mk(alb, true), normalMap: mk(heightToNormal(hgt, size, normalStrength), false), ormMap: mk(rgh, false) };
}

export function buildMaterials() {
  const r = mulberry32(7);
  const grain = (x, y, s) => fbm(x * s, y * s, 5);

  const concrete = makeSet(256, (u, v, x, y) => {
    const n = grain(u, v, 26) * 0.5 + 0.5;
    const pit = fbm(u * 90, v * 90, 3) > 0.42 ? -0.08 : 0;
    const stain = Math.max(0, fbm(u * 5 + 3, v * 5, 4)) * 0.16;
    const g = 0.36 + n * 0.16 + pit - stain;
    return { r: g * 1.0, g: g * 0.99, b: g * 0.95, rough: 0.88 + n * 0.08, h: n + pit * 3 };
  }, 6, 1.5);

  const asphalt = makeSet(256, (u, v) => {
    const n = grain(u, v, 60) * 0.5 + 0.5;
    const crack = Math.abs(fbm(u * 8, v * 8, 4)) < 0.02 ? -0.1 : 0;
    const g = 0.10 + n * 0.09 + crack;
    return { r: g, g: g * 1.02, b: g * 1.06, rough: 0.7 + n * 0.2, h: n * 0.6 + crack * 4 };
  }, 14, 2.4);

  const dirt = makeSet(256, (u, v) => {
    const n = grain(u, v, 20) * 0.5 + 0.5;
    const d = grain(u + 9, v - 4, 70) * 0.5 + 0.5;
    const g = 0.20 + n * 0.16;
    return { r: g * 1.16, g: g * 0.98, b: g * 0.74, rough: 0.95, h: n * 0.7 + d * 0.3 };
  }, 40, 2.0);

  const metal = makeSet(256, (u, v) => {
    const n = grain(u, v, 40) * 0.5 + 0.5;
    const rust = Math.max(0, fbm(u * 6 + 11, v * 6, 5)) * 1.6;
    const base = 0.30 + n * 0.10;
    return { r: base + rust * 0.30, g: base + rust * 0.10, b: base + rust * 0.02, rough: 0.42 + rust * 0.5 + n * 0.1, metal: Math.max(0, 0.85 - rust * 1.6), h: n };
  }, 3, 1.8);

  const M = (s, extra = {}) => new THREE.MeshStandardMaterial({
    map: s.map, normalMap: s.normalMap, roughnessMap: s.ormMap, metalnessMap: s.ormMap,
    roughness: 1, metalness: 1, normalScale: new THREE.Vector2(1, 1), ...extra
  });

  return {
    concrete: M(concrete),
    asphalt: M(asphalt),
    dirt: M(dirt),
    metal: M(metal),
    glassDark: new THREE.MeshPhysicalMaterial({ color: 0x0a0d0f, roughness: 0.12, metalness: 0.0, transmission: 0.0, envMapIntensity: 1.6 }),
    gunmetal: new THREE.MeshStandardMaterial({ color: 0x14161a, roughness: 0.46, metalness: 0.85 }),
    polymer: new THREE.MeshStandardMaterial({ color: 0x232522, roughness: 0.72, metalness: 0.05 }),
    fabric: new THREE.MeshStandardMaterial({ color: 0x3a3b32, roughness: 0.96, metalness: 0.0 }),
    skin: new THREE.MeshStandardMaterial({ color: 0x8a6a55, roughness: 0.7 }),
    _rand: r
  };
}
