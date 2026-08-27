/**
 * UES · Persistência — save/load do estado COMPLETO da simulação.
 *
 * O que é preservado:
 *  - RRW completo (entidades, componentes, estado comprimido, relações,
 *    eventos → causalidade, processos → alvos e estados, contadores);
 *  - mundo (chunks com heightfield, focus, raio de materialização, zonas);
 *  - relógio, RNG (estado exato → determinismo), hardware;
 *  - sociedade (cooldowns), agendamento D-O15 (nextDue/hz), ciclo de decisão;
 *  - memória da IA (opcional).
 *
 * Determinismo: mesma configuração + mesmo snapshot → evolução idêntica.
 * (IDs são únicos por runtime; em comparações entre runs independentes,
 *  use `normalizeUes` que mapeia IDs por ordem de inserção.)
 */

import type { MemorySystem } from '../ai/memory.ts';
import { Rng } from '../core/index.ts';
import type { HardwareProfile } from '../d-o15/index.ts';
import type { RrwSerialized } from '../rrw/index.ts';
import { createUes, type Engine, type EngineConfig } from './engine.ts';

export interface UesSnapshot {
  v: 1;
  seed: number;
  worldCfg: Record<string, unknown>;
  time: number;
  rngState: number;
  focus: { x: number; y: number };
  focusRadius: { active: number; outer: number };
  hardware: HardwareProfile;
  rrw: RrwSerialized;
  chunks: Array<{ x: number; y: number; loaded: boolean; moisture: number; dominantBiome: string; state: Record<string, unknown>; height: number[] | null }>;
  biomeZones: Array<{ biome: string; x: number; y: number; radius: number }>;
  society: { famineCooldown: Array<[string, number]> };
  schedule: Record<string, { nextDue: number; hz: number }>;
  lastDecide: number;
  graphics: { frame: number };
  memory?: unknown;
}

export function serializeUes(engine: Engine, memory?: MemorySystem): UesSnapshot {
  const w = engine.world;
  return {
    v: 1,
    seed: w.cfg.seed,
    worldCfg: { ...w.cfg },
    time: engine.rrw.time,
    rngState: engine.rng.state(),
    focus: { ...w.focus },
    focusRadius: { ...w.focusRadius },
    hardware: { ...engine.hardware },
    rrw: engine.rrw.serialize(),
    chunks: [...w.chunks.values()].map((c) => ({
      x: c.x,
      y: c.y,
      loaded: c.loaded,
      moisture: c.moisture,
      dominantBiome: c.dominantBiome,
      state: { ...c.state },
      height: c.height ? Array.from(c.height) : null,
    })),
    biomeZones: w.biomeZones.map((z) => ({ ...z })),
    society: { famineCooldown: [...engine.society.famineCooldown.entries()] },
    schedule: engine.scheduler.scheduleState(),
    lastDecide: engine.lastDecide,
    graphics: { frame: engine.graphics.frameCounter },
    memory: memory ? memory.serialize() : undefined,
  };
}

export function restoreUes(cfg: EngineConfig, snap: UesSnapshot, memory?: MemorySystem): Engine {
  const e = createUes({
    seed: snap.seed,
    world: { ...(snap.worldCfg as object) },
    hardware: snap.hardware,
    backend: cfg.backend,
    log: cfg.log,
  });
  const w = e.world;
  // 1) RRW completo (entidades + causalidade + processos)
  e.rrw.restore(snap.rrw);
  // 2) referências do mundo
  const env = e.rrw.query({ categories: ['phenomenon/environment'] })[0];
  if (!env) throw new Error('persistence: entidade de ambiente não encontrada no snapshot');
  w.env = env;
  w.chunks.clear();
  for (const c of snap.chunks) {
    w.chunkAt(c.x, c.y);
    const chunk = w.chunkAt(c.x, c.y);
    chunk.loaded = c.loaded;
    chunk.moisture = c.moisture;
    chunk.dominantBiome = c.dominantBiome;
    chunk.state = { ...c.state };
    chunk.height = c.height ? Float32Array.from(c.height) : null;
  }
  w.focus = { ...snap.focus };
  w.setFocusRadius(snap.focusRadius.active, snap.focusRadius.outer);
  w.biomeZones = snap.biomeZones.map((z) => ({ ...z }));
  // 3) tempo + RNG exato (determinismo)
  e.rrw.time = snap.time;
  e.clock.time = snap.time;
  const rng = Rng.fromState(snap.rngState);
  e.rng = rng;
  w.rng = rng;
  // 4) sociedade + D-O15 (agendamento e ciclo de decisão)
  e.society.famineCooldown = new Map(snap.society.famineCooldown);
  e.scheduler.restoreScheduleState(snap.schedule);
  e.lastDecide = snap.lastDecide;
  e.hardware = snap.hardware;
  e.strategy.setHardware(snap.hardware);
  // 5) gráficos (contador de frames)
  e.graphics.frameCounter = snap.graphics.frame;
  // 6) wrappers NMN em volta das entidades restauradas
  e.adoptNpcs();
  // 7) memória da IA (opcional)
  if (memory && snap.memory) memory.load(snap.memory as never);
  return e;
}

