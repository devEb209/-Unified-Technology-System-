import { test } from 'node:test';
import assert from 'node:assert/strict';
import { MemorySystem } from '../src/ai/memory.ts';
import { HeuristicProvider, ModelRegistry, ProviderRegistry, PuterProvider } from '../src/ai/registries.ts';
import { SingularityCore, createDefaultAgents, createDefaultTools } from '../src/ai/core.ts';
import { createUes } from '../src/ues/engine.ts';
import { HARDWARE_PRESETS } from '../src/d-o15/index.ts';
import { buildVillage } from '../src/ues/npc.ts';
import { MATERIAL_THRESHOLD } from '../src/rrw/index.ts';

function buildSetup(seed = 7, hardware = 'high-end') {
  const engine = createUes({ seed, hardware: HARDWARE_PRESETS[hardware] });
  const memory = new MemorySystem();
  const models = new ModelRegistry();
  const providers = new ProviderRegistry();
  providers.define(new HeuristicProvider());
  providers.define(new PuterProvider());
  for (const m of [
    { id: 'uts-architect', providerId: 'heuristic', tier: 'S++' as const, capabilities: ['planning', 'decomposition', 'architecture'], cost: 1.0 },
    { id: 'uts-coder', providerId: 'heuristic', tier: 'S' as const, capabilities: ['code', 'specification', 'generation'], cost: 0.6 },
    { id: 'uts-critic', providerId: 'heuristic', tier: 'A' as const, capabilities: ['verification', 'critique', 'testing'], cost: 0.3 },
    { id: 'uts-scribe', providerId: 'heuristic', tier: 'B' as const, capabilities: ['summarization', 'naming', 'labels'], cost: 0.1 },
  ]) {
    models.define(m);
  }
  const core = new SingularityCore({
    models,
    providers,
    tools: createDefaultTools(() => ({ world: engine.world })),
    agents: createDefaultAgents(),
    memory,
  });
  return { engine, core, memory };
}

test('INTEGRAÇÃO: OBJETIVO → Singularity Core → UES → mundo vive (ciclo completo)', () => {
  const { engine, core, memory } = buildSetup(7, 'high-end');
  const world = engine.world;
  const center = world.worldSize() / 2;
  world.setFocus(center, center);
  world.stream();

  // 1) IA orquestra a construção da cena (com localização — o foco está no centro)
  const report = core.run(`construir bioma desert com 12 NPCs e um mercado em x ${Math.round(center)} y ${Math.round(center)}`, { world, rng: engine.rng, now: 0 });
  assert.equal(report.status, 'success', report.summary);
  assert.equal(world.npcCount(), 12);
  assert.equal(world.rrw.query({ categories: ['structure'], data: { type: 'market' } }).length, 1);
  assert.ok(world.biomeAt(center, center) === 'desert', 'zona de bioma desert ativa');

  // 2) mundo evolui: NPCs raciocinam, agem, deixam rastro causal
  const npc0 = engine.npcList()[0];
  const moneyBefore = npc0.mind.money;
  engine.advance(30); // 30 s de simulação
  const episodes = engine.npcList().flatMap((n) => n.mind.episodes);
  assert.ok(episodes.length > 5, `NPCs evoluíram (${episodes.length} episódios)`);
  const hungerEvents = world.rrw.eventTypesList().includes('npc.hunger');
  const actionEvents = ['npc.eat', 'npc.trade', 'work.produced', 'npc.socialize'].filter((t) => world.rrw.eventTypesList().includes(t));
  assert.ok(hungerEvents || actionEvents.length > 0, 'há eventos de comportamento no RRW');

  // 3) causalidade verificável: toda transação tem causa que existe
  const trades = world.rrw.recent(500).filter((e) => e.type === 'npc.trade');
  for (const t of trades.slice(0, 5)) {
    assert.ok(t.cause, 'trade tem causa');
    const causeEvt = world.rrw.eventsOf(t.cause!.by).find((e) => e.type === t.cause!.event);
    assert.ok(causeEvt, `evento causa ${t.cause!.event} existe no log`);
  }

  // 4) streaming + preservação de estado: foco se afasta e volta
  const far = { x: 2, y: 2 };
  world.setFocus(far.x, far.y);
  world.stream();
  const matAfterLeave = engine.npcList().filter((n) => world.rrw.isMaterial(n.id, MATERIAL_THRESHOLD)).length;
  assert.ok(matAfterLeave < 6, `NPCs se abstratizam fora do foco (${matAfterLeave} materializados)`);
  // estado preservado em abstração (acessível via snapshot)
  const mindSnap = world.rrw.get(npc0.id)?.compressed?.get('Mind') as { money: number } | undefined;
  assert.ok(mindSnap, 'mente preservada em snapshot comprimido');
  world.setFocus(center, center);
  world.stream();
  assert.ok(world.rrw.isMaterial(npc0.id, MATERIAL_THRESHOLD), 'NPC re-materializado ao voltar o foco');
  assert.equal(npc0.mind.money, moneyBefore, 'dinheiro íntegro após abstração+materialização');

  // 5) D-O15 ativo: decisões por sistema + relatório
  const stats = engine.stats() as { decisions: string[]; pressure: number };
  assert.ok(stats.decisions.length >= 5, 'D-O15 tem decisão por sistema');
  assert.ok(stats.pressure >= 0);

  // 6) gráficos: frames derivaram do estado
  assert.ok(engine.lastFrame, 'frames renderizados');
  assert.ok(engine.lastFrame!.entities.length > 0);

  // 7) invariants do mundo
  const inv = world.checkInvariants();
  assert.equal(inv.ok, true, inv.issues.join('; '));

  // 8) memória: a IA lembra do que fez (continuidade)
  assert.equal(memory.decision(`result/${report.goalId}`)?.value.status, 'success');
  assert.ok(memory.stats().messages >= 5);
});

