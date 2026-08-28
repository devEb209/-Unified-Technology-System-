// UTS :: world/streaming — OUR streaming system (no engine imports).
// Terrain patches are "loaded" by an owned pipeline: a priority queue fed
// by focus + D-O15 radius, drained under a per-tick time budget, with
// eviction of out-of-range content. RRW/terrain stay the truth; streaming
// only decides WHAT IS RESIDENT and WHEN.

import { dist2 } from '../core/math.js';

export class StreamingSystem {
  constructor({ world, perf = null, tese = null, cache = null } = {}) {
    this.world = world;
    this.perf = perf;
    this.tese = tese;
    this.cache = cache; // OUR ChunkCache (optional): resample-free residency
    /** key -> {key, cx, cz, res, state: 'pending'|'ready', priority, bytes} */
    this.resident = new Map();
    this.stats = { loaded: 0, evicted: 0, scheduled: 0, budgetExhausted: 0, resChanges: 0, cacheHits: 0 };
    this.maxResident = 128;
  }

  key(cx, cz, res) { return `${cx}:${cz}:${res}`; }

  /** per-tick update: schedule desired patches around focus, load within budget */
  update(focus, { radius = 220, budgetMs = 2 } = {}) {
    const t = this.world.terrain;
    const cs = t.chunkSize;
    const now = () => (this.perf ? this.perf.now() : performance.now());

    // ---- schedule desires (priority: nearest first; res by distance ring)
    const c0x = Math.floor((focus[0] - radius) / cs), c1x = Math.floor((focus[0] + radius) / cs);
    const c0z = Math.floor((focus[2] - radius) / cs), c1z = Math.floor((focus[2] + radius) / cs);
    const wants = [];
    for (let cx = c0x; cx <= c1x; cx++) {
      for (let cz = c0z; cz <= c1z; cz++) {
        if (cx < 0 || cz < 0 || cx >= t.chunksPerSide || cz >= t.chunksPerSide) continue;
        const ccx = cx * cs + cs / 2, ccz = cz * cs + cs / 2;
        const d = Math.sqrt(dist2(ccx, ccz, focus[0], focus[2]));
        if (d > radius) continue;
        // GÊNESIS-LOD: hysteresis — a resident chunk only changes ring when
        // CLEARLY beyond the boundary (±HYST u), so a camera hovering on a
        // ring border never flickers resolutions (measured: resChanges).
        const res = this._ringRes(cx, cz, d);
        wants.push({ cx, cz, res, d, key: this.key(cx, cz, res) });
      }
    }
    wants.sort((a, b) => a.d - b.d);

    let scheduledNow = 0;
    for (const w of wants) {
      if (!this.resident.has(w.key)) {
        const prevRes = this._residentRes(w.cx, w.cz);
        if (prevRes != null && prevRes !== w.res) this.stats.resChanges++;
        this.resident.set(w.key, {
          key: w.key, cx: w.cx, cz: w.cz, res: w.res,
          state: 'pending', priority: w.d, bytes: 0,
        });
        this.stats.scheduled++;
        scheduledNow++;
      }
    }

    // ---- evict far/out-of-range residents (never the truth — only residency)
    const wantKeys = new Set(wants.map(w => w.key));
    for (const [key, entry] of [...this.resident]) {
      if (wantKeys.has(key)) continue;
      // superseded resolution of a chunk that IS wanted at another ring:
      const wantedHere = wants.some(w => w.cx === entry.cx && w.cz === entry.cz);
      if (entry.state === 'ready' || wantedHere) {
        this.resident.delete(key);
        this.stats.evicted++;
      }
    }
    while (this.resident.size > this.maxResident) {
      let oldest = null;
      for (const e of this.resident.values()) if (!oldest || e.priority > oldest.priority) oldest = e;
      this.resident.delete(oldest.key);
      this.stats.evicted++;
    }

    // ---- load pending within the time budget (nearest first)
    const t0 = now();
    let loadedNow = 0;
    for (const entry of this.resident.values()) {
      if (entry.state !== 'pending') continue;
      if ((now() - t0) > budgetMs) { this.stats.budgetExhausted++; break; }
      // OUR persistent cache first: a hit reuses the chunk WITHOUT resampling
      // (sampling is pure — byte-exact equality is proven by tests).
      let patch = this.cache?.get(entry.cx, entry.cz, entry.res) ?? null;
      if (patch) this.stats.cacheHits++;
      else {
        patch = this.world.terrain.sampleChunk(entry.cx, entry.cz, entry.res);
        this.cache?.put(entry.cx, entry.cz, entry.res, {
          heights: patch.heights, biomes: patch.biomes, step: patch.step,
        });
      }
      entry.patch = {
        heights: patch.heights, biomes: patch.biomes,
        res: patch.res, step: patch.step,
      };
      entry.bytes = patch.heights.byteLength + patch.biomes.byteLength;
      entry.state = 'ready';
      entry.version = 1;
      this.stats.loaded++;
      loadedNow++;
    }
    // NOTE: residency is derived cache, not a layer effect — it never touches
    // the tese (a cache warming up is not an observable event of reality).
    return { scheduledNow, loadedNow, pending: this.pendingCount() };
  }

  /** current resident res for a chunk (null if not resident) */
  _residentRes(cx, cz) {
    for (const e of this.resident.values()) {
      if (e.cx === cx && e.cz === cz) return e.res;
    }
    return null;
  }

  /** ring resolution WITH hysteresis (boundaries 70/150, margin ±10u) */
  _ringRes(cx, cz, d) {
    const HYST = 10;
    const cur = this._residentRes(cx, cz);
    if (cur == null) return d < 70 ? 24 : d < 150 ? 16 : 8;
    if (cur === 24) return d < 70 + HYST ? 24 : 16;
    if (cur === 16) return d < 70 - HYST ? 24 : (d < 150 + HYST ? 16 : 8);
    return d < 150 - HYST ? 16 : 8;
  }

  pendingCount() {
    let n = 0;
    for (const e of this.resident.values()) if (e.state === 'pending') n++;
    return n;
  }

  /** ready patch or null (frame extraction only uses READY residency) */
  getPatch(cx, cz, res) {
    const entry = this.resident.get(this.key(cx, cz, res));
    if (!entry || entry.state !== 'ready') return null;
    return entry;
  }

  residentBytes() {
    let b = 0;
    for (const e of this.resident.values()) if (e.state === 'ready') b += e.bytes;
    return b;
  }

  report() {
    return {
      ...this.stats,
      resident: this.resident.size,
      pending: this.pendingCount(),
      bytes: this.residentBytes(),
    };
  }
}
