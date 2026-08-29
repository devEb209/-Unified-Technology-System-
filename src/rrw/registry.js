// UTS :: rrw — Reality Representation Weave (RRW).
//
// RRW is the open, extensible, multilevel representation of the computational
// reality. It is NOT a closed list of game objects: entities, properties,
// relations, events, causal chains, processes, aggregates — and any future
// category — live here without rewriting the core.
//
// Invariants:
//   * RRW is the single source of truth. Indices (spatial grid, GPU buffers)
//     are derived and must be rebuildable from RRW alone.
//   * Causality is verified by construction: an event may only cite an
//     existing event as its cause.
//   * Abstraction (material -> abstract) NEVER erases semantic state.
//     D-14 governs the transitions; state travels with the entity.

export const MATERIALIZATION = Object.freeze({
  ABSTRACT: 'abstract',
  PARTIAL: 'partial',
  FULL: 'full',
});

export class RRWError extends Error {}
export class CausalityError extends RRWError {}
export class SnapshotError extends RRWError {}

const MAX_MAT_HISTORY = 8;

export class RRW {
  constructor({ rng = null, bus = null, eventCap = 20000, tese = null } = {}) {
    this.rng = rng;
    this.bus = bus;
    this.tese = tese;
    this.eventCap = eventCap;

    /** @type {Map<string, entity>} id -> entity record (plain data) */
    this.entities = new Map();
    /** @type {Map<string, relation>} */
    this.relations = new Map();
    /** @type {Map<string, event>} */
    this.events = new Map();
    this.eventOrder = [];
    /** @type {Map<string, process>} */
    this.processes = new Map();
    /** process kind -> { evolveAbstract, evolveDetailed, describe } — code-defined, open registry */
    this.processTypes = new Map();

    this.byKind = new Map();
    this.nextEntityId = 1;
    this.nextRelationId = 1;
    this.nextEventId = 1;
    this.nextProcessId = 1;

    this.stats = { created: 0, destroyed: 0, materialized: 0, abstracted: 0, events: 0 };
  }

  // ---------------------------------------------------------------- entities

  createEntity({
    kind = 'entity',
    materialization = MATERIALIZATION.ABSTRACT,
    importance = 0,
    tags = [],
    components = {},
    pos = null,
    name = null,
  } = {}) {
    const id = 'e' + this.nextEntityId++;
    const entity = {
      id,
      kind,
      name,
      tags: new Set(tags),
      materialization,
      importance,
      alive: true,
      components: new Map(),
      relations: new Set(),
      matHistory: [],
      bornTick: null,
    };
    if (pos) components.spatial = { pos: [pos[0], pos[1] ?? 0, pos[2]] };
    for (const [type, data] of Object.entries(components)) entity.components.set(type, structuredClone(data));
    this.entities.set(id, entity);
    if (!this.byKind.has(kind)) this.byKind.set(kind, new Set());
    this.byKind.get(kind).add(id);
    this.stats.created++;
    this.tese?.touch('D-0', `entity ${id} (${kind})`);
    this.bus?.emit('rrw.entity.created', { id, kind });
    return entity;
  }

  get(id) { return this.entities.get(id) ?? null; }
  require(id) {
    const e = this.entities.get(id);
    if (!e) throw new RRWError(`entity not found: ${id}`);
    return e;
  }

  destroy(id) {
    const e = this.require(id);
    e.alive = false;
    for (const relId of e.relations) this.relations.delete(relId);
    this.byKind.get(e.kind)?.delete(id);
    this.entities.delete(id);
    this.stats.destroyed++;
    this.bus?.emit('rrw.entity.destroyed', { id });
  }

  addComponent(id, type, data) {
    const e = this.require(id);
    e.components.set(type, structuredClone(data));
    return e.components.get(type);
  }

  getComponent(id, type) {
    return this.entities.get(id)?.components.get(type) ?? null;
  }

  hasComponent(id, type) {
    return this.entities.get(id)?.components.has(type) ?? false;
  }

  removeComponent(id, type) {
    this.require(id).components.delete(type);
  }

  /** merge patch into a component (plain data only) */
  patchComponent(id, type, patch, tick = null) {
    if (patch && typeof patch === 'object' && tick != null) patch.__v = tick; // per-entity delta stamp
    const c = this.getComponent(id, type);
    if (!c) throw new RRWError(`component ${type} missing on ${id}`);
    deepPatch(c, patch);
    return c;
  }

