// UTS :: test/rrw — the representation core: entities, components, relations,
// verified causality, processes, materialization, snapshots.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { RRW, MATERIALIZATION, CausalityError, SnapshotError } from '../src/rrw/registry.js';
import { RNG } from '../src/core/rng.js';

function makeRRW() {
  return new RRW({ rng: new RNG('rrw-test'), eventCap: 100 });
}

test('rrw: entities exist with stable identity and components (D-0)', () => {
  const rrw = makeRRW();
  const e = rrw.createEntity({ kind: 'npc', components: { mind: { hunger: 0.2 } }, pos: [1, 0, 2] });
  assert.ok(e.id.startsWith('e'));
  assert.equal(rrw.get(e.id).kind, 'npc');
  assert.equal(rrw.getComponent(e.id, 'mind').hunger, 0.2);
  assert.deepEqual(rrw.getComponent(e.id, 'spatial').pos, [1, 0, 2]);
  assert.throws(() => rrw.require('nope'), /not found/);
});

test('rrw: patchComponent merges deeply without replacing siblings', () => {
  const rrw = makeRRW();
  const e = rrw.createEntity({ components: { mind: { needs: { hunger: 0.1, energy: 1 }, memory: [] } } });
  rrw.patchComponent(e.id, 'mind', { needs: { hunger: 0.9 } });
  const mind = rrw.getComponent(e.id, 'mind');
  assert.equal(mind.needs.hunger, 0.9);
  assert.equal(mind.needs.energy, 1);
  assert.deepEqual(mind.memory, []);
});

test('rrw: relations typed, deduped and queryable (D-1)', () => {
  const rrw = makeRRW();
  const a = rrw.createEntity({ kind: 'npc' });
  const b = rrw.createEntity({ kind: 'npc' });
  const r1 = rrw.addRelation(a.id, b.id, 'knows', { weight: 0.2 });
  rrw.addRelation(a.id, b.id, 'knows', { weight: 0.5 });
  assert.equal(rrw.getRelations(a.id, { type: 'knows' }).length, 1);
  assert.equal(rrw.getRelation(a.id, b.id, 'knows').weight, 0.5);
  assert.ok(r1.id.startsWith('r'));
  assert.deepEqual(rrw.getRelations(b.id).map(r => r.id), [r1.id]);
});

test('rrw: causality is verified by construction — fabricating a cause throws (D-2)', () => {
  const rrw = makeRRW();
  assert.throws(() => rrw.emitEvent({ type: 'b', cause: 'ev999' }), CausalityError);
  const root = rrw.emitEvent({ type: 'a', tick: 1 });
  const child = rrw.emitEvent({ type: 'b', cause: root, tick: 2 });
  const grand = rrw.emitEvent({ type: 'c', cause: child, tick: 3 });
  const chain = rrw.causalityChain(grand);
  assert.deepEqual(chain.map(e => e.type), ['c', 'b', 'a']);
  const verdict = rrw.verifyCausalChain(grand);
  assert.equal(verdict.valid, true);
  assert.equal(verdict.depth, 2);
});

test('rrw: exogenous events allowed with cause null', () => {
  const rrw = makeRRW();
  const id = rrw.emitEvent({ type: 'world.init' });
  assert.equal(rrw.verifyCausalChain(id).valid, true);
});

test('rrw: processes evolve through registered types with serializable state', () => {
  const rrw = makeRRW();
  rrw.registerProcessType('grow', {
    evolveAbstract: (s, dt) => { s.amount += dt; },
    evolveDetailed: (s, dt) => { s.amount += dt * 2; },
  });
  const p = rrw.createProcess('grow', { state: { amount: 0 }, level: 'abstract' });
  rrw.evolveProcess(p.id, 2, {});
  assert.equal(rrw.processes.get(p.id).state.amount, 2);
  rrw.processes.get(p.id).level = 'detailed';
  rrw.evolveProcess(p.id, 2, {});
  assert.equal(rrw.processes.get(p.id).state.amount, 6);
});

test('rrw: unknown process type rejected', () => {
  const rrw = makeRRW();
  assert.throws(() => rrw.createProcess('nope'), /unknown process type/);
});

