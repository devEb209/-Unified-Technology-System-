/**
 * UTS — Unified Technology System · core
 *
 * Fundações neutras de domínio: identificadores, RNG determinístico,
 * relógio de simulação, barramento de eventos, logging estruturado e
 * medição de desempenho. Nenhum conhecimento de RRW/D/O15/AI aqui —
 * isso mantém o acoplamento baixo (Prompt 3/20).
 */

/* ------------------------------------------------------------------ */
/* Identifiers                                                         */
/* ------------------------------------------------------------------ */

let idSeq = 0;
let idStamp = Date.now() % 0x7fffffff;

/** Gera um id único (não-determinístico — uso runtime). */
export function newId(prefix = 'e'): string {
  idSeq = (idSeq + 1) % 0xfffffff;
  idStamp = (idStamp + 1) % 0x7fffffff;
  const rand = Math.floor(Math.random() * 0xffffff).toString(36);
  return `${prefix}_${idStamp.toString(36)}${idSeq.toString(36)}${rand}`;
}

/* ------------------------------------------------------------------ */
/* Deterministic RNG (mulberry32)                                      */
/* ------------------------------------------------------------------ */

/**
 * PRNG determinístico. Toda emergência no mundo usa um Rng semeado,
 * o que torna a evolução do mundo reproduzível para testes
 * (emergência ≠ aleatoriedade sem controle).
 */
export class Rng {
  private s: number;
  constructor(seed: number) {
    this.s = seed >>> 0;
    if (this.s === 0) this.s = 0x9e3779b9;
  }
  /** [0,1) */
  next(): number {
    this.s = (this.s + 0x6d2b79f5) >>> 0;
    let t = this.s;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  }
  range(min: number, max: number): number {
    return min + this.next() * (max - min);
  }
  int(maxExclusive: number): number {
    return Math.floor(this.next() * maxExclusive);
  }
  pick<T>(arr: readonly T[]): T {
    return arr[this.int(arr.length)];
  }
  chance(p: number): boolean {
    return this.next() < p;
  }
  shuffle<T>(arr: T[]): T[] {
    for (let i = arr.length - 1; i > 0; i--) {
      const j = this.int(i + 1);
      const a = arr[i];
      arr[i] = arr[j];
      arr[j] = a;
    }
    return arr;
  }
  /** Estado interno (para persistência determinística). */
  state(): number {
    return this.s >>> 0;
  }
  /** Restaura um Rng a um estado exato (persistência/reprodução). */
  static fromState(s: number): Rng {
    const r = new Rng(1);
    r.s = (s >>> 0) || 0x9e3779b9;
    return r;
  }
}

/* ------------------------------------------------------------------ */
/* Simulation clock                                                    */
/* ------------------------------------------------------------------ */

export class SimClock {
  time = 0; // segundos de simulação
  frame = 0; // ticks renderizados
  tickCount = 0; // ticks de simulação
  tick(dt = 0.1): void {
    this.time += dt;
    this.tickCount += 1;
  }
  renderFrame(): void {
    this.frame += 1;
  }
  reset(): void {
    this.time = 0;
    this.frame = 0;
    this.tickCount = 0;
  }
}

/* ------------------------------------------------------------------ */
/* Event bus                                                           */
/* ------------------------------------------------------------------ */

export interface BusHandler {
  (payload: unknown): void;
}

export class EventBus {
  private handlers = new Map<string, { priority: number; fn: BusHandler }[]>();

  on(type: string, fn: BusHandler, priority = 0): () => void {
    let list = this.handlers.get(type);
    if (!list) {
      list = [];
      this.handlers.set(type, list);
    }
    list.push({ priority, fn });
    list.sort((a, b) => b.priority - a.priority);
    return () => this.off(type, fn);
  }

  off(type: string, fn: BusHandler): void {
    const list = this.handlers.get(type);
    if (!list) return;
    const i = list.findIndex((h) => h.fn === fn);
    if (i >= 0) list.splice(i, 1);
  }

