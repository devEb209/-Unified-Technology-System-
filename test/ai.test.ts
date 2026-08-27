import { test } from 'node:test';
import assert from 'node:assert/strict';
import { Rng } from '../src/core/index.ts';
import type { WorldAdapter } from '../src/contracts.ts';
import { MemorySystem } from '../src/ai/memory.ts';
import { HeuristicProvider, ModelRegistry, ProviderRegistry, PuterProvider, TIER_RANK } from '../src/ai/registries.ts';
import { SingularityCore, createDefaultAgents, createDefaultTools, interpretGoal } from '../src/ai/core.ts';

/* ------------------------------------------------------------------ */
/* Stub de mundo (implementa WorldAdapter — sem depender da UES real)  */
/* ------------------------------------------------------------------ */

class StubWorld implements WorldAdapter {
  exists = false;
  biomes: string[] = [];
  structures: string[] = [];
  npcs = 0;
  entityTotal = 0;
  failNextSpawn = false;
  breakStructures = false;

  createWorld(_opts: { size: number; biomes: string[]; seed: number }): { ok: boolean; id: string } {
    this.exists = true;
    return { ok: true, id: 'world-1' };
  }
  worldExists(): boolean {
    return this.exists;
  }
  createBiome(biome: string, _x: number, _y: number): { ok: boolean; id: string } {
    this.biomes.push(biome);
    return { ok: true, id: `biome-${biome}` };
  }
  buildStructures(structures: string[], _x: number, _y: number): { ok: boolean; count: number } {
    if (this.breakStructures) return { ok: false, count: 0 };
    this.structures.push(...structures);
    return { ok: true, count: structures.length };
  }
  spawnNpcs(count: number, _x: number, _y: number, _opts?: Record<string, unknown>): { ok: boolean; count: number; ids: string[] } {
    if (this.failNextSpawn) {
      this.failNextSpawn = false;
      return { ok: false, count: 0, ids: [] };
    }
    this.npcs += count;
    this.entityTotal += count;
    return { ok: true, count, ids: Array.from({ length: count }, (_, i) => `npc-${i}`) };
  }
  entityCount(): number {
    return this.entityTotal;
  }
  npcCount(): number {
    return this.npcs;
  }
  describe(): Record<string, unknown> {
    return { exists: this.exists, biomes: this.biomes, structures: this.structures, npcs: this.npcs };
  }
  checkInvariants(): { ok: boolean; issues: string[] } {
    const issues: string[] = [];
    if (!this.exists) issues.push('mundo não existe');
    if (this.npcs < 0) issues.push('npcs negativos');
    return { ok: issues.length === 0, issues };
  }
  optimizationReport(): Record<string, unknown> {
    return { pressure: 0.2, decisions: [] };
  }
  applyOptimization(): { ok: boolean; before: Record<string, unknown>; after: Record<string, unknown> } {
    return { ok: true, before: { pressure: 0.2 }, after: { pressure: 0.1 } };
  }
}

function makeCore(world: StubWorld): { core: SingularityCore; memory: MemorySystem } {
  const models = new ModelRegistry();
  const providers = new ProviderRegistry();
  const heuristic = new HeuristicProvider();
  providers.define(heuristic);
  providers.define(new PuterProvider());
  for (const m of [
    { id: 'uts-architect', providerId: 'heuristic', tier: 'S++' as const, capabilities: ['planning', 'decomposition', 'architecture'], cost: 1.0 },
    { id: 'uts-coder', providerId: 'heuristic', tier: 'S' as const, capabilities: ['code', 'specification', 'generation'], cost: 0.6 },
    { id: 'uts-critic', providerId: 'heuristic', tier: 'A' as const, capabilities: ['verification', 'critique', 'testing'], cost: 0.3 },
    { id: 'uts-scribe', providerId: 'heuristic', tier: 'B' as const, capabilities: ['summarization', 'naming', 'labels'], cost: 0.1 },
  ]) {
    models.define(m);
  }
  const memory = new MemorySystem();
  const core = new SingularityCore({
    models,
    providers,
    tools: createDefaultTools(() => ({ world })),
    agents: createDefaultAgents(),
    memory,
  });
  return { core, memory };
}

