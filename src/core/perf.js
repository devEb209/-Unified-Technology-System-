// UTS :: core/perf — PerfMeter. Real measurement only. Feeds D-O15 with evidence.

const defaultNow = () =>
  (typeof performance !== 'undefined' && performance.now) ? performance.now() : Date.now();

export class PerfMeter {
  constructor({ now = defaultNow, enabled = true } = {}) {
    this.now = now;
    this.enabled = enabled;
    this.spans = new Map();
  }

  start(name) {
    if (!this.enabled) return null;
    return { name, t: this.now() };
  }

  end(token) {
    if (!token) return 0;
    const d = this.now() - token.t;
    let s = this.spans.get(token.name);
    if (!s) {
      s = { count: 0, total: 0, max: 0 };
      this.spans.set(token.name, s);
    }
    s.count++;
    s.total += d;
    if (d > s.max) s.max = d;
    return d;
  }

  measure(name, fn) {
    const tk = this.start(name);
    try {
      return fn();
    } finally {
      this.end(tk);
    }
  }

  get(name) {
    return this.spans.get(name) ?? { count: 0, total: 0, max: 0 };
  }

  /** averaged recent ms for a span (used by D-O15 input) */
  avgMs(name) {
    const s = this.get(name);
    return s.count ? s.total / s.count : 0;
  }

  report() {
    return [...this.spans.entries()]
      .map(([name, s]) => ({ name, count: s.count, totalMs: s.total, avgMs: s.total / s.count, maxMs: s.max }))
      .sort((a, b) => b.totalMs - a.totalMs);
  }

  reset() {
    this.spans.clear();
  }
}
