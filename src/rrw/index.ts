/**
 * UTS · RRW — fundação de representação da realidade.
 *
 * Regra central (versão mais recente das decisões):
 *   «RRW deve abranger TUDO DA REALIDADE.»
 *
 * Isso é implementado como ABERTURA, não como lista:
 *  - categorias abertas (qualquer aspecto da realidade pode ser registrado em runtime);
 *  - componentes abertos (estrutura + comportamento + custo de materialização);
 *  - tipos de relação abertos;
 *  - tipos de evento abertos (com causalidade explícita: causa → efeito → contexto);
 *  - processos abertos (estados + tick full-fidelity + tick abstrato);
 *  - contexto/scope (o mundo é organizado, não um lago de entidades);
 *  - materialização contínua 0..1 com PRESERVAÇÃO DE ESTADO na abstração.
 *
 * RRW NÃO é uma biblioteca de assets: a representação visual é apenas uma
 * manifestação possível (a UES/graphics interpreta o estado RRW — ver ues/graphics).
 */

import { EventBus, Logger, Rng, newId } from '../core/index.ts';

/* ------------------------------------------------------------------ */
/* Tipos                                                               */
/* ------------------------------------------------------------------ */

export type EntityState = 'abstract' | 'material' | 'transient';

export interface RrwEntity {
  id: string;
  name: string | null;
  categories: string[]; // categorias (hierárquicas: 'a/b')
  components: Map<string, unknown>;
  data: Record<string, unknown>; // estado semântico aberto
  contextId: string | null;
  parentId: string | null;
  /** Nível de materialização: 0 = abstrato puro, 1 = totalmente materializado. */
  detail: number;
  state: EntityState;
  createdAt: number;
  alive: boolean;
  /** Snapshot comprimido de componentes preservado ao abstraizar (estado nunca é apagado). */
  compressed: Map<string, unknown> | null;
  /** Causa da criação (causalidade de origem). */
  spawnedBy: { by: string; event?: string; description?: string } | null;
}

export interface Relation {
  id: string;
  from: string;
  to: string;
  type: string;
  weight: number;
  causal: boolean;
  data: Record<string, unknown>;
  since: number; // sim-time
  until: number | null;
}

export interface RrwEvent {
  id: string;
  type: string;
  at: number;
  entities: string[];
  data: Record<string, unknown>;
  cause: { by: string; event?: string; description?: string } | null;
}

export interface ComponentDef {
  name: string;
  init?: (ent: RrwEntity, args?: Record<string, unknown>) => unknown;
  /** Comprime o valor ao abstraizar (estado preservado de forma barata). */
  compress?: (value: unknown) => unknown;
  /** Restaura ao materializar. */
  restore?: (ent: RrwEntity, snap: unknown) => unknown;
  /** Custo relativo de manter materializado (alimenta D-O15). */
  cost?: number;
}

export type ProcessCtx = {
  dt: number;
  time: number;
  rng: Rng;
  rrw: RRW;
  [key: string]: unknown;
};

export interface ProcessDef {
  name: string;
  /** Estado inicial por entidade. */
  init?: (ent: RrwEntity, ctx: ProcessCtx) => string;
  /** Estado atual de uma entidade sob este processo. */
  stateOf?: (ent: RrwEntity) => string;
  /** Entrada em estado (transição). */
  enter?: (ent: RrwEntity, state: string, ctx: ProcessCtx) => void;
  /** Tick em entidades MATERIALIZADAS (fidelidade alta). */
  tick?: (ent: RrwEntity, state: string, ctx: ProcessCtx) => void;
  /** Tick em entidades ABSTRATAS (evolução agregada barata — mundo vivo fora do foco). */
  abstractTick?: (ent: RrwEntity, state: string, ctx: ProcessCtx) => void;
  /** Cobre entidades de um contexto (scope) em vez de lista fixa. */
  contextScope?: string | null;
}

export interface RrwQuery {
  categories?: string[]; // qualquer-uma das categorias (com herança hierárquica)
  allCategories?: string[]; // todas
  has?: string[]; // componentes presentes
  data?: Record<string, unknown>; // igualdade de primitivos
  contextId?: string;
  detailMin?: number;
  detailMax?: number;
  alive?: boolean;
  state?: EntityState;
  limit?: number;
}

export const MATERIAL_THRESHOLD = 0.5;
const EVENT_RING = 256;

/* ------------------------------------------------------------------ */
/* RRW                                                                 */
/* ------------------------------------------------------------------ */

