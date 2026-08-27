import { test } from 'node:test';
import assert from 'node:assert/strict';
import { Rng } from '../src/core/index.ts';
import { MATERIAL_THRESHOLD, RRW } from '../src/rrw/index.ts';

function makeRrw(): RRW {
  return new RRW();
}

test('RRW: categorias abertas (extensibilidade em runtime)', () => {
  const r = makeRrw();
  // Aspecto da realidade ainda não citado em lugar nenhum: deve ser incorporável.
  r.defineCategory('phenomenon/magnetohydrodynamics');
  r.defineCategory('information/memetics');
  const e = r.create({ name: 'fluxo', categories: ['phenomenon/magnetohydrodynamics'] });
  assert.ok(r.hasCategory(e.id, 'phenomenon')); // herança hierárquica
  assert.ok(r.hasCategory(e.id, 'phenomenon/magnetohydrodynamics'));
  assert.ok(!r.hasCategory(e.id, 'organism'));
  assert.ok(r.categoryNames().includes('information/memetics'));
});

test('RRW: componentes abertos com init/compress/restore', () => {
  const r = makeRrw();
  r.defineComponent('Wallet', {
    init: (_e, args) => ({ coins: (args?.coins as number) ?? 0 }),
    compress: (v) => {
      const { coins } = v as { coins: number };
      return { coins };
    },
    restore: (_e, snap) => snap,
    cost: 1,
  });
  const e = r.create({ name: 'viajante', components: { Wallet: { coins: 42 } } });
  assert.equal((r.componentValue(e.id, 'Wallet') as { coins: number }).coins, 42);
  r.materialize(e.id, 1);
  r.abstractize(e.id, 'afastou');
  // estado preservado (regra: abstração não apaga informação)
  assert.equal(r.get(e.id)?.state, 'abstract');
  const snap = r.get(e.id)?.components.get('Wallet');
  assert.equal(snap, undefined); // componente comprimido fora do componente
  assert.equal((r.get(e.id)?.compressed?.get('Wallet') as { coins: number }).coins, 42);
  r.materialize(e.id, 1);
  assert.equal((r.componentValue(e.id, 'Wallet') as { coins: number }).coins, 42);
  assert.equal(r.get(e.id)?.state, 'material');
});

test('RRW: relações abertas, direcionadas, ponderadas', () => {
  const r = makeRrw();
  const a = r.create({ name: 'A', categories: ['organism'] });
  const b = r.create({ name: 'B', categories: ['organism'] });
  r.relate(a.id, b.id, 'debt/owes', { weight: 10, causal: true, data: { item: 'food' } });
  r.relate(b.id, a.id, 'kin/family', { weight: 3 });
  const out = r.relationsOf(a.id, undefined, 'out');
  assert.equal(out.length, 1);
  assert.equal(out[0].to, b.id);
  assert.equal(out[0].type, 'debt/owes');
  const inb = r.relationsOf(b.id, undefined, 'in');
  assert.equal(inb.length, 1);
  assert.equal(inb[0].from, a.id);
  assert.deepEqual(r.neighbors(a.id, 'debt/owes', 'out').map((e) => e.name), ['B']);
  r.unrelate(a.id, b.id, 'debt/owes');
  assert.equal(r.relationsOf(a.id, 'debt/owes', 'out').length, 0);
});

test('RRW: eventos com causalidade + cadeia causal', () => {
  const r = makeRrw();
  const env = r.create({ name: 'ambiente', categories: ['phenomenon'] });
  const crop = r.create({ name: 'cultivo', categories: ['terrain'] });
  const storm = r.emit('weather.storm', [env.id], { intensity: 2 });
  const flood = r.emit('env.flood', [crop.id], { depth: 1 }, { by: env.id, event: 'weather.storm', description: 'tempestade causou inundação' });
  const rot = r.emit('crop.rot', [crop.id], {}, { by: crop.id, event: 'env.flood' });
  assert.ok(storm.cause === null);
  assert.equal(flood.cause?.by, env.id);
  assert.equal(rot.cause?.event, 'env.flood');
  const chain = r.causalChain(crop.id, 'crop.rot');
  assert.deepEqual(chain.map((e) => e.type), ['crop.rot', 'env.flood', 'weather.storm']);
  assert.equal(r.eventsOf(crop.id).length, 3); // created + flood + rot
});

test('RRW: contexto organiza o mundo (scope)', () => {
  const r = makeRrw();
  const region = r.create({ name: 'região norte', categories: ['world'] });
  const v1 = r.create({ name: 'v1', categories: ['structure'], contextId: region.id });
  const v2 = r.create({ name: 'v2', categories: ['structure'], contextId: region.id });
  r.create({ name: 'fora', categories: ['structure'] });
  assert.equal(r.within(region.id, { categories: ['structure'] }).length, 2);
  r.setContext(v1.id, null);
  assert.equal(r.within(region.id, { categories: ['structure'] }).length, 1);
  assert.equal(r.get(v2.id)?.contextId, region.id);
});

