import { test } from 'node:test';
import assert from 'node:assert/strict';
import { interpolate, presentBudget, PresentError, type Snapshot } from '../src/present.ts';
import { ladderFor } from '../../d-system/src/ladders.ts';
import type { Domain, DStep } from '../../d-system/src/types.ts';
import type { DomainDecision, Region } from '../src/optimizer.ts';

const snap = (tick: number, tMs: number, pos: Record<string, [number, number]>, vel: Record<string, [number, number]> = {}): Snapshot => ({ tick, tMs, pos, vel });

function decision(domain: Domain, D: number): DomainDecision {
  const step = ladderFor(domain).steps[D];
  return { domain, D, step, cost: 0, quality: step.quality, floors: { domain, QpMin: 0, QfMin: 0, QiMin: 0, minD: 0, maxD: 5, overridden: false, reason: 'teste' }, margin: 1, why: 'teste' } as DomainDecision;
}

test('PR1 interpolar entre dois snapshots reais é avaliar o que a física já sabe', () => {
  const a = snap(10, 1000, { npc1: [0, 0], npc2: [10, 0] }, { npc1: [1, 0], npc2: [0, 2] });
  const b = snap(11, 1066, { npc1: [1, 0], npc2: [10, 2] }, { npc1: [1, 0], npc2: [0, 2] });
  const mid = interpolate(a, b, 0.5);
  assert.deepEqual(mid.pos.npc1, [0.5, 0]);
  assert.deepEqual(mid.pos.npc2, [10, 1]);
  assert.equal(mid.surprises.length, 0, `velocidades previstas não divergem: ${mid.surprises}`);
  assert.equal(mid.predicted, false);
});

test('PR2 t=0 e t=1 reproduzem os snapshots, sem deriva de arredondamento', () => {
  const a = snap(3, 300, { e: [1.5, -2.25] });
  const b = snap(4, 366, { e: [7.75, 3.5] });
  assert.deepEqual(interpolate(a, b, 0).pos.e, [1.5, -2.25]);
  assert.deepEqual(interpolate(a, b, 1).pos.e, [7.75, 3.5]);
});

test('PR3 entidade nascida entre snapshots NÃO é suavizada do nada', () => {
  const a = snap(1, 0, {});
  const b = snap(2, 66, { tiro: [3, 4] });
  const r = interpolate(a, b, 0.2);
  assert.deepEqual(r.pos.tiro, [3, 4]);
  assert.equal(r.delta.tiro, 0, 'sem estado anterior não há interpolação — apenas entra');
});

test('PR4 t>1 é PREDIÇÃO e sai marcado, nunca disfarçado de estado', () => {
  const a = snap(1, 0, { p: [0, 0] }, { p: [1, 0] });
  const b = snap(2, 66, { p: [1, 0] }, { p: [1, 0] });
  const r = interpolate(a, b, 1.9, { maxLead: 0.5 });
  assert.equal(r.predicted, true);
  assert.ok(r.t <= 1.5 + 1e-9 && r.t > 1, `t=${r.t}`);
});

test('PR5 desoclusão é detectada por divergência do previsto, e a política é nomeada no plano', () => {
  const a = snap(1, 0, { n: [0, 0] }, { n: [1, 0] });
  const b = snap(2, 66, { n: [9, 0] }, { n: [1, 0] }); // teleportou: a física mentiu ou algo colidiu
  const r = interpolate(a, b, 0.5, { surprise: 0.5 });
  assert.deepEqual(r.surprises, ['n']);
  const budget = presentBudget({ physical: decision('physical', 3), temporal: decision('temporal', 3), visual: decision('visual', 1) }, region(720 * 1612, 800, 2), {
    simHz: 15, dispHz: 60, unitsPerSecond: 5000, policy: 'repeat',
  });
  assert.match(budget.why, /Política de desoclusão: "repeat"/);
});

const region = (pixels: number, entities: number, lights: number): Region => ({ id: 'r:0,0', pixels, entities, lights, volumes: 0, importance: 1, motion: 0.5 });

test('PR6 célula limitada por FILL RATE: gerar quadro não vale, e o motivo é numérico', () => {
  // tela inteira com o visual mais caro, quase nada simulado → o gargalo é raster
  const b = presentBudget({ visual: decision('visual', 5), physical: decision('physical', 0), temporal: decision('temporal', 0) }, region(720 * 1612, 1, 0), {
    simHz: 15, dispHz: 30, unitsPerSecond: 3000,
  });
  assert.equal(b.verdict, 'não vale', b.why);
  assert.match(b.why, /quem manda é o render|deadline NÂO é estourado/);
  assert.ok(b.presentCostPerFrameMs > 0);
  assert.ok(b.savingMs < 0, 'aqui gerar quadro é custo líquido: a reprojeção não tem de onde se pagar');
});

