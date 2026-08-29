// UTS :: media/textures — PROCEDURAL texture synthesis (the AI paints from
// the material's own structure: wood rings from growth, brick from masonry,
// marble from turbulence). RGBA, deterministic, zero deps.
const fract = (x) => x - Math.floor(x);
const noise = (x, y) => fract(Math.sin(x * 127.1 + y * 311.7) * 43758.5453);
const smooth = (t) => t * t * (3 - 2 * t);
function vnoise(x, y) {
  const xi = Math.floor(x), yi = Math.floor(y), xf = x - xi, yf = y - yi;
  const u = smooth(xf), v = smooth(yf);
  const n = (i, j) => noise(xi + i, yi + j);
  return (n(0, 0) * (1 - u) + n(1, 0) * u) * (1 - v) + (n(0, 1) * (1 - u) + n(1, 1) * u) * v;
}
const turb = (x, y, oct = 4) => {
  let s = 0, a = 0.5, f = 1;
  for (let i = 0; i < oct; i++) { s += vnoise(x * f, y * f) * a; a *= 0.5; f *= 2; }
  return s;
};

export function woodTexture({ size = 64, rings = 6 } = {}) {
  const d = new Uint8ClampedArray(size * size * 4);
  for (let y = 0; y < size; y++) for (let x = 0; x < size; x++) {
    const dx = x - size / 2, dy = y - size / 2;
    const r = Math.hypot(dx, dy) + turb(x / 9, y / 9) * 3;
    const ring = Math.abs(Math.sin(r * rings * Math.PI / size));
    const c = 120 + 90 * ring;
    const i = (y * size + x) * 4;
    d[i] = c * 1.05; d[i + 1] = c * 0.72; d[i + 2] = c * 0.45; d[i + 3] = 255;
  }
  return { kind: 'wood', size, rgba: d };
}

export function brickTexture({ size = 64, rows = 4 } = {}) {
  const d = new Uint8ClampedArray(size * size * 4);
  const bh = size / rows, bw = size / 2;
  for (let y = 0; y < size; y++) for (let x = 0; x < size; x++) {
    const row = Math.floor(y / bh);
    const ox = (x + (row % 2) * bw / 2) % bw;
    const mortar = (y % bh < 2) || (ox < 2);
    const i = (y * size + x) * 4;
    if (mortar) { d[i] = 150; d[i + 1] = 148; d[i + 2] = 142; }
    else { const v = 160 + noise(Math.floor(x / 4), Math.floor(y / 4)) * 40; d[i] = v * 1.25; d[i + 1] = v * 0.55; d[i + 2] = v * 0.4; }
    d[i + 3] = 255;
  }
  return { kind: 'brick', size, rgba: d };
}

export function marbleTexture({ size = 64, veins = 5 } = {}) {
  const d = new Uint8ClampedArray(size * size * 4);
  for (let y = 0; y < size; y++) for (let x = 0; x < size; x++) {
    const t = turb(x / 14, y / 14, 5);
    const v = Math.abs(Math.sin((x + t * 42) * veins * Math.PI / size));
    const c = 200 + (1 - v) * 55;
    const i = (y * size + x) * 4;
    d[i] = c; d[i + 1] = c * 0.99; d[i + 2] = c * 0.96; d[i + 3] = 255;
  }
  return { kind: 'marble', size, rgba: d };
}

export function generateTexture(kind, opts = {}) {
  if (kind === 'wood') return woodTexture(opts);
  if (kind === 'brick') return brickTexture(opts);
  if (kind === 'marble') return marbleTexture(opts);
  throw new Error(`textura desconhecida: ${kind}`);
}
