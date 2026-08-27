/**
 * UTS · Demo — o ciclo completo em um só lugar:
 *
 *   OBJETIVO (texto) → Singularity Core → UES/RRW → mundo vivo →
 *   D-O15 (adaptação) → Gráficos (frame ASCII) → Relatório.
 *
 * Uso:
 *   npm run demo                    (hardware alto, 60 s de sim)
 *   npm run demo:lowend             (mesmo seed, hardware low-end)
 *   node tools/demo.ts --hardware mid --seconds 30 --seed 42
 */

import { HeuristicProvider, ModelRegistry, ProviderRegistry, PuterProvider } from '../src/ai/registries.ts';
import { MemorySystem } from '../src/ai/memory.ts';
import { SingularityCore, createDefaultAgents, createDefaultTools } from '../src/ai/core.ts';
import { HARDWARE_PRESETS, type HardwareProfile } from '../src/d-o15/index.ts';
import { createUes } from '../src/ues/engine.ts';
import { buildVillage } from '../src/ues/npc.ts';
import { TextBackend } from '../src/ues/graphics.ts';

/* ---------------- args ---------------- */

const args: Record<string, string> = {};
for (let i = 2; i < process.argv.length - 1; i++) {
  if (process.argv[i].startsWith('--')) args[process.argv[i].slice(2)] = process.argv[i + 1];
}
const hwId = args.hardware ?? 'high-end';
const seconds = Number(args.seconds ?? 60);
const seed = Number(args.seed ?? 42);
const hardware: HardwareProfile = { ...HARDWARE_PRESETS[hwId], label: `${HARDWARE_PRESETS[hwId].label} (demo)` };

const line = (s = '─') => console.log(s.repeat(64));

/* ---------------- boot ---------------- */

console.log('UTS — UNIFIED TECHNOLOGY SYSTEM · demo');
line();
const engine = createUes({ seed, hardware, backend: 'text' });
const world = engine.world;
const center = world.worldSize() / 2;
world.setFocus(center, center);
world.stream();

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
  tools: createDefaultTools(() => ({ world })),
  agents: createDefaultAgents(),
  memory,
});

/* ---------------- 1) IA constrói a cena ---------------- */

const goal = `construir bioma desert com 12 NPCs e um mercado em x ${Math.round(center)} y ${Math.round(center)}`;
console.log(`\n[OBJETIVO] "${goal}"`);
const report = core.run(goal, { world, rng: engine.rng, now: 0 });
console.log(`[CORE] ${report.summary}`);
console.log(`[CORE] etapas: ${report.steps.map((s) => `${s.action}${s.ok ? '✓' : '✗'}`).join(' · ')}`);
console.log(`[CORE] modelos usados: ${report.modelsUsed.join(', ')}`);

// sociedade: uma vila perto do mercado (via API direta da UES)
const village = buildVillage(world, center - 10, center + 10, { name: 'Alvorada', population: 5 });
engine.society.refresh();
world.spawnStructure('market', center + 8, center - 6);
engine.society.refresh();
console.log(`[MUNDO] vila "${village.name}" fundada (pop=${village.data.population})`);

/* ---------------- 2) mundo vive ---------------- */

const ticks = Math.round(seconds / 0.1);
const every = Math.round(15 / 0.1);
const weatherSeen = new Set<string>();
for (let i = 0; i < ticks; i++) {
  engine.tick();
  const w = world.rrw.get(world.env.id)?.data.weather as string;
  if (w && !weatherSeen.has(w)) weatherSeen.add(w);
  if ((i + 1) % every === 0) {
    const t = world.rrw.time;
    const env = world.rrw.get(world.env.id)!;
    const s = engine.stats() as Record<string, unknown>;
    const wDesc = s['world'] as { npcs: number; material: number; abstract: number; weather: string; loadedChunks: number };
    const society = s['society'] as string[];
    console.log(`\n[${t.toFixed(0)}s] clima=${env.data.weather} temp=${Number(env.data.temperature).toFixed(1)}° npcs=${wDesc.npcs} (mat=${wDesc.material}, abs=${wDesc.abstract}) chunks=${wDesc.loadedChunks} pressao=${(s['pressure'] as number).toFixed(2)}`);
    for (const ln of society) console.log(`   ${ln}`);
    const frame = engine.lastFrame;
    if (frame) {
      const out = (engine.graphics as { backend: TextBackend }).backend.render(frame, world).output;
      if (out) console.log(out);
    }
  }
}

/* ---------------- 3) relatório final ---------------- */

line('═');
console.log('RELATÓRIO FINAL');
line('═');
const finalStats = engine.stats() as {
  time: number;
  hardware: string;
  pressure: number;
  bottleneck: string | null;
  memoryMB: number;
  decisions: string[];
  world: Record<string, number>;
  society: string[];
};
console.log(`simulação: ${finalStats.time}s · hardware: ${finalStats.hardware} · pressão última janela: ${finalStats.pressure} · gargalo: ${finalStats.bottleneck ?? '—'} · memória: ${finalStats.memoryMB}MB`);
console.log(`adaptatividade: ticks sobre orçamento=${engine.counters.overBudgetTicks} · deferidos=${engine.counters.deferredTotal} de ${engine.counters.ticks} ticks`);
console.log('\nD-O15 (decisões por sistema):');
for (const d of finalStats.decisions) console.log(`   ${d}`);
console.log('\nmundo:');
for (const [k, v] of Object.entries(finalStats.world)) {
  const shown = v && typeof v === 'object' ? JSON.stringify(v) : v;
  console.log(`   ${k}: ${shown}`);
}
console.log('\nsociedade:');
for (const s of finalStats.society) console.log(`   ${s}`);

// rastro comportamental dos NPCs (NMN)
const npcs = engine.npcList();
const acted = npcs.filter((n) => n.mind.episodes.length > 0);
console.log(`\nNMN: ${acted.length}/${npcs.length} NPCs com episódios de experiência`);
const sample = npcs.slice(0, 4);
for (const n of sample) {
  const m = n.mind;
  const last = m.episodes[m.episodes.length - 1];
  console.log(`   ${n.ent.name}: money=${m.money} food=${m.inventory.food ?? 0} fome=${m.needs.hunger.toFixed(2)} último=${last ? last.type : '—'}`);
}

// causalidade real capturada no RRW
const fires = world.rrw.recent(400).filter((e) => e.type === 'fire.starts');
if (fires.length > 0) {
  const f = fires[fires.length - 1];
  const chain = world.rrw.causalChain(f.entities[0], 'fire.starts');
  console.log(`\ncausalidade capturada: ${chain.map((e) => e.type).join(' ← ')}`);
} else {
  const trades = world.rrw.recent(400).filter((e) => e.type === 'npc.trade');
  if (trades.length > 0) {
    const t = trades[trades.length - 1];
    console.log(`\ncausalidade capturada: npc.trade ← ${t.cause?.event ?? '—'} (${t.cause?.description})`);
  }
}

const mem = memory.stats();
console.log(`\nmemória da IA: ${mem.messages} mensagens · ${mem.longTerm} fatos longos · ${mem.decisionTopics} tópicos de decisão`);
const inv = world.checkInvariants();
console.log(`invariants: ${inv.ok ? 'OK' : inv.issues.join('; ')}`);
console.log('\nfim da demo — a UTS continua evoluindo.');
