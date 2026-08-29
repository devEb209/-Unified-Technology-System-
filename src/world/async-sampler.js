// UTS :: world/async-sampler — ASYNC STREAMING (R6): chunk sampling off-thread.
//
//   reality chain preserved: the worker samples the SAME pure terrain
//   (seed → fbm), so results are byte-identical to the synchronous path.
//   The main thread only ever consumes COMPLETED deterministic results —
//   the workers change WHEN the data is ready, never WHAT the data is.
//
// worker_threads does not exist in browsers: `supported()` is false there
// and the streaming system falls back to the synchronous path honestly.

export function supported() {
  try {
    // dynamic access so bundlers/browsers don't hard-crash on import
    return typeof process !== 'undefined' && !!process.versions?.node;
  } catch {
    return false;
  }
}

export class AsyncChunkSampler {
  constructor({ threads = 2, seed = 'uts:world' } = {}) {
    this.seed = seed;
    this.threads = Math.max(1, threads);
    this.stats = { dispatched: 0, completed: 0, errors: 0 };
    this._workers = [];
    this._nextId = 1;
    this._inFlight = new Map();   // id -> { cx, cz, res }
    this._pending = [];           // jobs not yet handed to a worker
    this._done = [];              // completed results awaiting poll()
    this._keys = new Set();       // dedupe: cx,cz,res already queued
    this._started = false;
  }

  /** spawn the pool lazily; DYNAMIC import so browsers never touch node:
   *  internals (worker_threads) — static import would break demos/web */
  async _spawn() {
    if (!supported() || this._started) return false;
    try {
      const { Worker } = await import('node:worker_threads');
      const path = new URL('./chunk-worker.js', import.meta.url).pathname;
      for (let i = 0; i < this.threads; i++) {
        // execArgv: [] — workers must not inherit parent CLI flags
        // (e.g. --input-type would crash the worker thread)
        const w = new Worker(path, { workerData: { seed: this.seed }, execArgv: [] });
        w.on('message', (msg) => {
          this._inFlight.delete(msg.id);
          if (msg.error) { this.stats.errors++; this._done.push({ ...msg, error: true }); }
          else {
            this.stats.completed++;
            this._done.push({ ...msg, error: false });
          }
          this._drain();
        });
        w.on('error', () => { this.stats.errors++; this._started = false; });
        this._workers.push(w);
      }
      this._started = true;
      return true;
    } catch {
      this._started = false;   // honest fallback: caller stays synchronous
      return false;
    }
  }

  /** queue a chunk job (deduped); jobs run on the worker pool */
  request({ cx, cz, res }) {
    const key = `${cx},${cz},${res}`;
    if (this._keys.has(key)) return false;
    this._keys.add(key);
    this._pending.push({ id: this._nextId++, cx, cz, res, key });
    this.stats.dispatched++;
    this._spawn()              // async, idempotent; jobs flow when ready
      .then((ok) => { if (ok) this._drain(); })
      .catch(() => {});
    this._drain();
    return true;
  }

  _drain() {
    if (!this._started || this._workers.length === 0) return;
    while (this._pending.length > 0 && this._inFlight.size < this.threads * 2) {
      const job = this._pending.shift();
      const w = this._workers[this._inFlight.size % this._workers.length];
      if (!w) { this._pending.unshift(job); break; }
      this._inFlight.set(job.id, job);
      w.postMessage({ ...job, seed: this.seed });
    }
  }

  /** drain completed results: [{ cx, cz, res, heights, biomes, step }] */
  poll() {
    const out = this._done;
    this._done = [];
    for (const r of out) if (!r.error) this._keys.delete(`${r.cx},${r.cz},${r.res}`);
    return out;
  }

  get queued() { return this._pending.length + this._inFlight.size; }
  get running() { return this._started; }

  async destroy() {
    await Promise.all(this._workers.map(w => w.terminate()));
    this._workers = [];
    this._started = false;
  }
}
