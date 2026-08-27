import { test } from 'node:test';
import assert from 'node:assert/strict';
import { PerfMeter } from '../src/core/index.ts';
import { createDefaultTese } from '../src/d/index.ts';
import { AdaptiveScheduler, HARDWARE_PRESETS, Profiler, StrategyEngine, detectHardware, type SystemSpec } from '../src/d-o15/index.ts';

function makeEngine(hwId: string): { engine: StrategyEngine; meter: PerfMeter; profiler: Profiler } {
  const meter = new PerfMeter();
  const engine = new StrategyEngine({ hardware: HARDWARE_PRESETS[hwId], tese: createDefaultTese() });
  const profiler = new Profiler(meter);
  return { engine, meter, profiler };
}

const SPECS: SystemSpec[] = [
  { id: 'npc-mind', baseHz: 10, minHz: 1, baseDetail: 1, priority: 90, critical: true },
  { id: 'society', baseHz: 1, minHz: 0.1, baseDetail: 1, priority: 50, critical: true },
  { id: 'graphics', baseHz: 10, minHz: 1, baseDetail: 1, priority: 70, critical: false },
  { id: 'ambient-sound', baseHz: 5, minHz: 0, baseDetail: 1, priority: 20, critical: false },
];

test('D-O15: folga → concede o pedido (representação full)', () => {
  const { engine, meter, profiler } = makeEngine('high-end');
  meter.reset();
  const decisions = engine.decide(SPECS, 0.1);
  for (const d of decisions) {
    assert.equal(d.grantedDetail, d.requestedDetail);
    assert.equal(d.representation, 'full');
  }
  assert.equal(profiler.bottleneck(1000), null);
});

test('D-O15: pressão média → escala detalhe, relevante sofre menos', () => {
  const { engine, meter } = makeEngine('high-end');
  meter.reset();
  engine.setRelevance('ambient-sound', 0.1);
  engine.setRelevance('npc-mind', 1.0);
  const decisions = engine.decide(SPECS, 0.7);
  const sound = decisions.find((d) => d.system === 'ambient-sound')!;
  const npc = decisions.find((d) => d.system === 'npc-mind')!;
  assert.ok(sound.grantedDetail < npc.grantedDetail, 'relevância baixa deve ser otimizada primeiro');
  assert.equal(sound.representation, 'aggregate');
  assert.equal(npc.representation, 'coarse');
});

test('D-O15: pressão extrema → não-críticos vão a cached, críticos mantêm floor', () => {
  const { engine, meter } = makeEngine('low-end');
  meter.reset();
  const decisions = engine.decide(SPECS, 1.4);
  const sound = decisions.find((d) => d.system === 'ambient-sound')!;
  const npc = decisions.find((d) => d.system === 'npc-mind')!;
  assert.equal(sound.representation, 'cached');
  assert.equal(sound.grantedDetail, 0);
  assert.equal(sound.updateHz, 0);
  assert.ok(npc.grantedDetail >= 0.1, 'crítico não pode perder o estado');
  assert.ok(npc.updateHz >= 1, 'crítico mantém Hz mínimo');
});

test('D-O15: profiler mede custo real e identifica gargalo', () => {
  const { engine, meter, profiler } = makeEngine('low-end');
  // sistema A: caro; B: barato
  meter.measure('sys:A', () => {
    let x = 0;
    for (let i = 0; i < 400000; i++) x += i;
    return x;
  });
  meter.measure('sys:B', () => 1 + 1);
  const costs = profiler.sample();
  const a = costs.find((c) => c.name === 'sys:A')!;
  const b = costs.find((c) => c.name === 'sys:B')!;
  assert.ok(a.avgMs > b.avgMs);
  assert.ok(a.share > 0.9);
  const bneck = profiler.bottleneck(1); // orçamento de 1ms: estourado
  assert.equal(bneck?.name, 'sys:A');
  assert.ok(profiler.pressure(1) > 1);
  assert.ok(profiler.memoryMB() > 0);
});