test('INTEGRAÇÃO: vila + sociedade + IA (buildVillage e invariants econômicos)', () => {
  const { engine, core } = buildSetup(11, 'high-end');
  const world = engine.world;
  const c = world.worldSize() / 2;
  world.setFocus(c, c);
  world.stream();
  const group = buildVillage(world, c - 8, c - 8, { name: 'Demo', population: 6 });
  engine.society.refresh();
  const stockBefore = { ...(group.data.stock as Record<string, number>) };
  engine.advance(25);
  const stockAfter = group.data.stock as Record<string, number>;
  assert.ok(stockAfter.wood > stockBefore.wood, 'economia da vila produziu madeira');
  // a IA pode inspecionar o estado construído
  const insp = core.run('analisar o mundo', { world, rng: engine.rng, now: 1 });
  assert.equal(insp.status, 'success');
  const inv = world.checkInvariants();
  assert.equal(inv.ok, true, inv.issues.join('; '));
});

test('INTEGRAÇÃO: hardware adaptativo — autoOptimize degrada sob pressão extrema', () => {
  const { engine } = buildSetup(3, 'workstation');
  const world = engine.world;
  const c = world.worldSize() / 2;
  world.setFocus(c, c);
  world.stream();
  // sobrecarga deliberada: 400 NPCs materializados no foco
  for (let i = 0; i < 400; i++) {
    const a = engine.rng.next() * Math.PI * 2;
    const r = engine.rng.next() * 10;
    engine.world.spawnNpc({ x: c + Math.cos(a) * r, y: c + Math.sin(a) * r });
  }
  // orçamento minúsculo → pressão garantidamente extrema
  engine.setHardware({ ...HARDWARE_PRESETS.workstation, id: 'workstation', cpuBudgetMs: 0.05 });
  for (let i = 0; i < 100; i++) engine.tick();
  const pressure = engine.lastDecisionPressure;
  assert.ok(pressure > 0.85, `pressão extrema medida (${pressure.toFixed(2)})`);
  const applied = engine.autoOptimize();
  assert.equal(applied.applied, true, 'autoOptimize deve degradar o hardware');
  assert.equal(applied.to, 'high-end', 'degrada um degrau da escada');
  assert.ok(engine.lastTick?.deferred.length > 0 || engine.counters.deferredTotal > 0, 'sistemas foram deferidos (adaptação real)');
});

test('INTEGRAÇÃO: ferramenta da IA lê D-O15 e aplica otimização (WorldAdapter)', () => {
  const { engine, core } = buildSetup(5, 'mid');
  const world = engine.world;
  world.setFocus(24, 24);
  world.stream();
  const report = core.run('otimizar o mundo', { world, rng: engine.rng, now: 0 });
  assert.equal(report.status, 'success', report.summary);
  const analyzeStep = report.steps.find((s) => s.action === 'analyze');
  assert.ok(analyzeStep?.ok);
  const applyStep = report.steps.find((s) => s.action === 'apply-strategy');
  assert.ok(applyStep, 'etapa de aplicar estratégia existe');
  // o bridge de otimização está ligado ao D-O15 real
  const rep = world.optimizationReport() as { decisions: unknown[] };
  assert.ok(Array.isArray(rep.decisions));
});
