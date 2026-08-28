// UTS :: persistence/chunk-cache — OUR persistent LRU terrain cache.
//
//   StreamingSystem --(miss)--> sampleChunk() --(put)--> ChunkCache
//        |--(hit)--> chunk reused, NO resample
//   host-side flush() --> ONE UTS-DB transaction --> journal (durable)
//
// Terrain sampling is a PURE function of (seed, cx, cz, res): caching it
// cannot change reality — derived data with byte-exact equality, proven by
// tests. Reads are synchronous (mirror-first, journal fallback); writes
// queue in memory and flush as a single atomic transaction — the same
// host-side pattern as autosave, never inside a tick. LRU by use counter
// with a byte budget; evictions delete durably at the next flush. After a
// restart the LRU ORDER resets (documented: order is cosmetic, contents
// and integrity are durable).
// Node-side (Buffer/base64); the browser demo simply doesn't attach one.

import { fnv1a } from '../core/math.js';

const arrToB64 = (arr) => Buffer.from(arr.buffer, arr.byteOffset, arr.byteLength).toString('base64');
const b64ToF32 = (b64, len) => {
  const buf = Buffer.from(b64, 'base64');
  const out = new Float32Array(len);
  for (let i = 0; i < len; i++) out[i] = buf.readFloatLE(i * 4); // explicit, pool-proof
  return out;
};
const b64ToU8 = (b64, len) => {
  const buf = Buffer.from(b64, 'base64');
  const out = new Uint8Array(len);
  for (let i = 0; i < len; i++) out[i] = buf.readUInt8(i);
  return out;
};

export class ChunkCache {
  constructor(db, { col = 'terrain', lruCol = 'terrain-lru', byteBudget = 4 * 1024 * 1024 } = {}) {
    this.db = db;
    this.col = col;
    this.lruCol = lruCol;
    this.byteBudget = byteBudget;
    this.useN = 0;
    /** key -> record (mirror of the durable state + fresh puts) */
    this.recs = new Map();
    /** key -> {n, bytes} LRU bookkeeping (memory-only order) */
    this.lru = new Map();
    this.dirty = new Set();     // keys to write at flush
    this.tombstones = new Set(); // keys to delete at flush
    this.stats = { hits: 0, misses: 0, puts: 0, evictions: 0, bytes: 0, flushes: 0 };
  }

  _key(cx, cz, res) { return `t:${cx}:${cz}:${res}:v1`; }

  /** cached patch or null; touch on hit; synchronous by contract */
  get(cx, cz, res) {
    const key = this._key(cx, cz, res);
    let rec = this.recs.get(key);
    if (!rec) {
      const raw = this.db.get(this.col, key);
      if (!raw) { this.stats.misses++; return null; }
      rec = raw;
      this.recs.set(key, rec); // hydrate the mirror once
    }
    const heights = b64ToF32(rec.heights, rec.n);
    const biomes = rec.biomesType === 'Uint8Array' ? b64ToU8(rec.biomes, rec.n) : b64ToF32(rec.biomes, rec.n);
    this.useN++;
    this.lru.set(key, { n: this.useN, bytes: rec.bytes });
    this.stats.hits++;
    this._account();
    return {
      heights, biomes, res: rec.res, step: rec.step,
      x0: cx * rec.step * rec.res, z0: cz * rec.step * rec.res,
      size: rec.step * rec.res,
    };
  }

  /** store a sampled patch (idempotent; byte-exact by construction) */
  put(cx, cz, res, { heights, biomes, step }) {
    const key = this._key(cx, cz, res);
    if (this.recs.has(key) || this.db.get(this.col, key)) return false;
    const n = heights.length;
    const hb = arrToB64(heights), bb = arrToB64(biomes);
    const rec = { n, res, step, heights: hb, biomes: bb, biomesType: biomes.constructor.name,
                  bytes: n * 8 + 16, sum: fnv1a(hb + bb) };
    this.recs.set(key, rec);
    this.tombstones.delete(key);
    this.dirty.add(key);
    this.useN++;
    this.lru.set(key, { n: this.useN, bytes: rec.bytes });
    this.stats.puts++;
    this._account();
    return true;
  }

  /** recorded integrity sum for a key (audit) */
  sum(cx, cz, res) { return this.recs.get(this._key(cx, cz, res))?.sum ?? this.db.get(this.col, this._key(cx, cz, res))?.sum ?? null; }

  _account() {
    let bytes = 0;
    for (const l of this.lru.values()) bytes += l.bytes;
    this.stats.bytes = bytes;
    if (bytes <= this.byteBudget) return 0;
    let evicted = 0;
    const ordered = [...this.lru.entries()].sort((a, b) => a[1].n - b[1].n);
    for (const [key, l] of ordered) {
      if (bytes <= this.byteBudget) break;
      this.recs.delete(key);
      this.lru.delete(key);
      this.dirty.delete(key);
      this.tombstones.add(key);
      bytes -= l.bytes;
      evicted++;
      this.stats.evictions++;
    }
    this.stats.bytes = bytes;
    return evicted;
  }

  /** host-side (between ticks): ONE atomic transaction makes the cache durable */
  async flush() {
    if (this.dirty.size === 0 && this.tombstones.size === 0) return { written: 0, deleted: 0 };
    await this.db.begin();
    for (const key of this.dirty) {
      this.db.stagePut(this.col, key, this.recs.get(key));
      this.db.stagePut(this.lruCol, key, { n: this.lru.get(key)?.n ?? 0 });
    }
    for (const key of this.tombstones) {
      this.db.stageDelete(this.col, key);
      this.db.stageDelete(this.lruCol, key);
    }
    const written = this.dirty.size, deleted = this.tombstones.size;
    await this.db.commit();
    this.dirty.clear();
    this.tombstones.clear();
    this.stats.flushes++;
    return { written, deleted };
  }

  report() { return { ...this.stats }; }
}