test('rrw: materialization transitions are recorded, abstraction never silent (D-14)', () => {
  const rrw = makeRRW();
  const e = rrw.createEntity({ materialization: MATERIALIZATION.FULL });
  rrw.setMaterialization(e.id, MATERIALIZATION.ABSTRACT, { reason: 'far away', tick: 5 });
  const rec = rrw.get(e.id);
  assert.equal(rec.materialization, 'abstract');
  assert.equal(rec.matHistory[0].reason, 'far away');
  assert.equal(rec.matHistory[0].from, 'full');
  assert.equal(rrw.stats.abstracted, 1);
});

test('rrw: queries filter by kind/materialization/component/predicate', () => {
  const rrw = makeRRW();
  rrw.createEntity({ kind: 'npc', materialization: 'full' });
  rrw.createEntity({ kind: 'npc', materialization: 'abstract', components: { mind: {} } });
  rrw.createEntity({ kind: 'tree', materialization: 'full' });
  assert.equal(rrw.query({ kind: 'npc' }).length, 2);
  assert.equal(rrw.query({ kind: 'npc', materialization: 'full' }).length, 1);
  assert.equal(rrw.query({ hasComponent: 'mind' }).length, 1);
  assert.equal(rrw.query({ kind: 'npc', predicate: e => e.materialization === 'abstract' }).length, 1);
  assert.equal(rrw.count('tree'), 1);
});

test('rrw: snapshot/restore roundtrip preserves everything exactly', () => {
  const rrw = makeRRW();
  const a = rrw.createEntity({ kind: 'npc', pos: [3, 0, 4], components: { mind: { hunger: 0.4 } } });
  const b = rrw.createEntity({ kind: 'npc', pos: [8, 0, 9] });
  rrw.addRelation(a.id, b.id, 'knows', { weight: 0.3 });
  const root = rrw.emitEvent({ type: 'x', tick: 1 });
  rrw.emitEvent({ type: 'y', cause: root, tick: 2 });
  rrw.registerProcessType('grow', { evolveAbstract: () => {}, evolveDetailed: () => {} });
  rrw.createProcess('grow', { state: { amount: 3 } });
  rrw.setMaterialization(b.id, 'partial', { reason: 'mid', tick: 3 });

  const snap = rrw.snapshot();
  // process BEHAVIOR is code — restore receives the registered implementation
  const restored = RRW.restore(JSON.parse(JSON.stringify(snap)), {
    processTypes: new Map([['grow', { evolveAbstract: () => {}, evolveDetailed: () => {} }]]),
  });
  assert.deepEqual(restored.snapshot(), snap);
});

test('rrw: restore rejects snapshots with broken relation references', () => {
  const rrw = makeRRW();
  const a = rrw.createEntity({ kind: 'npc' });
  const b = rrw.createEntity({ kind: 'npc' });
  rrw.addRelation(a.id, b.id, 'knows', { weight: 1 });
  const snap = rrw.snapshot();
  // simulate corruption: entity 'b' vanished but its relation survived
  snap.entities = snap.entities.filter(e => e.id !== b.id);
  assert.throws(() => RRW.restore(snap, {}), SnapshotError);
});

test('rrw: restore rejects snapshots with missing causal parents', () => {
  const rrw = makeRRW();
  const root = rrw.emitEvent({ type: 'a' });
  const child = rrw.emitEvent({ type: 'b', cause: root });
  const snap = rrw.snapshot();
  // simulate corruption: the causal parent vanished while the child survived
  snap.events = snap.events.filter(e => e.id !== root);
  snap.eventOrder = snap.eventOrder.filter(id => id !== root);
  assert.throws(() => RRW.restore(snap, {}), SnapshotError);
});

test('rrw: event cap prunes oldest but keeps counting honestly', () => {
  const rrw = new RRW({ rng: new RNG('cap'), eventCap: 5 });
  let first = null;
  for (let i = 0; i < 8; i++) {
    const id = rrw.emitEvent({ type: 'e' + i, cause: i === 0 ? null : rrw.eventOrder[rrw.eventOrder.length - 1] });
    if (i === 0) first = id;
  }
  assert.equal(rrw.events.has(first), false);
  assert.equal(rrw.eventOrder.length, 5);
  assert.equal(rrw.stats.events, 8);
});
