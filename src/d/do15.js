// UTS :: d/do15 — D-O15 OPTIMIZATION LAYER.
//
// The question is not "how do we compute everything?" but
// "what is the best way to represent and compute what actually needs
//  to exist right now?"
//
// D-O15 measures real pressure and chooses strategies:
//   * materialization radius        — how much of the world is detailed
//   * update frequencies            — how often each tier of entity thinks
//   * perception resolution         — full / reduced / coarse (never blind)
//   * terrain LOD bias and radius
//   * visual quality (shadows, particles)
//   * a DEFER queue — under pressure work is deferred, NEVER discarded.
//
// Optimization is not "reduce quality": it is obtaining the same necessary
// result through a more efficient representation. Every decision is logged
// with its reason; every deferral returns when budget exists.

import { clamp01 } from '../core/math.js';

export const PERCEPTION_RESOLUTIONS = Object.freeze({
  full: { cap: 12, rangeMul: 1.0 },
  reduced: { cap: 6, rangeMul: 0.8 },
  coarse: { cap: 3, rangeMul: 0.6 },
});

export function defaultStrategy() {
  return {
    materializationRadius: 90,
    updateEveryTicks: { full: 1, partial: 4, abstract: 0 }, // 0 = skip (aggregate handles)
    perceptionResolution: 'full',
    terrainRadius: 220,
    terrainLodBias: 0,
    shadows: true,
    particleDensity: 1,
    maxMaterialized: 400,
    audioSr: 22050,
    audioVoices: 8,
  };
}

export class DO15 {
  constructor({ tese = null, budget = null, config = {} } = {}) {
    this.tese = tese;
    this.budget = { frameMs: 14, simMs: 8, ...budget };
    this.config = { extreme: 0.9, high: 0.7, low: 0.35, ...config };
    this.pressure = 0;
    this.strategy = defaultStrategy();
    this.decisions = [];
    this.decisionCap = 256;
    /** deferred work — closures deferred under pressure, never dropped */
    this.deferred = [];
    this.deferredDone = 0;
    this.metrics = {};
    /**
     * Deterministic replay/CI mode: when pinned, measured metrics are ignored
     * and the strategy stays fixed. Host timing is runtime evidence — pinning
     * makes save/load evolution bitwise-deterministic across machines.
     */
    this.pinned = false;
  }

  report(metrics) {
    if (this.pinned) return this.strategy;
    this.metrics = { ...this.metrics, ...metrics };
    const b = this.budget;
    const raw = Math.max(
      clamp01((metrics.frameMs ?? 0) / b.frameMs),
      clamp01((metrics.simMs ?? 0) / b.simMs),
    );
    const prev = this.pressure;
    this.pressure = clamp01(prev * 0.7 + raw * 0.3); // hysteresis via EMA
    this.recomputeStrategy({ prevPressure: prev });
    return this.strategy;
  }

  recomputeStrategy(ctx = {}) {
    const s = this.strategy;
    const p = this.pressure;
    const c = this.config;
    const before = JSON.stringify(pickFields(s));

    if (p >= c.extreme) {
      s.materializationRadius = 45;
      s.updateEveryTicks = { full: 2, partial: 8, abstract: 0 };
      s.perceptionResolution = 'coarse';
      s.terrainRadius = 140;
      s.terrainLodBias = 1;
      s.shadows = false;
      s.particleDensity = 0.4;
      s.audioSr = 11025;
      s.audioVoices = 3;
    } else if (p >= c.high) {
      s.materializationRadius = 65;
      s.updateEveryTicks = { full: 1, partial: 6, abstract: 0 };
      s.perceptionResolution = 'reduced';
      s.terrainRadius = 180;
      s.terrainLodBias = 1;
      s.shadows = true;
      s.particleDensity = 0.7;
      s.audioSr = 16000;
      s.audioVoices = 5;
    } else if (p <= c.low) {
      const d = defaultStrategy();
      Object.assign(s, d);
    } else {
      s.materializationRadius = 90;
      s.updateEveryTicks = { full: 1, partial: 4, abstract: 0 };
      s.perceptionResolution = 'full';
      s.terrainRadius = 220;
      s.terrainLodBias = 0;
      s.shadows = true;
      s.particleDensity = 1;
      s.audioSr = 22050;
      s.audioVoices = 8;
    }

    const after = JSON.stringify(pickFields(s));
    if (before !== after) {
      this.logDecision({
        kind: 'strategy',
        from: JSON.parse(before),
        to: JSON.parse(after),
        reason: `pressure ${prevStr(ctx.prevPressure)} -> ${this.pressure.toFixed(2)} (frame ${fmt(this.metrics.frameMs)}ms / sim ${fmt(this.metrics.simMs)}ms vs budget ${this.budget.frameMs}/${this.budget.simMs}ms)`,
        pressure: this.pressure,
      });
    }
    this.tese?.touch('D-O15', `strategy: radius=${s.materializationRadius} perception=${s.perceptionResolution}`, ctx.tick ?? null);
    return s;
  }

