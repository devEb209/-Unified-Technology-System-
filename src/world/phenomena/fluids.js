// UTS :: world/phenomena/fluids — SHALLOW WATER as substance (ADR-019):
// rain lands, water FLOWS DOWNHILL, pools in valleys, conserves mass.
// Pipe-model on a local grid around the camera (D-O15 governs the grid
// extent, never the physics). Deterministic, zero deps.

export const FLUID_CONST = Object.freeze({
  CELL: 4,          // world units per cell
  MAX_FLOW: 0.9,    // max depth transferred per step (stability)
  EVAP: 0.0006,     // evaporation per second
  SEEP: 0.0003,     // infiltration into the soil per second
});

export class FluidField {
  constructor({ world, half = 96 } = {}) {
    this.world = world;
    this.half = half;                       // half-extent around the focus
    this.depth = new Map();                 // "i,j" -> water depth
    this.mass = 0;
    this.lost = 0;                          // evaporação+infiltração acumuladas (medidas)
  }

  key(i, j) { return `${i},${j}`; }

  /** rain (or any source) adds depth at a world position */
  pour(x, z, amount) {
    const C = FLUID_CONST;
    const i = Math.round(x / C.CELL), j = Math.round(z / C.CELL);
    const k = this.key(i, j);
    const d = (this.depth.get(k) ?? 0) + amount;
    this.depth.set(k, d);
    this.mass += amount;
  }

  /**
   * One step: water flows to LOWER total head (ground+water) neighbors.
   * Conservative by construction (what leaves one cell enters the other).
   */
  step(dt) {
    const C = FLUID_CONST;
    const t = this.world.terrain;
    const flow = [];
    for (const [k, h] of this.depth) {
      if (h <= 1e-5) continue;
      const [i, j] = k.split(',').map(Number);
      const gx = i * C.CELL, gz = j * C.CELL;
      const myHead = (t.height(gx, gz) ?? 0) + h;
      for (const [di, dj] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
        const nk = this.key(i + di, j + dj);
        const nx = (i + di) * C.CELL, nz = (j + dj) * C.CELL;
        const nh = this.depth.get(nk) ?? 0;
        const nHead = (t.height(nx, nz) ?? 0) + nh;
        if (nHead < myHead) {
          const drop = Math.min(h * 0.2, (myHead - nHead) * 0.25, C.MAX_FLOW);
          if (drop > 1e-5) flow.push([k, nk, drop]);
        }
      }
    }
    // apply ATOMICALLY (a cell appearing in several flows must not over-drain)
    const delta = new Map();
    for (const [a, b, q] of flow) {
      delta.set(a, (delta.get(a) ?? 0) - q);
      delta.set(b, (delta.get(b) ?? 0) + q);
    }
    for (const [k, dq] of delta) {
      const v = (this.depth.get(k) ?? 0) + dq;
      this.depth.set(k, Math.max(0, v));
    }
    // losses: evaporation + seepage — MEASURED, not hidden (conservation is
    // mass + lost == poured; the water returns to the cycle)
    let mass = 0;
    for (const [k, h] of this.depth) {
      const loss = (C.EVAP + C.SEEP) * dt;
      const nh = Math.max(0, h - loss);
      if (nh <= 1e-5) { this.lost += h; this.depth.delete(k); } else { this.depth.set(k, nh); mass += nh; this.lost += loss < h ? loss : h; }
    }
    this.mass = mass;
    return this.mass;
  }

  /** deepest pooling position near a point (for probes/tests/render) */
  pool(x, z, radius = 40) {
    const C = FLUID_CONST;
    let best = null;
    const ci = Math.round(x / C.CELL), cj = Math.round(z / C.CELL);
    const r = Math.ceil(radius / C.CELL);
    for (const [k, h] of this.depth) {
      if (h < 0.05) continue;
      const [i, j] = k.split(',').map(Number);
      if (Math.abs(i - ci) > r || Math.abs(j - cj) > r) continue;
      if (!best || h > best.h) best = { x: i * C.CELL, z: j * C.CELL, h };
    }
    return best;
  }
}