export class RRW {
  readonly rrw = this;
  entities = new Map<string, RrwEntity>();
  relations: Relation[] = [];
  private relIndex = new Map<string, Relation[]>(); // from|to -> relations
  private categories = new Set<string>();
  private relationTypes = new Set<string>();
  private eventTypes = new Set<string>();
  private components = new Map<string, ComponentDef>();
  private processes = new Map<string, ProcessDef>();
  private processTargets = new Map<string, Set<string>>();
  private processState = new Map<string, Map<string, string>>(); // proc -> ent -> state
  private eventLog: RrwEvent[] = [];
  private entEvents = new Map<string, RrwEvent[]>();
  private eventCounters: Record<string, number> = {};
  private nextSeq = 0;

  bus = new EventBus();
  log: Logger;
  /** Relógio de simulação (segundos) — setado pelo engine. */
  time = 0;

  constructor(opts: { log?: Logger; seedRng?: Rng } = {}) {
    this.log = (opts.log ?? new Logger('rrw')).child('rrw');
    // Categorias de base — exemplos, NÃO um limite (regra de abertura).
    for (const c of ['world', 'terrain', 'entity', 'organism', 'structure', 'phenomenon', 'information', 'society']) {
      this.defineCategory(c);
    }
  }

  /* ---------------- categorias (abertas) ---------------- */

  defineCategory(name: string): void {
    if (!name || name.includes('//') || name.startsWith('/') || name.endsWith('/')) {
      throw new Error(`RRW: categoria inválida: ${name}`);
    }
    const parts = name.split('/');
    let acc = '';
    for (const p of parts) {
      acc = acc ? `${acc}/${p}` : p;
      this.categories.add(acc);
    }
  }

  categoryNames(): string[] {
    return [...this.categories].sort();
  }

  hasCategory(id: string, cat: string): boolean {
    const ent = this.entities.get(id);
    if (!ent) return false;
    for (const c of ent.categories) {
      if (c === cat) return true;
      if (cat.endsWith('/') && c.startsWith(cat)) return true; // 'biome' cobre 'biome/desert'
      // herança: entidade com 'organism/human' pertence a 'organism'
      const idx = c.indexOf('/');
      if (idx > 0 && c.slice(0, idx) === cat) return true;
    }
    return false;
  }

  /* ---------------- entidades ---------------- */

  create(opts: {
    name?: string | null;
    categories?: string[];
    data?: Record<string, unknown>;
    components?: Record<string, Record<string, unknown>>;
    contextId?: string | null;
    parentId?: string | null;
    detail?: number;
    spawnedBy?: { by: string; event?: string; description?: string } | null;
  } = {}): RrwEntity {
    for (const c of opts.categories ?? []) this.defineCategory(c);
    if (opts.contextId && !this.entities.has(opts.contextId)) {
      throw new Error(`RRW: contextId desconhecida: ${opts.contextId}`);
    }
    const id = newId('ent');
    const ent: RrwEntity = {
      id,
      name: opts.name ?? null,
      categories: [...(opts.categories ?? [])],
      components: new Map(),
      data: { ...(opts.data ?? {}) },
      contextId: opts.contextId ?? null,
      parentId: opts.parentId ?? null,
      detail: opts.detail ?? 0,
      state: (opts.detail ?? 0) >= MATERIAL_THRESHOLD ? 'material' : 'abstract',
      createdAt: this.time,
      alive: true,
      compressed: null,
      spawnedBy: opts.spawnedBy ?? null,
    };
    this.entities.set(id, ent);
    for (const [name, args] of Object.entries(opts.components ?? {})) {
      this.component(id, name, args);
    }
    this.emit('rrw.entity.created', [id], { name: ent.name }, { by: opts.spawnedBy?.by ?? id, description: 'entity created' });
    return ent;
  }

  get(id: string): RrwEntity | undefined {
    return this.entities.get(id);
  }

  require(id: string): RrwEntity {
    const e = this.entities.get(id);
    if (!e) throw new Error(`RRW: entidade inexistente: ${id}`);
    return e;
  }

