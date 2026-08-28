// UTS :: test/autosave — OUR checkpoint journaling: compressed atomic
// checkpoints in OUR UTS-DB, loud crash recovery, bounded retention,
// byte-identical determinism after restore. Nothing silent, nothing fake.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createUTS } from '../src/index.js';
import { createAutosave, AutosaveManager } from '../src/persistence/autosave.js';
import { UTSDB, MemoryJournal } from '../src/persistence/utsdb.js';
import { serializeState } from '../src/persistence/snapshot.js';
import { fnv1a } from '../src/core/math.js';

const boot = async (seed = 'auto') => {
  const uts = createUTS({ seed });
  await uts.core.processObjective('criar uma vila chamada Aurora perto de um rio');
  uts.ues.run(120);
  return uts;
};

test('autosave: checkpoints are written on the tick boundary and keyed by tick', async () => {
  const uts = await boot('auto1');
  const db = new UTSDB({ journal: new MemoryJournal() });
  await db.open();
  const mgr = createAutosave(uts, db, { everyTicks: 100 });
  assert.equal(mgr.shouldSave(50), false, 'before the boundary');
  assert.equal(mgr.shouldSave(120), true, 'past the boundary');
  const r = await mgr.maybeSave();
  assert.ok(r && r.tick === 120 && r.bytes > 0);
  assert.deepEqual(await db.keys('checkpoints'), ['cp:120']);
  assert.equal(mgr.shouldSave(150), false, 'boundary moved');
  assert.equal(mgr.shouldSave(230), true);
});

test('autosave: recover() restores reality and the continuation is byte-identical', async () => {
  const uts = await boot('auto2');
  const db = new UTSDB({ journal: new MemoryJournal() });
  await db.open();
  const mgr = createAutosave(uts, db, { everyTicks: 40 });
  await mgr.maybeSave(); // cp:120
  uts.ues.run(40);
  await mgr.maybeSave(); // cp:160

  const { uts: restored } = await mgr.recover();
  assert.equal(restored.world.clock.tick, 160);
  assert.equal(restored.rrw.count('npc'), uts.rrw.count('npc'));
  assert.deepEqual(restored.rrw.snapshot(), uts.rrw.snapshot(), 'same reality at the checkpoint');
  // both evolve identically after restore
  restored.ues.run(50); uts.ues.run(50);
  assert.deepEqual(serializeState(restored), serializeState(uts), 'A==B after checkpoint restore + ticks');
});

test('autosave: CRASH — corrupt newest checkpoint is stepped over LOUDLY, older wins', async () => {
  const uts = await boot('auto3');
  const db = new UTSDB({ journal: new MemoryJournal() });
  await db.open();
  const mgr = createAutosave(uts, db, { everyTicks: 40 });
  await mgr.maybeSave(); // cp:120 good
  uts.ues.run(60);
  await mgr.maybeSave(); // cp:180 (we corrupt it below)

  await db.begin();
  const bad = await db.get('checkpoints', 'cp:180');
  await db.commit();
  await db.put('checkpoints', 'cp:180', { ...bad, data: bad.data.slice(0, 40) + 'AAAA' + bad.data.slice(44) });

  const r = await mgr.recover();
  assert.equal(r.restoredTick, 120, 'recovered from the OLDER valid checkpoint');
  assert.equal(r.skipped.length, 1);
  assert.match(r.skipped[0].reason, /checksum|mismatch|malformed/, 'the skip says WHY');
  assert.equal(mgr.stats.skippedCorrupt, 1);
  assert.equal(r.uts.world.clock.tick, 120);
});

test('autosave: zero valid checkpoints fails LOUD (never a silent empty world)', async () => {
  const uts = await boot('auto4');
  const db = new UTSDB({ journal: new MemoryJournal() });
  await db.open();
  const mgr = createAutosave(uts, db, { everyTicks: 60 });
  await mgr.maybeSave();
  const keys = await db.keys('checkpoints');
  const rec = await db.get('checkpoints', keys[0]);
  await db.put('checkpoints', keys[0], { ...rec, data: 'not-base64-gzip at all ###' });
  await assert.rejects(() => mgr.recover(), /all 1 checkpoint|corrupt/);
});

test('autosave: retention keeps newest N + stride anchors — history is bounded', async () => {
  const uts = await boot('auto5');
  const db = new UTSDB({ journal: new MemoryJournal() });
  await db.open();
  const mgr = createAutosave(uts, db, { everyTicks: 20, keep: 3, stride: 4 });
  for (let g = 1; g <= 8; g++) {
    uts.ues.run(20);
    await mgr.save();
  }
  const ticks = (await db.keys('checkpoints')).map(k => Number(k.slice(3))).sort((a, b) => a - b);
  assert.ok(ticks.length <= 6, `bounded history (kept ${ticks.length}: ${ticks})`);
  assert.ok(ticks.includes(280), 'newest kept (boot 120 + 8×20)');
  assert.ok(ticks.includes(140), 'the first generation anchor survived');
  assert.ok(ticks.every(t => t % 20 === 0), 'checkpoint ticks align with the boundary');
});

test('autosave: compression + integrity are measured (ratio, sha via fnv, ms)', async () => {
  const uts = await boot('auto6');
  const db = new UTSDB({ journal: new MemoryJournal() });
  await db.open();
  const mgr = createAutosave(uts, db, { everyTicks: 100 });
  await mgr.save();
  assert.ok(mgr.stats.bytesGz > 0 && mgr.stats.bytesGz < mgr.stats.bytesRaw, 'gzip actually compresses');
  assert.ok(mgr.stats.lastRatio > 1.5, `compression ratio measured (${mgr.stats.lastRatio.toFixed(2)}×)`);
  assert.ok(mgr.stats.lastMs >= 0, 'save duration measured');
  const rec = await db.get('checkpoints', 'cp:120');
  assert.equal(fnv1a(rec.data), rec.sum, 'integrity field verifies');
  assert.equal(rec.algo, 'gzip');
});

test('autosave: file-backed journal — checkpoint survives a fresh process (end-to-end)', async () => {
  const os = await import('node:os');
  const path = await import('node:path');
  const fs = await import('node:fs/promises');
  const dir = await fs.mkdtemp(path.join(os.tmpdir(), 'uts-autosave-'));
  const file = path.join(dir, 'journal.utslog');

  let restoredTick;
  { // "process 1": simulate, autosave, leave
    const uts = await boot('auto7');
    const db = new UTSDB({ journal: new (await import('../src/persistence/utsdb.js')).FileJournal(file) });
    await db.open();
    const mgr = createAutosave(uts, db, { everyTicks: 60 });
    await mgr.maybeSave();
    await db.close?.();
  }
  { // "process 2": recover WITHOUT the live world
    const db = new UTSDB({ journal: new (await import('../src/persistence/utsdb.js')).FileJournal(file) });
    await db.open();
    const mgr = new AutosaveManager(null, db);
    const r = await mgr.recover();
    restoredTick = r.restoredTick;
    assert.equal(r.uts.world.clock.tick, 120);
    assert.ok(r.uts.rrw.count('settlement') >= 1, 'the village survived the process boundary');
  }
  assert.equal(restoredTick, 120);
});
