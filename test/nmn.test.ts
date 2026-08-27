import { test } from 'node:test';
import assert from 'node:assert/strict';
import { Rng } from '../src/core/index.ts';
import { World } from '../src/ues/world.ts';
import { Npc } from '../src/ues/npc.ts';

function setup(): { w: World; npc: Npc; ctx: () => Parameters<Npc['step']>[0] } {
  const w = new World({ seed: 11, gridDim: 8, chunkSize: 8, activeRadiusChunks: 2, outerRadiusChunks: 3 }, undefined, new Rng(11));
  w.setFocus(24, 24);
  w.stream();
  Npc.ensureComponents(w.rrw);
  w.spawnStructure('market', 24, 24);
  const npc = Npc.create(w, { x: 24, y: 26, work: 'farmer' });
  const ctx = () => ({ dt: 0.1, time: w.rrw.time, rng: w.rng, world: w });
  return { w, npc, ctx };
}

test('NMN: identidade, necessidades e conhecimento inicial', () => {
  const { npc } = setup();
  const m = npc.mind;
  assert.ok(npc.ent.name);
  assert.ok(m.needs.hunger >= 0 && m.needs.hunger <= 1);
  assert.ok(m.money > 0);
  assert.equal(m.work?.type, 'farmer');
  // conhece o mercado (criado antes do NPC)
  assert.ok(npc.know('market'));
});

test('NMN: decisão por utilidade — fome com comida → comer', () => {
  const { npc, ctx } = setup();
  const m = npc.mind;
  m.needs.hunger = 0.9;
  m.inventory.food = 2;
  m.goal = null;
  m.retargetAt = 0;
  const before = m.needs.hunger;
  // tem comida no inventário e está no próprio ponto → come no primeiro tick
  npc.step(ctx());
  assert.ok(m.needs.hunger < before - 0.2, `fome caiu após comer (${before.toFixed(2)} → ${m.needs.hunger.toFixed(2)})`);
  assert.ok(m.episodes.some((e) => e.type === 'ate'), 'experiência registrada na memória');
  assert.ok(m.inventory.food <= 1, 'inventário consumido');
});

test('NMN: foge de fogo (ameaça) — comportamento adaptativo, não script', () => {
  const { w, npc, ctx } = setup();
  const p0 = { ...npc.pos() }; // cópia: o componente é mutável
  // fogo próximo e materializado
  const fire = w.rrw.create({
    name: 'fogo',
    categories: ['phenomenon/fire'],
    components: { Position: { x: p0.x + 1, y: p0.y + 1 } },
    data: { fuel: 5 },
    detail: 1,
  });
  let fled = false;
  for (let i = 0; i < 40; i++) {
    npc.step(ctx());
    if (npc.mind.state === 'fleeing' || npc.mind.goal?.type === 'flee') fled = true;
  }
  assert.ok(fled, 'NPC deveria escolher fugir');
  const p1 = { ...npc.pos() };
  const d0 = Math.hypot(p0.x - (p0.x + 1), p0.y - (p0.y + 1));
  const d1 = Math.hypot(p1.x - (p0.x + 1), p1.y - (p0.y + 1));
  assert.ok(d1 > d0, `afastou-se do fogo (${d0.toFixed(1)} → ${d1.toFixed(1)})`);
  // memória do episódio
  assert.ok(npc.mind.episodes.some((e) => e.type === 'goal.flee'));
  w.rrw.destroy(fire.id);
});

test('NMN: relações — socializar aumenta confiança (memória relacional)', () => {
  const { w, npc, ctx } = setup();
  const other = Npc.create(w, { x: 25, y: 26 });
  const before = npc.relateTo(other.id).trust;
  const m = npc.mind;
  m.needs.social = 0.9;
  m.goal = null;
  m.retargetAt = 0;
  for (let i = 0; i < 60; i++) npc.step(ctx());
  const after = npc.relateTo(other.id).trust;
  assert.ok(after > before, `confiança subiu (${before.toFixed(2)} → ${after.toFixed(2)})`);
  const soc = w.rrw.eventsOf(npc.id).filter((e) => e.type === 'npc.socialize');
  assert.ok(soc.length > 0, 'evento social registrado no RRW');
});

test('NMN: trade — compra comida com causa (fome) no RRW', () => {
  const { w, npc, ctx } = setup();
  const m = npc.mind;
  m.needs.hunger = 0.49; // vai cruzar 0.5 naturalmente (evento real de fome)
  m.inventory.food = 0;
  m.money = 20;
  m.goal = null;
  m.retargetAt = 0;
  const market = w.rrw.query({ categories: ['structure'], data: { type: 'market' } })[0]!;
  const stockBefore = (market.data.stock as { food: { qty: number } }).food.qty;
  let bought = false;
  for (let i = 0; i < 120 && !bought; i++) {
    w.rrw.time += 0.1;
    npc.step({ ...ctx(), time: w.rrw.time });
    bought = (market.data.stock as { food: { qty: number } }).food.qty < stockBefore;
  }
  assert.ok(bought, 'NPC comprou comida no mercado');
  const trade = w.rrw.eventsOf(npc.id).filter((e) => e.type === 'npc.trade')[0];
  assert.ok(trade, 'evento npc.trade existe');
  assert.equal(trade.cause?.event, 'npc.hunger', 'causa registrada: fome');
  // a cadeia causal existe nos logs (causa real, não fabricada)
  const hungerEvt = w.rrw.eventsOf(npc.id).find((e) => e.type === 'npc.hunger');
  assert.ok(hungerEvt, 'evento de fome existe');
});

test('NMN: estado preservado em abstração (morte e vida do detalhe)', () => {
  const { w, npc } = setup();
  const m = npc.mind;
  m.money = 77;
  npc.relateTo('outro123').trust = 0.42;
  m.knowledge['teste'] = { value: 'valor-guardado', at: 0, confidence: 0.9 };
  // abstraí o NPC (saiu do foco)
  w.rrw.abstractize(npc.id, 'test');
  assert.equal(w.rrw.get(npc.id)?.detail, 0);
  // o componente Mind (estado) foi preservado via compress
  const mindSnap = w.rrw.get(npc.id)?.components.get('Mind') ?? w.rrw.get(npc.id)?.compressed?.get('Mind');
  assert.ok(mindSnap, 'mente preservada em abstração');
  // a posição abstrata continua acessível via world (snapshot)
  const posAbstract = w.positionOf(npc.id);
  assert.ok(posAbstract && isFinite(posAbstract.x), 'posição preservada em abstração');
  // volta do foco → estado íntegro
  w.rrw.materialize(npc.id, 1, 'test');
  const m2 = npc.mind;
  assert.equal(m2.money, 77);
  assert.equal(m2.relations['outro123']?.trust, 0.42);
  assert.equal(m2.knowledge['teste']?.value, 'valor-guardado');
});

test('NMN: NPC abstrato não raciocina fino (custo D-2)', () => {
  const { w, npc, ctx } = setup();
  const before = w.positionOf(npc.id)!;
  w.rrw.abstractize(npc.id, 'longe');
  for (let i = 0; i < 10; i++) npc.step(ctx());
  const after = w.positionOf(npc.id)!;
  assert.equal(before.x, after.x);
  assert.equal(before.y, after.y);
});
