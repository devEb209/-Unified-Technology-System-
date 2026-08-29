// UTS :: world/phenomena/ecology — VEGETATION AS A LIVING POPULATION.
//
//   reality question first: WHAT IS A FOREST, PHYSICALLY? A population of
//   individual trees competing for light and water, growing on a timescale
//   of seasons, dying of fire/drought/age, and reproducing. NOT a color
//   painted on the terrain.
//
// Each tree is an RRW-anchored individual: species (from the biome's
// represented ecology), age, biomass, health. Growth follows a logistic
// curve driven by SUN and SOIL WATER (hydrology.soil — real coupling).
// Fire consumes trees (combustion kills them) and dead trees ADD fuel.
// Seeds spread from mature trees; density competition caps the stand.
// Deterministic (seeded rng). D-O15 governs how many trees are
// MATERIALIZED for rendering, never that the population exists.

import { clamp01 } from '../../core/math.js';

// Species are keyed by NAME (a forest is a MIXED stand — reality is not
// monoculture); each biome carries its species list.
const SPECIES = {
  'grass-shrub': { mature: 4, lifespan: 900, growth: 0.010, seedDist: 14, fuel: 0.25, height: 1.2 },
  'pine':        { mature: 26, lifespan: 5200, growth: 0.0035, seedDist: 22, fuel: 1.4, height: 9 },
  'broadleaf':   { mature: 20, lifespan: 3600, growth: 0.005, seedDist: 18, fuel: 1.1, height: 7 },
};
const BIOME_SPECIES = { 2: ['grass-shrub'], 3: ['pine', 'broadleaf'] };

export class Ecology {
  constructor({ world, maxTrees = 240 } = {}) {
    this.world = world;
    this.maxTrees = maxTrees;                 // D-O15 budget for MATERIALIZED trees
    this.nextId = 1;
    /** id -> tree { id, pos, species, biome, age, maturity, health, biomass, state } */
    this.trees = new Map();
    this.stats = { seeded: 0, died: 0, burnt: 0, grown: 0 };
  }

  speciesFor(biome) { const l = BIOME_SPECIES[biome]; return l ? { ...SPECIES[l[0]], name: l[0] } : null; }
  speciesListFor(biome) { return (BIOME_SPECIES[biome] ?? []).map(n => ({ ...SPECIES[n], name: n })); }

  /** is this terrain spot plantable? (honest: no trees in deep water/rock/snow) */
  plantable(x, z) {
    const t = this.world.terrain;
    const h = t.height(x, z);
    if (h <= t.seaLevel + 0.4) return false;          // underwater/shore
    const b = t.biomeAt(x, z, h);
    return b === 2 || b === 3;                        // grass & forest soils
  }

  seed(x, z, { biome = null, age = 0, causeEvent = null } = {}) {
    const t = this.world.terrain;
    const h = t.height(x, z);
    const b = biome ?? t.biomeAt(x, z, h);
    const list = this.speciesListFor(b);
    if (!list.length || !this.plantable(x, z)) return null;
    // mixed stands: the seeded rng picks the species (deterministic)
    const sp = list[Math.floor(this.world.rng.next() * list.length) % list.length];
    const id = `tree${this.nextId++}`;
    const tree = {
      id, pos: [x, h, z], biome: b, species: sp.name,
      age, maturity: clamp01(age / sp.mature),
      health: 1, biomass: 0.15 + 0.85 * clamp01(age / sp.mature),
      state: age >= sp.mature ? 'mature' : 'growing',
      fuel: sp.fuel,
    };
    this.trees.set(id, tree);
    this.stats.seeded++;
    this.world.rrw.emitEvent({
      type: 'ecology.seeded', subject: id, cause: causeEvent,
      data: { pos: tree.pos, species: sp.name }, tick: this.world.clock.tick,
    });
    return tree;
  }

  /** the RRW persistence contract */
  snapshot() {
    return { nextId: this.nextId, maxTrees: this.maxTrees, trees: [...this.trees], stats: { ...this.stats } };
  }
  restore(s) {
    this.nextId = s.nextId; this.maxTrees = s.maxTrees;
    this.trees = new Map(s.trees ?? []);
    Object.assign(this.stats, s.stats ?? {});
    return this;
  }

  kill(tree, reason, { causeEvent = null } = {}) {
    if (!tree || tree.state === 'dead') return;
    tree.state = 'dead';
    tree.health = 0;
    this.stats.died++;
    if (reason === 'fire') {
      this.stats.burnt++;
      // dead biomass becomes FUEL for the combustion field (closed loop)
      const c = this.world.combustion;
      if (c) {
        const cell = c.cells.get(c._key(tree.pos[0], tree.pos[2]));
        if (cell) cell.fuel = Math.min(1.6, cell.fuel + tree.biomass * 0.5);
      }
    }
    this.world.rrw.emitEvent({
      type: 'ecology.tree.died', subject: tree.id, cause: causeEvent,
      data: { reason, pos: tree.pos, age: +tree.age.toFixed(0) }, tick: this.world.clock.tick,
    });
  }

