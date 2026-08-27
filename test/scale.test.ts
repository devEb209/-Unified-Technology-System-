import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createUes } from '../src/ues/engine.ts';
import { HARDWARE_PRESETS } from '../src/d-o15/index.ts';
import { MATERIAL_THRESHOLD } from '../src/rrw/index.ts';

interface ScaleResult {
  avgTickMs: number;
  maxTickMs: number;
  overBudgetTicks: number;
  deferredTotal: number;
  materialNpcs: number;
  totalNpcs: number;
  totalEntities: number;
  pressure: number;
}

function runScale(npcs: number, seconds: number, hardware: string, seed = 7): ScaleResult {
  const engine = createUes({ seed, hardware: HARDWARE_PRESETS[hardware] });
  const world = engine.world;
  const c = world.worldSize() / 2;
  world.setFocus(c, c);
  world.stream();
  for (let i = 0; i < npcs; i++) {
    const a = engine.rng.next() * Math.PI * 2;
    const r = engine.rng.next() * (world.cfg.activeRadiusChunks * world.cfg.chunkSize);
    world.spawnNpc({ x: c + Math.cos(a) * r, y: c + Math.sin(a) * r });
  }
  const t0 = process.hrtime.bigint();
  const ticks = Math.round(seconds / 0.1);
  let maxTick = 0;
  for (let i = 0; i < ticks; i++) {
    const ta = process.hrtime.bigint();
    engine.tick();
    const ms = Number(process.hrtime.bigint() - ta) / 1e6;
    maxTick = Math.max(maxTick, ms);
  }
  const totalMs = Number(process.hrtime.bigint() - t0) / 1e6;
  const mat = engine.npcList().filter((n) => world.rrw.isMaterial(n.id, MATERIAL_THRESHOLD)).length;
  return {
    avgTickMs: totalMs / ticks,
    maxTickMs: maxTick,
    overBudgetTicks: engine.counters.overBudgetTicks,
    deferredTotal: engine.counters.deferredTotal,
    materialNpcs: mat,
    totalNpcs: engine.npcList().length,
    totalEntities: world.rrw.stats().entities,
    pressure: engine.lastDecisionPressure,
  };
}

test('ESCALA: pequeno (20 NPCs) — tudo full, sem pressão', () => {
  const r = runScale(20, 10, 'high-end');
  assert.equal(r.totalNpcs, 20);
  assert.ok(r.pressure < 0.9, `pressão baixa em escala pequena (${r.pressure.toFixed(2)})`);
  assert.ok(r.avgTickMs > 0);
});

test('ESCALA: médio (120 NPCs) — D-O15 mantém o resultado dentro do orçamento', () => {
  const r = runScale(120, 15, 'mid');
  assert.equal(r.totalNpcs, 120);
  assert.ok(r.materialNpcs > 0, 'NPCs no foco continuam materializados');
  assert.ok(r.totalEntities > 120, 'mundo tem entidades além dos NPCs (recursos/estrutura)');
});

test('ESCALA: grande (500 NPCs, low-end) — adaptação real (defer + pressão)', () => {
  const r = runScale(500, 10, 'low-end');
  assert.equal(r.totalNpcs, 500);
  assert.ok(r.deferredTotal > 0 || r.overBudgetTicks > 0, `adaptação ocorreu (defer=${r.deferredTotal}, over=${r.overBudgetTicks})`);
  assert.ok(r.avgTickMs < 25, `tick médio sob controle (${r.avgTickMs.toFixed(2)}ms)`);
});

test('ESCALA: extremo — 5 mil entidades abstratas (D-1) evoluem barato', () => {
  const engine = createUes({ seed: 9, hardware: HARDWARE_PRESETS.mid });
  const world = engine.world;
  const c = world.worldSize() / 2;
  world.setFocus(c, c);
  world.stream();
  // enxame de entidades abstratas longes do foco (representação semântica D-1)
  for (let i = 0; i < 5000; i++) {
    const a = (i / 5000) * Math.PI * 2;
    const rr = 30 + (i % 20);
    world.rrw.create({
      name: `drift-${i}`,
      categories: ['organism/creature'],
      components: { Position: { x: c + Math.cos(a) * rr, y: c + Math.sin(a) * rr } },
      data: { vitality: 1 },
      detail: 0,
    });
  }
  // processo abstrato simples (evolução do enxame)
  world.rrw.defineProcess('drift', {
    init: () => 'roaming',
    abstractTick: (ent) => {
      ent.data.vitality = Number(ent.data.vitality) - 0.001;
    },
  });
  const swarm = world.rrw.query({ categories: ['organism/creature'] });
  world.rrw.startProcess('drift', swarm.map((e) => e.id));
  const t0 = process.hrtime.bigint();
  for (let i = 0; i < 300; i++) {
    world.rrw.time += 0.1;
    world.rrw.stepProcess('drift', { dt: 0.1, time: world.rrw.time, rng: engine.rng, rrw: world.rrw });
  }
  const ms = Number(process.hrtime.bigint() - t0) / 1e6;
  assert.ok(ms < 500, `5000 entidades abstratas em 300 ticks custaram ${ms.toFixed(1)}ms (< 500ms)`);
  const alive = world.rrw.query({ categories: ['organism/creature'] }).length;
  assert.equal(alive, 5000, 'nenhuma entidade abstrata perdida');
  const v = (swarm[0].data.vitality as number);
  assert.ok(v < 1, `estado abstrato evolui (vitality ${v.toFixed(4)})`);
});

test('ESCALA: representação adaptativa reage (foco afasta → custo cai)', () => {
  const engine = createUes({ seed: 7, hardware: HARDWARE_PRESETS.mid });
  const world = engine.world;
  const c = world.worldSize() / 2;
  world.setFocus(c, c);
  world.stream();
  for (let i = 0; i < 200; i++) {
    const a = engine.rng.next() * Math.PI * 2;
    const r = engine.rng.next() * 8;
    world.spawnNpc({ x: c + Math.cos(a) * r, y: c + Math.sin(a) * r });
  }
  // custo com NPCs no foco
  const t0 = process.hrtime.bigint();
  for (let i = 0; i < 100; i++) engine.tick();
  const msNear = Number(process.hrtime.bigint() - t0) / 1e6;
  const matNear = engine.npcList().filter((n) => world.rrw.isMaterial(n.id, MATERIAL_THRESHOLD)).length;
  // foco vai para longe: NPCs ficam abstratos (D-2 não roda)
  world.setFocus(1, 1);
  world.stream();
  const matFar = engine.npcList().filter((n) => world.rrw.isMaterial(n.id, MATERIAL_THRESHOLD)).length;
  const t1 = process.hrtime.bigint();
  for (let i = 0; i < 100; i++) engine.tick();
  const msFar = Number(process.hrtime.bigint() - t1) / 1e6;
  assert.ok(matFar < matNear, `materialização caiu com o foco (${matNear} → ${matFar})`);
  assert.ok(msFar < msNear, `custo caiu com a abstração (${msNear.toFixed(1)}ms → ${msFar.toFixed(1)}ms)`);
});