  query(q: RrwQuery = {}): RrwEntity[] {
    const out: RrwEntity[] = [];
    for (const ent of this.entities.values()) {
      if (!ent.alive) continue;
      if (q.alive === false) continue;
      if (q.categories && !q.categories.some((c) => this.hasCategory(ent.id, c))) continue;
      if (q.allCategories && !q.allCategories.every((c) => this.hasCategory(ent.id, c))) continue;
      if (q.has && !q.has.every((c) => ent.components.has(c))) continue;
      if (q.data) {
        let ok = true;
        for (const [k, v] of Object.entries(q.data)) {
          if (ent.data[k] !== v) {
            ok = false;
            break;
          }
        }
        if (!ok) continue;
      }
      if (q.contextId !== undefined && ent.contextId !== q.contextId) continue;
      if (q.detailMin !== undefined && ent.detail < q.detailMin) continue;
      if (q.detailMax !== undefined && ent.detail > q.detailMax) continue;
      if (q.state && ent.state !== q.state) continue;
      out.push(ent);
      if (q.limit && out.length >= q.limit) break;
    }
    return out;
  }

  destroy(id: string, reason?: string): void {
    const ent = this.entities.get(id);
    if (!ent || !ent.alive) return;
    ent.alive = false;
    ent.detail = 0;
    ent.state = 'abstract';
    this.relations = this.relations.filter((r) => {
      if (r.from === id || r.to === id) return false;
      return true;
    });
    this.rebuildRelIndex();
    this.emit('rrw.entity.destroyed', [id], { reason: reason ?? null });
  }

  /* ---------------- componentes (abertos) ---------------- */

  defineComponent(name: string, def: ComponentDef): void {
    if (this.components.has(name)) {
      throw new Error(`RRW: componente já definido: ${name}`);
    }
    this.components.set(name, { name, ...def });
  }

  componentNames(): string[] {
    return [...this.components.keys()].sort();
  }

  component(id: string, name: string, args?: Record<string, unknown>): unknown {
    const ent = this.require(id);
    if (ent.components.has(name)) return ent.components.get(name);
    const def = this.components.get(name);
    if (!def) throw new Error(`RRW: componente não definido: ${name}`);
    const value = def.init ? def.init(ent, args ?? {}) : { ...(args ?? {}) };
    ent.components.set(name, value);
    return value;
  }

  componentValue(id: string, name: string): unknown {
    const ent = this.entities.get(id);
    return ent?.components.get(name);
  }

  removeComponent(id: string, name: string): void {
    this.require(id).components.delete(name);
  }

  /** Custo estimado de manter a entidade materializada (soma de custos de componentes). */
  materialCost(id: string): number {
    const ent = this.entities.get(id);
    if (!ent) return 0;
    let c = 1; // base: presença
    for (const [name] of ent.components) {
      c += this.components.get(name)?.cost ?? 1;
    }
    return c;
  }

  /* ---------------- relações (abertas) ---------------- */

  relate(from: string, to: string, type: string, opts: { weight?: number; causal?: boolean; data?: Record<string, unknown>; since?: number } = {}): Relation {
    this.require(from);
    this.require(to);
    this.relationTypes.add(type);
    const r: Relation = {
      id: newId('rel'),
      from,
      to,
      type,
      weight: opts.weight ?? 1,
      causal: opts.causal ?? false,
      data: { ...(opts.data ?? {}) },
      since: opts.since ?? this.time,
      until: null,
    };
    this.relations.push(r);
    let list = this.relIndex.get(from);
    if (!list) this.relIndex.set(from, (list = []));
    list.push(r);
    let list2 = this.relIndex.get(to);
    if (!list2) this.relIndex.set(to, (list2 = []));
    list2.push(r);
    this.emit('rrw.relation.created', [from, to], { type });
    return r;
  }

  unrelate(from: string, to: string, type: string): void {
    this.relations = this.relations.filter((r) => !(r.from === from && r.to === to && r.type === type && r.until === null));
    this.rebuildRelIndex();
  }

  private rebuildRelIndex(): void {
    this.relIndex.clear();
    for (const r of this.relations) {
      let l = this.relIndex.get(r.from);
      if (!l) this.relIndex.set(r.from, (l = []));
      l.push(r);
      let l2 = this.relIndex.get(r.to);
      if (!l2) this.relIndex.set(r.to, (l2 = []));
      l2.push(r);
    }
  }

  relationsOf(id: string, type?: string, dir: 'out' | 'in' | 'both' = 'both'): Relation[] {
    const out: Relation[] = [];
    for (const r of this.relations) {
      if (type && r.type !== type) continue;
      if (r.until !== null) continue;
      if (dir !== 'in' && r.from === id) out.push(r);
      else if (dir !== 'out' && r.to === id) out.push(r);
    }
    return out;
  }

