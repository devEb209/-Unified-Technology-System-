// UTS :: test/chunk-cache — OUR persistent LRU terrain cache: byte-exact
// reuse of pure sampling, LRU under a byte budget, durable flush as ONE
// UTS-DB transaction, and honest statistics. Derived data, never truth.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createUTS } from '../src/index.js';
import { ChunkCache } from '../src/persistence/chunk-cache.js';
import { UTSDB, MemoryJournal, FileJournal } from '../src/persistence/utsdb.js';

test('cache: miss -> put -> hit is byte-exact vs a fresh sample (pure sampling proof)', () => {
  const uts = createUTS({ seed: 'cache-exact' });
  const db = new UTSDB({ journal: new MemoryJournal() });
  const cache = new ChunkCache(db, { byteBudget: 16 * 1024 * 1024 });
  const fresh = uts.world.terrain.sampleChunk(5, 5, 16);
  assert.equal(cache.get(5, 5, 16), null, 'first look is a miss');
  cache.put(5, 5, 16, { heights: fresh.heights, biomes: fresh.biomes, step: fresh.step });
  const hit = cache.get(5, 5, 16);
  assert.ok(hit, 'second look hits');
  assert.equal(hit.heights.length, fresh.heights.length);
  for (let i = 0; i < fresh.heights.length; i++) {
    assert.equal(hit.heights[i], fresh.heights[i], `height ${i} byte-exact`);
  }
  assert.deepEqual([...hit.biomes], [...fresh.biomes], 'biomes byte-exact');
  assert.equal(hit.res, 16);
  const r = cache.report();
  assert.equal(r.hits, 1);
  assert.equal(r.misses, 1);
  assert.equal(r.puts, 1);
  assert.ok(r.bytes > 0);
  assert.ok(cache.sum(5, 5, 16), 'integrity sum recorded');
});

test('cache: LRU under a tiny budget — the least recently used chunk is evicted first', () => {
  const uts = createUTS({ seed: 'cache-lru' });
  const db = new UTSDB({ journal: new MemoryJournal() });
  const oneChunk = 17 * 17 * 8 + 16; // res16 heights+biomes+overhead
  const cache = new ChunkCache(db, { byteBudget: oneChunk * 2.5 });
  const get = (cx, cz) => uts.world.terrain.sampleChunk(cx, cz, 16);
  cache.put(1, 1, 16, { ...g(get(1, 1)) });
  cache.put(2, 1, 16, { ...g(get(2, 1)) });
  cache.put(3, 1, 16, { ...g(get(3, 1)) }); // budget 2.5 → one eviction by now
  cache.get(2, 1, 16); // touch (2,1): MRU now
  cache.put(4, 1, 16, { ...g(get(4, 1)) }); // evicts (1,1) or (3,1), never (2,1)
  const alive = new Set();
  for (const cx of [1, 2, 3, 4]) if (cache.get(cx, 1, 16)) alive.add(cx);
  assert.ok(alive.has(2), `the touched chunk survives ((2,1) in ${[...alive]})`);
  assert.ok(alive.size <= 3, `bounded by budget (kept ${alive.size})`);
  assert.ok(cache.report().evictions >= 1, 'evictions are counted');
  function g(p) { return { heights: p.heights, biomes: p.biomes, step: p.step }; }
});

test('cache: flush + RESTART — a fresh UTS-DB on the same journal serves pure hits', async () => {
  const os = await import('node:os');
  const path = await import('node:path');
  const fs = await import('node:fs/promises');
  const dir = await fs.mkdtemp(path.join(os.tmpdir(), 'uts-chunkcache-'));
  const jpath = path.join(dir, 'j.utslog');

  const uts = createUTS({ seed: 'cache-restart' });
  const j1 = new FileJournal(jpath);
  const db1 = new UTSDB({ journal: j1 });
  await db1.open();
  const c1 = new ChunkCache(db1);
  const fresh = uts.world.terrain.sampleChunk(7, 7, 24);
  c1.put(7, 7, 24, { heights: fresh.heights, biomes: fresh.biomes, step: fresh.step });
  const f1 = await c1.flush();
  assert.equal(f1.written, 1, 'flush wrote the chunk');

  // "process 2": same journal, cold memory
  const db2 = new UTSDB({ journal: new FileJournal(jpath) });
  await db2.open();
  const c2 = new ChunkCache(db2);
  assert.equal(c2.report().hits, 0);
  const hit = c2.get(7, 7, 24);
  assert.ok(hit, 'survives the restart (durable)');
  assert.equal(hit.heights.length, fresh.heights.length);
  assert.equal(hit.heights[100], fresh.heights[100], 'still byte-exact after the roundtrip');
  assert.equal(c2.report().hits, 1, 'a durable chunk is a HIT, not a resample');
  const f2 = await c2.flush();
  assert.equal(f2.written, 0, 'nothing dirty — flush is a no-op');
});

test('cache: streaming integration — second pass over the same ground = all hits, same patches', async () => {
  const uts = createUTS({ seed: 'cache-stream' });
  const db = new UTSDB({ journal: new MemoryJournal() });
  uts.world.streaming.cache = new ChunkCache(db);

  uts.world.streaming.update([480, 40, 480], { radius: 220, budgetMs: 1e9 });
  const first = uts.world.streaming.report();
  const patchesNoCache = [];
  for (const e of uts.world.streaming.resident.values()) {
    patchesNoCache.push([...e.patch.heights].slice(0, 8).join(','));
  }
  uts.world.streaming.resident.clear();

  uts.world.streaming.update([480, 40, 480], { radius: 220, budgetMs: 1e9 });
  const second = uts.world.streaming.report();
  const patchesCached = [];
  for (const e of uts.world.streaming.resident.values()) {
    patchesCached.push([...e.patch.heights].slice(0, 8).join(','));
  }
  assert.deepEqual(patchesCached, patchesNoCache, 'cached patches are identical to sampled ones');
  assert.ok(second.cacheHits > 0, `second pass hit the cache (${second.cacheHits}/${first.loaded})`);
  await uts.world.streaming.cache.flush();
  assert.ok(uts.world.streaming.cache.report().flushes === 1);
});
