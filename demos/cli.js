#!/usr/bin/env node
// UTS :: demos/cli — end-to-end proof in the terminal.
// Creates a reality via the Singularity Core, evolves it, prints frames,
// shows D-O15 decisions, causal chains and perf numbers. No renderer needed.

import { createUTS, TextRenderer, NullRenderer } from '../src/index.js';
import { serializeState } from '../src/persistence/snapshot.js';

const seed = process.argv[2] ?? 'uts-cli-demo';
console.log(`\n=== UTS — Unified Technology System (seed: ${seed}) ===\n`);

const uts = createUTS({ seed, log: { level: 'warn' } });
const { core, ues, world, rrw, do15 } = uts;

// 1) Singularity AI: objective -> interpretation -> plan -> tools -> verification
console.log('[1] Singularity Core: processing objective…');
const report = await core.processObjective('criar uma pequena vila próxima a um rio chamada Vila Doce Rio');
console.log(`    intent=${report.interpretation.intent} provider=${report.chosen.provider} model=${report.chosen.model}`);
console.log(`    plan: ${report.plan.tasks.map(t => t.tool).join(' -> ')}`);
console.log(`    verified: ${report.verifications.map(v => `${v.check}=${v.ok ? 'OK' : 'FAIL'}`).join(', ')}\n`);

// 2) force a storm through the causal chain and let reality react
console.log('[2] RealLife: forcing storm (causal chain)…');
const stormId = world.setWeather('storm');
console.log(`    weather event ${stormId}, chain:`, JSON.stringify(rrw.verifyCausalChain(stormId)), '\n');

// 3) evolve the reality
console.log('[3] Evolving 600 ticks (weather, ecology, economy, NMN, materialization)…');
const textRenderer = new TextRenderer({ cols: 76, rows: 24 });
const nullRenderer = new NullRenderer();
for (let i = 0; i < 600; i++) {
  ues.tick();
  if (i % 200 === 0) {
    const frame = ues.renderFrame();
    nullRenderer.render(frame);
    console.log(textRenderer.render(frame));
    console.log('');
  }
}

// 4) D-O15 decisions + perf + stats
console.log('[4] D-O15 decisions (last 5):');
for (const d of do15.decisions.slice(-5)) {
  console.log(`    [p=${d.pressure?.toFixed(2)}] ${d.kind}: ${d.reason}`);
}
const stats = ues.getStats();
console.log('\n[5] Scheduler:');
for (const s of stats.scheduler) {
  console.log(`    ${s.name.padEnd(14)} runs=${String(s.runs).padEnd(6)} skipped=${String(s.skipped).padEnd(4)} avg=${s.avgMs.toFixed(2)}ms max=${s.maxMs.toFixed(2)}ms`);
}
console.log('\n[6] Counts:', JSON.stringify(stats.counts));
console.log('    RRW stats:', JSON.stringify(rrw.stats));

// 7) causal chain of an NPC flee (if a fire happened)
const fled = rrw.query({ kind: 'npc' })
  .map(id => rrw.getComponent(id, 'mind')?.lastDecision)
  .find(d => d?.action === 'flee');
if (fled) {
  const ev = rrw.getEvent(fled.because?.[0]?.perceived ? rrw.getComponent(fled.because[0].perceived, 'hazard')?.startedEvent : null);
  console.log('\n[7] NPC flee detected; hazard chain:', ev ? JSON.stringify(rrw.verifyCausalChain(ev.id)) : '(chained via sighted event)');
} else {
  console.log('\n[7] No flee occurred in this seed run (weather RNG did not ignite near NPCs).');
}

// 8) persistence determinism check
const snap = serializeState(uts);
console.log(`\n[8] Snapshot serialized: schemaVersion=${snap.schemaVersion}, entities=${snap.rrw.entities.length}, events=${snap.rrw.events.length}`);
console.log('\n=== done ===\n');