  neighbors(id: string, type?: string, dir: 'out' | 'in' | 'both' = 'both'): RrwEntity[] {
    const seen = new Set<string>();
    const out: RrwEntity[] = [];
    for (const r of this.relationsOf(id, type, dir)) {
      const other = r.from === id ? r.to : r.from;
      if (seen.has(other)) continue;
      seen.add(other);
      const e = this.entities.get(other);
      if (e?.alive) out.push(e);
    }
    return out;
  }

  relationTypes(): string[] {
    return [...this.relationTypes].sort();
  }

  /* ---------------- eventos + causalidade ---------------- */

  emit(type: string, entities: string | string[], data: Record<string, unknown> = {}, cause: { by: string; event?: string; description?: string } | null = null): RrwEvent {
    this.eventTypes.add(type);
    const ids = Array.isArray(entities) ? entities : [entities];
    for (const id of ids) this.require(id);
    const counter = (this.eventCounters[type] ?? 0) + 1;
    this.eventCounters[type] = counter;
    const evt: RrwEvent = {
      id: `evt_${type.replace(/[^a-z0-9]/gi, '_')}_${this.nextSeq++}_${counter}`,
      type,
      at: this.time,
      entities: ids,
      data: { ...data },
      cause: cause ?? null,
    };
    this.eventLog.push(evt);
    if (this.eventLog.length > EVENT_RING) this.eventLog.splice(0, this.eventLog.length - EVENT_RING);
    for (const id of ids) {
      let l = this.entEvents.get(id);
      if (!l) this.entEvents.set(id, (l = []));
      l.push(evt);
      if (l.length > EVENT_RING) l.splice(0, l.length - EVENT_RING);
    }
    this.bus.emit(type, evt);
    this.bus.emit('rrw.event', evt);
    return evt;
  }

  eventsOf(id: string, type?: string): RrwEvent[] {
    const l = this.entEvents.get(id) ?? [];
    return type ? l.filter((e) => e.type === type) : [...l];
  }

  recent(n = 20): RrwEvent[] {
    return this.eventLog.slice(-n);
  }

  /** Cadeia causal até a raiz (profundidade limitada). */
  causalChain(id: string, type: string, maxDepth = 8): RrwEvent[] {
    const out: RrwEvent[] = [];
    let cur = [...(this.entEvents.get(id) ?? [])].reverse().find((e) => e.type === type);
    let depth = 0;
    while (cur && depth < maxDepth) {
      out.push(cur);
      if (!cur.cause) break;
      const causeEnt = cur.cause.by;
      const causeType = cur.cause.event;
      if (!causeEnt || !causeType) break;
      cur = [...(this.entEvents.get(causeEnt) ?? [])].reverse().find((e) => e.type === causeType);
      depth += 1;
    }
    return out;
  }

  eventTypesList(): string[] {
    return [...this.eventTypes].sort();
  }

  /* ---------------- contexto / scope ---------------- */

  setContext(id: string, contextId: string | null): void {
    const ent = this.require(id);
    if (contextId && !this.entities.has(contextId)) throw new Error(`RRW: contextId desconhecida: ${contextId}`);
    ent.contextId = contextId;
  }

  within(contextId: string, q: RrwQuery = {}): RrwEntity[] {
    return this.query({ ...q, contextId });
  }

  /* ---------------- processos (abertos) ---------------- */

  defineProcess(name: string, def: ProcessDef): void {
    if (this.processes.has(name)) throw new Error(`RRW: processo já definido: ${name}`);
    this.processes.set(name, { name, ...def });
  }

  processNames(): string[] {
    return [...this.processes.keys()].sort();
  }

  getProcess(name: string): ProcessDef | undefined {
    return this.processes.get(name);
  }

  startProcess(name: string, targetIds?: string[], opts: { contextScope?: string | null } = {}): void {
    const def = this.processes.get(name);
    if (!def) throw new Error(`RRW: processo não definido: ${name}`);
    const targets = this.processTargets.get(name) ?? new Set<string>();
    if (opts.contextScope !== undefined) def.contextScope = opts.contextScope;
    if (targetIds) {
      for (const id of targetIds) targets.add(id);
    } else if (def.contextScope) {
      for (const e of this.within(def.contextScope)) targets.add(e.id);
    }
    this.processTargets.set(name, targets);
    const states = this.processState.get(name) ?? new Map<string, string>();
    this.processState.set(name, states);
    for (const id of targets) {
      if (!states.has(id) && def.init) {
        const ent = this.require(id);
        if (ent.alive) states.set(id, def.init(ent, this.ctx0()));
      }
    }
  }

