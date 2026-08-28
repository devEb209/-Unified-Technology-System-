// UTS :: test/singularity — Core flow: objective -> interpretation ->
// plan -> agents/tools -> verification -> correction -> memory. Model
// selection is capability+cost driven; fallbacks keep the Core in control.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createUTS } from '../src/index.js';
import { ProviderRegistry } from '../src/singularity/provider.js';
import { HeuristicProvider } from '../src/singularity/heuristic.js';
import { PuterProvider } from '../src/singularity/puter.js';
import { ModelRegistry } from '../src/singularity/models.js';
import { ToolValidationError } from '../src/singularity/tools.js';

test('core: full flow creates a verified settlement from a natural objective', async () => {
  const uts = createUTS({ seed: 'core' });
  const report = await uts.core.processObjective('criar uma pequena vila próxima a um rio chamada Vila Teste');
  assert.equal(report.interpretation.intent, 'create_settlement');
  assert.equal(report.interpretation.params.nearRiver, true);
  assert.equal(report.ok, true);
  assert.ok(report.verifications.every(v => v.ok), JSON.stringify(report.verifications));
  assert.ok(uts.rrw.count('settlement') === 1);
  assert.ok(uts.rrw.count('npc') >= 8);
  const s = uts.rrw.query({ kind: 'settlement' }).map(id => uts.rrw.get(id))[0];
  assert.equal(s.name, 'Vila Teste');
  assert.ok(s.components.get('spatial').pos.every(Number.isFinite), 'position finite (near real water)');
});

test('core: memory records decisions and project state', async () => {
  const uts = createUTS({ seed: 'mem' });
  await uts.core.processObjective('criar uma pequena vila próxima a um rio chamada Memória');
  const dec = uts.core.memory.decisions.at(-1);
  assert.equal(dec.intent, 'create_settlement');
  assert.equal(dec.ok, true);
  assert.equal(uts.core.memory.getProject('lastSettlement'), 'Memória');
  assert.ok(uts.core.memory.recall({ contains: 'vila' }).length > 0);
});

test('core: weather objective applies causal weather change', async () => {
  const uts = createUTS({ seed: 'weather-core' });
  const report = await uts.core.processObjective('começar uma tempestade agora');
  assert.equal(report.ok, true);
  assert.equal(uts.world.environment.weather, 'storm');
  assert.ok(report.verifications.find(v => v.check === 'weather.causalChain').ok);
});

test('core: unknown objectives are honestly reported, never invented', async () => {
  const uts = createUTS({ seed: 'unknown' });
  const report = await uts.core.processObjective('fazer café quântico para todos');
  assert.equal(report.interpretation.intent, 'unknown');
  assert.equal(report.ok, false);
  assert.equal(report.plan.tasks.length, 0, 'free text never mutates state');
  assert.equal(uts.rrw.count('settlement'), 0);
});

test('core: failing provider falls back to heuristic and still completes', async () => {
  const uts = createUTS({ seed: 'fallback' });
  const failing = {
    name: 'failing',
    capabilities: () => ({ structured: true, reasoning: true }),
    cost: () => 0,
    async availability() { return true; },
    async generate() { throw new Error('provider exploded'); },
  };
  uts.core.providers.register(failing);
  uts.core.models.register({ id: 'failing-1', tier: 'B', provider: 'failing', costPer1k: 1, latencyMs: 1, context: 1000, capabilities: { text: true, reasoning: true, code: false, structured: true, tools: false } });
  const report = await uts.core.processObjective('criar uma pequena vila próxima a um rio chamada Fallback', { preferredProvider: 'failing' });
  assert.equal(report.interpretation.provider, 'heuristic');
  assert.ok(report.interpretation.fallbackReason.includes('exploded'));
  assert.equal(report.ok, true, 'fallback kept the Core in control');
  assert.ok(uts.rrw.count('settlement') === 1);
});

