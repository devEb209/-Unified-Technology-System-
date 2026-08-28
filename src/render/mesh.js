// UTS :: render/mesh — static unit meshes + dynamic terrain mesh builder.
// Static resources are created once; per-frame data stays in uniforms.

export function cubeMesh() {
  const p = [
    // px, nx, py, ny, pz, nz faces (pos, normal interleaved)
  ];
  const face = (a, b, c, d, n) => {
    for (const v of [a, b, c, a, c, d]) p.push(v[0], v[1], v[2], n[0], n[1], n[2]);
  };
  face([1, -1, 1], [1, -1, -1], [1, 1, -1], [1, 1, 1], [1, 0, 0]);
  face([-1, -1, -1], [-1, -1, 1], [-1, 1, 1], [-1, 1, -1], [-1, 0, 0]);
  face([-1, 1, 1], [1, 1, 1], [1, 1, -1], [-1, 1, -1], [0, 1, 0]);
  face([-1, -1, -1], [1, -1, -1], [1, -1, 1], [-1, -1, 1], [0, -1, 0]);
  face([-1, -1, 1], [1, -1, 1], [1, 1, 1], [-1, 1, 1], [0, 0, 1]);
  face([1, -1, -1], [-1, -1, -1], [-1, 1, -1], [1, 1, -1], [0, 0, -1]);
  return { data: new Float32Array(p), count: 36 };
}

export function sphereMesh(stacks = 6, slices = 10) {
  const p = [];
  const pt = (i, j) => {
    const th = (i / stacks) * Math.PI, ph = (j / slices) * Math.PI * 2;
    return [Math.sin(th) * Math.cos(ph), Math.cos(th), Math.sin(th) * Math.sin(ph)];
  };
  for (let i = 0; i < stacks; i++) {
    for (let j = 0; j < slices; j++) {
      const a = pt(i, j), b = pt(i + 1, j), c = pt(i + 1, j + 1), d = pt(i, j + 1);
      for (const v of [a, b, c, a, c, d]) p.push(v[0], v[1], v[2], v[0], v[1], v[2]);
    }
  }
  return { data: new Float32Array(p), count: p.length / 6 };
}

export function coneMesh(segments = 10) {
  const p = [];
  const tip = [0, 1, 0];
  for (let j = 0; j < segments; j++) {
    const a0 = (j / segments) * Math.PI * 2, a1 = ((j + 1) / segments) * Math.PI * 2;
    const b0 = [Math.cos(a0), -1, Math.sin(a0)], b1 = [Math.cos(a1), -1, Math.sin(a1)];
    const n0 = [Math.cos(a0 + Math.PI / segments), 0.3, Math.sin(a0 + Math.PI / segments)];
    p.push(tip[0], tip[1], tip[2], n0[0], n0[1], n0[2]);
    p.push(b0[0], b0[1], b0[2], n0[0], n0[1], n0[2]);
    p.push(b1[0], b1[1], b1[2], n0[0], n0[1], n0[2]);
  }
  return { data: new Float32Array(p), count: segments * 3 };
}

export function domeMesh(stacks = 4, slices = 8) {
  const s = sphereMesh(stacks * 2, slices);
  const p = [];
  for (let i = 0; i < s.count; i++) {
    const vi = i * 6;
    if (s.data[vi + 1] >= -0.001) p.push(s.data[vi], s.data[vi + 1], s.data[vi + 2], s.data[vi + 3], s.data[vi + 4], s.data[vi + 5]);
  }
  return { data: new Float32Array(p), count: p.length / 6 };
}

/**
 * Build a terrain mesh from a patch (heights/biomes at res) — the visual
 * MANIFESTATION of the represented heightfield. Absolute world coords so the
 * model matrix stays identity (static resource).
 */
export function buildTerrainMesh(patch) {
  const { heights, biomes, res, size, x0, z0 } = patch;
  const step = size / res;
  const n = res + 1;
  const H = (i, j) => heights[j * n + i];
  const B = (i, j) => biomes[j * n + i];
  const verts = new Float32Array(res * res * 6 * 7);
  let o = 0;
  const push = (x, y, z, nx, ny, nz, b) => {
    verts[o++] = x; verts[o++] = y; verts[o++] = z;
    verts[o++] = nx; verts[o++] = ny; verts[o++] = nz;
    verts[o++] = b;
  };
  const normalAt = (i, j) => {
    const hl = H(Math.max(0, i - 1), j), hr = H(Math.min(res, i + 1), j);
    const hd = H(i, Math.max(0, j - 1)), hu = H(i, Math.min(res, j + 1));
    const dx = (hr - hl) / (2 * step), dz = (hu - hd) / (2 * step);
    const l = Math.hypot(dx, 1, dz);
    return [-dx / l, 1 / l, -dz / l];
  };
  for (let j = 0; j < res; j++) {
    for (let i = 0; i < res; i++) {
      const x00 = x0 + i * step, z00 = z0 + j * step;
      const x10 = x00 + step, z10 = z00;
      const x01 = x00, z01 = z00 + step;
      const x11 = x10, z11 = z01;
      const h00 = H(i, j), h10 = H(i + 1, j), h01 = H(i, j + 1), h11 = H(i + 1, j + 1);
      const b00 = B(i, j), b10 = B(i + 1, j), b01 = B(i, j + 1), b11 = B(i + 1, j + 1);
      push(x00, h00, z00, ...normalAt(i, j), b00);
      push(x10, h10, z10, ...normalAt(i + 1, j), b10);
      push(x11, h11, z11, ...normalAt(i + 1, j + 1), b11);
      push(x00, h00, z00, ...normalAt(i, j), b00);
      push(x11, h11, z11, ...normalAt(i + 1, j + 1), b11);
      push(x01, h01, z01, ...normalAt(i, j + 1), b01);
    }
  }
  return { data: verts, count: res * res * 6 };
}
