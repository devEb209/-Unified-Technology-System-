import { test } from 'node:test';
import assert from 'node:assert/strict';
import { MemorySystem } from '../src/ai/memory.ts';
import { HARDWARE_PRESETS } from '../src/d-o15/index.ts';
import { createUes, type Engine } from '../src/ues/engine.ts';
import { buildVillage } from '../src/ues/npc.ts';
import { canonicalJson, normalizeUes, restoreFromJson, saveUes, serializeUes } from '../src/ues/persistence.ts';

const HW = HARDWARE_PRESETS['high-end'];

function setup(seed = 42): Engine {
  const e = createUes({ seed, hardware: HW, backend: 'null' });
  const w = e.world;
  const c = w.worldSize() / 2;
  w.setFocus(c, c);
  w.stream();
  buildVillage(w, c - 8, c + 8, { name: 'V1', population: 4 });
  w.spawnStructure('market', c + 8, c - 8);
  e.society.refresh();
  return e;
}

test('PERSISTÊNCIA: save/restore preserva estado completo (mundo, NPCs, sociedade, causalidade, RNG)', () => {
  const e = setup();
  e.advance(10);
  const json = saveUes(e);
  const e2 = restoreFromJson({ seed: 42, hardware: HW, backend: 'null' }, json);
  // tempo, clima, RNG exato
  assert.equal(e2.rrw.time, e.rrw.time);
  const env1 = e.rrw.get(e.world.env.id)!;
  const env2 = e2.rrw.get(e2.world.env.id)!;
  assert.equal(env2.data.weather, env1.data.weather);
  assert.equal(e2.rng.state(), e.rng.state(), 'estado do RNG preservado (determinismo)');
  // entidades, relações, eventos
  assert.equal(e2.rrw.stats().entities, e.rrw.stats().entities);
  assert.equal(e2.rrw.relations.length, e.rrw.relations.length);
  assert.equal(e2.rrw.recent(500).length, e.rrw.recent(500).length);
  // NPC wrappers adotados com estado íntegro (mesmo id, mesmo dinheiro)
  const npcs1 = e.npcList();
  const npcs2 = e2.npcList();
  assert.equal(npcs2.length, npcs1.length);
  for (const n of npcs1) {
    const n2 = e2.npcById(n.id);
    assert.ok(n2, `wrapper do NPC ${n.id} restaurado`);
    assert.equal(n2.mind.money, n.mind.money);
    assert.equal(n2.ent.name, n.ent.name);
  }
  // sociedade
  const g1 = e.world.rrw.query({ categories: ['society/group'] })[0];
  const g2 = e2.world.rrw.query({ categories: ['society/group'] })[0];
  assert.equal((g2.data.stock as Record<string, number>).food, (g1.data.stock as Record<string, number>).food);
  // chunks e foco
  assert.equal(e2.world.loadedChunkCount(), e.world.loadedChunkCount());
  assert.deepEqual(e2.world.focus, e.world.focus);
  // causalidade continua válida após restore
  assert.equal(e2.rrw.validateCausality().length, 0);
});

test('PERSISTÊNCIA + DETERMINISMO: restaurado evolui IDENTICAMENTE ao original', () => {
  const e1 = setup();
  e1.advance(10);
  const json = saveUes(e1);
  const e2 = restoreFromJson({ seed: 42, hardware: HW, backend: 'null' }, json);
  e1.advance(10);
  e2.advance(10);
  const state = (e: Engine) => {
    const env = e.rrw.get(e.world.env.id)!;
    return {
      time: e.rrw.time,
      weather: env.data.weather,
      temp: env.data.temperature,
      rng: e.rng.state(),
      entities: e.rrw.stats().entities,
      events: e.rrw.recent(500).map((x) => x.type).join(','),
      npcs: e.npcList().map((n) => [n.id, n.mind.money, Number(n.pos().x.toFixed(9)), Number(n.pos().y.toFixed(9)), Number(n.mind.needs.hunger.toFixed(9))]),
      groups: e.world.rrw.query({ categories: ['society/group'] }).map((g) => [g.id, Number((g.data.stock as Record<string, number>).food.toFixed(9))]),
    };
  };
  assert.deepEqual(state(e2), state(e1), 'estado do restaurado == estado do original após 10 s adicionais');
});

test('REPRODUÇÃO: dois runs independentes, mesma seed → mesmos resultados (IDs normalizados)', () => {
  const eA = setup(42);
  eA.advance(8);
  const eB = setup(42);
  eB.advance(8);
  const a = canonicalJson(normalizeUes(serializeUes(eA)));
  const b = canonicalJson(normalizeUes(serializeUes(eB)));
  assert.equal(a, b, 'mesma seed → mesma realidade (modos IDs)');
  // seed diferente → realidade diferente
  const eC = setup(99);
  eC.advance(8);
  const c = canonicalJson(normalizeUes(serializeUes(eC)));
  assert.notEqual(a, c, 'seed diferente → resultados diferentes');
});

test('PERSISTÊNCIA: memória da IA faz round-trip', () => {
  const mem = new MemorySystem();
  mem.message('conv-1', 'user', 'construir cena', 0);
  mem.setDecision('result/g1', { status: 'success' }, 1, 'ok');
  const mem2 = new MemorySystem();
  const data = mem.serialize() as never;
  mem2.load(data);
  assert.equal(mem2.stats().messages, mem.stats().messages);
  assert.deepEqual(mem2.decision('result/g1')?.value, { status: 'success' });
  // integração com saveUes
  const e = setup();
  e.advance(2);
  const json = saveUes(e, mem);
  const mem3 = new MemorySystem();
  const e2 = restoreFromJson({ seed: 42, hardware: HW, backend: 'null' }, json, mem3);
  void e2;
  assert.equal(mem3.decision('result/g1')?.value.status, 'success');
});
