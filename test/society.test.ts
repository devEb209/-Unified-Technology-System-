import { test } from 'node:test';
import assert from 'node:assert/strict';
import { Rng } from '../src/core/index.ts';
import { World } from '../src/ues/world.ts';
import { Society } from '../src/ues/society.ts';
import { buildVillage } from '../src/ues/npc.ts';

function setup(): { w: World; society: Society; rng: Rng } {
  const w = new World({ seed: 21, gridDim: 8, chunkSize: 8 }, undefined, new Rng(21));
  w.setFocus(24, 24);
  w.stream();
  const society = new Society(w);
  society.define();
  return { w, society, rng: w.rng };
}

test('sociedade: produção e consumo evoluem o estoque', () => {
  const { w, society } = setup();
  const group = w.rrw.create({
    name: 'vila-teste',
    categories: ['society/group'],
    components: { Position: { x: 24, y: 24 } },
    data: { population: 10, farmers: 5, loggers: 3, miners: 2, stock: { food: 100, wood: 50, ore: 10 }, production: { food: 0, wood: 0, ore: 0 } },
    detail: 1,
  });
  society.refresh();
  const before = { ...(group.data.stock as Record<string, number>) };
  for (let i = 0; i < 200; i++) {
    w.rrw.time += 0.1;
    society.step({ dt: 0.1, time: w.rrw.time, rng: w.rng, world: w });
  }
  const after = group.data.stock as Record<string, number>;
  // 20 s de sim: produção de comida ~5*0.35*20=35, consumo ~10*0.22*20=44
  assert.ok(after.food !== before.food, 'estoque de comida mudou');
  assert.ok(after.wood > before.wood, 'madeira cresceu (produção)');
  assert.ok(after.ore > before.ore, 'minério cresceu (produção)');
});

test('sociedade: famine com CAUSALIDADE (estoque baixo → alerta → causa registrada)', () => {
  const { w, society } = setup();
  const group = w.rrw.create({
    name: 'vila-fome',
    categories: ['society/group'],
    components: { Position: { x: 24, y: 24 } },
    data: { population: 10, farmers: 1, loggers: 0, miners: 0, stock: { food: 3, wood: 10, ore: 0 }, production: { food: 0, wood: 0, ore: 0 } },
    detail: 1,
  });
  society.refresh();
  let warned = false;
  for (let i = 0; i < 100 && !warned; i++) {
    w.rrw.time += 0.1;
    society.step({ dt: 0.1, time: w.rrw.time, rng: w.rng, world: w });
    warned = w.rrw.eventsOf(group.id).some((e) => e.type === 'society.famine.warning');
  }
  assert.ok(warned, 'alerta de fome deveria ocorrer com estoque crítico');
  const warn = w.rrw.eventsOf(group.id).find((e) => e.type === 'society.famine.warning')!;
  assert.equal(warn.cause?.event, 'society.stock.low', 'causa registrada: estoque baixo');
  const low = w.rrw.eventsOf(group.id).find((e) => e.type === 'society.stock.low');
  assert.ok(low, 'evento raiz (stock.low) existe');
  // cadeia causal completa
  const chain = w.rrw.causalChain(group.id, 'society.famine.warning');
  assert.deepEqual(chain.map((e) => e.type), ['society.famine.warning', 'society.stock.low']);
});

test('sociedade: grupos ABSTRATOS continuam evoluindo (mundo vivo fora do foco)', () => {
  const { w, society } = setup();
  const group = w.rrw.create({
    name: 'vila-distante',
    categories: ['society/group'],
    components: { Position: { x: 24, y: 24 } },
    data: { population: 8, farmers: 4, loggers: 2, miners: 0, stock: { food: 80, wood: 40, ore: 0 }, production: { food: 0, wood: 0, ore: 0 } },
    detail: 0, // ABSTRATA (longe do foco)
  });
  society.refresh();
  const before = { ...(group.data.stock as Record<string, number>) };
  for (let i = 0; i < 150; i++) {
    w.rrw.time += 0.1;
    society.step({ dt: 0.1, time: w.rrw.time, rng: w.rng, world: w });
  }
  assert.equal(w.rrw.get(group.id)?.detail, 0, 'continua abstrata');
  const after = group.data.stock as Record<string, number>;
  assert.ok(after.wood > before.wood, 'produção evolui em abstração (tick abstrato)');
  assert.ok(after.food < before.food + 10, 'consumo também evolui (não é congelado)');
});

test('mercado: preços seguem oferta/demanda', () => {
  const { w } = setup();
  const market = w.spawnStructure('market', 24, 24);
  const stock = market.data.stock as { food: { qty: number; price: number } };
  const society = new Society(w);
  society.define();
  society.refresh();
  // demanda alta e CONTÍNUA → preço sobe
  for (let i = 0; i < 10; i++) {
    (market.data.demand as Record<string, number>).food = 10;
    w.rrw.time += 0.1;
    society.step({ dt: 0.1, time: w.rrw.time, rng: w.rng, world: w });
  }
  assert.ok(stock.food.price > 1, `demanda alta elevou preço (1 → ${stock.food.price.toFixed(2)})`);
  // sem demanda + estoque alto → preço volta
  (market.data.demand as Record<string, number>).food = 0;
  stock.food.qty = 30;
  const p1 = stock.food.price;
  for (let i = 0; i < 40; i++) {
    w.rrw.time += 0.1;
    society.step({ dt: 0.1, time: w.rrw.time, rng: w.rng, world: w });
  }
  assert.ok(stock.food.price < p1, `excesso de oferta derrubou preço (${p1.toFixed(2)} → ${stock.food.price.toFixed(2)})`);
});

test('buildVillage: grupo + habitantes + relações member-of', () => {
  const { w } = setup();
  const group = buildVillage(w, 24, 24, { name: 'Teste', population: 4 });
  const members = w.rrw.neighbors(group.id, 'member-of', 'in');
  assert.equal(members.length, 4);
  assert.ok(members.every((m) => m.categories.includes('organism/human')));
  assert.ok(w.rrw.query({ categories: ['structure'], data: { type: 'house' } }).length >= 1);
  // habitantes conhecem a vila
  assert.ok(members.every((m) => (w.rrw.get(m.id)?.components.get('Mind') as { knowledge: Record<string, unknown> })?.knowledge['village']));
});
