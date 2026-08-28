// UTS :: test/tese_do15 — every D layer must have operational, observable
// effects; D-O15 must measure, adapt, defer (never discard) and recover.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createUTS } from '../src/index.js';
import { TeseDosD } from '../src/d/tese.js';
import { DO15 } from '../src/d/do15.js';

test('tese: canonical layers registered, each with objective and observable', () => {
  const tese = new TeseDosD();
  const ids = tese.list().map(l => l.id);
  for (const d of ['D-0', 'D-1', 'D-2', 'D-3', 'D-4', 'D-5', 'D-6', 'D-7', 'D-8', 'D-9', 'D-10', 'D-11', 'D-12', 'D-13', 'D-14', 'D-O15']) {
    assert.ok(ids.includes(d), `missing ${d}`);
    assert.ok(tese.describe(d).objective.length > 5);
    assert.ok(tese.describe(d).observable.length > 5);
  }
});

test('tese: open extension — new layers of reality can be defined', () => {
  const tese = new TeseDosD();
  tese.define({ id: 'D-16', name: 'Magnetic', objective: 'represent magnetic phenomena' });
  assert.equal(tese.isEnabled('D-16'), true);
  assert.throws(() => tese.define({ id: 'D-16', name: 'dup' }));
});

test('tese: touch records observable effects from real systems', async () => {
  const uts = createUTS({ seed: 'tese-touch' });
  await uts.core.processObjective('criar uma pequena vila próxima a um rio chamada Tese');
  uts.ues.run(30);
  for (const d of ['D-0', 'D-2', 'D-3', 'D-4', 'D-5', 'D-6', 'D-7', 'D-8', 'D-12', 'D-14', 'D-O15']) {
    const eff = uts.tese.effect(d);
    assert.ok(eff, `layer ${d} produced no observable effect`);
    assert.ok(eff.count > 0);
  }
});

test('tese: D-9 ecology toggle changes reality (bush regrow)', async () => {
  const growTicks = 400;
  const withD9 = createUTS({ seed: 'eco' });
  const bush1 = withD9.world.spawnResource('bush', [100, 0, 100], { amount: 0, cap: 1, regrowDelay: 40 });
  withD9.ues.run(growTicks);
  const amtOn = withD9.rrw.getComponent(bush1.id, 'resource').amount;

  const noD9 = createUTS({ seed: 'eco' });
  noD9.tese.setEnabled('D-9', false);
  const bush2 = noD9.world.spawnResource('bush', [100, 0, 100], { amount: 0, cap: 1, regrowDelay: 40 });
  noD9.ues.run(growTicks);
  const amtOff = noD9.rrw.getComponent(bush2.id, 'resource').amount;

  assert.ok(amtOn > 0.5, `D-9 should regrow bushes (got ${amtOn})`);
  assert.equal(amtOff, 0, 'without D-9 nothing regrows');
});

test('tese: D-13 toggle stops knowledge spread (gossip)', async () => {
  const run = async (enabled) => {
    const uts = createUTS({ seed: 'gossip' });
    uts.tese.setEnabled('D-13', enabled);
    const a = uts.world.spawnNPC({ pos: [500, 0, 500] });
    const b = uts.world.spawnNPC({ pos: [500, 0, 502] });
    uts.rrw.getComponent(a.id, 'mind').knowledge.push('secret-entity');
    uts.rrw.getComponent(a.id, 'mind').needs.social = 0.95;
    uts.rrw.getComponent(a.id, 'mind').needs.energy = 1;
    uts.rrw.getComponent(a.id, 'mind').personality.sociability = 1;
    for (let i = 0; i < 30; i++) uts.ues.tick();
    return uts.rrw.getComponent(b.id, 'mind').knowledge.includes('secret-entity');
  };
  assert.equal(await run(true), true, 'knowledge should spread when D-13 active');
  assert.equal(await run(false), false, 'knowledge should not spread without D-13');
});

// ------------------------------------------------------------------ D-O15