  stopProcess(name: string): void {
    this.processTargets.delete(name);
    this.processState.delete(name);
  }

  processTargetsOf(name: string): string[] {
    return [...(this.processTargets.get(name) ?? [])];
  }

  processStateOf(name: string, id: string): string | null {
    return this.processState.get(name)?.get(id) ?? null;
  }

  setProcessState(name: string, id: string, state: string, ctx?: ProcessCtx): void {
    const def = this.processes.get(name);
    const states = this.processState.get(name);
    if (!def || !states) throw new Error(`RRW: processo não ativo: ${name}`);
    const ent = this.require(id);
    const prev = states.get(id);
    states.set(id, state);
    if (prev !== state && def.enter) {
      def.enter(ent, state, ctx ?? this.ctx0());
    }
  }

  /**
   * Avança UM processo (usado pelo engine para controle por sistema/D-O15).
   * Entidades materializadas rodam `tick`; abstratas, `abstractTick`.
   */
  stepProcess(name: string, ctx: ProcessCtx): number {
    const def = this.processes.get(name);
    const targets = this.processTargets.get(name);
    if (!def || !targets || targets.size === 0) return 0;
    const states = this.processState.get(name) ?? new Map<string, string>();
    let ran = 0;
    const c: ProcessCtx = { ...ctx, process: name };
    for (const id of [...targets]) {
      const ent = this.entities.get(id);
      if (!ent || !ent.alive) {
        targets.delete(id);
        continue;
      }
      let state = states.get(id);
      if (state === undefined) {
        state = def.init ? def.init(ent, c) : 'active';
        states.set(id, state);
      }
      if (def.tick && ent.detail >= MATERIAL_THRESHOLD) {
        def.tick(ent, state, c);
      } else if (def.abstractTick && ent.detail < MATERIAL_THRESHOLD) {
        def.abstractTick(ent, state, c);
      } else {
        continue;
      }
      ran += 1;
    }
    return ran;
  }

  /**
   * Avança processos para todas as entidades-alvo.
   * Entidades materializadas rodam `tick` (fidelidade alta);
   * abstratas rodam `abstractTick` (evolução barata — mundo vivo fora do foco).
   */
  stepProcesses(ctx: ProcessCtx): number {
    let ran = 0;
    for (const [name, def] of this.processes) {
      const targets = this.processTargets.get(name);
      if (!targets || targets.size === 0) continue;
      const states = this.processState.get(name) ?? new Map<string, string>();
      const c: ProcessCtx = { ...ctx, process: name };
      for (const id of [...targets]) {
        const ent = this.entities.get(id);
        if (!ent || !ent.alive) {
          targets.delete(id);
          continue;
        }
        let state = states.get(id);
        if (state === undefined) {
          state = def.init ? def.init(ent, c) : 'active';
          states.set(id, state);
        }
        if (def.tick && ent.detail >= MATERIAL_THRESHOLD) {
          def.tick(ent, state, c);
        } else if (def.abstractTick && ent.detail < MATERIAL_THRESHOLD) {
          def.abstractTick(ent, state, c);
        } else {
          continue; // processo não cobre esse nível — custo zero
        }
        ran += 1;
      }
    }
    return ran;
  }

  private ctx0(): ProcessCtx {
    return { dt: 0, time: this.time, rng: new Rng(1), rrw: this };
  }

  /* ---------------- materialização / abstração ---------------- */

  isMaterial(id: string, threshold = MATERIAL_THRESHOLD): boolean {
    const ent = this.entities.get(id);
    return !!ent && ent.alive && ent.detail >= threshold;
  }

  /**
   * Aumenta o nível de materialização até `target` (0..1).
   * Restaura componentes comprimidos.
   */
  materialize(id: string, target: number, reason?: string): void {
    const ent = this.require(id);
    if (!ent.alive) return;
    if (target <= ent.detail) return;
    const t = Math.min(1, Math.max(0, target));
    const wasAbstract = ent.detail < MATERIAL_THRESHOLD;
    ent.detail = t;
    ent.state = t >= MATERIAL_THRESHOLD ? 'material' : 'transient';
    if (wasAbstract && ent.compressed) {
      for (const [name, snap] of ent.compressed) {
        const def = this.components.get(name);
        if (!def || ent.components.has(name)) continue;
        const restored = def.restore ? def.restore(ent, snap) : snap;
        ent.components.set(name, restored);
      }
      ent.compressed = null;
    }
    if (reason) this.emit('rrw.materialized', [id], { detail: ent.detail, reason });
  }