test('PR7 cenário A70 realista: sim pesada + visual rico → a conta não fecha, e o motivo é dito', () => {
  // 720p, visual D4, 400 entidades, física D5: é o retrato do "Free Fire com tsunami"
  const b = presentBudget(
    { visual: decision('visual', 4), physical: decision('physical', 5), temporal: decision('temporal', 3) },
    region(720 * 1612, 400, 2),
    { simHz: 15, dispHz: 30, unitsPerSecond: 3000 },
  );
  assert.equal(b.verdict, 'não vale', b.why);
  assert.match(b.why, /câmera\/arma\/UI|latência/);
  // e o que VALE neste cenário é o caminho que não depende de gerar quadro:
  assert.ok(b.addedLatencyMs > 60, 'se gerássemos, a latência entraria no tiroteio');
});

// Cena calibrada numa escala autoconsistente: tela cheia do A70 (720×1612), o
// visual D0 numa célula custa ~8 ms/quadro a 30 Hz com unitsPerSecond = 870_000
// (a ordem de grandeza que `uts measure` produz, não um número inventado).
// Os vereditos abaixo são o que sai DA CONTA, não o que gostaríamos de ler.
const A70 = { unitsPerSecond: 870_000, dispHz: 30, full: 720 * 1612 };

test('PR7b regime dominado por SIMULAÇÃO (multidão enorme a visual barato): gerar quadro vale', () => {
  // 12.000 corpos em física densa numa célula de fundo (50k px, visual no piso):
  // ~41 ms de sim por quadro contra ~2 ms de pixels. É o único regime em que FG existe.
  const b = presentBudget(
    { visual: decision('visual', 0), physical: decision('physical', 5), temporal: decision('temporal', 5) },
    region(50000, 12000, 0),
    { simHz: 15, dispHz: A70.dispHz, unitsPerSecond: A70.unitsPerSecond },
  );
  assert.equal(b.verdict, 'vale', b.why);
  // a economia é limitada pela RAZÃO DAS TAXAS, não pela esperteza do algoritmo
  assert.ok(Math.abs(b.simSaving - (1 - 15 / 30)) < 1e-6, `economia de simulação ${b.simSaving}`);
  assert.ok(b.addedLatencyMs > 66 && b.addedLatencyMs < 67, `latência ${b.addedLatencyMs} ms deve ser ~1/simHz`);
  assert.ok(b.savingMs > 20, `economia líquida ${b.savingMs} ms`);
  assert.match(b.why, /corpos dos OUTROS/);
});

test('PR7c três modos de "não vale", com textos diferentes porque a conduta é diferente', () => {
  // (1) folga: não há o que recuperar — sobe-se o D, não a taxa
  const loose = presentBudget({ visual: decision('visual', 1) }, region(4096, 4, 0), { simHz: 30, dispHz: 30, unitsPerSecond: A70.unitsPerSecond });
  assert.equal(loose.verdict, 'não vale', loose.why);
  assert.equal(loose.overDeadline, false);
  assert.match(loose.why, /deadline NÂO é estourado/);

  // (2) fill rate: a própria reprojeção não cabe
  const fill = presentBudget({ visual: decision('visual', 5) }, region(A70.full, 0, 0), { simHz: 30, dispHz: A70.dispHz, unitsPerSecond: A70.unitsPerSecond });
  assert.equal(fill.verdict, 'não vale', fill.why);
  assert.ok(fill.presentCostPerFrameMs > 3.9, `reprojeção full-screen a 720p: ${fill.presentCostPerFrameMs} ms`);

  // (3) CUSTO LÍQUIDO NEGATIVO mesmo estourando o deadline: faltam ms no quadro,
  // mas o que sobra a recuperar (0.3 ms de sim) é menor do que a reprojeção criada
  // (4 ms). Este é o retrato fiel do A70 a 720p — e por isso a resposta à pergunta
  // "suavizar 15 para parecer 30?" é NÃO na célula em foco, SIM na célula de multidão.
  const net = presentBudget({ visual: decision('visual', 4), physical: decision('physical', 4), temporal: decision('temporal', 0) }, region(A70.full, 2400, 0), { simHz: 15, dispHz: A70.dispHz, unitsPerSecond: A70.unitsPerSecond });
  assert.equal(net.verdict, 'não vale', net.why);
  assert.equal(net.overDeadline, true, 'aqui de facto falta tempo no quadro');
  assert.ok(net.savingMs < 0, `economia deveria ser negativa, veio ${net.savingMs}`);
  assert.match(net.why, /NEGATIVO/);
});

