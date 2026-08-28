// UTS :: core/comm — OUR inter-module communication (request/response + events).
// Modules talk through owned, typed routes with correlation ids, timeouts and
// metrics — not through ad-hoc function call spaghetti. UI-independent.

export class CommError extends Error {}

export class Comm {
  constructor() {
    this.routes = new Map();     // name -> handler
    this.events = new Map();     // name -> Set(fn)
    this.pending = new Map();    // correlation -> {resolve, reject, timer}
    this.nextId = 1;
    this.stats = { requests: 0, responses: 0, timeouts: 0, errors: 0, events: 0 };
  }

  route(name, handler) {
    if (typeof handler !== 'function') throw new CommError(`route ${name} needs a handler`);
    if (this.routes.has(name)) throw new CommError(`route already registered: ${name}`);
    this.routes.set(name, handler);
    return this;
  }

  async request(name, payload = {}, { timeoutMs = 2000 } = {}) {
    const handler = this.routes.get(name);
    if (!handler) throw new CommError(`unknown route: ${name}`);
    this.stats.requests++;
    const result = await handler(payload, { comm: this });
    this.stats.responses++;
    return result;
  }

  /** request with timeout — hangs are errors, never silent */
  requestWithTimeout(name, payload, { timeoutMs = 500 } = {}) {
    const handler = this.routes.get(name);
    if (!handler) return Promise.reject(new CommError(`unknown route: ${name}`));
    this.stats.requests++;
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        this.stats.timeouts++;
        reject(new CommError(`route '${name}' timed out after ${timeoutMs}ms`));
      }, timeoutMs);
      Promise.resolve()
        .then(() => handler(payload, { comm: this }))
        .then((result) => { clearTimeout(timer); this.stats.responses++; resolve(result); })
        .catch((err) => { clearTimeout(timer); this.stats.errors++; reject(err); });
    });
  }

  on(eventName, fn) {
    if (!this.events.has(eventName)) this.events.set(eventName, new Set());
    this.events.get(eventName).add(fn);
    return () => this.events.get(eventName)?.delete(fn);
  }

  emit(eventName, payload = {}) {
    this.stats.events++;
    const set = this.events.get(eventName);
    if (set) for (const fn of [...set]) fn(payload);
  }

  report() {
    return { ...this.stats, routes: [...this.routes.keys()], events: [...this.events.keys()] };
  }
}