test('RRW: processos — tick materializado vs abstrato (mundo vivo fora do foco)', () => {
  const r = makeRrw();
  let materialTicks = 0;
  let abstractTicks = 0;
  r.defineProcess('grow', {
    init: () => 'idle',
    tick: (e, state) => {
      if (state !== 'growing') {
        r.setProcessState('grow', e.id, 'growing');
        return;
      }
      e.data.size = Number(e.data.size) + 1;
      materialTicks += 1;
    },
    abstractTick: (e) => {
      // evolução agregada barata: cresce de forma resumida
      e.data.size = (Number(e.data.size) ?? 0) + 0.25;
      abstractTicks += 1;
    },
  });
  const near = r.create({ name: 'perto', data: { size: 0 } });
  const far = r.create({ name: 'longe', data: { size: 0 } });
  r.materialize(near.id, 1);
  r.startProcess('grow', [near.id, far.id]);
  const ctx = { dt: 0.1, time: 0, rng: new Rng(1), rrw: r };
  for (let i = 0; i < 4; i++) {
    r.time = i * 0.1;
    r.stepProcesses(ctx);
  }
  assert.equal(abstractTicks, 4); // longe: 4 ticks abstratos
  assert.equal(materialTicks, 3); // perto: init no primeiro tick, depois 3 growing
  assert.equal(r.get(near.id)?.data.size, 3);
  assert.equal(r.get(far.id)?.data.size, 1); // 4 * 0.25
  assert.equal(r.processStateOf('grow', near.id), 'growing');
});

test('RRW: materializeForFocus — relevância espacial + preservação de estado', () => {
  const r = makeRrw();
  r.defineComponent('Pos', { init: (_e, a) => ({ x: (a?.x as number) ?? 0, y: (a?.y as number) ?? 0 }) });
  r.defineComponent('W', { init: (_e, a) => ({ c: (a?.c as number) ?? 0 }), compress: (v) => v, restore: (_e, s) => s, cost: 1 });
  const make = (name: string, x: number, y: number, coins: number) =>
    r.create({ name, categories: ['organism'], components: { Pos: { x, y }, W: { c: coins } } });
  const near = make('perto', 0, 0, 7);
  const mid = make('meio', 7, 0, 9);
  const far = make('longe', 100, 0, 11);
  const focus = {
    x: 0,
    y: 0,
    innerRadius: 3,
    outerRadius: 10,
    positionOf: (id: string) => {
      const p = r.componentValue(id, 'Pos') as { x: number; y: number } | undefined;
      return p ?? null;
    },
  };
  // Todo o mundo começa materializado (ex.: o jogador já interagiu com tudo).
  r.materialize(near.id, 1);
  r.materialize(mid.id, 1);
  r.materialize(far.id, 1);
  const res = r.materializeForFocus(focus);
  assert.equal(res.abstractized, 2); // meio (rampa) e longe (fora da zona)
  assert.equal(r.get(near.id)?.detail, 1);
  assert.equal(r.get(mid.id)?.detail, 0.5); // rampa preserva ≥ limiar na zona ativa
  assert.equal(r.get(far.id)?.detail, 0);
  // 'longe' foi abstraído: estado preservado via snapshot comprimido
  assert.equal((r.get(far.id)?.compressed?.get('W') as { c: number }).c, 11);
  // foco se move → 'longe' materializa de volta com estado íntegro
  const res2 = r.materializeForFocus({ ...focus, x: 100, y: 0 });
  assert.equal(res2.materialized, 1);
  assert.equal(r.get(far.id)?.detail, 1);
  assert.equal(r.get(far.id)?.state, 'material');
  assert.equal((r.componentValue(far.id, 'W') as { c: number }).c, 11);
  // e o 'perto' agora fora da zona foi abstraído preservando estado
  assert.equal((r.get(near.id)?.compressed?.get('W') as { c: number }).c, 7);
});

test('RRW: query combinada e destroy limpa relações', () => {
  const r = makeRrw();
  const c1 = r.create({ name: 'a', categories: ['organism/human'], data: { alive: true } });
  const c2 = r.create({ name: 'b', categories: ['organism/animal'] });
  r.relate(c1.id, c2.id, 'causes', { causal: true });
  assert.equal(r.query({ categories: ['organism'] }).length, 2);
  assert.equal(r.query({ categories: ['organism/human'] }).length, 1);
  r.destroy(c1.id, 'fim');
  assert.equal(r.query({ categories: ['organism'] }).length, 1);
  assert.equal(r.relationsOf(c1.id).length, 0);
  assert.equal(r.get(c1.id)?.alive, false);
});

test('RRW: stats e snapshot são consistentes', () => {
  const r = makeRrw();
  r.create({ name: 'x', categories: ['entity'] });
  r.create({ name: 'y', categories: ['entity'] });
  const s = r.stats();
  assert.equal(s.entities, 2);
  const snap = r.snapshot();
  assert.equal(snap.entities.length, 2);
  assert.ok(typeof JSON.stringify(snap) === 'string');
});