  /**
   * Abaixa para abstração (0) PRESERVANDO estado:
   *  - `data` semântica permanece íntegra (é a fonte da verdade);
   *  - componentes com `compress` viram snapshot; sem `compress`, o valor fica
   *    no componente (fidedigno, só o detalhe espacial cai).
   * Abstração → materialização → interação → abstração pode ocorrer continuamente.
   */
  abstractize(id: string, reason?: string): void {
    const ent = this.require(id);
    if (!ent.alive || ent.detail === 0) return;
    const hadDetail = ent.detail;
    ent.detail = 0;
    ent.state = 'abstract';
    ent.compressed = new Map();
    for (const [name, value] of [...ent.components]) {
      const def = this.components.get(name);
      if (def?.compress) {
        ent.compressed.set(name, def.compress(value));
        ent.components.delete(name);
      }
    }
    if (reason) this.emit('rrw.abstractized', [id], { from: hadDetail, reason });
  }

  /**
   * Materialização por relevância espacial (foco + raio).
   * detail alvo cai linearmente com a distância além do raio interno.
   */
  materializeForFocus(
    focus: { x: number; y: number; innerRadius: number; outerRadius: number; positionOf: (id: string) => { x: number; y: number } | null },
  ): { materialized: number; abstractized: number } {
    let materialized = 0;
    let abstractized = 0;
    for (const ent of this.entities.values()) {
      if (!ent.alive) continue;
      const p = focus.positionOf(ent.id);
      if (!p) continue;
      const dx = p.x - focus.x;
      const dy = p.y - focus.y;
      const d = Math.sqrt(dx * dx + dy * dy);
      let target: number;
      if (d <= focus.innerRadius) target = 1;
      else if (d >= focus.outerRadius) target = 0;
      else {
        // Faixa intermediária: rampa de detalhe que NUNCA fica abaixo do
        // limiar de materialização dentro do raio ativo (zona ativa ≥ D-material).
        const t = 1 - (d - focus.innerRadius) / (focus.outerRadius - focus.innerRadius);
        target = Math.min(1, Math.max(MATERIAL_THRESHOLD, t));
      }
      if (target > ent.detail + 0.001) {
        this.materialize(ent.id, target);
        materialized += 1;
      } else if (target < ent.detail - 0.001) {
        if (target <= 0) this.abstractize(ent.id);
        else {
          ent.detail = target;
          ent.state = target >= MATERIAL_THRESHOLD ? 'material' : 'transient';
        }
        abstractized += 1;
      }
    }
    return { materialized, abstractized };
  }

  /* ---------------- estatísticas / introspecção ---------------- */

  stats(): {
    entities: number;
    material: number;
    abstract: number;
    transient: number;
    relations: number;
    events: number;
    categories: number;
    components: number;
    processes: number;
    relationTypes: number;
  } {
    let material = 0;
    let abstract = 0;
    let transient = 0;
    for (const e of this.entities.values()) {
      if (!e.alive) continue;
      if (e.state === 'material') material += 1;
      else if (e.state === 'transient') transient += 1;
      else abstract += 1;
    }
    return {
      entities: [...this.entities.values()].filter((e) => e.alive).length,
      material,
      abstract,
      transient,
      relations: this.relations.length,
      events: this.eventLog.length,
      categories: this.categories.size,
      components: this.components.size,
      processes: this.processes.size,
      relationTypes: this.relationTypes.size,
    };
  }

  /**
   * Snapshot mínimo e serializável do estado SEMÂNTICO (para introspecção/debug).
   * Para PERSISTÊNCIA completa (com causalidade, componentes e processos),
   * use `serialize()` + `restore()`.
   */
  snapshot(): { time: number; entities: Array<{ id: string; name: string | null; categories: string[]; data: Record<string, unknown>; detail: number; state: EntityState; contextId: string | null }>; relations: Array<{ from: string; to: string; type: string; weight: number; causal: boolean }> } {
    return {
      time: this.time,
      entities: [...this.entities.values()]
        .filter((e) => e.alive)
        .map((e) => ({ id: e.id, name: e.name, categories: e.categories, data: e.data, detail: e.detail, state: e.state, contextId: e.contextId })),
      relations: this.relations
        .filter((r) => r.until === null)
        .map((r) => ({ from: r.from, to: r.to, type: r.type, weight: r.weight, causal: r.causal })),
    };
  }

