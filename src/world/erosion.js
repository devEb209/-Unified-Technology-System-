// UTS :: world/erosion — THE LADDER MADE FLESH: rain that LANDS moves the
// ground. Water erodes where it flows (slope × energy), sediment travels
// DOWNHILL, deposits where the slope dies (or into the water table), and
// the TOTAL moved mass climbs the scale ladder: street → region → planet
// (the geological record). Terrain deltas are REAL state (height() reads
// them), conserved: eroded == deposited + in motion, always.
const CELL = 3; // m per delta cell (matches terrain.deltas quantization)

export const deltaKey = (x, z) => `${Math.round(x / CELL)},${Math.round(z / CELL)}`;

export class Erosion {
  constructor({ world, kE = 0.05, geologyEvery = 12 } = {}) {
    this.world = world;
    this.kE = kE;                 // how hard flowing water bites
    this.geologyEvery = geologyEvery; // m³ of moved ground per geology event
    this.accum = 0;               // accumulated movement since last geology event
    this.silt = new Map();        // sedimento depositado por célula → SOLO FÉRTIL
    this.events = [];             // the planet-scale record
    this.stats = { eroded: 0, deposited: 0, inMotion: 0 };
  }

  snapshot() { return { stats: { ...this.stats }, accum: this.accum, events: this.events.slice(-20) }; }

  restore(s) {
    if (!s) return;
    if (s.stats) this.stats = { ...s.stats };
    this.accum = s.accum ?? 0;
    if (Array.isArray(s.events)) this.events = s.events.slice(-20);
  }

  step(dt) {
    const env = this.world.environment;
    const rain = env.rain ?? 0;
    if (rain > 0.02) {
      const focus = this.world.ues?.camera?.pos ?? [512, 0, 512];
      const cells = Math.max(1, Math.round(rain * dt * 2));
      for (let k = 0; k < cells; k++) {
        const a = this.world.rng.next() * Math.PI * 2;
        const r = this.world.rng.next() * 60;
        this.erodeAt(focus[0] + Math.cos(a) * r, focus[2] + Math.sin(a) * r, Math.min(0.25, rain * dt));
      }
    }
    // suspended sediment settles (deposits where it is)
    if (this.stats.inMotion > 1e-9) {
      const settle = this.stats.inMotion * Math.min(1, dt * 0.5);
      this.stats.inMotion -= settle;
      this.stats.deposited += settle;
    }
    // the GEOLOGICAL record: enough moved mass climbs the ladder
    if (this.accum > this.geologyEvery) {
      const up = this.world.scales?.propagateUp?.([this.accum], 'region');
      this.events.push({ at: this.world.clock.tick, moved: +this.accum.toFixed(4), up: up ?? null });
      if (this.events.length > 50) this.events.shift();
      this.accum = 0;
    }
  }

  /** water with `energy` flows over (x, z): bite the ground, carry downhill */
  erodeAt(x, z, energy) {
    const terrain = this.world.terrain;
    if (!terrain || !terrain.deltas) return;
    const h = terrain.height(x, z);
    if (h <= 0.05) return; // under water: no bites
    const hx = terrain.height(x + CELL, z) - h;
    const hz = terrain.height(x, z + CELL) - h;
    const slope = Math.min(1.2, Math.hypot(hx, hz));
    const take = Math.min(h * 0.05, this.kE * energy * slope);
    if (take <= 1e-6) return;
    // find the downhill neighbor (the sediment goes where water goes)
    let bx = x, bz = z, bh = h;
    for (const [dx, dz] of [[CELL, 0], [-CELL, 0], [0, CELL], [0, -CELL]]) {
      const nh = terrain.height(x + dx, z + dz);
      if (nh < bh) { bh = nh; bx = x + dx; bz = z + dz; }
    }
    const k0 = deltaKey(x, z), k1 = deltaKey(bx, bz);
    terrain.deltas.set(k0, (terrain.deltas.get(k0) ?? 0) - take);
    terrain.deltas.set(k1, (terrain.deltas.get(k1) ?? 0) + take * 0.9);
    this.silt.set(k1, (this.silt.get(k1) ?? 0) + take * 0.9); // o rio ADUBA
    this.stats.eroded += take;
    this.stats.deposited += take * 0.9;
    this.stats.inMotion += take * 0.1; // 10% stays suspended (settles later)
    this.accum += take;
  }

  /** fertilidade do solo em (x,z): sedimento dos vizinhos (3×3 células) */
  siltAt(x, z) {
    const kx = Math.round(x / CELL), kz = Math.round(z / CELL);
    let v = 0;
    for (let dx = -1; dx <= 1; dx++) for (let dz = -1; dz <= 1; dz++) {
      v += this.silt.get(`${kx + dx},${kz + dz}`) ?? 0;
    }
    return v;
  }

  /** total ground moved (m) — the honest number for the HUD/the chat */
  get movedTotal() { return this.stats.eroded; }
}
