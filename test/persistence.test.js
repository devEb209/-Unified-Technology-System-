// UTS :: test/persistence — real save/load: integrity, versioning, migration,
// loud failures on corruption, deterministic continuation, no secrets saved.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createUTS } from '../src/index.js';
import {
  save, load, serializeState, migrate, SCHEMA_VERSION, SnapshotError,
} from '../src/persistence/snapshot.js';
import { MemoryStorage, FileStorage } from '../src/persistence/storage.js';
import { fnv1a } from '../src/core/math.js';
import { ExternalLLMProvider } from '../src/singularity/external.js';

async function bootWithVillage(seed = 'pers') {
  const uts = createUTS({ seed });
  await uts.core.processObjective('criar uma pequena vila próxima a um rio chamada Persistência');
  uts.ues.run(120);
  return uts;
}

test('persistence: save -> load roundtrip restores the same reality', async () => {
  const A = await bootWithVillage('roundtrip');
  const store = new MemoryStorage();
  const snap = await save(store, 'slot1', A);
  assert.equal(snap.schemaVersion, SCHEMA_VERSION);

  const B = await load(store, 'slot1');
  assert.equal(B.rrw.count('settlement'), 1);
  assert.equal(B.rrw.count('npc'), A.rrw.count('npc'));
  assert.deepEqual(B.world.environment, A.world.environment);
  assert.deepEqual(B.rrw.snapshot(), A.rrw.snapshot());
});

test('persistence: determinism — A and B evolve identically after restore', async () => {
  const A = await bootWithVillage('det');
  const store = new MemoryStorage();
  await save(store, 'k', A);
  const B = await load(store, 'k');

  A.ues.run(80);
  B.ues.run(80);

  assert.deepEqual(serializeState(B), serializeState(A), 'same seed + same ticks = same reality');
});

test('persistence: load fails LOUDLY on invalid JSON', async () => {
  const store = new MemoryStorage();
  await store.set('bad', '{not json');
  await assert.rejects(() => load(store, 'bad'), /not valid JSON/);
});

test('persistence: load fails on checksum mismatch (corrupted body)', async () => {
  const uts = await bootWithVillage('corrupt');
  const store = new MemoryStorage();
  await save(store, 'k', uts);
  const body = await store.get('k');
  const parsed = JSON.parse(body);
  parsed.state.world.environment.rain = 0.42; // tamper
  await store.set('k', JSON.stringify(parsed));
  await assert.rejects(() => load(store, 'k'), /integrity check/);
});

test('persistence: load rejects NEWER schemas instead of guessing', async () => {
  const uts = await bootWithVillage('future');
  const store = new MemoryStorage();
  await save(store, 'k', uts);
  const parsed = JSON.parse(await store.get('k'));
  parsed.state.schemaVersion = SCHEMA_VERSION + 5;
  parsed.checksum = fnv1a(JSON.stringify(parsed.state));
  await store.set('k', JSON.stringify(parsed));
  await assert.rejects(() => load(store, 'k'), /newer than engine/);
});

test('persistence: v0 snapshots migrate to current schema', async () => {
  const uts = await bootWithVillage('v0');
  const store = new MemoryStorage();
  await save(store, 'k', uts);
  const parsed = JSON.parse(await store.get('k'));
  // simulate an OLD snapshot: schema 0 without the newer environment fields
  const legacy = parsed.state;
  legacy.schemaVersion = 0;
  delete legacy.world.environment.wetness;
  delete legacy.world.environment.dust;
  delete legacy.world.environment.lastWeatherEventId;
  await store.set('old', JSON.stringify({ schemaVersion: 0, engineVersion: 'uts-0.9', checksum: fnv1a(JSON.stringify(legacy)), state: legacy }));

  const restored = await load(store, 'old');
  assert.ok('wetness' in restored.world.environment, 'migration added wetness');
  assert.ok(restored.rrw.count('settlement') === 1);
});

test('persistence: migrate() on a plain object works and validates', () => {
  const out = migrate({ schemaVersion: 0, world: { environment: { weather: 'clear' } } });
  assert.equal(out.schemaVersion, 1);
  assert.equal(out.world.environment.wetness, 0);
  assert.throws(() => migrate({ schemaVersion: 999 }), /newer than engine/);
});

test('persistence: FileStorage writes real files with atomic rename', async () => {
  const os = await import('node:os');
  const path = await import('node:path');
  const fs = await import('node:fs/promises');
  const dir = await fs.mkdtemp(path.join(os.tmpdir(), 'uts-fs-'));
  const store = new FileStorage(dir);
  await store.set('hello/world', 'data');
  assert.equal(await store.get('hello/world'), 'data');
  assert.deepEqual(await store.keys(), ['hello_world']);
  const uts = await bootWithVillage('fs');
  await save(store, 'slot', uts);
  const loaded = await load(store, 'slot');
  assert.equal(loaded.rrw.count('settlement'), 1);
});

test('persistence: provider secrets NEVER enter snapshots', async () => {
  const SECRET = 'sk-super-secret-key-123';
  const fetchImpl = async (url, init) => {
    if (String(url).endsWith('/models')) return { ok: true };
    const body = JSON.parse(init.body);
    return {
      ok: true,
      json: async () => ({
        choices: [{ message: { content: JSON.stringify({ intent: 'create_settlement', params: { name: 'Vila Secreta', pop: 5, nearRiver: false } }) } }],
      }),
    };
  };
  const external = new ExternalLLMProvider({ name: 'mock-llm', baseUrl: 'https://mock/v1', apiKey: SECRET, fetchImpl });
  const uts = createUTS({ seed: 'secrets' });
  const { ProviderRegistry } = await import('../src/singularity/provider.js');
  const { ModelRegistry } = await import('../src/singularity/models.js');
  const { HeuristicProvider } = await import('../src/singularity/heuristic.js');
  const providers = new ProviderRegistry();
  providers.register(new HeuristicProvider(), { isDefault: true });
  providers.register(external);
  const models = new ModelRegistry();
  models.register({ id: 'mock-1', tier: 'B', provider: 'mock-llm', costPer1k: 1, latencyMs: 50, context: 16000, capabilities: { text: true, reasoning: true, code: true, structured: true, tools: false } });
  uts.core.providers = providers;
  uts.core.models = models;

  await uts.core.processObjective('analise e criar uma pequena vila próxima a um rio chamada Vila Secreta');
  const dump = JSON.stringify(serializeState(uts)) + JSON.stringify(uts.core.memory.snapshot());
  assert.ok(!dump.includes(SECRET), 'secret leaked into persisted state!');
  assert.ok(external.toString().includes('***masked***'));
});
