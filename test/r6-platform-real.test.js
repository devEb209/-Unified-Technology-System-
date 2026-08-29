// UTS :: test/r6-platform-real — R6: async streaming (workers), a REAL LLM
// behind env config (tested against a local HTTP server), real web search
// behind an interface, and the honest upgrade path. ADR-018/ADR-019 apply:
// externals live behind OUR interfaces; keys never enter logs or snapshots.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import http from 'node:http';
import { createUTS, Persistence, ExternalLLMProvider } from '../src/index.js';
import { ProviderRegistry } from '../src/singularity/provider.js';
import { AsyncChunkSampler, supported } from '../src/world/async-sampler.js';
import { HttpSearchProvider, ResearchService } from '../src/platform/services/research-service.js';
import { Terrain } from '../src/world/terrain.js';

function listen(server) {
  return new Promise(resolve => server.listen(0, '127.0.0.1', () => resolve(server.address().port)));
}
function close(server) {
  if (!server) return;
  server.closeAllConnections?.(); // fetch keep-alive must not hold the test
  server.close();
  server.unref?.();
}

// ---------- ASYNC STREAMING (workers) ----------
test('async streaming: worker result is BYTE-IDENTICAL to the synchronous sampling', async () => {
  if (!supported()) return; // browser test hosts fall back honestly
  const seed = 'det-worker';
  const t = new Terrain({ seed });
  const sync = t.sampleChunk(8, 8, 8);
  const s = new AsyncChunkSampler({ threads: 1, seed });
  s.request({ cx: 8, cz: 8, res: 8 });
  let msg = null;
  for (let i = 0; i < 20 && !msg; i++) { await new Promise(r => setTimeout(r, 100)); msg = s.poll()[0] ?? null; }
  assert.ok(msg && !msg.error, 'the worker answered');
  assert.equal(Buffer.from(msg.heights.buffer).compare(Buffer.from(sync.heights.buffer)), 0,
    'heights are byte-exact (the worker is the SAME reality, off-thread)');
  assert.equal(Buffer.from(msg.biomes.buffer).compare(Buffer.from(sync.biomes.buffer)), 0);
  await s.destroy();
});

test('async streaming: createUTS(asyncStreaming) streams off-thread; determinism survives', async () => {
  if (!supported()) return;
  const a = createUTS({ seed: 'async-det', asyncStreaming: true });
  try {
    assert.ok(a.world.streaming.asyncSampler, 'the sampler is attached');
    a.ues.moveCamera([560, 30, 560]);
    for (let i = 0; i < 12; i++) { a.ues.run(4); await new Promise(r => setTimeout(r, 30)); }
    // RELOCATE: a fresh area has no residents and no cache — these chunks
    // MUST stream through the workers (the pool is warm by now)
    a.ues.moveCamera([60, 30, 900]);
    for (let i = 0; i < 14; i++) { a.ues.run(4); await new Promise(r => setTimeout(r, 40)); }
    const st = a.world.streaming.report();
    assert.ok(st.asyncDispatched > 0, `work was dispatched to workers (${st.asyncDispatched})`);
    // frames keep working while chunks stream in (pending may exist — honest)
    const frame = a.ues.renderFrame();
    assert.ok(frame.terrain.patches.length > 0, 'the frame still renders');
    // determinism: async is a SCHEDULING change, not a reality change
    const b = Persistence.restoreState(JSON.parse(JSON.stringify(Persistence.serializeState(a))));
    try {
      b.ues.run(10); a.ues.run(10);
      assert.equal(JSON.stringify(Persistence.serializeState(b)), JSON.stringify(Persistence.serializeState(a)),
        'A and B evolve byte-identically with workers on');
    } finally { await b.world.streaming.asyncSampler?.destroy(); }
  } finally { await a.world.streaming.asyncSampler?.destroy(); }
});