/* ---------------- conveniência JSON ---------------- */

export function saveUes(engine: Engine, memory?: MemorySystem): string {
  return JSON.stringify(serializeUes(engine, memory));
}

export function restoreFromJson(cfg: EngineConfig, json: string, memory?: MemorySystem): Engine {
  return restoreUes(cfg, JSON.parse(json) as UesSnapshot, memory);
}

/* ---------------- comparação entre runs independentes ---------------- */

/**
 * Normaliza um snapshot mapeando IDs → índice de inserção (runs
 * independentes geram IDs diferentes para a mesma entidade).
 * Snapshots normalizados de runs determinísticos devem ser idênticos.
 */
export function normalizeUes(snap: UesSnapshot): Record<string, unknown> {
  const idMap = new Map<string, number>();
  snap.rrw.entities.forEach((e, i) => idMap.set(e.id, i));
  const mapId = (id: string | null | undefined): unknown => (id === null || id === undefined ? id : (idMap.get(id) ?? -1));
  // re-mapeia IDs embutidos em QUALQUER valor (conhecimento, data, etc.)
  const remap = (v: unknown): unknown => {
    if (typeof v === 'string') return idMap.has(v) ? (idMap.get(v) as number) : v;
    if (Array.isArray(v)) return v.map(remap);
    if (v && typeof v === 'object') {
      const out: Record<string, unknown> = {};
      for (const [k, x] of Object.entries(v)) out[k] = remap(x);
      return out;
    }
    return v;
  };
  const r = snap.rrw;
  return {
    time: snap.time,
    rngState: snap.rngState,
    focus: snap.focus,
    focusRadius: snap.focusRadius,
    entities: r.entities.map((e) => ({
      name: e.name,
      categories: e.categories,
      data: remap(e.data),
      contextId: mapId(e.contextId),
      detail: e.detail,
      state: e.state,
      alive: e.alive,
      components: e.components.map(([k, v]) => [k, remap(v)]),
      compressed: e.compressed ? e.compressed.map(([k, v]) => [k, remap(v)]) : null,
      spawnedBy: e.spawnedBy ? mapId(e.spawnedBy.by) : null,
    })),
    relations: r.relations.map((rel) => ({ from: mapId(rel.from), to: mapId(rel.to), type: rel.type, weight: rel.weight, causal: rel.causal, data: remap(rel.data) })),
    eventLog: r.eventLog.map((ev) => ({ type: ev.type, at: ev.at, entities: ev.entities.map((x) => mapId(x)), data: remap(ev.data), cause: ev.cause ? { by: mapId(ev.cause.by), event: ev.cause.event } : null })),
    entEvents: r.entEvents.map(([id, list]) => [mapId(id), list.map((e) => e.type)]),
    processTargets: r.processTargets.map(([n, ids]) => [n, ids.map((x) => mapId(x))]),
    nextSeq: r.nextSeq,
    eventCounters: r.eventCounters,
    chunks: snap.chunks.map((c) => ({ x: c.x, y: c.y, loaded: c.loaded, height: c.height })),
    society: { famineKeys: snap.society.famineCooldown.map(([k]) => mapId(k)).sort() as unknown },
  };
}

export function canonicalJson(v: unknown): string {
  const sort = (x: unknown): unknown => {
    if (Array.isArray(x)) return x.map(sort);
    if (x && typeof x === 'object' && !(x instanceof Map) && !(x instanceof Set) && !(x instanceof Float32Array)) {
      const out: Record<string, unknown> = {};
      for (const k of Object.keys(x as object).sort()) out[k] = sort((x as Record<string, unknown>)[k]);
      return out;
    }
    if (x instanceof Float32Array) return Array.from(x);
    return x;
  };
  return JSON.stringify(sort(v));
}
