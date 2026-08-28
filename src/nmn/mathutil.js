// UTS :: nmn/mathutil — tiny helpers for the NMN module (kept dependency-light).

export function clamp01(v) {
  return v < 0 ? 0 : v > 1 ? 1 : v;
}

/** normalize a 2D vector [x, z] */
export function normalize2(v) {
  const l = Math.hypot(v[0], v[1]) || 1;
  return [v[0] / l, v[1] / l];
}