  setSpatial(id, pos) {
    const e = this.require(id);
    let sp = e.components.get('spatial');
    if (!sp) { sp = { pos: [0, 0, 0], yaw: 0 }; e.components.set('spatial', sp); }
    sp.pos = [pos[0], pos[1] ?? 0, pos[2] ?? 0];
    return sp;
  }

  /**
   * PER-ENTITY DELTAS: components stamped with a tick (__v) can be shipped
   * after a full snapshot — streaming only what CHANGED (D-O15: transfer
   * less, represent everything).
   */
  deltaSince(tick, { quantize = 0 } = {}) {
    const q = (v) => (quantize > 0 && typeof v === 'number' ? Math.round(v / quantize) * quantize : v);
    const out = [];
    for (const e of this.entities.values()) {
      const comps = {};
      let any = false;
      for (const [type, c] of e.components) {
        if (!(c && typeof c === 'object' && c.__v != null && c.__v > tick)) continue;
        let cc = c;
        if (quantize > 0) {
          cc = {};
          for (const [f2, v] of Object.entries(c)) {
            cc[f2] = Array.isArray(v) ? v.map(q) : q(v);
          }
        }
        comps[type] = cc; any = true;
      }
      if (any) out.push({ id: e.id, kind: e.kind, comps });
    }
    return out;
  }

  applyDelta(deltas) {
    let applied = 0;
    for (const d of deltas ?? []) {
      const e = this.entities.get(d.id);
      if (!e) continue; // honest: a delta never invents entities
      for (const [type, c] of Object.entries(d.comps)) {
        const clean = { ...c }; delete clean.__v;
        this.patchComponent(d.id, type, clean, null);
        Object.assign(e.components.get(type), c); // keep the stamp
        applied++;
      }
    }
    return applied;
  }

  // --------------------------------------------------------------- relations

  addRelation(a, b, type, { weight = 0, data = {} } = {}) {
    this.require(a); this.require(b);
    for (const relId of this.get(a).relations) {
      const r = this.relations.get(relId);
      if (r && r.a === a && r.b === b && r.type === type) {
        r.weight = weight;
        r.data = data;
        return r;
      }
    }
    const rel = { id: 'r' + this.nextRelationId++, a, b, type, weight, data };
    this.relations.set(rel.id, rel);
    this.get(a).relations.add(rel.id);
    this.get(b).relations.add(rel.id);
    this.tese?.touch('D-1', `relation ${a}-${b}:${type}`);
    return rel;
  }

  getRelation(a, b, type) {
    for (const relId of this.get(a)?.relations ?? []) {
      const r = this.relations.get(relId);
      if (r && r.a === a && r.b === b && r.type === type) return r;
    }
    return null;
  }

  getRelations(id, { type = null, direction = 'both' } = {}) {
    const out = [];
    for (const relId of this.get(id)?.relations ?? []) {
      const r = this.relations.get(relId);
      if (!r) continue;
      if (type && r.type !== type) continue;
      if (direction === 'out' && r.a !== id) continue;
      if (direction === 'in' && r.b !== id) continue;
      out.push(r);
    }
    return out;
  }

  removeRelation(relId) {
    const r = this.relations.get(relId);
    if (!r) return;
    this.get(r.a)?.relations.delete(relId);
    this.get(r.b)?.relations.delete(relId);
    this.relations.delete(relId);
  }

  // ------------------------------------------------------------------ events

  /**
   * Emit an event into the verified causal log.
   * `cause` MUST be an existing event id (or null for exogenous events).
   * Fabricating causes (referencing events that never happened) throws.
   */
  emitEvent({ type, subject = null, cause = null, data = {}, tick = null }) {
    if (cause !== null && !this.events.has(cause)) {
      throw new CausalityError(`event ${type} cites cause ${cause} which never happened`);
    }
    const id = 'ev' + this.nextEventId++;
    const ev = { id, type, subject, cause, data, tick };
    this.events.set(id, ev);
    this.eventOrder.push(id);
    this.stats.events++;
    if (this.eventOrder.length > this.eventCap) {
      const pruned = this.eventOrder.splice(0, this.eventOrder.length - this.eventCap);
      for (const p of pruned) this.events.delete(p);
    }
    this.tese?.touch('D-2', `${type} <- ${cause ?? 'exogenous'}`);
    this.bus?.emit(type, ev);
    return id;
  }

