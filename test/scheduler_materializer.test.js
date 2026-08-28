// UTS :: test/scheduler_materializer — budgeted scheduling (defer, not drop)
// and focus-driven materialization with state preservation.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { Scheduler } from '../src/ues/scheduler.js';
import { createUTS } from '../src/index.js';

test('scheduler: priority order is respected', () => {
  const ran = [];
  const s = new Scheduler({});
  s.add({ name: 'c', priority: 30, fn: () => ran.push('c') });
  s.add({ name: 'a', priority: 10, fn: () => ran.push('a') });
  s.add({ name: 'b', priority: 20, fn: () => ran.push('b') });
  s.tick(0.05);
  assert.deepEqual(ran, ['a', 'b', 'c']);
});

test('scheduler: unlimited budget runs every system every tick', () => {
  const s = new Scheduler({});
  let n = 0;
  s.add({ name: 'x', priority: 1, fn: () => n++ });
  s.add({ name: 'y', priority: 2, fn: () => n++ });
  s.tick(0.05); s.tick(0.05);
  assert.equal(n, 4);
  assert.deepEqual(s.last.skipped, []);
});

test('scheduler: budget exceeded -> systems deferred to NEXT tick, never dropped', () => {
  let t = 0;
  const now = () => t;
  const s = new Scheduler({ now, globalBudgetMs: 10 });
  const ran = [];
  s.add({ name: 'heavy', priority: 1, fn: () => { t += 9; ran.push('heavy'); } });
  s.add({ name: 'mid', priority: 2, fn: () => { t += 9; ran.push('mid'); } });
  s.add({ name: 'late', priority: 3, fn: () => { t += 1; ran.push('late'); } });

  const r1 = s.tick(0.05);
  assert.deepEqual(r1.ran, ['heavy', 'mid']);
  assert.deepEqual(r1.skipped, ['late']);

  t = 0; // budget resets next tick
  const r2 = s.tick(0.05);
  assert.ok(r2.ran.includes('late'), 'deferred system ran on the next tick');
  assert.equal(s.getSystem('late').skipped, 1);
  assert.ok(ran.filter(x => x === 'late').length === 1);
});

test('scheduler: stats report honest averages and skips', () => {
  let t = 0;
  const s = new Scheduler({ now: () => t });
  s.add({ name: 'sys', priority: 1, fn: () => { t += 2; } });
  s.tick(0.05); t += 10; s.tick(0.05);
  const st = s.stats()[0];
  assert.equal(st.runs, 2);
  assert.ok(st.avgMs > 0);
  assert.equal(st.skipped, 0);
});

// ------------------------------------------------------- materialization

test('materializer: full/partial/abstract by distance with importance override (D-10)', async () => {
  const uts = createUTS({ seed: 'mat-dist' });
  const near = uts.world.spawnNPC({ pos: [520, 0, 500] });
  const mid = uts.world.spawnNPC({ pos: [560, 0, 500] });
  const far = uts.world.spawnNPC({ pos: [660, 0, 500] });
  const importantFar = uts.world.spawnNPC({ pos: [700, 0, 500] });
  uts.rrw.get(importantFar.id).importance = 0.95;
  for (const n of [near, mid, far]) uts.rrw.get(n.id).importance = 0;

  uts.ues.moveCamera([500, 40, 500]);
  uts.world.updateMaterialization(uts.ues.camera.pos);

  assert.equal(uts.rrw.get(near.id).materialization, 'full');   // 20m < 54m
  assert.equal(uts.rrw.get(mid.id).materialization, 'partial'); // 60m < 97m
  assert.equal(uts.rrw.get(far.id).materialization, 'abstract'); // 160m
  assert.equal(uts.rrw.get(importantFar.id).materialization, 'full', 'importance overrides distance');
});

test('materializer: budget cap degrades farthest partial NPCs first', async () => {
  const uts = createUTS({ seed: 'mat-budget' });
  uts.do15.strategy.maxMaterialized = 2;
  const ids = [];
  for (let i = 0; i < 5; i++) {
    const n = uts.world.spawnNPC({ pos: [500 + i * 3, 0, 500] });
    uts.rrw.get(n.id).importance = 0;
    ids.push(n.id);
  }
  uts.ues.moveCamera([500, 40, 500]);
  uts.world.updateMaterialization(uts.ues.camera.pos);
  const matCount = uts.rrw.query({ kind: 'npc', materialization: 'full' }).length
    + uts.rrw.query({ kind: 'npc', materialization: 'partial' }).length;
  assert.ok(matCount <= 2, `budget enforced (${matCount})`);
  // entities were NEVER destroyed — only abstracted
  assert.equal(uts.rrw.count('npc'), 5);
});

test('materializer: abstract->materialize roundtrip preserves mind state (D-14 invariant)', async () => {
  const uts = createUTS({ seed: 'mat-state' });
  const npc = uts.world.spawnNPC({ pos: [500, 0, 500] });
  const mind = uts.rrw.getComponent(npc.id, 'mind');
  mind.memory.push({ tick: 1, kind: 'decision', action: 'eat', because: [] });
  mind.knowledge.push('e42');
  mind.needs.hunger = 0.7;
  uts.rrw.addRelation(npc.id, npc.id, 'selfref', { weight: 1 }); // relations survive

  uts.rrw.setMaterialization(npc.id, 'abstract', { reason: 'test', tick: 2 });
  uts.rrw.setMaterialization(npc.id, 'full', { reason: 'test back', tick: 3 });

  const after = uts.rrw.getComponent(npc.id, 'mind');
  assert.equal(after.memory.length, 1);
  assert.deepEqual(after.knowledge, ['e42']);
  assert.equal(after.needs.hunger, 0.7);
  assert.ok(uts.rrw.getRelation(npc.id, npc.id, 'selfref'));
  assert.equal(uts.rrw.get(npc.id).id, npc.id, 'identity preserved');
});

test('materializer: hazards are always materialized (events must be visible)', async () => {
  const uts = createUTS({ seed: 'mat-fire' });
  const strike = uts.rrw.emitEvent({ type: 'reallife.lightning.strike', cause: null, data: {}, tick: 0 });
  // fire needs FUEL now (ADR-019): strike dry grass ~570m from the camera;
  // the hazard anchor must STILL materialize fully (events must be visible)
  const spot = [950, 0, 950]; // dry grass (fuel 0.55) — verified above sea level
  const fire = uts.world.reallife.igniteFire(spot, strike);
  assert.ok(fire, 'dry grass ignites (fuel is respected)');
  uts.ues.moveCamera([500, 40, 500]);
  uts.world.updateMaterialization(uts.ues.camera.pos);
  assert.equal(uts.rrw.get(fire).materialization, 'full', 'fire stays materialized 570m away');
});
