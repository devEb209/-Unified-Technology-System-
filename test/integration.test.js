// UTS :: test/integration — the WHOLE chain in one reality:
// USER -> SINGULARITY CORE -> RRW -> WORLD+NMN+SOCIETY -> D-O15 ->
// MATERIALIZATION -> FRAME -> RENDERERS, plus causality, persistence,
// and scale under one roof.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createUTS, NullRenderer, TextRenderer } from '../src/index.js';
import { save, load, serializeState } from '../src/persistence/snapshot.js';
import { MemoryStorage } from '../src/persistence/storage.js';

test('integration: full chain — objective becomes a living, rendered, persistent reality', async () => {
  const uts = createUTS({ seed: 'integration-1', log: { level: 'error' } });

  // 1) Singularity AI builds the world from a natural objective
  const report = await uts.core.processObjective('criar uma pequena vila próxima a um rio chamada Vale Verde');
  assert.equal(report.ok, true, JSON.stringify(report.verifications));

  // 2) the reality evolves: weather, ecology, economy, minds, movement
  uts.ues.run(240);
  const stats = uts.ues.getStats();
  assert.ok(stats.counts.npcs > 0);
  assert.ok(stats.counts.events > 10, 'causal events accumulated');

  // 3) D-O15 reacted to measured pressure (EMA hysteresis -> sustained overload)
  for (let i = 0; i < 6; i++) uts.do15.report({ frameMs: 40, simMs: 40, tick: 1 });
  assert.ok(uts.do15.strategy.materializationRadius < 90, `radius adapted (${uts.do15.strategy.materializationRadius})`);

  // 4) Frame extraction -> GPU-shaped description
  const frame = uts.ues.renderFrame();
  assert.ok(frame.terrain.patches.length > 0);
  assert.ok(frame.entities.length > 0);

  // 5) backends manifest the same frame
  const nullR = new NullRenderer();
  nullR.render(frame);
  const textR = new TextRenderer({ cols: 60, rows: 20 });
  const ascii = textR.render(frame);
  assert.ok(ascii.includes('Vale Verde') === false && ascii.includes('tick='), 'text frame header');

  // 6) storm -> lightning -> fire -> NPC fear (verifiable causal chain)
  uts.world.reallife.igniteChance = 1.0;
  const someNpc = uts.rrw.query({ kind: 'npc', materialization: 'full' })[0];
  const npcPos = uts.rrw.getComponent(someNpc, 'spatial').pos;
  uts.world.strikeLightning([npcPos[0] + 6, 0, npcPos[2]]);
  uts.ues.run(3);
  const minds = uts.rrw.query({ kind: 'npc' }).map(id => uts.rrw.getComponent(id, 'mind'));
  const fled = minds.find(m => m.lastDecision?.action === 'flee');
  assert.ok(fled, 'an NPC fled from the fire');
  const sighted = Object.values(fled.fear)[0];
  assert.equal(uts.rrw.verifyCausalChain(sighted).valid, true, 'fear chain fully verifiable');
  const chain = uts.rrw.causalityChain(sighted).map(e => e.type);
  // the chain reaches at least: sighted -> fire.started -> lightning.strike -> (weather history…)
  assert.deepEqual(chain.slice(0, 3), ['npc.hazard.sighted', 'reallife.fire.started', 'reallife.lightning.strike']);
  assert.ok(chain.length >= 3);

  // 7) persistence: save mid-storm, restore, both realities evolve identically.
  // Before persisting, D-O15 is relaxed to the low-pressure regime and pinned:
  // host timing is runtime evidence, so deterministic replay pins the strategy.
  for (let i = 0; i < 12; i++) uts.do15.report({ frameMs: 0.5, simMs: 0.5, tick: uts.world.clock.tick });
  uts.do15.pinned = true;
  const store = new MemoryStorage();
  await save(store, 'mid', uts);
  const B = await load(store, 'mid');
  B.do15.pinned = true;
  B.ues.run(50);
  uts.ues.run(50);
  assert.deepEqual(serializeState(B), serializeState(uts), 'A == B after 50 more ticks');
});

test('integration: UES scheduler respects the global budget under load', async () => {
  const uts = createUTS({ seed: 'integration-2' });
  // every now() call advances the fake clock by 5ms -> budgets exhaust mid-tick
  let c = 0;
  uts.ues.scheduler.now = () => (c += 5);
  uts.ues.scheduler.globalBudgetMs = 0.0001; // force deferrals every tick
  for (let i = 0; i < 10; i++) uts.ues.tick();
  const sched = uts.ues.scheduler;
  assert.ok(sched.last.skipped.length > 0 || sched.systems.some(s => s.skipped > 0), 'budget produced deferrals');
  // nothing was dropped: every system still ran
  assert.ok(sched.systems.every(s => s.runs > 0), 'deferred systems all ran eventually');
});

test('integration: 95+ invariant — D layers all show observable effects in a lived world', async () => {
  const uts = createUTS({ seed: 'integration-3' });
  await uts.core.processObjective('criar uma pequena vila próxima a um rio chamada Campos');
  uts.world.setWeather('rain');
  uts.ues.run(120);
  uts.ues.renderFrame(); // manifests the Frame (D-11 audio touch)
  const active = ['D-0', 'D-1', 'D-2', 'D-3', 'D-4', 'D-5', 'D-6', 'D-7', 'D-8', 'D-11', 'D-12', 'D-14', 'D-O15'];
  for (const d of active) {
    const eff = uts.tese.effect(d);
    assert.ok(eff && eff.count > 0, `${d} had no observable effect`);
  }
});