  getEvent(id) { return this.events.get(id) ?? null; }

  /** walk the causal chain from an event up to its roots */
  causalityChain(id) {
    const chain = [];
    let cur = this.events.get(id) ?? null;
    const seen = new Set();
    while (cur && !seen.has(cur.id)) {
      seen.add(cur.id);
      chain.push(cur);
      cur = cur.cause != null ? this.events.get(cur.cause) ?? null : null;
    }
    return chain;
  }

  /** verify that an event's full causal chain is intact and resolvable */
  verifyCausalChain(id) {
    let cur = this.events.get(id);
    if (!cur) return { valid: false, reason: 'unknown-event', depth: 0 };
    let depth = 0;
    while (cur.cause != null) {
      depth++;
      const next = this.events.get(cur.cause);
      if (!next) return { valid: false, reason: 'broken-or-pruned-at', depth, at: cur.cause };
      cur = next;
    }
    return { valid: true, reason: 'root', depth };
  }

  // --------------------------------------------------------------- processes

  /** register a process kind — open extension point (code-defined behavior, serializable state) */
  registerProcessType(kind, def) {
    if (typeof def.evolveAbstract !== 'function' || typeof def.evolveDetailed !== 'function') {
      throw new RRWError(`process type ${kind} needs evolveAbstract and evolveDetailed`);
    }
    this.processTypes.set(kind, def);
  }

  createProcess(kind, { state = {}, attachedTo = null, level = 'abstract', tick = null } = {}) {
    if (!this.processTypes.has(kind)) throw new RRWError(`unknown process type: ${kind}`);
    const proc = { id: 'p' + this.nextProcessId++, kind, level, attachedTo, state, lastTick: tick };
    this.processes.set(proc.id, proc);
    return proc;
  }

  evolveProcess(id, dt, ctx) {
    const proc = this.processes.get(id);
    if (!proc) throw new RRWError(`unknown process: ${id}`);
    const def = this.processTypes.get(proc.kind);
    if (!def) return proc;
    if (proc.level === 'detailed') def.evolveDetailed(proc.state, dt, ctx, proc);
    else def.evolveAbstract(proc.state, dt, ctx, proc);
    proc.lastTick = ctx.tick ?? proc.lastTick;
    return proc;
  }

  evolveProcesses(dt, ctx) {
    for (const proc of [...this.processes.values()]) this.evolveProcess(proc.id, dt, ctx);
  }

  // ---------------------------------------------------- materialization (D-14)

  setMaterialization(id, level, { reason = '', tick = null } = {}) {
    const e = this.require(id);
    if (e.materialization === level) return e.materialization;
    const from = e.materialization;
    e.materialization = level;
    e.matHistory.push({ tick, from, to: level, reason });
    if (e.matHistory.length > MAX_MAT_HISTORY) e.matHistory.shift();
    if (level === MATERIALIZATION.ABSTRACT) this.stats.abstracted++;
    if (level === MATERIALIZATION.FULL) this.stats.materialized++;
    this.tese?.touch('D-14', `${id}: ${from} -> ${level} (${reason})`);
    this.bus?.emit('rrw.materialization.changed', { id, from, to: level, reason });
    return level;
  }

  // ------------------------------------------------------------------ queries

  query({ kind = null, materialization = null, hasComponent = null, tag = null, aliveOnly = true, predicate = null, limit = Infinity } = {}) {
    const out = [];
    const source = kind ? (this.byKind.get(kind) ?? []) : this.entities.keys();
    for (const id of source) {
      const e = this.entities.get(id);
      if (!e) continue;
      if (aliveOnly && !e.alive) continue;
      if (materialization && e.materialization !== materialization) continue;
      if (hasComponent && !e.components.has(hasComponent)) continue;
      if (tag && !e.tags.has(tag)) continue;
      if (predicate && !predicate(e)) continue;
      out.push(id);
      if (out.length >= limit) break;
    }
    return out;
  }

  count(kind) {
    return kind ? (this.byKind.get(kind)?.size ?? 0) : this.entities.size;
  }