const ctx = { world: null as unknown as WorldAdapter, rng: new Rng(7), now: 0 };

/* ------------------------------------------------------------------ */

test('ModelRegistry: Main Model = melhor tier (S++); seleção por tarefa', () => {
  const models = new ModelRegistry();
  models.define({ id: 'm-b', providerId: 'p', tier: 'B', capabilities: ['code'], cost: 0.2 });
  models.define({ id: 'm-s', providerId: 'p', tier: 'S', capabilities: ['code', 'planning'], cost: 0.6 });
  models.define({ id: 'm-spp', providerId: 'p', tier: 'S++', capabilities: ['planning', 'decomposition'], cost: 1.0 });
  assert.equal(models.main().id, 'm-spp');
  // tarefa simples → tier baixo suficiente (barato)
  const easy = models.select({ capabilities: ['code'], complexity: 0.1 });
  assert.ok(TIER_RANK[easy.model.tier] >= 4, `tarefa simples deve usar tier mais baixo, veio ${easy.model.tier}`);
  // tarefa complexa → sobe de tier
  const hard = models.select({ capabilities: ['planning', 'decomposition'], complexity: 0.95 });
  assert.equal(hard.model.id, 'm-spp');
  // capacidade inexigível filtra
  assert.throws(() => models.select({ capabilities: ['vision'], complexity: 0.5 }));
});

test('Memory: conversação, short-term TTL, long-term + decaimento', () => {
  const m = new MemorySystem();
  m.message('c1', 'user', 'oi', 0);
  m.message('c1', 'assistant', 'olá', 1);
  assert.equal(m.conversation('c1').length, 2);
  m.setShort('viu uma tempestade', 10, 5);
  assert.equal(m.shortSince(10).length, 1);
  assert.equal(m.shortSince(20).length, 0); // expirou
  m.remember('fato.1', { x: 1 }, 0.9, 0);
  assert.deepEqual(m.recallFact('fato.1', 100)?.value, { x: 1 });
  m.decay(100 * 3600, 3600); // idade >> halfLife
  assert.ok((m.recallFact('fato.1')?.importance ?? 0) < 0.9);
  m.user.preferencia = 'pt-BR';
  m.preferences.theme = 'dark';
  m.project.uts = { versao: '0.1' };
  assert.ok(m.stats().messages >= 2);
});

test('Memory: decisions — a versão mais recente sempre vence (regra do projeto)', () => {
  const m = new MemorySystem();
  m.setDecision('arquitetura.nome', 'Unified Engine System', 0, 'versão antiga');
  m.setDecision('arquitetura.nome', 'UTS — Unified Technology System', 100, 'versão mais recente');
  const latest = m.decision('arquitetura.nome');
  assert.equal(latest?.value, 'UTS — Unified Technology System');
  assert.equal(latest?.supersedes, m.decisionHistory('arquitetura.nome')[0].id);
  assert.equal(m.decisionHistory('arquitetura.nome').length, 2);
});

test('interpretGoal: objetivos em PT/EN viram estrutura', () => {
  const g1 = interpretGoal('construir um bioma desert com 12 NPCs e um mercado');
  assert.equal(g1.type, 'build-scene');
  assert.equal(g1.params?.biome, 'desert');
  assert.equal(g1.params?.npcs, 12);
  assert.deepEqual(g1.params?.structures, ['market']);

  const g2 = interpretGoal('build a world of size 6 with plains and forest, 20 npcs, seed 99');
  assert.equal(g2.type, 'build-world');
  assert.equal(g2.params?.size, 6);
  assert.deepEqual(g2.params?.biomes, ['plains', 'forest']);
  assert.equal(g2.params?.seed, 99);
  assert.equal(g2.params?.count, 20);

  const g3 = interpretGoal('otimizar o mundo');
  assert.equal(g3.type, 'optimize');
  const g4 = interpretGoal('analisar o estado atual');
  assert.equal(g4.type, 'inspect');
  const g5 = interpretGoal('algo não categorizável xyz');
  assert.equal(g5.type, 'generic');
});

