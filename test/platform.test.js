// UTS :: test/platform — UTS is the PLATFORM (services, AI-first, apps,
// research, github, durable projects). UES is just one consumer.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createUTS, createPlatform, MemorySearchProvider, AppError, ProjectError } from '../src/index.js';
import { MemoryStorage } from '../src/persistence/storage.js';
import { HeuristicProvider } from '../src/singularity/heuristic.js';

function bootWithPlatform(seed = 'plat') {
  const platform = createPlatform();
  const uts = createUTS({ seed, platform });
  return { platform, uts };
}

test('platform: UTS registers services; UES is a CONSUMER, not the platform', async () => {
  const { platform } = bootWithPlatform('svc');
  const names = platform.services.list().map(s => s.name);
  for (const s of ['ai', 'research', 'github', 'apps', 'storage', 'events', 'ues']) {
    assert.ok(names.includes(s), `service ${s} missing`);
  }
  const status = await platform.status();
  assert.equal(status.platform, 'UTS');
  const ues = status.services.find(s => s.name === 'ues');
  assert.deepEqual(ues.capabilities, ['engine', 'world-sim', 'frames', 'render-backends']);
});

test('platform: AI-first — natural language is the interface, tools do the work', async () => {
  const { platform, uts } = bootWithPlatform('ai-first');
  const report = await platform.ask('criar uma pequena vila próxima a um rio chamada Platforma');
  assert.equal(report.ok, true);
  assert.ok(uts.rrw.count('settlement') === 1);
  assert.equal(platform.ai.status().attached, true);
  assert.ok(platform.ai.models().length >= 3, 'platform advertises every reachable model');
});

test('platform: research triangulates across models and keeps consensus', async () => {
  const { platform } = bootWithPlatform('research');
  platform.research.setSearch(new MemorySearchProvider([
    { title: 'Astronomy', snippet: 'The sun is a star at the center of the solar system', url: 'x://a' },
    { title: 'Science', snippet: 'Sol é uma estrela do tipo espectral G2V', url: 'x://b' },
  ]));
  const agree = (ans) => ({
    name: 'm-' + ans,
    capabilities: () => ({ structured: true }),
    async generate() {
      return { text: '', json: { answer: ans, confidence: 0.9 } };
    },
  });
  platform.research.setProviders([agree('o sol é uma estrela'), agree('O Sol é uma estrela!'), agree('a lua é de queijo')]);

  const v = await platform.research.validate('o que é o sol?');
  assert.equal(v.modelsAsked, 3);
  assert.equal(v.modelsAnswered, 3);
  assert.equal(v.snippets, 2, 'search results reached the models');
  assert.match(v.consensus, /sol é uma estrela/i);
  assert.equal(v.agreement, 0.667);
  assert.equal(v.triangulated, true, '3 models, 2/3 agreement');
  assert.equal(v.conflicts.length, 1, 'conflicting answer reported, not hidden');
});

test('platform: research honestly reports when it CANNOT triangulate', async () => {
  const { platform } = bootWithPlatform('research2');
  const mk = (ans) => ({
    name: 'p-' + (ans ?? 'err'),
    capabilities: () => ({ structured: true }),
    async generate() { return ans ? { text: '', json: { answer: ans } } : Promise.reject(new Error('down')); },
  });
  platform.research.setProviders([mk('a'), mk('b'), mk(null)]);
  const v = await platform.research.validate('pergunta difícil');
  assert.equal(v.modelsAnswered, 2);
  assert.equal(v.triangulated, false, '2 answered of 3 asked -> not triangulated');
  assert.equal(v.agreement, 0.5, 'no majority: agreement below the threshold');
  assert.ok(v.consensus, 'top answer still reported, but flagged as weak');
});

test('platform: github service masks tokens and talks REST (mocked fetch)', async () => {
  const calls = [];
  const fetchMock = async (url, init = {}) => {
    calls.push({ url: String(url), init });
    if (String(url).endsWith('/contents/README.md') && init.method !== 'PUT') {
      return { ok: true, json: async () => ({ type: 'file', path: 'README.md', encoding: 'base64', content: Buffer.from('# hello').toString('base64'), sha: 'abc123' }) };
    }
    return { ok: true, json: async () => ({ commit: { sha: 'def456' } }) };
  };
  const { GitHubService } = await import('../src/platform/services/github-service.js');
  const gh = new GitHubService({ token: 'gh-secret-token', owner: 'dev', repo: 'world', fetchImpl: fetchMock });
  assert.ok(gh.toString().includes('***masked***'));
  assert.ok(!JSON.stringify(gh).includes('gh-secret-token'), 'token must never serialize');

  const read = await gh.getFile('README.md');
  assert.equal(read.content, '# hello');
  const put = await gh.putFile('docs/plan.md', '# plan', 'UTS: plan');
  assert.equal(put.commit, 'def456');
  assert.equal(put.updated, false, 'new file is created, not updated');
  const putBody = JSON.parse(calls.find(c => c.init.method === 'PUT').init.body);
  assert.ok(putBody.content, 'content base64-encoded');
  // token ONLY in the authorization header — never in URLs or bodies
  assert.ok(calls.every(c => !c.url.includes('gh-secret-token')), 'token never in URL');
  assert.ok(calls.every(c => !(c.init.body ?? '').includes('gh-secret-token')), 'token never in body');
  const authHeader = calls[0].init.headers.authorization;
  assert.equal(authHeader, 'Bearer gh-secret-token', 'token travels only in the auth header');

  // explicit empty token overrides even a GITHUB_TOKEN present in the environment
  const noToken = new GitHubService({ token: '', fetchImpl: fetchMock });
  assert.equal(await noToken.health(), 'not-configured');
  await assert.rejects(() => noToken.getFile('x'), /no token/);
});

