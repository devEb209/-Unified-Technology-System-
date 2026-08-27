import { test } from 'node:test';
import assert from 'node:assert/strict';
import { HARDWARE_PRESETS } from '../src/d-o15/index.ts';
import { createUes } from '../src/ues/engine.ts';

/**
 * PROVA DE ESCALA — mede ONDE os gargalos realmente aparecem (Prompt 24).
 *
 * Números medidos nesta máquina (sandbox, Node 22, workstation 60ms):
 *   500 NPCs materializados  → avg ~27 ms/tick  (dentro do orçamento)
 *   2000 NPCs materializados → avg ~216 ms/tick (fora do orçamento → gargalo CPU)
 *   20.000 entidades abstratas → ~2 ms/tick (representação D-1: barato)
 *
 * As asserções usam margens (não os números exatos) para robustez entre
 * máquinas; o PADO de adaptação (defer/sobrepresão) é o que importa.
 */

function bigWorld(npcs: number, seconds: number, warmup = 5) {
  const e = createUes({
    seed: 7,
    hardware: HARDWARE_PRESETS['workstation'],
    backend: 'null',
    world: { gridDim: 12, maxLoadedChunks: 144, activeRadiusChunks: 12, outerRadiusChunks: 12 },
  });
  const w = e.world;
  const c = w.worldSize() / 2;
  w.setFocus(c, c);
  w.stream();
  for (let i = 0; i < npcs; i++) w.spawnNpc({ x: c + e.rng.range(-45, 45), y: c + e.rng.range(-45, 45) });
  const ticks = Math.round(seconds / 0.1);
  let maxTick = 0;
  let measuredMs = 0;
  let measured = 0;
  for (let i = 0; i < ticks; i++) {
    if (i < warmup) {
      e.tick(); // aquece (adocção inicial, primeira decisão) — fora da média
      continue;
    }
    const ta = process.hrtime.bigint();
    e.tick();
    const ms = Number(process.hrtime.bigint() - ta) / 1e6;
    maxTick = Math.max(maxTick, ms);
    measuredMs += ms;
    measured += 1;
  }
  return { e, avg: measuredMs / measured, max: maxTick };
}

test('ESCALA-PROBE: 500 NPCs materializados cabem no orçamento de workstation', () => {
  const { e, avg } = bigWorld(500, 5);
  const mat = e.world.rrw.query({ categories: ['organism/human'] }).filter((n) => e.world.rrw.isMaterial(n.id, 0.5)).length;
  assert.equal(mat, 500);
  // medido: ~27ms/tick — asserção com margem 2x o orçamento (60ms)
  assert.ok(avg < 120, `avg ${avg.toFixed(1)}ms/tick < 120ms`);
});

test('ESCALA-PROBE: 2000 NPCs materializados → gargalo CPU aparece (e o sistema ADAPTA, não trava)', () => {
  const { e, avg } = bigWorld(2000, 4);
  // medido: ~216ms/tick (muito acima do orçamento de 60ms) → gargalo real
  assert.ok(e.counters.overBudgetTicks > 0, `gargalo CPU detectado por métrica real (${e.counters.overBudgetTicks} ticks sobre orçamento; avg ${avg.toFixed(0)}ms)`);
  assert.ok(e.counters.deferredTotal > 0, 'sistemas deferidos (adaptação D-O15 ativa)');
  // a simulação continuou funcionando (não travou, não quebrou)
  assert.ok(e.world.rrw.stats().entities > 2000);
  assert.ok(e.lastFrame || e.rrw.time > 0, 'motor segue produzindo');
});

test('ESCALA-PROBE: 20.000 entidades ABSTRATAS (D-1) evoluem barato', () => {
  const e = createUes({ seed: 9, hardware: HARDWARE_PRESETS.mid, backend: 'null' });
  const w = e.world;
  const c = w.worldSize() / 2;
  w.setFocus(c, c);
  w.stream();
  for (let i = 0; i < 20000; i++) {
    const a = (i / 20000) * Math.PI * 2;
    const rr = 30 + (i % 25);
    w.rrw.create({ name: `d-${i}`, categories: ['organism/creature'], components: { Position: { x: c + Math.cos(a) * rr, y: c + Math.sin(a) * rr } }, data: { vit: 1 }, detail: 0 });
  }
  w.rrw.defineProcess('drift', { init: () => 'roam', abstractTick: (ent) => { ent.data.vit = Number(ent.data.vit) - 0.001; } });
  const swarm = w.rrw.query({ categories: ['organism/creature'] });
  w.rrw.startProcess('drift', swarm.map((s) => s.id));
  const t0 = process.hrtime.bigint();
  for (let i = 0; i < 300; i++) {
    w.rrw.time += 0.1;
    w.rrw.stepProcess('drift', { dt: 0.1, time: w.rrw.time, rng: e.rng, rrw: w.rrw });
  }
  const ms = Number(process.hrtime.bigint() - t0) / 1e6;
  // medido: ~625ms para 300 ticks → asserção com folga generosa
  assert.ok(ms < 5000, `20k abstratas: 300 ticks em ${ms.toFixed(0)}ms (custo D-1) ≈ ${(ms / 300).toFixed(2)}ms/tick`);
  assert.equal(w.rrw.stats().entities, 20076);
});

test('ESCALA-PROBE: representação > força bruta — custo médio cai com a abstração', () => {
  const e = createUes({
    seed: 7,
    hardware: HARDWARE_PRESETS['workstation'],
    backend: 'null',
    world: { gridDim: 12, maxLoadedChunks: 144, activeRadiusChunks: 12, outerRadiusChunks: 12 },
  });
  const w = e.world;
  const c = w.worldSize() / 2;
  w.setFocus(c, c);
  w.stream();
  for (let i = 0; i < 800; i++) w.spawnNpc({ x: c + e.rng.range(-45, 45), y: c + e.rng.range(-45, 45) });
  const phase = (n: number, skip: number) => {
    let sum = 0;
    let count = 0;
    for (let i = 0; i < n; i++) {
      if (i < skip) {
        e.tick();
        continue;
      }
      const ta = process.hrtime.bigint();
      e.tick();
      sum += Number(process.hrtime.bigint() - ta) / 1e6;
      count += 1;
    }
    return sum / count;
  };
  // 1) todos materializados (raio cobre o mundo)
  const avgFull = phase(30, 10);
  // 2) foco encolhe (D-O15/manual): a maioria fica abstrata
  w.setFocusRadius(1, 2);
  w.stream();
  const matNow = w.rrw.query({ categories: ['organism/human'] }).filter((n) => w.rrw.isMaterial(n.id, 0.5)).length;
  const avgAbs = phase(30, 10);
  assert.ok(matNow < 400, `abstração reduziu materializados (${matNow})`);
  assert.ok(avgAbs < avgFull, `custo caiu com abstração (${avgFull.toFixed(1)} → ${avgAbs.toFixed(1)}ms/tick, médias de 20 ticks)`);
});