test('core: invalid LLM JSON triggers correction loop, then success', async () => {
  const uts = createUTS({ seed: 'flaky' });
  let calls = 0;
  const flaky = {
    name: 'flaky',
    capabilities: () => ({ structured: true, reasoning: true }),
    cost: () => 0,
    async availability() { return true; },
    async generate({ messages }) {
      calls++;
      const hint = messages.at(-1).content.includes('invalid');
      if (calls <= 2 && !hint) return { text: 'not json at all', json: null };
      if (calls <= 2) return { text: 'still wrong', json: { intent: 'NOT_AN_INTENT' } };
      const good = { intent: 'create_settlement', params: { name: 'Vila Flaky', pop: 8, nearRiver: false } };
      return { text: JSON.stringify(good), json: good };
    },
  };
  uts.core.providers.register(flaky);
  uts.core.models.register({ id: 'flaky-1', tier: 'B', provider: 'flaky', costPer1k: 1, latencyMs: 1, context: 1000, capabilities: { text: true, reasoning: true, code: false, structured: true, tools: false } });
  const report = await uts.core.processObjective('criar vila chamada Vila Flaky', { preferredProvider: 'flaky' });
  assert.equal(calls, 3, 'two corrections then success');
  assert.equal(report.interpretation.corrections, 2);
  assert.equal(report.ok, true);
});

test('model registry: cheapest sufficient model wins; filters by cost/capability', () => {
  const models = new ModelRegistry();
  const reasoning = models.select({ reasoning: true });
  assert.ok(!reasoning.some(m => m.id === 'heuristic-core'), 'heuristic cannot satisfy reasoning');
  assert.equal(reasoning.at(-1).id, 'gpt-main'); // most powerful last
  assert.equal(models.select({ maxCost: 1 })[0]?.id, 'heuristic-core');
  assert.deepEqual(models.select({ vision: true }).map(m => m.id), ['gpt-main']);
  assert.ok(models.select({}).length >= 3);
});

test('agents: capability-based selection picks the right specialist', async () => {
  const uts = createUTS({ seed: 'agents' });
  assert.equal(uts.core.agents.select(['world']).name, 'world-builder');
  assert.equal(uts.core.agents.select(['architecture']).name, 'architect');
  assert.equal(uts.core.agents.select(['verification']).name, 'verifier');
  assert.equal(uts.core.agents.select(['graphics']).name, 'graphics');
  assert.equal(uts.core.agents.select(['test']).name, 'tester');
});

test('tools: params are validated — free text cannot bypass the schema', async () => {
  const uts = createUTS({ seed: 'tools' });
  await assert.rejects(() => uts.core.tools.execute('ues.create_settlement', {}), ToolValidationError);
  await assert.rejects(() => uts.core.tools.execute('ues.spawn_npcs', { count: 99999 }), /max/);
  await assert.rejects(() => uts.core.tools.execute('world.set_weather', { weather: 'apocalipse' }), /one of/);
  await assert.rejects(() => uts.core.tools.execute('does.not.exist', {}), /unknown tool/);
});

test('tools: create_settlement is idempotent under corrective retries', async () => {
  const uts = createUTS({ seed: 'idem' });
  const r1 = await uts.core.tools.execute('ues.create_settlement', { name: 'Unica', pop: 10, nearRiver: false });
  const r2 = await uts.core.tools.execute('ues.create_settlement', { name: 'Unica', pop: 10, nearRiver: false });
  assert.equal(r2.existed, true);
  assert.equal(uts.rrw.count('settlement'), 1);
});

test('puter: is treated as an access-layer provider, not the intelligence', async () => {
  const fakeGlobal = { puter: { ai: { chat: async () => ({ message: { content: '{"intent":"set_weather","params":{"weather":"rain"}}' } }) } } };
  const p = new PuterProvider({ globalRef: fakeGlobal });
  assert.equal(await p.availability(), true);
  const res = await p.generate({ messages: [{ role: 'user', content: 'chuva' }] });
  assert.equal(res.json.intent, 'set_weather');
  const absent = new PuterProvider({ globalRef: {} });
  assert.equal(await absent.availability(), false);
});

test('heuristic: honest self-description (it is NOT an LLM)', async () => {
  const h = new HeuristicProvider();
  assert.equal(h.name, 'heuristic');
  assert.equal(h.capabilities().reasoning, false);
  assert.ok(h.toString().includes('deterministic'));
});