  emit(type: string, payload: unknown): void {
    const list = this.handlers.get(type);
    if (!list) return;
    for (const h of [...list]) h.fn(payload);
  }

  listenerCount(type: string): number {
    return this.handlers.get(type)?.length ?? 0;
  }
}

/* ------------------------------------------------------------------ */
/* Structured logging                                                  */
/* ------------------------------------------------------------------ */

export type LogLevel = 'debug' | 'info' | 'warn' | 'error';
const LEVEL_RANK: Record<LogLevel, number> = { debug: 10, info: 20, warn: 30, error: 40 };

export interface LogEntry {
  level: LogLevel;
  scope: string;
  msg: string;
  data?: unknown;
  at: number;
}

type Sink = (e: LogEntry) => void;

export class Logger {
  static sink: Sink = () => {};
  static level: LogLevel = 'info';
  static entries: LogEntry[] = [];

  scope: string;
  constructor(scope = 'uts') {
    this.scope = scope;
  }
  child(scope: string): Logger {
    return new Logger(`${this.scope}:${scope}`);
  }
  private write(level: LogLevel, msg: string, data?: unknown): void {
    if (LEVEL_RANK[level] < LEVEL_RANK[Logger.level]) return;
    const entry: LogEntry = { level, scope: this.scope, msg, data, at: Date.now() };
    Logger.entries.push(entry);
    if (Logger.entries.length > 20000) Logger.entries.splice(0, 10000);
    Logger.sink(entry);
  }
  debug(msg: string, data?: unknown): void {
    this.write('debug', msg, data);
  }
  info(msg: string, data?: unknown): void {
    this.write('info', msg, data);
  }
  warn(msg: string, data?: unknown): void {
    this.write('warn', msg, data);
  }
  error(msg: string, data?: unknown): void {
    this.write('error', msg, data);
  }
  static reset(): void {
    Logger.entries.length = 0;
  }
}

/* ------------------------------------------------------------------ */
/* Performance meter (alimenta o Profiler do D-O15)                     */
/* ------------------------------------------------------------------ */

export interface PerfEntry {
  name: string;
  count: number;
  totalMs: number;
  avgMs: number;
  maxMs: number;
  lastMs: number;
}

export class PerfMeter {
  private entries = new Map<string, PerfEntry>();

  measure<T>(name: string, fn: () => T): T {
    const t0 = process.hrtime.bigint();
    try {
      return fn();
    } finally {
      const ms = Number(process.hrtime.bigint() - t0) / 1e6;
      let e = this.entries.get(name);
      if (!e) {
        e = { name, count: 0, totalMs: 0, maxMs: 0, avgMs: 0, lastMs: 0 };
        this.entries.set(name, e);
      }
      e.count += 1;
      e.totalMs += ms;
      e.lastMs = ms;
      e.maxMs = Math.max(e.maxMs, ms);
      e.avgMs = e.totalMs / e.count;
    }
  }

  snapshot(): PerfEntry[] {
    return [...this.entries.values()].map((e) => ({ ...e }));
  }

  get(name: string): PerfEntry | undefined {
    const e = this.entries.get(name);
    return e ? { ...e } : undefined;
  }

  totalMs(): number {
    let t = 0;
    for (const e of this.entries.values()) t += e.totalMs;
    return t;
  }

  reset(): void {
    this.entries.clear();
  }
}

/* ------------------------------------------------------------------ */
/* Utils                                                               */
/* ------------------------------------------------------------------ */

export function clamp(v: number, min: number, max: number): number {
  return v < min ? min : v > max ? max : v;
}

export function lerp(a: number, b: number, t: number): number {
  return a + (b - a) * clamp(t, 0, 1);
}

/** Distância euclidiana 2D (coordenadas de mundo UES). */
export function dist2d(ax: number, ay: number, bx: number, by: number): number {
  const dx = ax - bx;
  const dy = ay - by;
  return Math.sqrt(dx * dx + dy * dy);
}

/** Suavização exponencial (framerate-independent). */
export function damp(current: number, target: number, rate: number, dt: number): number {
  return lerp(current, target, 1 - Math.exp(-rate * dt));
}