  logDecision(d) {
    d.tick = d.tick ?? null;
    this.decisions.push(d);
    if (this.decisions.length > this.decisionCap) this.decisions.shift();
  }

  /**
   * Which materialization does an entity need?
   * Distance + importance (D-10) — importance overrides distance.
   */
  decideMaterialization(dist, importance = 0) {
    if (importance >= 0.9) {
      this.tese?.touch('D-10', `importance override at ${dist.toFixed(0)}m`);
      return 'full';
    }
    const r = this.strategy.materializationRadius * (0.6 + 0.8 * clamp01(importance));
    if (dist < r) return 'full';
    if (dist < r * 1.8) return 'partial';
    return 'abstract';
  }

  /** how often should this entity think? (ticks to wait) */
  decideUpdateEvery(materialization) {
    return this.strategy.updateEveryTicks[materialization] ?? 0;
  }

  /** adjust a perception model — under pressure resolution drops, reality is NOT discarded */
  decidePerception(model) {
    const res = PERCEPTION_RESOLUTIONS[this.strategy.perceptionResolution];
    return {
      ...model,
      range: model.range * res.rangeMul,
      cap: Math.max(res.cap, model.minCap ?? 0),
      resolution: this.strategy.perceptionResolution,
    };
  }

  /**
   * DEFER, do not discard. Work queued here is guaranteed to run when
   * the budget allows. Returns how many items were executed.
   */
  defer(work, label = 'work') {
    this.deferred.push({ work, label });
    this.tese?.touch('D-O15', `deferred: ${label} (queue=${this.deferred.length})`);
    return this.deferred.length;
  }

  runDeferred(budgetMs, now = () => performance.now()) {
    let executed = 0;
    const t0 = now();
    while (this.deferred.length > 0 && (now() - t0) < budgetMs) {
      const item = this.deferred.shift();
      item.work();
      executed++;
      this.deferredDone++;
    }
    if (executed > 0) {
      this.logDecision({
        kind: 'deferred-run', count: executed,
        reason: `executed ${executed} deferred items within ${budgetMs}ms budget`,
        pressure: this.pressure,
      });
    }
    return { executed, remaining: this.deferred.length };
  }

  stats() {
    return {
      pressure: this.pressure,
      strategy: { ...this.strategy, updateEveryTicks: { ...this.strategy.updateEveryTicks } },
      deferredQueued: this.deferred.length,
      deferredExecuted: this.deferredDone,
      decisions: this.decisions.length,
      metrics: { ...this.metrics },
    };
  }

  /**
   * Snapshot carries STRATEGY and BUDGET only. Pressure and raw metrics are
   * host-timing measurements (runtime evidence, not reality state) — keeping
   * them out preserves save/load determinism across machines.
   */
  snapshot() {
    return {
      strategy: { ...this.strategy, updateEveryTicks: { ...this.strategy.updateEveryTicks } },
      budget: { ...this.budget },
    };
  }

  restore(s) {
    this.pressure = 0;
    this.metrics = {};
    if (s.strategy) Object.assign(this.strategy, s.strategy);
    if (s.budget) Object.assign(this.budget, s.budget);
    this.deferred.length = 0; // runtime closures are not serializable (by design)
  }
}

function pickFields(s) {
  const { materializationRadius, updateEveryTicks, perceptionResolution, terrainRadius, terrainLodBias, shadows, particleDensity, audioSr, audioVoices } = s;
  return { materializationRadius, updateEveryTicks, perceptionResolution, terrainRadius, terrainLodBias, shadows, particleDensity, audioSr, audioVoices };
}

function fmt(v) { return (v ?? 0).toFixed(1); }
function prevStr(p) { return p == null ? 'n/a' : p.toFixed(2); }
