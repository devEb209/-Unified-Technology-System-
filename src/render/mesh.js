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
 *
 * GÊNESIS-LOD (AAAA): every mesh carries SKIRTS — vertical walls hanging
 * from all four borders down past the lowest height. Adjacent chunks at
 * different LOD resolutions can never show cracks: the skirt physically
 * covers the T-junction gap (standard AAA terrain technique, ours natively).
 * Skirt triangles are emitted with both windings so they are visible from
 * any side (CULL_FACE stays on; the cost is trivial).
 */
export function buildTerrainMesh(patch, { skirt = true } = {}) {
  const { heights, biomes, res, size, x0, z0 } = patch;
  const step = size / res;
  const n = res + 1;
  const H = (i, j) => heights[j * n + i];
  const B = (i, j) => biomes[j * n + i];
  let minH = Infinity, maxH = -Infinity;
  for (let k = 0; k < heights.length; k++) {
    if (heights[k] < minH) minH = heights[k];
    if (heights[k] > maxH) maxH = heights[k];
  }
  // skirt reaches below the deepest possible neighbor mismatch
  const skirtDepth = Math.max(4, (maxH - minH) * 0.6);
  const verts = new Float32Array((res * res * 6 + (skirt ? res * 4 * 12 : 0)) * 7);
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
  if (skirt) {
    // one wall per border, both windings, biome from the border vertex
    const skirtSeg = (xa, za, xb, zb, ia, ja, ib, jb, nx, nz) => {
      const hA = H(ia, ja), hB = H(ib, jb), bA = B(ia, ja), bB = B(ib, jb);
      const TA = [xa, hA, za], TB = [xb, hB, zb], BA = [xa, hA - skirtDepth, za], BB = [xb, hB - skirtDepth, zb];
      const tri = (p, q, r) => {
        for (const v of [p, q, r]) {
          const b = (v === TA || v === BA) ? bA : bB;
          push(v[0], v[1], v[2], nx, 0, nz, b);
        }
      };
      tri(TA, TB, BB); tri(TA, BB, BA); // facing out
      tri(TA, BB, TB); tri(TA, BA, BB); // facing in (CULL_FACE stays honest)
    };
    for (let i = 0; i < res; i++) {
      skirtSeg(x0 + i * step, z0, x0 + (i + 1) * step, z0, i, 0, i + 1, 0, 0, -1);           // north
      skirtSeg(x0 + i * step, z0 + size, x0 + (i + 1) * step, z0 + size, i, res, i + 1, res, 0, 1); // south
      skirtSeg(x0, z0 + i * step, x0, z0 + (i + 1) * step, 0, i, 0, i + 1, -1, 0);           // west
      skirtSeg(x0 + size, z0 + i * step, x0 + size, z0 + (i + 1) * step, res, i, res, i + 1, 1, 0);// east
    }
  }
  return { data: verts, count: o / 7, tris: o / 21, skirtDepth, minH, maxH };
}

/**
 * Impostor mesh (GÊNESIS-LOD): distant chunks stop paying for geometry and
 * render as ONE flat quad at the average height with the dominant biome —
 * the honest minimal representation of "the terrain continues that way".
 * Same vertex layout (stride 7), same terrain program, ~zero cost.
 */
export function buildImpostorMesh(patch) {
  const { heights, biomes, size, x0, z0 } = patch;
  let sum = 0;
  const votes = new Map();
  for (let k = 0; k < heights.length; k++) {
    sum += heights[k];
    const b = Math.round(biomes[k]);
    votes.set(b, (votes.get(b) ?? 0) + 1);
  }
  const avgH = sum / heights.length;
  let dominant = 0, best = -1;
  for (const [b, c] of votes) if (c > best) { best = c; dominant = b; }
  const y = avgH;
  const A = [x0, y, z0], Bp = [x0 + size, y, z0], C = [x0 + size, y, z0 + size], D = [x0, y, z0 + size];
  const verts = new Float32Array(6 * 7);
  let o = 0;
  const push = (p) => { verts[o++] = p[0]; verts[o++] = p[1]; verts[o++] = p[2]; verts[o++] = 0; verts[o++] = 1; verts[o++] = 0; verts[o++] = dominant; };
  push(A); push(Bp); push(C);
  push(A); push(C); push(D);
  return { data: verts, count: 6, tris: 2, avgH, dominantBiome: dominant };
}

