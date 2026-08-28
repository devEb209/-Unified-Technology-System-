// UTS :: render/culling — OUR frustum + distance culling (pure math, no API).
// Visible-set decisions belong to the UTS, not to the GPU driver.

import { dist2 } from '../core/math.js';

/** extract 6 planes (a,b,c,d) from a column-major VP matrix */
export function frustumPlanes(vp) {
  const p = [];
  const row = (i) => [vp[i], vp[4 + i], vp[8 + i], vp[12 + i]];
  const rows = [row(0), row(1), row(2), row(3)];
  // left, right, bottom, top, near, far
  const add = (a, s) => {
    const pl = [
      rows[3][0] + s * a[0], rows[3][1] + s * a[1], rows[3][2] + s * a[2], rows[3][3] + s * a[3],
    ];
    const len = Math.hypot(pl[0], pl[1], pl[2]) || 1;
    p.push([pl[0] / len, pl[1] / len, pl[2] / len, pl[3] / len]);
  };
  add(rows[0], 1); add(rows[0], -1);
  add(rows[1], 1); add(rows[1], -1);
  add(rows[2], 1); add(rows[2], -1);
  return p;
}

/** sphere vs frustum: true when visible (or intersecting) */
export function sphereVisible(planes, x, y, z, radius) {
  for (const [a, b, c, d] of planes) {
    if (a * x + b * y + c * z + d < -radius) return false;
  }
  return true;
}

/**
 * Cull a Frame's entities + aggregates.
 * Camera frustum + maxDrawDistance (from D-O15 strategy). Pure, measurable.
 */
export function cullFrame(frame, { margin = 2, maxDrawDistance = Infinity } = {}) {
  const vp = frame._vp; // renderer injects the composed matrix (optional)
  const planes = vp ? frustumPlanes(vp) : null;
  const cam = frame.camera.pos;
  const visible = [];
  let culled = 0, distanceCulled = 0;
  const test = (e, radius) => {
    const d2 = dist2(e.pos[0], e.pos[2], cam[0], cam[2]);
    if (d2 > maxDrawDistance * maxDrawDistance) { distanceCulled++; culled++; return; }
    if (planes && !sphereVisible(planes, e.pos[0], (e.pos[1] ?? 0) + radius * 0.5, e.pos[2], radius + margin)) { culled++; return; }
    visible.push(e);
  };
  for (const e of frame.entities) test(e, e.kind === 'tree' ? 6 : 2);
  for (const a of frame.aggregates) test(a, a.radius ?? 8);
  return { visible, culled, distanceCulled, total: frame.entities.length + frame.aggregates.length };
}