  /* ---------------- causalidade verificável ---------------- */

  /**
   * Valida a causalidade de TODOS os eventos: toda causa {by, event} deve
   * apontar para um evento que REALMENTE existe no log da entidade causadora.
   * Retorna violações (eventos com causa inexistente/fabricada).
   */
  validateCausality(): Array<{ eventId: string; type: string; missingBy: string | null; missingEvent: string | null }> {
    const violations: Array<{ eventId: string; type: string; missingBy: string | null; missingEvent: string | null }> = [];
    for (const evt of this.eventLog) {
      const c = evt.cause;
      if (!c) continue;
      if (!c.by || !this.entities.has(c.by)) {
        violations.push({ eventId: evt.id, type: evt.type, missingBy: c.by ?? null, missingEvent: c.event ?? null });
        continue;
      }
      if (c.event) {
        const exists = (this.entEvents.get(c.by) ?? []).some((e) => e.type === c.event);
        if (!exists) violations.push({ eventId: evt.id, type: evt.type, missingBy: null, missingEvent: c.event });
      }
    }
    return violations;
  }

  /* ---------------- persistência completa (determinística) ---------------- */

  /**
   * Serializa o ESTADO COMPLETO do RRW em objeto JSON-safe:
   * entidades (ordem de inserção) com componentes + snapshots comprimidos,
   * relações, eventos (global + por entidade → causalidade), processos
   * (alvos + estados) e contadores sequenciais.
   * `restore()` reconstrói exatamente esse estado (ordens preservadas).
   */
  serialize(): RrwSerialized {
    const toPlain = (v: unknown): unknown => {
      if (v === null || typeof v !== 'object') return v;
      if (Array.isArray(v)) return v.map(toPlain);
      if (v instanceof Map) return { __uts: 'map', v: [...v.entries()].map(([k, x]) => [toPlain(k), toPlain(x)]) };
      if (v instanceof Set) return { __uts: 'set', v: [...v.values()].map(toPlain) };
      if (ArrayBuffer.isView(v)) {
        const ctor = (v as { constructor: { name: string } }).constructor.name;
        const ctorName =
          ctor === 'Float32Array' ? 'float32' :
          ctor === 'Float64Array' ? 'float64' :
          ctor === 'Uint8Array' ? 'uint8' : 'generic';
        return { __uts: ctorName, v: Array.from(v as unknown as ArrayLike<number>) };
      }
      const out: Record<string, unknown> = {};
      for (const [k, x] of Object.entries(v)) out[k] = toPlain(x);
      return out;
    };
    return {
      v: 1,
      time: this.time,
      nextSeq: this.nextSeq,
      eventCounters: { ...this.eventCounters },
      categories: [...this.categories],
      relationTypes: [...this.relationTypes],
      eventTypes: [...this.eventTypes],
      componentNames: [...this.components.keys()],
      processNames: [...this.processes.keys()],
      entities: [...this.entities.values()].map((e) => ({
        id: e.id,
        name: e.name,
        categories: e.categories,
        data: toPlain(e.data),
        contextId: e.contextId,
        parentId: e.parentId,
        detail: e.detail,
        state: e.state,
        createdAt: e.createdAt,
        alive: e.alive,
        components: [...e.components.entries()].map(([k, x]) => [k, toPlain(x)]),
        compressed: e.compressed ? [...e.compressed.entries()].map(([k, x]) => [k, toPlain(x)]) : null,
        spawnedBy: e.spawnedBy,
      })),
      relations: this.relations.map((r) => ({ ...r, data: toPlain(r.data) })),
      eventLog: this.eventLog.map((e) => ({ ...e, data: toPlain(e.data), entities: [...e.entities] })),
      entEvents: [...this.entEvents.entries()].map(([id, list]) => [id, list.map((e) => ({ ...e, data: toPlain(e.data), entities: [...e.entities] }))]),
      processTargets: [...this.processTargets.entries()].map(([name, set]) => [name, [...set]]),
      processState: [...this.processState.entries()].map(([name, map]) => [name, [...map.entries()]]),
    };
  }

