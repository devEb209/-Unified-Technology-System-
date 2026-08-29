// UTS :: world/phenomena/combustion — FIRE AS A PHENOMENON, modeled.
//
//   reality question first: WHAT IS FIRE DOING TO THIS PLACE RIGHT NOW?
//
// Fire is a combustion PROCESS over FUEL: it consumes real biomass
// (trees/bushes are fuel objects in the RRW), spreads along fuel
// continuity modulated by WIND and moisture (hydrology wetness!), weakens
// under rain (the air's water beats the fire's heat), leaves BURNT GROUND
// as persistent state, and can re-ignite. Lightning is the natural
// ignition source (reallife already provides the causal strike). Every
// ignition/spread/extinguish is an RRW causal event chain. Deterministic
// (seeded RNG). D-O15 governs the update cadence + spread radius, never
// the phenomenon itself.

import { clamp01 } from '../../core/math.js';

export class Combustion {
  constructor({ world, tese = null, cell = 12, maxCells = 80 } = {}) {
    this.world = world;
    this.tese = tese;
    this.cell = cell;
    this.maxCells = maxCells;
    /** "x,z" -> { fuel, burning, intensity, since } — ground fuel field */
    this.cells = new Map();
    this.stats = { ignitions: 0, spreads: 0, extinctions: 0, consumed: 0, burntCells: 0 };
  }

  _key(x, z) { return `${Math.floor(x / this.cell)},${Math.floor(z / this.cell)}`; }

  /** base fuel from the REPRESENTED biome (forest is dense, sand is not) */
  _biomeFuel(biome) {
    switch (biome) {
      case 3: return 1.0;  // forest
      case 2: return 0.55; // grass
      case 1: return 0.08; // sand
      case 4: return 0.15; // rock
      case 5: return 0.2;  // snow (wet fuel)
      default: return 0;   // water
    }
  }

  _cell(x, z) {
    const k = this._key(x, z);
    let c = this.cells.get(k);
    if (!c) {
      const w = this.world;
      if (this.cells.size >= this.maxCells) return null; // D-O15 budget
      const t = w.terrain;
      c = { fuel: this._biomeFuel(t.biomeAt ? t.biomeAt(x, z) : (t.height(x, z) < t.seaLevel ? 0 : 2)),
            burning: false, intensity: 0, since: 0 };
      this.cells.set(k, c);
    }
    return c;
  }

  /** ignition from ANY cause (lightning event, tool, player) — causal chain preserved */
  ignite(x, z, { causeEvent = null, intensity = 1 } = {}) {
    const w = this.world;
    const c = this._cell(x, z);
    if (!c || c.fuel < 0.15 || c.burning) return null; // no fuel, no fire (honest)
    // soaked fuel does not burn (reality: wet biomass + water film beat the strike)
    const wet = this.hydrologyRef
      ? this.hydrologyRef.wetnessAt(x, z, w.environment.wetness)
      : (w.environment.wetness ?? 0);
    if (wet > 0.55) {
      w.rrw.emitEvent({
        type: 'combustion.refused', subject: `ground:${this._key(x, z)}`,
        cause: causeEvent, data: { pos: [x, 0, z], wetness: +wet.toFixed(2) }, tick: w.clock.tick,
      });
      return null;
    }
    c.burning = true;
    c.intensity = intensity;
    c.since = w.clock.tick;
    const evId = w.rrw.emitEvent({
      type: 'combustion.ignited',
      subject: `ground:${this._key(x, z)}`,
      cause: causeEvent,
      data: { pos: [x, 0, z], fuel: +c.fuel.toFixed(2) },
      tick: w.clock.tick,
    });
    this.stats.ignitions++;
    c.startedEvent = evId;  // the field itself carries the causal chain (RRW)
    this.tese?.touch('D-2', `combustion.ignited @${this._key(x, z)}`, w.clock.tick);
    return { id: evId, type: 'combustion.ignited', subject: `ground:${this._key(x, z)}` };
  }