test('SingularityCore: fluxo completo OBJETIVO→…→VERIFICAÇÃO (build-scene)', () => {
  const world = new StubWorld();
  const { core, memory } = makeCore(world);
  ctx.world = world;
  world.exists = true; // pré-condição para a cena
  const report = core.run('construir bioma desert com 12 NPCs e um mercado', { ...ctx, now: 0 });
  assert.equal(report.status, 'success');
  assert.equal(report.goalType, 'build-scene');
  assert.equal(world.biomes[0], 'desert');
  assert.deepEqual(world.structures, ['market']);
  assert.equal(world.npcs, 12);
  assert.equal(report.corrections, 0);
  // modelos variados por tarefa (não só o S++)
  assert.ok(report.modelsUsed.length >= 2);
  assert.ok(report.modelsUsed.includes('uts-architect'));
  // memória registrou conversa + decisão + resultado
  assert.ok(memory.stats().messages >= 3);
  assert.equal(memory.decision(`result/${report.goalId}`)?.value.status, 'success');
  assert.ok(memory.recallFact(`goal.${report.goalId}.type`)?.value === 'build-scene');
});

test('SingularityCore: correção limitada — falha na 1ª, sucesso na 2ª', () => {
  const world = new StubWorld();
  const { core } = makeCore(world);
  ctx.world = world;
  world.exists = true;
  world.failNextSpawn = true;
  const report = core.run('adicionar um bioma plains com 5 NPCs', { ...ctx, now: 0 });
  assert.equal(report.status, 'success');
  assert.equal(report.corrections, 1);
  assert.equal(world.npcs, 5);
  const spawnStep = report.steps.find((s) => s.action === 'spawn-npcs')!;
  assert.equal(spawnStep.attempts, 2);
  assert.equal(spawnStep.ok, true);
});

test('SingularityCore: falha persistente → status partial (outros passos seguem)', () => {
  const world = new StubWorld();
  const { core } = makeCore(world);
  ctx.world = world;
  world.exists = true;
  world.breakStructures = true;
  const report = core.run('construir cena: bioma plains com 3 NPCs e um mercado', { ...ctx, now: 0 });
  assert.equal(report.status, 'partial');
  const structStep = report.steps.find((s) => s.action === 'build-structures')!;
  assert.equal(structStep.ok, false);
  assert.ok(structStep.issues.length > 0);
  assert.equal(structStep.attempts, 2); // bounded
  const npcStep = report.steps.find((s) => s.action === 'spawn-npcs')!;
  assert.equal(npcStep.ok, true);
  assert.equal(world.npcs, 3);
});

test('SingularityCore: build-world popula e verifica invariants', () => {
  const world = new StubWorld();
  const { core } = makeCore(world);
  ctx.world = world;
  assert.equal(world.worldExists(), false);
  const report = core.run('criar um mundo de tamanho 4 com plains e forest, 8 npcs, seed 42', { ...ctx, now: 0 });
  assert.equal(report.status, 'success');
  assert.equal(world.worldExists(), true);
  assert.equal(world.npcs, 8);
});

test('PuterProvider: é provider (não a IA); indisponível em Node com erro claro', () => {
  const p = new PuterProvider();
  assert.equal(p.isAvailable(), false);
  const providers = new ProviderRegistry();
  providers.define(p);
  assert.ok(!providers.available().includes('puter'));
  assert.ok(providers.available().length === 0);
  const res = p.call({
    model: { id: 'puter:auto', providerId: 'puter', tier: 'S', capabilities: [], cost: 0.5 },
    messages: [{ role: 'user', content: 'oi' }],
  });
  assert.equal(res.ok, false);
  assert.match(res.error ?? '', /Puter indisponível/);
});

test('ToolRegistry: a IA opera ferramentas nomeadas', () => {
  const world = new StubWorld();
  world.exists = true;
  const tools = createDefaultTools(() => ({ world }));
  assert.equal(tools.run('world.describe', {})['npcs'], 0);
  const r = tools.run('world.spawn-npcs', { count: 4, x: 0, y: 0 }) as { count: number };
  assert.equal(r.count, 4);
  assert.ok(tools.run('d-o15.report', {})['pressure'] === 0.2);
  assert.throws(() => tools.run('nao-existe', {}));
});
