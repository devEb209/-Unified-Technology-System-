// UTS :: media/models — the AI GENERATES models in every dimension (2D, 2.5D,
// 3D, 3.5D voxel, 4D time-varying) procedurally and deterministically. The
// style is a parameter — the user asks, the AI builds geometry.
export const DIMS = ['2d', '2.5d', '3d', '3.5d', '4d'];

/** 2D: an outline/polygon sprite (points in the plane). */
export function model2D({ shape = 'star', points = 5, r = 1 } = {}) {
  const pts = [];
  const inner = shape === 'star' ? r * 0.45 : r;
  const n = shape === 'star' ? points * 2 : points;
  for (let i = 0; i < n; i++) {
    const a = (i / n) * Math.PI * 2 - Math.PI / 2;
    const rad = shape === 'star' ? (i % 2 ? inner : r) : r;
    pts.push([Math.cos(a) * rad, Math.sin(a) * rad]);
  }
  return { dim: '2d', kind: shape, points: pts };
}

/** 2.5D: extrude a 2D outline into depth (billboards with real thickness). */
export function model2_5D(opts = {}, depth = 0.4) {
  const flat = model2D(opts);
  const p = flat.points;
  const tris = [];
  for (let i = 0; i < p.length; i++) {
    const a = p[i], b = p[(i + 1) % p.length];
    tris.push([a[0], a[1], 0], [b[0], b[1], 0], [b[0], b[1], depth]);
    tris.push([a[0], a[1], 0], [b[0], b[1], depth], [a[0], a[1], depth]);
  }
  return { dim: '2.5d', kind: flat.kind, tris };
}

/** 3D: parametric solids (deterministic; style = segment count). */
export function model3D({ solid = 'torus', seg = 16, r = 1, R = 2.2 } = {}) {
  const v = [];
  if (solid === 'torus') {
    for (let i = 0; i < seg; i++) for (let j = 0; j < seg; j++) {
      const u = (i / seg) * Math.PI * 2, w = (j / seg) * Math.PI * 2;
      const q = (k, l) => [(R + r * Math.cos(l)) * Math.cos(k), r * Math.sin(l), (R + r * Math.cos(l)) * Math.sin(k)];
      v.push(q(u, w), q(u + 2 * Math.PI / seg, w), q(u + 2 * Math.PI / seg, w + 2 * Math.PI / seg));
      v.push(q(u, w), q(u + 2 * Math.PI / seg, w + 2 * Math.PI / seg), q(u, w + 2 * Math.PI / seg));
    }
  } else {
    for (let j = 0; j < seg; j++) {
      const a0 = (j / seg) * 2 * Math.PI, a1 = ((j + 1) / seg) * 2 * Math.PI;
      const p0 = [Math.cos(a0) * r, -r, Math.sin(a0) * r], p1 = [Math.cos(a1) * r, -r, Math.sin(a1) * r];
      v.push([0, r, 0], p0, p1);
      v.push([0, -r, 0], p1, p0);
    }
  }
  return { dim: '3d', kind: solid, verts: v };
}

/** 3.5D: voxel field (buildable/breakable like the real thing). */
export function model3_5D({ size = 12, seed = 1, height = 4 } = {}) {
  const voxels = [];
  const h = (x, y) => {
    const s = Math.sin(x * 127.1 * seed + y * 311.7) * 43758.5453;
    return (s - Math.floor(s)) * height;
  };
  for (let x = 0; x < size; x++) for (let y = 0; y < size; y++) {
    const top = Math.floor(h(x, y));
    for (let z = 0; z <= top; z++) voxels.push([x, y, z]);
  }
  return { dim: '3.5d', kind: 'voxel-field', voxels };
}

/** 4D: time-varying model — frames + interpolation (the model MOVES). */
export function model4D({ frames = 6, pulse = 0.3 } = {}) {
  const seq = [];
  for (let f = 0; f < frames; f++) {
    const k = 1 + Math.sin((f / frames) * Math.PI * 2) * pulse;
    seq.push({ t: f / frames, model: model3D({ solid: 'prism', seg: 6, r: k }) });
  }
  return { dim: '4d', kind: 'animated-prism', frames: seq };
}

export function generate({ dim = '3d', ...opts } = {}) {
  switch (dim) {
    case '2d': return model2D(opts);
    case '2.5d': return model2_5D(opts, opts.depth);
    case '3d': return model3D(opts);
    case '3.5d': return model3_5D(opts);
    case '4d': return model4D(opts);
    default: throw new Error(`dimensão desconhecida: ${dim} (use ${DIMS.join(', ')})`);
  }
}
