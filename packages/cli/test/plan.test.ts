import { test } from 'node:test';
import assert from 'node:assert/strict';
import { planScene, naiveMaxCost, PlanError, DEFAULT_UNITS_PER_SECOND } from '../src/plan.ts';
import { FORBIDDEN_KEYS } from '../../dframe/src/schema.ts';

/** A70: 720×1612. Grade de decisão 6×13 = 78 células de 120px. */
function scene(over: Record<string, unknown> = {}) {
  const cells = Array.from({ length: 78 }, (_, i) => {
    const x = i % 6;
    const y = (i / 6) | 0;
    const near = x === 3 && y === 6;
    // volumes caros: é o que separa 'cabe no orçamento' de 'não cabe' entre célula quente e fria
    return { x, y, entities: near ? 40 : 6, lights: near ? 3 : 0, volumes: near ? 90000 : 0, importance: near ? 1 : 0.35, motion: near ? 0.8 : 0.1 };
  });
  return { ...{ name: 'nul-impacto/a70', screen: { w: 720, h: 1612 }, grid: { w: 6, h: 13, cellSize: 120 }, fps: 30, cells }, ...over } as never;
}

test('P1 o plano tem o tipo declarado e é livre de geometria em qualquer nível', () => {
  const plan = planScene(scene());
  assert.equal(plan.kind, 'uts.genesis.plan');
  assert.equal(plan.schemaVersion, 1);
  const raw = JSON.stringify(plan);
  for (const k of FORBIDDEN_KEYS) assert.ok(!raw.includes(`"${k}"`), `plan.json contém chave proibida ${k}`);
  assert.ok(raw.includes('notice'), 'o aviso de que unidades não são FPS viaja junto do artefato');
});

test('P2 importância distribui orçamento e o orçamento total respeita o overhead', () => {
  const plan = planScene(scene());
  const total = (1000 / 30) * 0.75 * DEFAULT_UNITS_PER_SECOND;
  assert.ok(Math.abs(plan.totals.budgetUnits - total) < 1e-9, `${plan.totals.budgetUnits} vs ${total}`);
  const sum = plan.regions.reduce((a, r) => a + r.budget, 0);
  assert.ok(Math.abs(sum - plan.totals.budgetUnits) < 0.05, 'a soma dos orçamentos por célula é o orçamento do frame');
  const hot = plan.regions.find((r) => r.cell[0] === 3 && r.cell[1] === 6)!;
  const cold = plan.regions.find((r) => r.cell[0] === 0 && r.cell[1] === 0)!;
  assert.ok(hot.budget > cold.budget * 2, `${hot.budget} vs ${cold.budget}`);
});

test('P3 a mesma regra do jogo custa mais onde há mais mundo — e a célula sem orçamento para ela é RECUSADA, não degradada', () => {
  const plan = planScene(scene({ requires: { visual: { domain: 'visual', requires: [], floors: { QpMin: 1, QfMin: 0.95, QiMin: 0 } } } }));
  const hot = plan.regions.find((r) => r.cell[0] === 3 && r.cell[1] === 6)!;
  const cold = plan.regions.find((r) => r.cell[0] === 0 && r.cell[1] === 0)!;
  assert.equal(hot.kind, 'ok');
  assert.equal(cold.kind, 'ok');
  // o requisito é o MESMO para as duas (regra do jogo); o que muda é o que o
  // orçamento da célula paga. Diferenciação é por capacidade comprada, não por
  // "a fria tem um requisito menor".
  assert.ok(hot.decisions!.visual.cost > cold.decisions!.visual.cost, `${hot.decisions!.visual.cost} vs ${cold.decisions!.visual.cost}`);
  assert.ok(hot.decisions!.visual.D >= cold.decisions!.visual.D);
  assert.ok(cold.decisions!.visual.caps.length > 0);
  // o orçamento DECLARADO é o que o otimizador usa — não o que o relatório mostra
  const gated = planScene(scene({ cells: [
    { x: 0, y: 0, budget: 5000, volumes: 90000, entities: 40, lights: 3, requires: { visual: { domain: 'visual', requires: [], floors: { QpMin: 1, QfMin: 0.95, QiMin: 0 } } } },
    { x: 1, y: 0, budget: 5, volumes: 0, entities: 6, requires: { visual: { domain: 'visual', requires: [], floors: { QpMin: 1, QfMin: 0.95, QiMin: 0 } } } },
  ] }));
  assert.equal(gated.regions[0].kind, 'ok', 'com 5000 unidades a célula paga D5');
  assert.equal(gated.regions[1].kind, 'infeasible', 'com 5 unidades a mesma regra do jogo não cabe — e isso é dito, não degradado');
  assert.match(gated.regions[1].error!.message, /E_INFEASIBLE/);
  assert.throws(() => planScene(scene({ cells: [{ x: 0, y: 0, budget: 1e9 }] })), (e: unknown) => (e as PlanError).code === 'DECLARED_BUDGET_EXCEEDS_FRAME');
});