test('platform: APPS run on platform infra — install, act, view, RESTART keeps state', async () => {
  const storage = new MemoryStorage();
  const p1 = createPlatform({ storage });
  const { id } = await p1.apps.install({ kind: 'tasks', name: 'Minhas Tarefas' });
  await p1.apps.act(id, 'add', { text: 'construir a plataforma' });
  await p1.apps.act(id, 'add', { text: 'dominar a realidade' });
  await p1.apps.act(id, 'toggle', { id: 1 });
  let view = p1.apps.view(id);
  assert.equal(view.total, 2);
  assert.equal(view.done, 1);

  // platform "restart": same storage, brand-new host
  const p2 = createPlatform({ storage });
  const restored = await p2.apps.boot();
  assert.equal(restored, 1, 'app reloaded from platform storage');
  const appId = p2.apps.list()[0].id;
  view = p2.apps.view(appId);
  assert.deepEqual(view.items.map(i => i.text), ['construir a plataforma', 'dominar a realidade']);
  assert.equal(view.items[0].done, true);

  // AI reaches apps through validated tools
  const { uts } = bootWithPlatform('apps-ai');
  const r1 = await uts.core.tools.execute('platform.app_install', { kind: 'counter', name: 'Contador' });
  await uts.core.tools.execute('platform.app_act', { appId: r1.id, action: 'increment' });
  await uts.core.tools.execute('platform.app_act', { appId: r1.id, action: 'increment' });
  const v = await uts.core.tools.execute('platform.app_act', { appId: r1.id, action: 'decrement' });
  assert.equal(v.view.value, 1);
  await assert.rejects(() => uts.core.tools.execute('platform.app_act', { appId: r1.id, action: 'explode' }), AppError);
});

test('platform: CREATION PROJECTS — durable, resumable, honest', async () => {
  const storage = new MemoryStorage();
  const platform = createPlatform({ storage });
  const uts = createUTS({ seed: 'projects', platform });

  const project = await platform.projects.create('criar uma pequena vila próxima a um rio chamada Longevidade');
  assert.equal(project.intent, 'create_settlement');
  assert.equal(project.status, 'active');
  assert.ok(project.tasks.length >= 4);

  const { steps, progress } = await platform.projects.run(project.id, { maxSteps: 2 });
  assert.equal(steps, 2, 'budget respected');
  assert.equal(progress.done_all, false, 'long work pauses, is not faked');

  // "days later": the WORLD is restored from storage (same persisted reality),
  // a fresh platform reattaches, and the project resumes where it stopped.
  const { load } = await import('../src/persistence/snapshot.js');
  const { save } = await import('../src/persistence/snapshot.js');
  await save(storage, 'world-slot', uts);
  const restoredWorld = await load(storage, 'world-slot');
  const platform2 = createPlatform({ storage });
  platform2.attachCore(restoredWorld.core, { ues: restoredWorld.ues });

  const resumed = await platform2.projects.resume(project.id);
  assert.equal(resumed.status, 'active');
  assert.equal(resumed.tasks.filter(t => t.done).length, 2);
  const run2 = await platform2.projects.run(project.id, {});
  assert.equal(run2.progress.done_all, true, 'project completes across sessions');
  assert.ok(restoredWorld.rrw.count('settlement') === 1, 'settlement exists exactly once (idempotent tools)');
  const stored = await platform2.projects.listStored();
  assert.ok(stored.includes(project.id));

  await assert.rejects(() => platform2.projects.resume('prj999'), ProjectError);
});

test('platform: failed project step records the error durably and keeps state', async () => {
  const storage = new MemoryStorage();
  const platform = createPlatform({ storage });
  createUTS({ seed: 'proj-fail', platform });
  const project = await platform.projects.create('criar uma pequena vila próxima a um rio chamada Falha');
  // force a failing task: unknown settlement name for population
  project.tasks.find(t => t.tool === 'ues.spawn_npcs').params.settlementName = 'Nao Existe';
  await assert.rejects(() => platform.projects.run(project.id, { maxSteps: 10 }));
  const persisted = JSON.parse(await storage.get(`project:${project.id}`));
  assert.ok(persisted.log.some(l => l.ok === false), 'failure is durably logged, never hidden');
});
