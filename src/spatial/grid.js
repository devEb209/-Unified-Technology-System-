// UTS :: spatial — SpatialGrid (uniform grid index).
//
// The grid is a DERIVED INDEX. RRW remains the source of truth; the grid is
// rebuilt from RRW spatial components on restore and kept in sync on move.
// NMN never knows this structure exists — it asks "perceive(pos, model)".
// Architecture allows quadtree/kd-tree later behind the same interface.

import { dist2 } from '../core/math.js';

export class SpatialGrid {
  constructor({ cellSize = 16 } = {}) {
    this.cellSize = cellSize;
    /** key "cx,cz" -> Set<entityId> */
    this.cells = new Map();
    /** entityId -> cell key (for O(1) move) */
    this.index = new Map();
    this.metrics = { inserts: 0, moves: 0, removes: 0, queries: 0, candidates: 0, hits: 0 };
  }

  key(cx, cz) { return cx + ',' + cz; }

  _cellOf(key) {
    let c = this.cells.get(key);
    if (!c) { c = new Set(); this.cells.set(key, c); }
    return c;
  }

  /** insert or move an entity — keeps the index synchronized with RRW positions */
  update(id, x, z) {
    const k = this.key(Math.floor(x / this.cellSize), Math.floor(z / this.cellSize));
    const prev = this.index.get(id);
    if (prev === k) return k;
    if (prev !== undefined) {
      this.cells.get(prev)?.delete(id);
      if (this.cells.get(prev)?.size === 0) this.cells.delete(prev);
      this.metrics.moves++;
    } else {
      this.metrics.inserts++;
    }
    this._cellOf(k).add(id);
    this.index.set(id, k);
    return k;
  }

  remove(id) {
    const prev = this.index.get(id);
    if (prev === undefined) return false;
    this.cells.get(prev)?.delete(id);
    if (this.cells.get(prev)?.size === 0) this.cells.delete(prev);
    this.index.delete(id);
    this.metrics.removes++;
    return true;
  }

  /** all entity ids within radius r of (x, z). Returns ids; caller applies semantic filters. */
  queryCircle(x, z, r) {
    this.metrics.queries++;
    const out = [];
    const seen = new Set();
    const r2 = r * r;
    const minCx = Math.floor((x - r) / this.cellSize), maxCx = Math.floor((x + r) / this.cellSize);
    const minCz = Math.floor((z - r) / this.cellSize), maxCz = Math.floor((z + r) / this.cellSize);
    for (let cx = minCx; cx <= maxCx; cx++) {
      for (let cz = minCz; cz <= maxCz; cz++) {
        const cell = this.cells.get(this.key(cx, cz));
        if (!cell) continue;
        for (const id of cell) {
          if (seen.has(id)) continue;
          seen.add(id);
          this.metrics.candidates++;
          out.push(id);
        }
      }
    }
    // distance filter when exact positions are available (World wires RRW as
    // the source of truth). Without a lookup, return the cell candidates —
    // the cell box is already bounded by the radius.
    if (!this.posLookup) {
      for (const _ of out) this.metrics.hits++;
      out.sort(); // deterministic order regardless of insertion history
      return out;
    }
    const filtered = [];
    for (const id of out) {
      const p = this.positionOf(id);
      if (!p) continue;
      if (dist2(x, z, p[0], p[2] ?? p[1]) <= r2) {
        this.metrics.hits++;
        filtered.push(id);
      }
    }
    filtered.sort(); // deterministic order regardless of insertion history
    return filtered;
  }

  /** raw ids in the 3x3 neighborhood of a position (unfiltered by distance) */
  queryNeighborhood(x, z) {
    const cx = Math.floor(x / this.cellSize), cz = Math.floor(z / this.cellSize);
    const out = [];
    for (let dx = -1; dx <= 1; dx++) {
      for (let dz = -1; dz <= 1; dz++) {
        const cell = this.cells.get(this.key(cx + dx, cz + dz));
        if (cell) for (const id of cell) out.push(id);
      }
    }
    return out;
  }

  positionOf(id) {
    // The index stores only the cell; exact positions come from RRW via callback.
    return this.posLookup ? this.posLookup(id) : null;
  }

  /** rebuild from an iterator of [id, x, z] — used after restore (RRW = truth) */
  rebuild(entries) {
    this.clear();
    for (const [id, x, z] of entries) this.update(id, x, z);
  }

  clear() {
    this.cells.clear();
    this.index.clear();
  }

  get size() { return this.index.size; }
  cellCount() { return this.cells.size; }

  /** rough memory estimate in bytes (cells + index entries) */
  memoryEstimate() {
    let perCellEntries = 0;
    for (const s of this.cells.values()) perCellEntries += s.size;
    return this.cells.size * 64 + this.index.size * 48 + perCellEntries * 8;
  }
}