// ---------- REAL LLM BEHIND ENV (local HTTP server as the endpoint) ----------
test('env LLM: registered ONLY when configured; key never enters memory/snapshots', async () => {
  const old = process.env.UTS_LLM_API_KEY;
  delete process.env.UTS_LLM_API_KEY;
  delete process.env.OPENAI_API_KEY;
  const offline = createUTS({ seed: 'no-key' });
  assert.ok(!offline.core.providers.names().includes('llm-env'), 'no key → no provider (honest)');

  process.env.UTS_LLM_API_KEY = 'sk-test-not-a-secret';
  try {
    const online = createUTS({ seed: 'with-key' });
    assert.ok(online.core.providers.names().includes('llm-env'), 'env key → provider registered');
    const snap = JSON.stringify(Persistence.serializeState(online));
    assert.ok(!snap.includes('sk-test'), 'THE KEY NEVER ENTERS SNAPSHOTS');
    const mem = JSON.stringify(online.core.memory.snapshot?.() ?? {});
    assert.ok(!mem.includes('sk-test'), 'THE KEY NEVER ENTERS MEMORY');
  } finally {
    if (old != null) process.env.UTS_LLM_API_KEY = old; else delete process.env.UTS_LLM_API_KEY;
  }
});

test('env LLM: when the heuristic says unknown, the REAL model takes the interpretation', async () => {
  const server = http.createServer((req, res) => {
    if (req.url.startsWith('/models')) { res.writeHead(200).end('[]'); return; }
    if (req.url.startsWith('/chat/completions')) {
      let body = '';
      req.on('data', c => body += c);
      req.on('end', () => {
        res.writeHead(200, { 'content-type': 'application/json' });
        res.end(JSON.stringify({
          choices: [{ message: { content: JSON.stringify({ intent: 'set_weather', params: { weather: 'storm' } }) } }],
        }));
      });
      return;
    }
    res.writeHead(404).end();
  });
  const port = await listen(server);
  const old = process.env.UTS_LLM_API_KEY, oldUrl = process.env.UTS_LLM_BASE_URL;
  process.env.UTS_LLM_API_KEY = 'sk-test';
  process.env.UTS_LLM_BASE_URL = `http://127.0.0.1:${port}`;
  try {
    const uts = createUTS({ seed: 'upgrade', log: { level: 'error' } });
    const report = await uts.core.processObjective('por que o céu é azul em Ubatuba nas quartas?');
    assert.equal(report.interpretation.intent, 'set_weather', 'the REAL model interpreted');
    // either the model was chosen up-front (reasoning needs filter the
    // heuristic out) OR the honest unknown→upgrade path fired — both prove
    // the configured model is the actual interpreter:
    const viaReal = report.chosen.provider === 'llm-env' || report.interpretation.upgradedFrom === 'heuristic';
    assert.ok(viaReal, `the real model interpreted (provider ${report.chosen.provider})`);
    assert.ok(!JSON.stringify(report).includes('sk-test'), 'the key never leaks into the report');
    assert.equal(uts.world.environment.weather, 'storm', 'the interpretation became REALITY through the causal chain');
  } finally {
    if (old != null) process.env.UTS_LLM_API_KEY = old; else delete process.env.UTS_LLM_API_KEY;
    if (oldUrl != null) process.env.UTS_LLM_BASE_URL = oldUrl; else delete process.env.UTS_LLM_BASE_URL;
  }
  close(server);
});

// ---------- REAL WEB SEARCH BEHIND AN INTERFACE ----------
test('HttpSearchProvider: normalizes endpoint results; ResearchService keeps triangulating', async () => {
  const server = http.createServer((req, res) => {
    res.writeHead(200, { 'content-type': 'application/json' });
    res.end(JSON.stringify({ results: [
      { title: 'Rayleigh scattering', url: 'https://x/r', snippet: 'why the sky is blue' },
      { title: 'Mie scattering', url: 'https://x/m', snippet: 'haze and aerosols' },
    ] }));
  });
  const port = await listen(server);
  const search = new HttpSearchProvider({ url: `http://127.0.0.1:${port}/search`, fetchImpl: fetch });
  const rows = await search.search('céu azul espalhamento');
  assert.equal(rows.length, 2);
  assert.equal(rows[0].title, 'Rayleigh scattering');
  // the service still triangulates (search feeds multiple models); a
  // deterministic stub provider keeps the test offline-honest
  const stub = { name: 'stub', generate: async () => ({ json: { answer: 'espalhamento de Rayleigh', confidence: 0.9 } }) };
  const svc = new ResearchService({ providers: [stub], search, minModels: 1, minAgreement: 0.5 });
  const out = await svc.validate('céu azul espalhamento');
  assert.ok(out, 'research works over the real provider');
  close(server);
});
