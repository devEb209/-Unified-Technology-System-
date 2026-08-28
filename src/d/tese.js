// UTS :: d/tese — TESE DOS D.
//
// The Ds are NOT physical dimensions. They are FUNCTIONAL LAYERS/CONCEPTS of
// the architecture — levels of representation, integration, abstraction and
// operation. Values may be fractional conceptually (D.x.25 …), but every D
// registered here MUST have operational consequences: systems consult the
// Tese, act through it, and record observable effects via touch().
//
// A D that cannot show an effect is removed ("remova nomenclatura vazia").
// The registry is open: new layers of reality can be defined at any time.

export const D_LAYERS = [
  {
    id: 'D-0', name: 'Informational',
    objective: 'Existence and identity of everything represented.',
    problem: 'Something must exist before it can behave.',
    representation: 'RRW entity records with stable ids and components.',
    systems: ['rrw'], cost: 'O(1) per entity',
    observable: 'entities exist with stable identity across ticks/saves',
  },
  {
    id: 'D-1', name: 'Relational',
    objective: 'Relations between entities (knows, member-of, trades-with…).',
    problem: 'Reality is relational, not a bag of isolated objects.',
    representation: 'typed weighted relation graph in RRW.',
    systems: ['rrw', 'nmn', 'society'], cost: 'O(degree)',
    observable: 'relation queries drive behavior and society',
  },
  {
    id: 'D-2', name: 'Causal',
    objective: 'Verifiable cause->effect chains between events.',
    problem: 'A coherent reality cannot invent causes.',
    representation: 'RRW event log with verified cause references.',
    systems: ['rrw', 'reallife', 'nmn', 'economy'], cost: 'O(chain depth)',
    observable: 'every derived event resolves to a verifiable chain',
  },
  {
    id: 'D-3', name: 'Temporal',
    objective: 'Time: clocks, day/night, process evolution, scheduling.',
    problem: 'Reality evolves; state without time is a dead snapshot.',
    representation: 'Clock + scheduled systems + processes.',
    systems: ['clock', 'ues.scheduler'], cost: 'O(systems)',
    observable: 'world state changes as time advances',
  },
  {
    id: 'D-4', name: 'Spatial',
    objective: 'Positions, regions, distances, spatial indexing.',
    problem: 'Perception and materialization need geometric answers fast.',
    representation: 'spatial components + SpatialGrid derived index.',
    systems: ['spatial', 'perception', 'materializer'], cost: 'O(candidates)',
    observable: 'indexed spatial queries return correct neighbors',
  },
  {
    id: 'D-5', name: 'Environmental',
    objective: 'Terrain, biome, weather, atmosphere — the ambience of reality.',
    problem: 'Behavior and visuals must respond to environment.',
    representation: 'Terrain heightfield/biomes + RealLife weather state.',
    systems: ['terrain', 'reallife', 'renderer'], cost: 'O(patches)',
    observable: 'weather/wetness/light change what NPCs and frames see',
  },
  {
    id: 'D-6', name: 'Perceptual',
    objective: 'What each agent can actually perceive.',
    problem: 'Omniscient agents are unreal; perception defines knowledge.',
    representation: 'perception models (range, fov, resolution) over the spatial index.',
    systems: ['nmn'], cost: 'O(candidates)',
    observable: 'agents only react to what they perceive',
  },
  {
    id: 'D-7', name: 'Cognitive',
    objective: 'Minds: needs, goals, decisions with reasons (NMN).',
    problem: 'Rigid scripts are not minds.',
    representation: 'mind components + utility decisions with explanations.',
    systems: ['nmn'], cost: 'O(perceived * actions)',
    observable: 'decisions are explainable and adaptive',
  },
  {
    id: 'D-8', name: 'Social',
    objective: 'Groups, settlements, aggregates, culture.',
    problem: 'Society exceeds individuals; relevance decides resolution.',
    representation: 'settlements + population aggregates in RRW.',
    systems: ['society', 'materializer'], cost: 'O(aggregate)',
    observable: 'distant populations evolve as aggregates',
  },
  {
    id: 'D-9', name: 'Ecological',
    objective: 'Resources, growth, regeneration, consumption.',
    problem: 'Finite resources create real tradeoffs and emergence.',
    representation: 'resource components with regrow dynamics.',
    systems: ['ecology'], cost: 'O(resources)',
    observable: 'consumed resources regrow only when D-9 is active',
  },
  {
    id: 'D-10', name: 'Narrative / Importance',
    objective: 'Importance overrides distance in materialization.',
    problem: 'Some realities matter more than geometry suggests.',
    representation: 'importance weights consulted by D-O15.',
    systems: ['materializer', 'perception'], cost: 'O(1) per entity',
    observable: 'important entities stay materialized beyond radius',
  },
  {
    id: 'D-11', name: 'Acoustic',
    objective: 'Audible state of the reality (ambience, events).',
    problem: 'Reality is not only visual.',
    representation: 'audio channel state in the Frame.',
    systems: ['frame'], cost: 'O(events)',
    observable: 'frames carry ambience/one-shot sounds derived from state',
  },
  {
    id: 'D-12', name: 'Economic',
    objective: 'Production, consumption, trade flows.',
    problem: 'Scarcity and exchange drive societies.',
    representation: 'settlement stores + trade events with causes.',
    systems: ['economy'], cost: 'O(pairs)',
    observable: 'stores change; trades emit verifiable events',
  },
  {
    id: 'D-13', name: 'Information / Knowledge',
    objective: 'Knowledge exists in minds and spreads (gossip).',
    problem: 'Information is part of reality and travels relationally.',
    representation: 'mind.knowledge sets exchanged during socialize.',
    systems: ['nmn'], cost: 'O(knowledge)',
    observable: 'knowledge appears in other minds after social contact',
  },
  {
    id: 'D-14', name: 'Abstraction / Materialization',
    objective: 'Multilevel representation: abstract <-> detailed without state loss.',
    problem: 'Full resolution everywhere is impossible; abstraction must not destroy.',
    representation: 'materialization levels + state-preserving transitions.',
    systems: ['rrw', 'materializer', 'society'], cost: 'O(state)',
    observable: 'abstract->materialize roundtrip preserves identity/state',
  },
  {
    id: 'D-O15', name: 'Optimization',
    objective: 'Decide the necessary resolution of everything, per moment.',
    problem: 'Brute force simulation does not scale; quality must be preserved smartly.',
    representation: 'pressure metrics -> strategy (radius, hz, perception res, LOD, defer queue).',
    systems: ['do15', 'ues', 'renderer'], cost: 'O(metrics)',
    observable: 'under pressure the system defers, not discards; recovers when free',
  },
];