test('P4 cena apertada devolve E_INFEASIBLE por célula, com fallback marcado — nunca "otimizado"', () => {
  const plan = planScene(scene({
    cells: [{ x: 0, y: 0, budget: 5, pixels: 64, entities: 400, lights: 6, volumes: 4000, importance: 1, requires: { visual: { domain: 'visual', requires: ['global_illumination'] } } }],
  }));
  assert.equal(plan.regions[0].kind, 'infeasible');
  assert.equal(plan.totals.infeasibleCells, 1);
  assert.ok(plan.regions[0].error!.message.startsWith('E_INFEASIBLE'));
  assert.match(plan.regions[0].error!.message, /decisão de objetivo/);
  assert.equal(plan.regions[0].fallback!.coarse, true);
});

test('P5 o plano gasta menos que o custo máximo ingênuo da cena', () => {
  const plan = planScene(scene());
  const max = naiveMaxCost(scene());
  assert.ok(plan.totals.chosenUnits < max, `${plan.totals.chosenUnits} vs ${max}`);
});

test('P6 unitsPerSecond é a constante que a medição fornece: dobrá-la dobra o orçamento', () => {
  const a = planScene(scene(), { unitsPerSecond: DEFAULT_UNITS_PER_SECOND });
  const b = planScene(scene(), { unitsPerSecond: DEFAULT_UNITS_PER_SECOND * 2 });
  assert.ok(b.totals.budgetUnits > a.totals.budgetUnits * 1.9);
  // com o dobro de orçamento, nenhuma célula pode ficar pior
  for (let i = 0; i < a.regions.length; i++) {
    const ad = a.regions[i].decisions?.visual?.D ?? -1;
    const bd = b.regions[i].decisions?.visual?.D ?? -1;
    assert.ok(bd >= ad, `célula ${i}: D${ad} → D${bd}`);
  }
});

test('P7 cena inválida é recusada com erro nomeado, não com plano vazio', () => {
  const bad: Array<[Record<string, unknown>, string]> = [
    [{ fps: 0 }, 'SCENE_FPS'],
    [{ screen: { w: 0, h: 0 } }, 'SCENE_SCREEN'],
    [{ cells: [] }, 'SCENE_CELLS'],
    [{ overhead: 0.99 }, 'SCENE_OVERHEAD'],
    [{ cells: [{ x: 99, y: 0 }] }, 'CELL_OUT_OF_GRID'],
  ];
  for (const [over, code] of bad) {
    assert.throws(() => planScene({ ...scene(), ...over } as never), (e: unknown) => (e as PlanError).code === code, code);
  }
  assert.throws(() => planScene(scene(), { unitsPerSecond: Number.NaN }), (e: unknown) => (e as PlanError).code === 'UNITS_PER_SECOND');
  assert.throws(() => planScene(scene({ cells: [{ x: 0, y: 0, budget: 0 }] }) as never), (e: unknown) => (e as PlanError).code === 'CELL_BUDGET');
});

test('P7b quando o orçamento não decide nada, o plano diz isso em vez de fingir que orçou', () => {
  const estimated = planScene(scene());
  assert.equal(estimated.calibration.source, 'estimated');
  assert.match(estimated.notice, /chute de engenharia/);
  const measured = planScene(scene(), { unitsPerSecond: 6_000_000, deviceFile: 'device.json' });
  assert.equal(measured.calibration.source, 'measured');
  assert.equal(measured.calibration.deviceFile, 'device.json');
  assert.doesNotMatch(measured.notice, /chute de engenharia/);
  assert.ok(measured.calibration.utilization < 0.02, `utilização ${measured.calibration.utilization} deveria ser mínima nessa cena`);
  assert.match(measured.calibration.warning!, /ORÇAMENTO SEM PODER DE DECISÃO/);
  // com orçamento apertado de verdade, o aviso desaparece porque a restrição decide
  const tight = planScene(scene({ fps: 30, overhead: 0.3, cells: [{ x: 0, y: 0, budget: 400, entities: 200, lights: 2 }] }), { unitsPerSecond: 1 });
  assert.ok(tight.calibration.utilization > 0.02, `utilização ${tight.calibration.utilization}`);
  assert.equal(tight.calibration.warning, undefined);
});

test('P8 caps no plano vêm da escada, não de um resumo paralelo', async () => {
  const { ladderFor } = await import('../../d-system/src/ladders.ts');
  const plan = planScene(scene());
  for (const r of plan.regions) {
    if (r.kind !== 'ok') continue;
    for (const [dom, v] of Object.entries(r.decisions!)) {
      assert.deepEqual([...v.caps], [...ladderFor(dom as never).steps[v.D].caps], `${dom} D${v.D}`);
    }
  }
});