  /**
   * Reconstrói o estado a partir de `serialize()` (ordens preservadas).
   * Não emite eventos (restauração ≠ nova ocorrência).
   */
  restore(data: RrwSerialized): void {
    const fromPlain = (v: unknown): unknown => {
      if (v === null || typeof v !== 'object') return v;
      if (Array.isArray(v)) return v.map(fromPlain);
      const o = v as Record<string, unknown>;
      if (typeof o.__uts === 'string') {
        if (o.__uts === 'map') return new Map((o.v as unknown[]).map(([k, x]) => [fromPlain(k), fromPlain(x)] as [unknown, unknown]));
        if (o.__uts === 'set') return new Set((o.v as unknown[]).map(fromPlain));
        if (o.__uts === 'float32') return Float32Array.from(o.v as number[]);
        if (o.__uts === 'float64') return Float64Array.from(o.v as number[]);
        if (o.__uts === 'uint8') return Uint8Array.from(o.v as number[]);
        if (o.__uts === 'generic') return Uint8Array.from(o.v as number[]);
      }
      const out: Record<string, unknown> = {};
      for (const [k, x] of Object.entries(o)) out[k] = fromPlain(x);
      return out;
    };
    // reseta
    this.entities.clear();
    this.relations = [];
    this.relIndex.clear();
    this.categories.clear();
    this.relationTypes.clear();
    this.eventTypes.clear();
    this.processTargets.clear();
    this.processState.clear();
    this.eventLog = [];
    this.entEvents.clear();
    this.eventCounters = {};
    this.nextSeq = 0;
    // reconstrói (ordem exata)
    this.time = data.time;
    this.nextSeq = data.nextSeq;
    this.eventCounters = { ...data.eventCounters };
    for (const c of data.categories) this.categories.add(c);
    for (const t of data.relationTypes) this.relationTypes.add(t);
    for (const t of data.eventTypes) this.eventTypes.add(t);
    for (const e of data.entities) {
      const ent: RrwEntity = {
        id: e.id,
        name: e.name,
        categories: [...e.categories],
        components: new Map(),
        data: fromPlain(e.data) as Record<string, unknown>,
        contextId: e.contextId,
        parentId: e.parentId,
        detail: e.detail,
        state: e.state,
        createdAt: e.createdAt,
        alive: e.alive,
        compressed: e.compressed ? new Map(e.compressed.map(([k, x]) => [k, fromPlain(x)] as [string, unknown])) : null,
        spawnedBy: e.spawnedBy,
      };
      for (const [k, x] of e.components) ent.components.set(k, fromPlain(x));
      this.entities.set(e.id, ent);
    }
    for (const r of data.relations) {
      this.relations.push({ ...r, data: fromPlain(r.data) as Record<string, unknown> });
    }
    this.rebuildRelIndex();
    for (const e of data.eventLog) this.eventLog.push({ ...e, data: fromPlain(e.data) as Record<string, unknown>, entities: [...e.entities] });
    for (const [id, list] of data.entEvents) {
      this.entEvents.set(id, list.map((e) => ({ ...e, data: fromPlain(e.data) as Record<string, unknown>, entities: [...e.entities] })));
    }
    for (const [name, ids] of data.processTargets) this.processTargets.set(name, new Set(ids));
    for (const [name, pairs] of data.processState) this.processState.set(name, new Map(pairs));
  }
}

/* ------------------------------------------------------------------ */
/* Serialização                                                        */
/* ------------------------------------------------------------------ */

export interface RrwSerialized {
  v: 1;
  time: number;
  nextSeq: number;
  eventCounters: Record<string, number>;
  categories: string[];
  relationTypes: string[];
  eventTypes: string[];
  componentNames: string[];
  processNames: string[];
  entities: Array<{
    id: string;
    name: string | null;
    categories: string[];
    data: unknown;
    contextId: string | null;
    parentId: string | null;
    detail: number;
    state: EntityState;
    createdAt: number;
    alive: boolean;
    components: Array<[string, unknown]>;
    compressed: Array<[string, unknown]> | null;
    spawnedBy: { by: string; event?: string; description?: string } | null;
  }>;
  relations: Array<Omit<Relation, 'data'> & { data: unknown }>;
  eventLog: Array<Omit<RrwEvent, 'data'> & { data: unknown }>;
  entEvents: Array<[string, Array<Omit<RrwEvent, 'data'> & { data: unknown }>]>;
  processTargets: Array<[string, string[]]>;
  processState: Array<[string, Array<[string, string]>]>;
}