test('do15: pressure raises from measured metrics and adapts strategy', () => {
  const do15 = new DO15({});
  // EMA hysteresis: sustained overload (frame 20ms vs 14ms budget) climbs to high/extreme
  for (let i = 0; i < 6; i++) do15.report({ frameMs: 20, simMs: 20 });
  assert.ok(do15.pressure > 0.7, `pressure climbed (${do15.pressure.toFixed(2)})`);
  assert.ok(['reduced', 'coarse'].includes(do15.strategy.perceptionResolution));
  // sustained relief recovers to full fidelity
  for (let i = 0; i < 8; i++) do15.report({ frameMs: 1, simMs: 1 });
  assert.equal(do15.strategy.perceptionResolution, 'full', 'strategy must recover after pressure ends');
});

test('do15: materialization respects distance AND importance (D-10 override)', () => {
  const do15 = new DO15({});
  assert.equal(do15.decideMaterialization(200, 0.95), 'full', 'important entities stay materialized far away');
  assert.equal(do15.decideMaterialization(30, 0), 'full');
  assert.equal(do15.decideMaterialization(70, 0), 'partial');
  assert.equal(do15.decideMaterialization(300, 0), 'abstract');
});

test('do15: perception resolution drops under pressure but reality is never discarded', () => {
  const do15 = new DO15({});
  const full = do15.decidePerception({ range: 24, cap: 12 });
  assert.equal(full.range, 24);
  for (let i = 0; i < 6; i++) do15.report({ frameMs: 30, simMs: 30 });
  const reduced = do15.decidePerception({ range: 24, cap: 12 });
  assert.ok(reduced.range < 24, 'range reduces under pressure');
  assert.ok(reduced.cap <= 12);
});

test('do15: DEFER NOT DISCARD — deferred work executes when budget returns', () => {
  let t = 0;
  const do15 = new DO15({});
  const ran = [];
  for (let i = 0; i < 5; i++) do15.defer(() => ran.push(i), `work-${i}`);

  // no budget at all -> nothing executes, nothing is lost
  const r0 = do15.runDeferred(0, () => t);
  assert.equal(r0.executed, 0);
  assert.equal(do15.deferred.length, 5);

  const r1 = do15.runDeferred(1000, () => (t += 10));
  assert.equal(r1.executed, 5);
  assert.equal(do15.deferred.length, 0);
  assert.deepEqual(ran, [0, 1, 2, 3, 4]);
  assert.equal(do15.deferredDone, 5);
});

test('do15: strategy changes are logged with reasons (auditable decisions)', () => {
  const do15 = new DO15({});
  const before = do15.decisions.length;
  for (let i = 0; i < 6; i++) do15.report({ frameMs: 40, simMs: 40, tick: 7 });
  assert.ok(do15.decisions.length > before, 'decision recorded');
  const last = do15.decisions.at(-1);
  assert.equal(last.kind, 'strategy');
  assert.ok(last.reason.includes('pressure'));
  assert.deepEqual(last.from, { materializationRadius: 90, updateEveryTicks: { full: 1, partial: 4, abstract: 0 }, perceptionResolution: 'full', terrainRadius: 220, terrainLodBias: 0, shadows: true, particleDensity: 1 });
});

test('do15: snapshot/restore keeps strategy+budget; pressure/metrics/defer are runtime-only', () => {
  const do15 = new DO15({});
  for (let i = 0; i < 6; i++) do15.report({ frameMs: 30, simMs: 30 });
  do15.defer(() => {}, 'x');
  const snap = JSON.parse(JSON.stringify(do15.snapshot()));
  const other = new DO15({});
  other.restore(snap);
  assert.equal(other.pressure, 0, 'pressure is host-timing evidence, not reality state');
  assert.equal(other.strategy.perceptionResolution, do15.strategy.perceptionResolution);
  assert.deepEqual(other.budget, do15.budget);
  assert.equal(other.deferred.length, 0, 'defer queue is runtime-only by design');
});
