// UTS :: ues/scheduler — budgeted deterministic scheduler.
// Systems run in priority order within a global time budget; when the budget
// is exceeded, remaining systems are DEFERRED to the next tick (never dropped).
// With an unlimited budget (tests/determinism) every system runs every tick.

const defaultNow = () =>
  (typeof performance !== 'undefined' && performance.now) ? performance.now() : Date.now();

export class Scheduler {
  constructor({ now = defaultNow, globalBudgetMs = 0, perf = null } = {}) {
    this.now = now;
    this.globalBudgetMs = globalBudgetMs; // 0 = unlimited
    this.perf = perf;
    this.systems = [];
    this.orderDirty = false;
    this.tickN = 0;
    this.last = { ran: [], skipped: [], totalMs: 0 };
  }

  add({ name, priority = 100, fn, budgetMs = 0 }) {
    if (this.systems.some(s => s.name === name)) throw new Error(`system already registered: ${name}`);
    this.systems.push({ name, priority, fn, budgetMs, pending: false, enabled: true, runs: 0, skipped: 0, disabledTicks: 0, totalMs: 0, maxMs: 0 });
    this.orderDirty = true;
    return this;
  }

  /** experience rulesets toggle systems without unregistering them */
  setEnabled(name, enabled) {
    const sys = this.systems.find(s => s.name === name);
    if (!sys) throw new Error(`unknown system: ${name}`);
    sys.enabled = !!enabled;
    if (!sys.enabled) sys.pending = false;
    return sys.enabled;
  }

  getSystem(name) {
    return this.systems.find(s => s.name === name) ?? null;
  }

  tick(dt) {
    if (this.orderDirty) {
      this.systems.sort((a, b) => a.priority - b.priority); // stable in V8 for equal keys
      this.orderDirty = false;
    }
    const t0 = this.now();
    const ran = [], skipped = [];

    // 1) systems deferred from the previous tick run first (deterministic order)
    const pending = this.systems.filter(s => s.pending);
    for (const s of pending) s.pending = false;

    const ordered = [...pending, ...this.systems.filter(s => !pending.includes(s))];
    for (const sys of ordered) {
      if (!sys.enabled) { sys.disabledTicks++; continue; } // ruleset-disabled: counted, never forgotten
      if (this.globalBudgetMs > 0 && (this.now() - t0) > this.globalBudgetMs && !pending.includes(sys)) {
        sys.pending = true;   // deferred, NOT dropped
        sys.skipped++;
        skipped.push(sys.name);
        continue;
      }
      const s0 = this.now();
      const tk = this.perf?.start('sys:' + sys.name) ?? null;
      sys.fn(dt);
      this.perf?.end(tk);
      const d = this.now() - s0;
      sys.runs++;
      sys.totalMs += d;
      if (d > sys.maxMs) sys.maxMs = d;
      ran.push(sys.name);
      if (sys.budgetMs > 0 && d > sys.budgetMs) {
        // per-system overrun is recorded for D-O15, execution is not aborted mid-system
        sys.overBudget = (sys.overBudget ?? 0) + 1;
      }
    }
    this.tickN++;
    this.last = { ran, skipped, totalMs: this.now() - t0 };
    return this.last;
  }

  stats() {
    return this.systems.map(s => ({
      name: s.name, priority: s.priority, runs: s.runs, skipped: s.skipped,
      enabled: s.enabled, disabledTicks: s.disabledTicks,
      avgMs: s.runs ? s.totalMs / s.runs : 0, maxMs: s.maxMs,
      overBudget: s.overBudget ?? 0,
    }));
  }
}