  /**
   * step the fire field. wind = represented wind 0..1 (spread boost + drift),
   * rain = represented rain 0..1 (extinguishing), wetness lookup from hydrology.
   */
  step(dt, { rain = 0, wind = 0, windDir = [1, 0], hydrology = null, spreadRate = 1 } = {}) {
    if (hydrology) this.hydrologyRef = hydrology; // remember for ignite-time wetness checks
    const w = this.world;
    let spreads = 0, consumed = 0, extinctions = 0;
    const ignitions = [];
    for (const [k, c] of this.cells) {
      const [cx, cz] = k.split(',').map(Number);
      const wx = cx * this.cell + this.cell / 2, wz = cz * this.cell + this.cell / 2;
      if (c.burning) {
        // ---- consume fuel (heat output ∝ intensity; fuel ∝ biomass)
        const burn = dt * (0.06 + c.intensity * 0.05);
        c.fuel = Math.max(0, c.fuel - burn);
        consumed += burn;
        c.intensity = clamp01(c.fuel * 2.2);
        // ---- rain fights fire (water film + humidity beat heat)
        if (hydrology) {
          const film = hydrology.depthAt(wx, wz);
          if (film > 0.004 || rain > 0.45) {
            c.fuel -= dt * (0.4 + film * 30);
            c.intensity = clamp01(c.fuel * 2.2);
          }
        } else if (rain > 0.45) {
          c.fuel -= dt * 0.4;
        }
        // ---- death when the fuel is gone → burnt ground persists
        if (c.fuel <= 0.02) {
          c.burning = false;
          c.intensity = 0;
          c.burnt = true;         // burnt state persists in the field
          c.burntAt = w.clock.tick; // ash fades with TIME (a real timescale)
          this.cells.set(k, c);
          this.stats.burntCells++;
          extinctions++;
          w.rrw.emitEvent({
            type: 'combustion.extinguished',
            subject: `ground:${k}`,
            cause: null,
            data: { pos: [wx, 0, wz] },
            tick: w.clock.tick,
          });
          continue;
        }
        // ---- spread: to the best-aligned, dry, fuel-rich neighbor
        if (c.intensity > 0.35 && spreadRate > 0) {
          const dirs = [[1, 0], [-1, 0], [0, 1], [0, -1], [0.7, 0.7], [-0.7, 0.7], [0.7, -0.7], [-0.7, -0.7]];
          for (const [dx, dz] of dirs) {
            const align = (dx * (windDir[0] ?? 1) + dz * (windDir[1] ?? 0)) * wind; // wind-aligned spread wins
            const p = 0.02 * spreadRate * dt * 10 * (0.25 + align * 2.2) * c.intensity;
            if (!w.rng.chance(p)) continue;
            const nx = wx + dx * this.cell, nz = wz + dz * this.cell;
            const nc = this._cell(nx, nz);
            if (!nc || nc.burning || nc.burnt || nc.fuel < 0.2) continue;
            // moisture stops fire: wet ground simply refuses to burn (honest)
            const wet = hydrology ? hydrology.wetnessAt(nx, nz, w.environment.wetness) : (w.environment.wetness ?? 0);
            if (wet > 0.55) continue;
            const ev = this.ignite(nx, nz, { causeEvent: null });
            if (ev) { spreads++; ignitions.push(ev); }
            if (spreads > 6) break; // per-step spread cap (stability)
          }
        }
      } else if (!c.burnt) {
        // ---- fuel slowly regrows (ecology will take this over in R2)
        c.fuel = Math.min(this._biomeFuel(this.world.terrain.biomeAt?.(wx, wz) ?? 2) || 0.4, c.fuel + dt * 0.001);
      }
    }
    this.stats.spreads += spreads;
    this.stats.consumed += consumed;
    this.stats.extinctions += extinctions;
    return { spreads, consumed: +consumed.toFixed(3), extinctions, ignitions: ignitions.length };
  }

  /**
   * D-O15 materialization of BURNT GROUND: burnt cells near the camera,
   * FRESHEST ASH FIRST, budget-capped. The renderer draws THESE (the burn
   * scar is field state; ash fades on a real timescale, not a texture).
   */
  burntNear(camPos, radius = 240, cap = 90) {
    const out = [];
    const t = this.world.terrain;
    const now = this.world.clock.tick;
    for (const [k, c] of this.cells) {
      if (!c.burnt) continue;
      const [cx, cz] = k.split(',').map(Number);
      const wx = cx * this.cell + this.cell / 2, wz = cz * this.cell + this.cell / 2;
      const d = Math.hypot(wx - camPos[0], wz - camPos[2]);
      if (d > radius) continue;
      const age = now - (c.burntAt ?? now);
      out.push({ pos: [wx, t.height(wx, wz) + 0.1, wz], age, alpha: Math.max(0, 1 - age / 3000) });
    }
    out.sort((a, b) => a.age - b.age);
    return out.slice(0, cap);
  }

  /** burning cell centers near a position (renderer/audio/NMN perception) */
  burningNear(x, z, radius = 80) {
    const out = [];
    for (const [k, c] of this.cells) {
      if (!c.burning) continue;
      const [cx, cz] = k.split(',').map(Number);
      const wx = cx * this.cell + this.cell / 2, wz = cz * this.cell + this.cell / 2;
      const d = Math.hypot(wx - x, wz - z);
      if (d <= radius) out.push({ pos: [wx, 0, wz], intensity: c.intensity, fuel: c.fuel, dist: d });
    }
    return out.sort((a, b) => a.dist - b.dist);
  }

  /** did fire cross here recently? (honest burnt-state query) */
  isBurnt(x, z) {
    const c = this.cells.get(this._key(x, z));
    return !!c?.burnt;
  }

  snapshot() {
    return { cell: this.cell, maxCells: this.maxCells, cells: [...this.cells], stats: { ...this.stats } };
  }
  restore(s) {
    this.cell = s.cell; this.maxCells = s.maxCells;
    this.cells = new Map(s.cells ?? []);
    Object.assign(this.stats, s.stats ?? {});
    return this;
  }
}
