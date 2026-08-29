// UTS :: persistence/snapshot — real save/load with versioning, integrity and
// deterministic restoration. A corrupted or incompatible snapshot fails
// LOUDLY (SnapshotError) — never silently boots an empty reality.
//
//   save:  validate -> checksum -> storage
//   load:  parse -> checksum -> migrate -> restore -> validate (RRW.restore)

import { fnv1a } from '../core/math.js';
import { RNG } from '../core/rng.js';
import { RRW, SnapshotError } from '../rrw/registry.js';
import { TeseDosD } from '../d/tese.js';

export { SnapshotError };
import { DO15 } from '../d/do15.js';
import { World } from '../world/world.js';
import { UES } from '../ues/ues.js';
import { buildSingularity } from '../index.js';

export const SCHEMA_VERSION = 1;
export const ENGINE_VERSION = 'uts-1.0.0';

/** process types must be re-registered on restore (code-defined behavior, serializable state) */
export function processTypeRegistry() {
  const evolve = (state, dt, ctx) => ctx.world.evolveSettlementProcess(state.settlementId, dt);
  return new Map([
    ['settlement-life', { evolveAbstract: evolve, evolveDetailed: evolve }],
  ]);
}

// ------------------------------------------------------------- serialize

export function serializeState(uts) {
  return {
    schemaVersion: SCHEMA_VERSION,
    engineVersion: ENGINE_VERSION,
    createdAt: null, // set by save(); determinism lives in rng/clock, not wall time
    rng: uts.rng.getState(),
    clock: uts.clock.snapshot(),
    tese: uts.tese.snapshot(),
    do15: uts.do15.snapshot(),
    rrw: uts.rrw.snapshot(),
    world: {
      seed: uts.world.seed,
      environment: structuredClone(uts.world.environment),
      settlementMaterialCap: uts.world.settlementMaterialCap,
      // REALITY PHENOMENA (ADR-019): air, water, fire, life persist WITH the world
      phenomena: uts.world.phenomenaSnapshot ? uts.world.phenomenaSnapshot() : null,
    },
    ues: {
      camera: structuredClone(uts.ues.camera),
      tickN: uts.ues.tickN,
      schedulerBudgetMs: uts.ues.scheduler.globalBudgetMs,
    },
    singularity: uts.core
      ? { memory: uts.core.memory.snapshot() } // provider NAMES only — never secrets
      : null,
  };
}

export async function save(storage, key, uts) {
  const state = serializeState(uts);
  state.createdAt = new Date().toISOString();
  const body = JSON.stringify({
    schemaVersion: state.schemaVersion,
    engineVersion: state.engineVersion,
    checksum: fnv1a(JSON.stringify(state)),
    state,
  });
  await storage.set(key, body);
  return state;
}

export async function load(storage, key, opts = {}) {
  const body = await storage.get(key);
  if (body == null) throw new SnapshotError(`snapshot '${key}' not found`);
  let envelope;
  try {
    envelope = JSON.parse(body);
  } catch (e) {
    throw new SnapshotError(`snapshot '${key}' is not valid JSON: ${e.message}`);
  }
  if (typeof envelope !== 'object' || envelope == null || !('state' in envelope) || !('checksum' in envelope)) {
    throw new SnapshotError(`snapshot '${key}' missing envelope fields`);
  }
  const actual = fnv1a(JSON.stringify(envelope.state));
  if (actual !== envelope.checksum) {
    throw new SnapshotError(`snapshot '${key}' failed integrity check (${envelope.checksum} != ${actual})`);
  }
  const state = migrate(envelope.state);
  return restoreState(state, opts);
}

// -------------------------------------------------------------- migrate

const MIGRATIONS = {
  0: (s) => {
    // v0 -> v1: environment gained wetness/dust/wind/flash/fog fields
    const env = s.world?.environment ?? {};
    return {
      ...s,
      schemaVersion: 1,
      world: {
        ...s.world,
        environment: {
          weather: 'clear', targetRain: 0, targetWind: 0.2, rain: 0, wetness: 0,
          dryness: 0.2, wind: 0.2, dust: 0, storm: false, flash: 0, fog: 0.12,
          sunDir: [0.5, 0.8, 0.3], sunColor: [1, 0.95, 0.8], ambient: 1,
          skyTop: [0.2, 0.4, 0.8], skyBottom: [0.7, 0.8, 0.9],
          lastWeatherEventId: null,
          ...env,
        },
      },
    };
  },
};

export function migrate(state) {
  let v = state?.schemaVersion ?? 0;
  if (v > SCHEMA_VERSION) {
    throw new SnapshotError(`snapshot schema ${v} is newer than engine ${SCHEMA_VERSION}`);
  }
  let cur = state;
  while (v < SCHEMA_VERSION) {
    const step = MIGRATIONS[v];
    if (!step) throw new SnapshotError(`no migration path from schema ${v}`);
    cur = step(cur);
    v = cur.schemaVersion ?? v + 1;
  }
  return cur;
}

// --------------------------------------------------------------- restore

export function restoreState(state, opts = {}) {
  if (state.rrw.processKinds) {
    const reg = processTypeRegistry();
    for (const kind of state.rrw.processKinds) {
      if (!reg.has(kind)) {
        throw new SnapshotError(`process type '${kind}' has no registered implementation`);
      }
    }
  }
  const bus = opts.bus ?? null;
  const tese = new TeseDosD();
  tese.restore(state.tese ?? { layers: [] });
  const rng = RNG.fromState(state.rng);
  const clock = new Clock();
  clock.restore(state.clock);

  const do15 = new DO15({ tese });
  do15.restore(state.do15 ?? {});
  const perf = opts.perf ?? null;

  const rrw = RRW.restore(state.rrw, { rng, bus, tese, processTypes: processTypeRegistry() });
  const world = new World({ rrw, rng, clock, tese, do15, seed: state.world.seed, bus, genesisSeed: false });
  world.environment = structuredClone(state.world.environment);
  world.settlementMaterialCap = state.world.settlementMaterialCap ?? 12;
  if (state.world.phenomena) world.phenomenaRestore(state.world.phenomena); // older saves migrate honestly (fresh phenomena)

  const ues = new UES({ world, perf, tese, do15, schedulerBudgetMs: state.ues.schedulerBudgetMs ?? 0 });
  ues.camera = structuredClone(state.ues.camera);
  ues.tickN = state.ues.tickN ?? 0;
  world.ues = ues; // o mundo restaurado foca os fenômenos onde o OBSERVADOR está (simetria com o original)

  const core = buildSingularity({ ues, world, rrw, memory: null });
  if (state.singularity?.memory) core.memory.restore(state.singularity.memory);

  // rebuild the DERIVED spatial index from the source of truth (RRW).
  // Membership matches the live rule: mobile/interactable things are indexed;
  // settlements are stationary aggregates reached by id, not by grid queries.
  const entries = [];
  for (const e of rrw.entities.values()) {
    const sp = e.components.get('spatial');
    if (sp && e.kind !== 'settlement') entries.push([e.id, sp.pos[0], sp.pos[2]]);
  }
  world.grid.rebuild(entries);
  // physics bodies + joints are RRW state: rebuild the derived solver caches
  world.physics.reattach();

  return { rng, clock, bus, tese, do15, perf, rrw, world, ues, core, version: ENGINE_VERSION };
}

// clock is imported directly (no cycle: core/clock imports nothing from here)
import { Clock } from '../core/clock.js';