test('D-O15: scheduler executa dentro do orçamento e defere o excedente', () => {
  const { engine, meter } = makeEngine('mid'); // orçamento 10ms
  const sched = new AdaptiveScheduler({ strategy: engine, meter });
  let runs: Record<string, number> = {};
  // caso 1: 8 sistemas × ~0.3ms = ~2.4ms < 4ms → todos rodam
  for (let i = 0; i < 8; i++) {
    const id = `s${i}`;
    sched.register({ id, baseHz: 10, minHz: 0, baseDetail: 1, priority: 50 - i, critical: false }, () => {
      runs[id] = (runs[id] ?? 0) + 1;
      const t0 = process.hrtime.bigint();
      let x = 0;
      while (Number(process.hrtime.bigint() - t0) / 1e6 < 0.3) x++;
      return x;
    });
  }
  engine.decide(sched.specsList(), 0.1);
  const t1 = sched.step(0, {});
  assert.equal(t1.ran.length, 8);
  assert.equal(t1.overBudget, false);
  assert.ok(t1.usedMs > 0);
  assert.ok(Object.values(runs).every((n) => n >= 1));

  // caso 2: hardware degrada em runtime → orçamento cai para 4ms e o excedente é deferido
  engine.setHardware(HARDWARE_PRESETS['low-end']);
  for (let i = 0; i < 8; i++) {
    const id = `big${i}`;
    sched.register({ id, baseHz: 10, minHz: 0, baseDetail: 1, priority: 90 - i, critical: false }, () => {
      runs[id] = (runs[id] ?? 0) + 1;
      const t0 = process.hrtime.bigint();
      let x = 0;
      while (Number(process.hrtime.bigint() - t0) / 1e6 < 0.5) x++;
      return x;
    });
  }
  engine.decide(sched.specsList(), 0.1);
  const t2 = sched.step(1.0, {});
  assert.ok(t2.ran.length < 16, 'orçamento não comporta todos num tick');
  assert.ok(t2.deferred.length > 0, 'sistemas excedentes são DEFERIDOS (não descartados)');
  assert.ok(t2.usedMs <= 8, 'uso fica sob controle (catch-up nos ticks seguintes)');
  // prioridade: os mais prioritários rodam primeiro
  assert.ok((runs.big0 ?? 0) >= 1);
});

test('D-O15: scheduler respeita Hz concedido (frequência adaptativa real)', () => {
  const { engine, meter } = makeEngine('high-end');
  const sched = new AdaptiveScheduler({ strategy: engine, meter });
  let count = 0;
  sched.register({ id: 'x', baseHz: 10, minHz: 1, baseDetail: 1, priority: 50, critical: true }, () => {
    count++;
  });
  engine.decide(sched.specsList(), 0.2); // folga → 10 Hz
  for (let i = 0; i < 100; i++) {
    sched.step(i * 0.1, {});
  }
  // 10 Hz × 10 s ≈ 100 execuções (1 por tick de 0.1s)
  assert.ok(count >= 90 && count <= 100, `esperado ~100 execuções, obtido ${count}`);
  // agora pressão extrema → critical cai para Hz mínimo (1 Hz)
  engine.setHardware(HARDWARE_PRESETS['low-end']);
  engine.decide(sched.specsList(), 1.2);
  count = 0;
  for (let i = 100; i < 200; i++) {
    sched.step(i * 0.1, {});
  }
  assert.ok(count >= 7 && count <= 13, `esperado ~10 em 1Hz×10s, obtido ${count}`);
});

test('hardware: presets existem e detecção retorna perfil válido', () => {
  for (const id of ['low-end', 'mid', 'high-end', 'workstation']) {
    const h = HARDWARE_PRESETS[id];
    assert.ok(h.cpuBudgetMs > 0);
    assert.ok(h.memoryBudgetMB > 0);
    assert.ok(h.targetTps > 0);
  }
  assert.ok(HARDWARE_PRESETS['low-end'].cpuBudgetMs < HARDWARE_PRESETS['workstation'].cpuBudgetMs);
  const d = detectHardware();
  assert.equal(d.detected, true);
  assert.ok(d.cpuBudgetMs > 0);
});