test('PR7d NO A70 REAL, NA CÉLULA EM FOCO, O VEREDITO É NÃO — tranca isso para não virar fé', () => {
  // Tela cheia, 1.000 entidades vivas, física já no D5: o gargalo é o render.
  const focus = presentBudget({ visual: decision('visual', 0), physical: decision('physical', 5), temporal: decision('temporal', 5) }, region(A70.full, 1000, 0), { simHz: 15, dispHz: A70.dispHz, unitsPerSecond: A70.unitsPerSecond });
  assert.equal(focus.verdict, 'não vale', `se isto um dia virar 'vale', a escala de custo mudou — reauditar o kernel inteiro: ${focus.why}`);
  const rich = presentBudget({ visual: decision('visual', 5), physical: decision('physical', 2), temporal: decision('temporal', 3) }, region(A70.full, 40, 2), { simHz: 15, dispHz: A70.dispHz, unitsPerSecond: A70.unitsPerSecond });
  assert.equal(rich.verdict, 'não vale', rich.why);
  // e o caminho que NÃO cobra latência continua orçado na mesma conta
  assert.ok(rich.viewModelCostPerFrameMs > 0 && rich.viewModelCostPerFrameMs < rich.presentCostPerFrameMs / 4, 'view-model deve ser ordem de grandeza mais barato que a reprojeção');
  assert.match(rich.why, /câmera\/arma\/UI/);
});

test('PR7e frame generation é decisão POR CÉLULA, não recurso global do motor', () => {
  const mk = (pix: number, ents: number, D: number) => presentBudget(
    { visual: decision('visual', 0), physical: decision('physical', D), temporal: decision('temporal', D) },
    region(pix, ents, 0),
    { simHz: 15, dispHz: A70.dispHz, unitsPerSecond: A70.unitsPerSecond },
  );
  const dense = mk(50000, 12000, 5);
  const focus = mk(A70.full, 1000, 5);
  assert.equal(dense.verdict, 'vale', dense.why);
  assert.equal(focus.verdict, 'não vale', focus.why);
  assert.notEqual(dense.verdict, focus.verdict);
  // reprodutibilidade: a conta é função pura dos dados do quadro
  assert.deepEqual(mk(50000, 12000, 5), dense);
});

test('PR8 entrada inconsistente é recusada com erro nomeado', () => {
  assert.throws(() => interpolate(snap(5, 0, {}), snap(5, 0, {}), 0.5), (e: unknown) => (e as PresentError).code === 'PRESENT_TICK_ORDER');
  assert.throws(() => interpolate(snap(1, 0, {}), snap(2, 1, {}), Number.NaN), (e: unknown) => (e as PresentError).code === 'PRESENT_T');
  assert.throws(() => presentBudget({}, region(100, 1, 0), { simHz: 30, dispHz: 15, unitsPerSecond: 1 }), (e: unknown) => (e as PresentError).code === 'PRESENT_RATES');
  assert.throws(() => presentBudget({}, region(100, 1, 0), { simHz: 0, dispHz: 60, unitsPerSecond: 1 }), (e: unknown) => (e as PresentError).code === 'PRESENT_RATES');
  assert.throws(() => presentBudget({}, region(100, 1, 0), { simHz: 15, dispHz: 60, unitsPerSecond: 0 }), (e: unknown) => (e as PresentError).code === 'PRESENT_UNITS');
});

test('PR9 interpolar não fabrica movimento além do delta real entre snapshots', () => {
  const a = snap(1, 0, { n: [0, 0] });
  const b = snap(2, 66, { n: [3, 4] });
  for (const t of [0, 0.25, 0.5, 0.75, 1]) {
    const r = interpolate(a, b, t);
    const d = r.delta.n;
    assert.ok(d >= 0 && d <= 5 + 1e-9, `delta ${d} fora do segmento`);
    assert.ok(Math.hypot(r.pos.n[0], r.pos.n[1]) <= 5 + 1e-9);
  }
});
