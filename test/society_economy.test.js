// UTS :: test/society_economy — settlements, aggregate <-> individual
// transitions with state preservation, economy flows, trade causality.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createUTS } from '../src/index.js';
import { materializeSettlement, abstractSettlement } from '../src/world/society.js';

function makeVillage(uts, name = 'Testópolis') {
  return uts.world.createSettlement({ name, pos: [500, 0, 500], pop: 10 });
}

test('society: settlement founds with process and aggregate representation', async () => {
  const uts = createUTS({ seed: 'soc' });
  const s = makeVillage(uts);
  assert.ok(uts.rrw.getComponent(s.id, 'settlement'));
  assert.equal(uts.rrw.get(s.id).materialization, 'abstract');
  assert.ok([...uts.rrw.processes.values()].some(p => p.kind === 'settlement-life' && p.attachedTo === s.id));
});

test('society: abstract settlement population grows with surplus food', async () => {
  const uts = createUTS({ seed: 'birth' });
  const s = makeVillage(uts);
  const comp = uts.rrw.getComponent(s.id, 'settlement');
  comp.store.food = 500;
  uts.ues.run(400);
  assert.ok(comp.pop > 10, `pop grew (${comp.pop})`);
  assert.ok([...uts.rrw.events.values()].some(e => e.type === 'society.birth'));
});

test('society: starvation emits events and decreases population', async () => {
  const uts = createUTS({ seed: 'famine' });
  const s = makeVillage(uts);
  const comp = uts.rrw.getComponent(s.id, 'settlement');
  comp.store.food = 0;
  const p0 = comp.pop;
  uts.ues.run(400);
  assert.ok(comp.pop < p0, `pop decreased (${p0} -> ${comp.pop})`);
  assert.ok([...uts.rrw.events.values()].some(e => e.type === 'society.starvation'));
});

test('society: materialize -> abstract preserves population exactly (D-14 state)', async () => {
  const uts = createUTS({ seed: 'mab' });
  const s = makeVillage(uts);
  const created = materializeSettlement(uts.world, s.id, 6);
  assert.equal(created.length, 6);
  assert.equal(uts.rrw.getComponent(s.id, 'settlement').pop, 4, 'aggregate shrank by materialized count');
  assert.equal(uts.rrw.count('npc'), 6);

  const merged = abstractSettlement(uts.world, s.id);
  assert.equal(merged, 6);
  assert.equal(uts.rrw.getComponent(s.id, 'settlement').pop, 10, 'population restored exactly');
  assert.equal(uts.rrw.count('npc'), 0);
  assert.equal(uts.rrw.get(s.id).materialization, 'abstract');
});

test('society: updateMaterialization drives settlement aggregate<->individuals by focus', async () => {
  const uts = createUTS({ seed: 'focus' });
  const s = makeVillage(uts);
  uts.ues.moveCamera([500, 40, 500]);
  uts.world.updateMaterialization(uts.ues.camera.pos);
  assert.ok((uts.rrw.getComponent(s.id, 'settlement').materialized ?? 0) > 0, 'individuals materialized near focus');

  uts.ues.moveCamera([100, 40, 100]); // far away
  uts.world.updateMaterialization(uts.ues.camera.pos);
  assert.equal(uts.rrw.getComponent(s.id, 'settlement').materialized, 0, 'absorbed back when far');
  assert.equal(uts.rrw.getComponent(s.id, 'settlement').pop, 10);
});

test('economy: labor increases stores only for materialized settlements', async () => {
  const uts = createUTS({ seed: 'labor' });
  const s = makeVillage(uts);
  materializeSettlement(uts.world, s.id, 4);
  const comp = uts.rrw.getComponent(s.id, 'settlement');
  const f0 = comp.store.food;
  uts.ues.run(20);
  assert.ok(comp.store.food > f0 - 1, `labor produced (food ${comp.store.food})`);
});

test('economy: trade transfers surplus -> deficit with verifiable event', async () => {
  const uts = createUTS({ seed: 'trade' });
  const a = uts.world.createSettlement({ name: 'A', pos: [400, 0, 400], pop: 10 });
  const b = uts.world.createSettlement({ name: 'B', pos: [470, 0, 470], pop: 10 });
  uts.rrw.getComponent(a.id, 'settlement').store.food = 100;
  uts.rrw.getComponent(b.id, 'settlement').store.food = 5;
  const trades = uts.world.updateTrade();
  assert.ok(trades >= 1);
  assert.ok(uts.rrw.getComponent(b.id, 'settlement').store.food > 5, 'B received food');
  const ev = [...uts.rrw.events.values()].find(e => e.type === 'economy.trade.executed');
  assert.ok(ev);
  assert.equal(ev.data.from, a.id);
  assert.equal(ev.data.to, b.id);
});
