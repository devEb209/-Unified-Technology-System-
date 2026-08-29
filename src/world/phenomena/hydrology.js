// UTS :: world/phenomena/hydrology — WATER AS A SUBSTANCE, modeled.
//
//   reality question first: WHERE IS WATER, HOW MUCH, AND WHERE IS IT GOING?
//
// Rain falls, water ACCUMULATES on terrain (surface water film), flows
// downhill (gradient of the REPRESENTED heightfield), pools in depressions
// (depth), feeds rivers/sea level dynamics, humidifies the ground
// (wetness with memory) and evaporates back under sun/heat. Floods are a
// CONSEQUENCE (low ground next to a full basin), not a scripted event.
// Deterministic (seeded RNG only for tie-breaks of equal gradients).
// Causality: reallife.rain → hydrology.step → wetness/depth → Frame →
// renderer (shorelines emerge from DEPTH, not from a biome paint) → audio.

import { clamp01, lerp } from '../../core/math.js';

export class Hydrology {
  constructor({ world, cell = 24, maxCells = 96 } = {}) {
    this.world = world;
    this.cell = cell;
    this.maxCells = maxCells;          // D-O15 budget: cells around focus
    /** scalar soil moisture 0..1 (the terrain's water table memory) */
    this.soil = { wetness: 0 };
    /** "x,z" -> { depth, flow } — water film depth (m) and flow speed (m/s) */
    this.cells = new Map();
    this.evaporationRate = 0.0008;     // m/s under full sun (sun dries SLOWER than rain pours)
    this.seepRate = 0.0004;            // infiltration: drizzle soaks in, cloudbursts run off
    this.stats = { rainVolume: 0, flowed: 0, evaporated: 0, pooled: 0 };
  }

  _key(x, z) { return `${Math.floor(x / this.cell)},${Math.floor(z / this.cell)}`; }

  /** surface water depth at a world position (0 if the cell is dry) */
  depthAt(x, z) {
    const c = this.cells.get(this._key(x, z));
    return c ? c.depth : 0;
  }

  /** ground wetness with memory: 0..1, fed by rain and pooled water */
  wetnessAt(x, z, envWetness) {
    const c = this.cells.get(this._key(x, z));
    const local = clamp01((c?.depth ?? 0) / 0.25 + (c ? 0.35 : 0));
    return clamp01(Math.max(local, envWetness ?? 0));
  }