/**
 * A REAL tree mesh (ADR-020: vegetation is the living population — it gets
 * geometry, not a billboard). Unit height (y 0..1); the instance scales it.
 * Interleaved [pos3, norm3, canopy1] — stride 7. Deterministic.
 */
export function treeMesh(species = 'pine', segments = 7) {
  const p = [];
  const P = (x, y, z, nx, ny, nz, c) => p.push(x, y, z, nx, ny, nz, c);
  // --- trunk: tapered cylinder, bark normals
  const trunk = (r0, r1, y0, y1) => {
    for (let j = 0; j < segments; j++) {
      const a0 = (j / segments) * Math.PI * 2, a1 = ((j + 1) / segments) * Math.PI * 2;
      const c0 = [Math.cos(a0), Math.sin(a0)], c1 = [Math.cos(a1), Math.sin(a1)];
      const am = (a0 + a1) / 2, n = [Math.cos(am), 0.08, Math.sin(am)];
      const v = (c, r, y) => [c[0] * r, y, c[1] * r];
      P(v(c0, r0, y0)[0], y0, v(c0, r0, y0)[2], n[0], n[1], n[2], 0);
      P(v(c0, r1, y1)[0], y1, v(c0, r1, y1)[2], n[0], n[1], n[2], 0);
      P(v(c1, r1, y1)[0], y1, v(c1, r1, y1)[2], n[0], n[1], n[2], 0);
      P(v(c0, r0, y0)[0], y0, v(c0, r0, y0)[2], n[0], n[1], n[2], 0);
      P(v(c1, r1, y1)[0], y1, v(c1, r1, y1)[2], n[0], n[1], n[2], 0);
      P(v(c1, r0, y0)[0], y0, v(c1, r0, y0)[2], n[0], n[1], n[2], 0);
    }
  };
  // --- canopy cone (stacked for pines)
  const cone = (y0, r, h) => {
    const tip = [0, y0 + h, 0];
    for (let j = 0; j < segments; j++) {
      const a0 = (j / segments) * Math.PI * 2, a1 = ((j + 1) / segments) * Math.PI * 2;
      const b0 = [Math.cos(a0) * r, y0, Math.sin(a0) * r], b1 = [Math.cos(a1) * r, y0, Math.sin(a1) * r];
      const am = (a0 + a1) / 2, n = [Math.cos(am) * 0.85, 0.35, Math.sin(am) * 0.85];
      P(tip[0], tip[1], tip[2], n[0], n[1], n[2], 1);
      P(b0[0], b0[1], b0[2], n[0], n[1], n[2], 1);
      P(b1[0], b1[1], b1[2], n[0], n[1], n[2], 1);
    }
  };
  // --- canopy sphere blob
  const blob = (cx, cy, cz, r) => {
    const s = sphereMesh(4, 7);
    for (let i = 0; i < s.count; i++) {
      const vi = i * 6;
      P(cx + s.data[vi] * r, cy + s.data[vi + 1] * r, cz + s.data[vi + 2] * r,
        s.data[vi + 3], s.data[vi + 4], s.data[vi + 5], 1);
    }
  };
  if (species === 'pine') {
    trunk(0.035, 0.016, 0, 0.42);
    cone(0.26, 0.30, 0.34); cone(0.47, 0.23, 0.30); cone(0.66, 0.15, 0.26);
  } else {
    trunk(0.040, 0.024, 0, 0.55);
    blob(0, 0.74, 0, 0.27); blob(0.15, 0.62, 0.06, 0.18); blob(-0.13, 0.66, -0.07, 0.17);
  }
  return { data: new Float32Array(p), count: p.length / 7 };
}
