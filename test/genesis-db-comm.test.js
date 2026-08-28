// UTS :: test/genesis-db-comm — OUR database (UTS-DB) and OUR comm layer.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { UTSDB, MemoryJournal, FileJournal, UTSDBError } from '../src/persistence/utsdb.js';
import { Comm, CommError } from '../src/core/comm.js';
import { createUTS, createPlatform } from '../src/index.js';

test('utsdb: put/get/delete through journal replay', async () => {
  const db = new UTSDB({ journal: new MemoryJournal() });
  await db.open();
  await db.put('worlds', 'a', 'alpha');
  await db.put('worlds', 'b', 'beta');
  await db.del('worlds', 'a');

  const db2 = new UTSDB({ journal: db.journal }); // "restart"
  await db2.open();
  assert.equal(db2.get('worlds', 'a'), undefined, 'delete survived');
  assert.equal(db2.get('worlds', 'b'), 'beta');
  assert.deepEqual(db2.keys('worlds'), ['b']);
});

test('utsdb: transactions — rollback discards, commit applies atomically', async () => {
  const db = new UTSDB({ journal: new MemoryJournal() });
  await db.open();
  await db.put('t', 'x', '1');

  await db.begin();
  db.stagePut('t', 'x', '2');
  db.stagePut('t', 'y', 'new');
  assert.equal(db.get('t', 'x'), '2', 'staged reads inside the tx');
  await db.rollback();
  assert.equal(db.get('t', 'x'), '1', 'rollback discards');
  assert.equal(db.get('t', 'y'), undefined);

  await db.begin();
  db.stagePut('t', 'x', '2');
  await db.commit();
  assert.equal(db.get('t', 'x'), '2');
  await assert.rejects(async () => db.stagePut('t', 'z', '9'), UTSDBError, 'staging outside a tx fails');
});

test('utsdb: CRASH SAFETY — torn tail ignored, mid-journal corruption fails loud', async () => {
  const j = new MemoryJournal();
  const db = new UTSDB({ journal: j });
  await db.open();
  await db.put('c', 'a', '1');
  j.lines.push('{"op":"put","col":"c"'); // torn tail (crash mid-append)
  const db2 = new UTSDB({ journal: j });
  const res = await db2.open();
  assert.equal(res.tornTails, 1, 'torn tail ignored');
  assert.equal(db2.get('c', 'a'), '1');

  const j3 = new MemoryJournal();
  j3.lines.push('garbage {"op":"put"', '{"op":"put","col":"c","key":"a","val":"1"}');
  const db3 = new UTSDB({ journal: j3 });
  await assert.rejects(() => db3.open(), /corrupted journal line 1/);
});

test('utsdb: compaction rewrites the journal preserving state', async () => {
  const j = new MemoryJournal();
  const db = new UTSDB({ journal: j });
  await db.open();
  for (let i = 0; i < 50; i++) await db.put('c', 'hot', 'v' + i);
  const opsBefore = j.lines.length;
  await db.compact();
  assert.ok(j.lines.length < opsBefore, `compacted (${j.lines.length} < ${opsBefore})`);
  const db2 = new UTSDB({ journal: j });
  await db2.open();
  assert.equal(db2.get('c', 'hot'), 'v49', 'state identical after compaction');
  assert.equal(db2.stats.compactions, 0, 'compaction count is per-instance stats');
});

test('utsdb: secondary indexes answer field queries', async () => {
  const db = new UTSDB({ journal: new MemoryJournal() });
  await db.open();
  await db.put('npcs', 'e1', { name: 'Ana', village: 'Norte' });
  await db.put('npcs', 'e2', { name: 'Bia', village: 'Sul' });
  await db.put('npcs', 'e3', { name: 'Caio', village: 'Norte' });
  db.createIndex('npcs', 'village');
  assert.deepEqual(db.findBy('npcs', 'village', 'Norte'), ['e1', 'e3']);
  await db.put('npcs', 'e4', { name: 'Duda', village: 'Norte' });
  assert.equal(db.findBy('npcs', 'village', 'Norte').length, 3, 'index is maintained live on put (documented)');
  assert.throws(() => db.findBy('npcs', 'name', 'Ana'), /no index/);
});

test('utsdb: FileJournal roundtrip on the real filesystem', async () => {
  const os = await import('node:os');
  const path = await import('node:path');
  const fs = await import('node:fs/promises');
  const dir = await fs.mkdtemp(path.join(os.tmpdir(), 'uts-db-'));
  const j = new FileJournal(path.join(dir, 'world.utsdb'));
  const db = new UTSDB({ journal: j });
  await db.open();
  await db.put('save', 'slot', 'genesis');
  const db2 = new UTSDB({ journal: j });
  await db2.open();
  assert.equal(db2.get('save', 'slot'), 'genesis');
  await db2.compact();
  assert.equal((await j.readAll()).length, 1);
});

test('utsdb: StorageBackend adapter powers the PLATFORM (apps survive restart)', async () => {
  const db = new UTSDB({ journal: new MemoryJournal() });
  await db.open();
  const p1 = createPlatform({ storage: db.asStorage('platform') });
  const app = await p1.apps.install({ kind: 'counter', name: 'DB App' });
  await p1.apps.act(app.id, 'increment');
  const p2 = createPlatform({ storage: db.asStorage('platform') });
  await p2.apps.boot();
  const view = p2.apps.view(p2.apps.list()[0].id);
  assert.equal(view.value, 1, 'app state came from OUR database');
  assert.ok(db.report().ops > 0);
});

test('comm: OUR request/response, routes, timeouts, events, metrics', async () => {
  const comm = new Comm();
  comm.route('add', ({ a, b }) => a + b);
  comm.route('fail', () => { throw new Error('boom'); });
  assert.equal(await comm.request('add', { a: 2, b: 3 }), 5);
  await assert.rejects(() => comm.request('nope', {}), CommError);
  await assert.rejects(() => comm.requestWithTimeout('fail', {}, { timeoutMs: 20 }), /boom/);

  let hangResolved = false;
  comm.route('hang', () => new Promise(() => { hangResolved = true; }));
  void hangResolved;
  await assert.rejects(() => comm.requestWithTimeout('hang', {}, { timeoutMs: 15 }), /timed out/);

  const seen = [];
  comm.on('ping', p => seen.push(p));
  comm.emit('ping', { x: 1 });
  assert.deepEqual(seen, [{ x: 1 }]);

  const rep = comm.report();
  assert.ok(rep.requests >= 3 && rep.timeouts >= 1);
});

test('comm: platform modules communicate through routes (ask + status)', async () => {
  const platform = createPlatform();
  const uts = createUTS({ seed: 'comm-plat', platform });
  const report = await platform.comm.request('ask', { objective: 'criar uma pequena vila próxima a um rio chamada Comms' });
  assert.equal(report.ok, true);
  const status = await platform.comm.request('system.status', {});
  assert.equal(status.platform, 'UTS');
  assert.ok(uts.rrw.count('settlement') === 1);
});