export class TeseDosD {
  constructor() {
    /** @type {Map<string, layer>} */
    this.layers = new Map();
    for (const def of D_LAYERS) this.layers.set(def.id, { ...def, enabled: true });
    /** dId -> {note, tick, count} observable-effect trail */
    this.effects = new Map();
  }

  /** open extension: define a brand new functional layer of reality */
  define({ id, name, objective, problem = '', representation = '', systems = [], cost = '', observable = '' }) {
    if (this.layers.has(id)) throw new Error(`D layer ${id} already defined`);
    this.layers.set(id, { id, name, objective, problem, representation, systems, cost, observable, enabled: true });
    return this.layers.get(id);
  }

  has(id) { return this.layers.has(id); }
  isEnabled(id) { return this.layers.get(id)?.enabled ?? false; }
  setEnabled(id, enabled) {
    const l = this.layers.get(id);
    if (!l) throw new Error(`unknown D layer: ${id}`);
    l.enabled = !!enabled;
    return l.enabled;
  }

  /** systems record observable effects here — proof a D is not just a name */
  touch(id, note, tick = null) {
    if (!this.layers.has(id)) return;
    let e = this.effects.get(id);
    if (!e) { e = { note, tick, count: 0 }; this.effects.set(id, e); }
    e.note = note;
    e.tick = tick ?? e.tick;
    e.count++;
  }

  effect(id) { return this.effects.get(id) ?? null; }
  list() { return [...this.layers.values()]; }
  activeIds() { return this.list().filter(l => l.enabled).map(l => l.id); }

  describe(id) {
    const l = this.layers.get(id);
    if (!l) return null;
    return { ...l, effect: this.effect(id) };
  }

  snapshot() {
    return {
      layers: this.list().map(l => ({ id: l.id, enabled: l.enabled })),
      effects: [...this.effects.entries()].map(([id, e]) => ({ id, ...e })),
    };
  }

  restore(s) {
    for (const l of s.layers ?? []) {
      if (this.layers.has(l.id)) this.layers.get(l.id).enabled = l.enabled;
    }
    this.effects = new Map((s.effects ?? []).map(e => [e.id, { note: e.note, tick: e.tick, count: e.count }]));
  }
}