  // ---------------------------------------------------------------- snapshot

  snapshot() {
    return {
      counters: {
        entity: this.nextEntityId, relation: this.nextRelationId,
        event: this.nextEventId, process: this.nextProcessId,
      },
      stats: { ...this.stats },
      entities: [...this.entities.values()].map(e => ({
        id: e.id, kind: e.kind, name: e.name, tags: [...e.tags],
        materialization: e.materialization, importance: e.importance,
        alive: e.alive, bornTick: e.bornTick,
        components: [...e.components.entries()],
        relations: [...e.relations],
        matHistory: e.matHistory,
      })),
      relations: [...this.relations.values()],
      events: [...this.events.values()],
      eventOrder: [...this.eventOrder],
      processes: [...this.processes.values()],
      processKinds: [...this.processTypes.keys()],
    };
  }

  static restore(data, deps = {}) {
    assertShape(data, ['counters', 'entities', 'relations', 'events', 'processes'], 'rrw');
    const rrw = new RRW(deps);
    for (const kind of data.processKinds ?? []) {
      // implementations must be (re)registered by the persistence layer before restore;
      // when a registry Map is provided it is (re)registered; raw roundtrips skip the check.
      if (deps.processTypes?.has?.(kind)) {
        rrw.registerProcessType(kind, deps.processTypes.get(kind));
      }
    }
    for (const ed of data.entities) {
      const e = {
        id: ed.id, kind: ed.kind, name: ed.name ?? null,
        tags: new Set(ed.tags), materialization: ed.materialization,
        importance: ed.importance, alive: ed.alive,
        components: new Map(ed.components), relations: new Set(ed.relations),
        matHistory: ed.matHistory ?? [], bornTick: ed.bornTick ?? null,
      };
      rrw.entities.set(e.id, e);
      if (!rrw.byKind.has(e.kind)) rrw.byKind.set(e.kind, new Set());
      rrw.byKind.get(e.kind).add(e.id);
      rrw.nextEntityId = Math.max(rrw.nextEntityId, num(e.id) + 1);
    }
    for (const r of data.relations) {
      if (!rrw.entities.has(r.a) || !rrw.entities.has(r.b)) {
        throw new SnapshotError(`relation ${r.id} references missing entity`);
      }
      rrw.relations.set(r.id, r);
      rrw.nextRelationId = Math.max(rrw.nextRelationId, num(r.id) + 1);
    }
    for (const ev of data.events) {
      if (ev.cause !== null && !data.events.some(x => x.id === ev.cause)) {
        throw new SnapshotError(`event ${ev.id} cites cause ${ev.cause} missing from snapshot`);
      }
      rrw.events.set(ev.id, ev);
      rrw.nextEventId = Math.max(rrw.nextEventId, num(ev.id) + 1);
    }
    rrw.eventOrder = data.eventOrder ?? data.events.map(e => e.id);
    for (const p of data.processes) {
      rrw.processes.set(p.id, p);
      rrw.nextProcessId = Math.max(rrw.nextProcessId, num(p.id) + 1);
    }
    Object.assign(rrw, rrw.countersFrom(data));
    rrw.stats = { ...rrw.stats, ...data.stats };
    return rrw;
  }

  countersFrom(data) {
    return {
      nextEntityId: Math.max(this.nextEntityId, data.counters.entity),
      nextRelationId: Math.max(this.nextRelationId, data.counters.relation),
      nextEventId: Math.max(this.nextEventId, data.counters.event),
      nextProcessId: Math.max(this.nextProcessId, data.counters.process),
    };
  }
}

function num(id) {
  const m = String(id).match(/(\d+)$/);
  return m ? parseInt(m[1], 10) : 0;
}

function deepPatch(target, patch) {
  for (const [k, v] of Object.entries(patch)) {
    if (v && typeof v === 'object' && !Array.isArray(v) && target[k] && typeof target[k] === 'object' && !Array.isArray(target[k])) {
      deepPatch(target[k], v);
    } else {
      target[k] = v;
    }
  }
}

function assertShape(obj, keys, label) {
  if (!obj || typeof obj !== 'object') throw new SnapshotError(`${label}: snapshot is not an object`);
  for (const k of keys) {
    if (!(k in obj)) throw new SnapshotError(`${label}: missing field '${k}'`);
  }
}