  /**
   * one step of the water cycle for the cells around `focus`.
   * @param dt seconds; @param rain represented rain intensity 0..1
   */
  step(dt, { focus, radius = 160, rain = 0, sunEl = 1 }) {
    const { terrain, rrw } = this.world;
    const t = terrain;
    const cs = t.chunkSize;

    // ---- ensure cells around focus (budgeted ring)
    const c0 = Math.floor((focus[0] - radius) / this.cell), c1 = Math.floor((focus[0] + radius) / this.cell);
    const d0 = Math.floor((focus[2] - radius) / this.cell), d1 = Math.floor((focus[2] + radius) / this.cell);
    for (let cx = c0; cx <= c1; cx++) {
      for (let cz = d0; cz <= d1; cz++) {
        const k = `${cx},${cz}`;
        if (!this.cells.has(k) && this.cells.size < this.maxCells) {
          this.cells.set(k, { depth: 0, flow: 0 });
        }
      }
    }

    // ---- SOIL MOISTURE (owned state): absorbed rainfall minus sun drying.
    // This is the hydrological memory that gates combustion, vegetation, dust.
    const soil = this.soil;
    soil.wetness = clamp01(soil.wetness
      + (rain * 0.06 * (1 - soil.wetness / 0.92)
         - 0.006 * clamp01(sunEl) * (1 - rain) * soil.wetness) * dt);

    let rainVolume = 0, flowed = 0, evaporated = 0, pooled = 0;
    const evap = this.evaporationRate * clamp01(sunEl) * (1 - rain);
    for (const [k, c] of this.cells) {
      const [cx, cz] = k.split(',').map(Number);
      const wx = cx * this.cell + this.cell / 2, wz = cz * this.cell + this.cell / 2;
      // ---- input: rain on EVERY cell (reality: rain falls everywhere in range)
      if (rain > 0) {
        const add = rain * 0.0018 * dt; // m of water film per second at rain=1
        c.depth += add;
        rainVolume += add * this.cell * this.cell;
      }
      const groundH = t.height(wx, wz);
      const sea = t.seaLevel;
      if (groundH > sea) {
        // ---- evaporation + seepage (sun and ground drink the film)
        const evapNow = Math.min(c.depth, evap * dt);
        const seepNow = Math.min(c.depth - evapNow, this.seepRate * dt);
        c.depth -= evapNow + seepNow;
        evaporated += evapNow;
        // ---- flow: downhill gradient into the LOWER neighbor cell
        const g = (x, z) => t.height(x, z);
        const gx = g(wx + this.cell, wz) - g(wx - this.cell, wz);
        const gz = g(wx, wz + this.cell) - g(wx, wz - this.cell);
        const grad = Math.hypot(gx, gz) / (2 * this.cell);
        if (grad > 1e-4 && c.depth > 0.004) {
          const nx = -gx, nz = -gz; // downhill direction
          const nl = Math.hypot(nx, nz) || 1;
          const speed = Math.min(4, 2.5 * Math.sqrt(grad)); // m/s-ish
          c.flow = lerp(c.flow, speed, 0.3);
          const move = Math.min(c.depth * 0.5, speed * dt * 0.02);
          // hand the water to the downhill neighbor cell
          const nk = this._key(wx + (nx / nl) * this.cell, wz + (nz / nl) * this.cell);
          const nc = this.cells.get(nk);
          if (nc) { nc.depth += move; c.depth -= move; flowed += move; }
          else {
            // neighbor outside the budget ring: water leaves the simulation
            // window honestly (it still exists in the world, we just don't
            // carry it) — river mouths and sea absorb it.
            c.depth -= move;
            flowed += move;
          }
        } else if (grad <= 1e-4 && c.depth > 0.02) {
          pooled++; // flat ground holding water — a puddle/lake forming
        }
      } else {
        // below sea level: the film is the SEA — it doesn't accumulate
        c.depth = 0;
      }
      if (c.depth < 1e-5 && rain === 0) c.depth = 0;
    }
    this.stats.rainVolume = rainVolume / dt || 0;
    this.stats.flowed += flowed;
    this.stats.evaporated += evaporated;
    this.stats.pooled = pooled;
    return { rainVolume, flowed, evaporated, pooled };
  }

  /**
   * D-O15 materialization of the FILM: puddles/flow cells near the camera,
   * deepest first, budget-capped. The renderer draws THESE (the cells are
   * the reality; the visual derives from them, never from a painted texture).
   */
  filmNear(camPos, radius = 220, cap = 120) {
    const out = [];
    const { terrain } = this.world;
    for (const [k, c] of this.cells) {
      if (c.depth < 0.004) continue;
      const [cx, cz] = k.split(',').map(Number);
      const wx = cx * this.cell + this.cell / 2, wz = cz * this.cell + this.cell / 2;
      const d = Math.hypot(wx - camPos[0], wz - camPos[2]);
      if (d > radius) continue;
      out.push({ pos: [wx, terrain.height(wx, wz) + 0.06, wz], depth: c.depth });
    }
    out.sort((a, b) => b.depth - a.depth);
    return out.slice(0, cap);
  }

  /** the Frame's hydrology summary for the camera area (renderer/audio read this) */
  sample(x, z) {
    return {
      depth: this.depthAt(x, z),
      wetness: this.wetnessAt(x, z, this.world.environment.wetness),
      cells: this.cells.size,
    };
  }

  /** RRW-compatible plain state (persistence, rule 5) */
  snapshot() {
    return { cell: this.cell, maxCells: this.maxCells, useN: this.useN ?? 0,
             cells: [...this.cells], stats: { ...this.stats } };
  }
  restore(s) {
    this.cell = s.cell; this.maxCells = s.maxCells;
    this.cells = new Map(s.cells ?? []);
    Object.assign(this.soil, s.soil ?? {});
    Object.assign(this.stats, s.stats ?? {});
    return this;
  }
}