  /**
   * step the population. REALITY DRIVERS:
   *   sunEl    — photosynthesis budget
   *   soilWet  — hydrology.soil.wetness (water beats everything)
   *   rain     — instant water
   *   combustion — fire hurts/kills trees near burning cells
   */
  /** cobertura de dossel perto de (x,z): a floresta madura TRANSPIRA
   *  (evapotranspiração real — a mata alimenta a umidade do ar) */
  canopyNear(x, z, r = 100) {
    let n = 0, sum = 0;
    const r2 = r * r;
    for (const tree of this.trees.values()) {
      if (tree.state === 'dead') continue;
      const dx = tree.pos[0] - x, dz = tree.pos[2] - z;
      if (dx * dx + dz * dz <= r2) { n += 1; sum += tree.maturity; }
    }
    return n === 0 ? 0 : Math.min(1, (sum / n) * Math.min(1, n / 40)); // densidade × maturidade
  }

  step(dt, { sunEl = 1, soilWet = 0.4, combustion = null, siltAt = null } = {}) {
    const w = this.world;
    let grown = 0;
    const day = clamp01(sunEl) * (0.35 + 0.65 * soilWet); // photosynthesis: light × water
    for (const tree of this.trees.values()) {
      if (tree.state === 'dead') continue;
      const sp = SPECIES[tree.species] ?? SPECIES.pine;
      // ---- growth (logistic toward maturity; stress shrinks health first)
      const stress = (soilWet < 0.15 && clamp01(sunEl) > 0.5) ? 1 : 0; // drought under hot sun
      tree.health = clamp01(tree.health - stress * 0.004 * dt + (soilWet > 0.3 ? 0.001 * dt : 0));
      if (tree.health <= 0.02) { this.kill(tree, 'drought'); continue; }
      if (tree.age < sp.mature) {
        // SILT: sedimente que o rio depositou ADUBA (a geologia alimenta a vida)
        const boost = siltAt ? Math.min(0.8, (siltAt(tree.pos?.[0] ?? tree.x ?? 0, tree.pos?.[2] ?? tree.z ?? 0)) * 2) : 0;
        tree.age += dt * (1 + boost);
        const prev = tree.maturity;
        tree.maturity = clamp01(tree.age / sp.mature);
        tree.biomass = 0.15 + 0.85 * tree.maturity;
        if (prev < 1 && tree.maturity >= 1) { tree.state = 'mature'; grown++; }
      }
      // ---- senescence
      tree.age += dt * 0.02;
      if (tree.age > sp.lifespan) { this.kill(tree, 'age'); continue; }
      // ---- FIRE feedback: burning cells nearby burn the tree itself
      if (combustion) {
        const fires = combustion.burningNear(tree.pos[0], tree.pos[2], 14);
        for (const f of fires) {
          tree.health -= f.intensity * 0.02 * dt;
          if (tree.health <= 0.02) { this.kill(tree, 'fire', {}); break; }
        }
      }
    }
    // ---- reproduction: mature stands seed their edge (competition caps density)
    if (this.trees.size < this.maxTrees && this.world.rng.chance(0.5 * dt * 10)) {
      const mature = [...this.trees.values()].filter(t => t.state === 'mature');
      if (mature.length) {
        const parent = mature[this.world.rng.int(0, mature.length - 1)];
        const sp = SPECIES[parent.species] ?? SPECIES.pine;
        const a = this.world.rng.range(0, Math.PI * 2);
        const d = (0.4 + this.world.rng.next() * 0.6) * sp.seedDist;
        const x = parent.pos[0] + Math.cos(a) * d, z = parent.pos[2] + Math.sin(a) * d;
        // competition: don't stack trees on the same spot
        let crowded = false;
        for (const t of this.trees.values()) {
          if (t.state !== 'dead' && Math.hypot(t.pos[0] - x, t.pos[2] - z) < 5) { crowded = true; break; }
        }
        if (!crowded) this.seed(x, z, { biome: parent.biome });
      }
    }
    this.stats.grown += grown;
    return { grown, population: this.trees.size, alive: this.aliveCount() };
  }

  aliveCount() {
    let n = 0;
    for (const t of this.trees.values()) if (t.state !== 'dead') n++;
    return n;
  }

  /** vegetation density near a point — fuel for combustion, cover for NMN agents */
  biomassAt(x, z, r = 24) {
    let b = 0;
    for (const t of this.trees.values()) {
      if (t.state === 'dead') continue;
      const d = Math.hypot(t.pos[0] - x, t.pos[2] - z);
      if (d <= r) b += t.biomass * (1 - d / r);
    }
    return b;
  }

  /** D-O15 materialization: trees near camera, culled by budget (identity preserved) */
  materialize(camPos, radius = 160, budget = this.maxTrees) {
    const out = [];
    for (const t of this.trees.values()) {
      if (t.state === 'dead') continue;
      const d = Math.hypot(t.pos[0] - camPos[0], t.pos[2] - camPos[2]);
      if (d <= radius) out.push({ tree: t, dist: d });
    }
    out.sort((a, b) => a.dist - b.dist);
    return out.slice(0, budget).map(({ tree }) => ({
      pos: tree.pos, height: (SPECIES[tree.species] ?? SPECIES.pine).height * tree.maturity,
      health: tree.health, species: tree.species, id: tree.id,
    }));
  }
}
