// UTS :: test/r5-grammar-attachments — the CREATION GRAMMAR + ATTACHMENTS
// under ADR-019: language is an INTERFACE to reality creation, so it must be
// composable, deterministic and auditable (every command cites its source).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createUTS } from '../src/index.js';
import { parseCreation } from '../src/singularity/grammar.js';

test('grammar: ONE objective -> MANY commands, each citing its source fragment', () => {
  const r = parseCreation(
    'crie uma vila chamada Vale Verde com 40 habitantes perto do rio e depois uma floresta com 60 arvores e 15 npcs e clima de tempestade',
  );
  assert.deepEqual(r.commands.map(c => c.intent),
    ['create_settlement', 'plant_forest', 'spawn_population', 'set_weather']);
  const settlement = r.commands[0];
  assert.equal(settlement.params.name, 'Vale Verde', 'the name ENDS at stop words');
  assert.equal(settlement.params.pop, 40, 'count extracted');
  assert.equal(settlement.params.nearRiver, true, 'relation perto do rio');
  assert.equal(r.commands[1].params.count, 60);
  assert.ok(settlement.source.startsWith('crie uma vila'), `source cited: "${settlement.source}"`);
  assert.deepEqual(r.unknown, [], 'nothing silently dropped');
  // determinism: same input, same parse
  const r2 = parseCreation('crie uma vila chamada Vale Verde com 40 habitantes perto do rio e depois uma floresta com 60 arvores e 15 npcs e clima de tempestade');
  assert.deepEqual(r2, r, 'the grammar is deterministic');
});

test('grammar: relations — ao norte de / perto de named anchors are STRUCTURED', () => {
  const r = parseCreation('crie um povoado chamada Porto ao norte de Vale Verde e depois uma vila perto de Vale Verde');
  assert.equal(r.commands.length, 2);
  assert.deepEqual(r.commands[0].params.dir, 'norte');
  assert.equal(r.commands[0].params.of, 'vale verde');
  assert.equal(r.commands[1].params.nearName, 'vale verde');
});

test('grammar: unknown fragments are HONEST (never guessed into state changes)', () => {
  const r = parseCreation('qual é a capital do Brasil?');
  assert.equal(r.commands.length, 0, 'a question creates NOTHING');
  assert.ok(r.unknown.length > 0, 'the fragment is reported honestly');
});

test('attachments: CSV positions become DATA-backed settlements; name lists become villages; images are honestly NOT seen', async () => {
  const uts = createUTS({ seed: 'r5-attach' });
  const csv = 'x,z,name,pop\n600,600,Vila A,20\n640,600,Vila B,15';
  const report = await uts.core.processObjective('crie as vilas do anexo', {
    attachments: [
      { kind: 'csv', name: 'vilas.csv', content: csv },
      { kind: 'text', name: 'nomes.txt', content: 'Sítio Novo, Recanto' },
      { kind: 'image', name: 'mapa.png', content: '…' },
    ],
  });
  assert.equal(report.ok, true, JSON.stringify(report.verifications));
  for (const name of ['Vila A', 'Vila B', 'Sítio Novo', 'Recanto']) {
    const id = uts.rrw.query({ kind: 'settlement', predicate: e => e.name === name })[0];
    assert.ok(id, `${name} exists (from the attachment)`);
  }
  const a = uts.rrw.query({ kind: 'settlement', predicate: e => e.name === 'Vila A' })
    .map(id => uts.rrw.getComponent(id, 'spatial').pos)[0];
  assert.ok(Math.abs(a[0] - 600) < 60 && Math.abs(a[2] - 600) < 60, `CSV position honored (${a.map(v => v.toFixed(0))})`);
  const img = report.attachments.find(x => x.kind === 'image');
  assert.equal(img.seen, false, 'the image is recorded as NOT seen (no fake perception)');
});

test('attachments: validation is strict — bad kind and oversized content FAIL loudly', async () => {
  const uts = createUTS({ seed: 'r5-strict' });
  await assert.rejects(
    () => uts.core.processObjective('crie algo', { attachments: [{ kind: 'exe', name: 'virus.exe', content: 'MZ' }] }),
    /not supported/,
  );
  await assert.rejects(
    () => uts.core.processObjective('crie algo', { attachments: [{ kind: 'text', name: 'big.txt', content: 'x'.repeat(70000) }] }),
    /64KB/,
  );
});

test('grammar in the FULL chain: anchor relations place villages in the REAL world', async () => {
  const uts = createUTS({ seed: 'r5-anchor', log: { level: 'error' } });
  const report = await uts.core.processObjective(
    'crie uma vila chamada Ancora e depois uma vila chamada Porto Sul ao sul de Ancora',
  );
  assert.equal(report.ok, true, JSON.stringify(report.verifications));
  const p = (name) => {
    const id = uts.rrw.query({ kind: 'settlement', predicate: e => e.name === name })[0];
    return uts.rrw.getComponent(id, 'spatial').pos;
  };
  const anchor = p('Ancora'), sul = p('Porto Sul');
  assert.ok(sul[2] > anchor[2] + 40, `Porto Sul is SOUTH of the anchor (Δz ${(sul[2] - anchor[2]).toFixed(0)}m)`);
  assert.ok(report.plan.grammar === true, 'the plan is grammar-driven (auditable)');
});

test('forest: planted trees are REAL individuals (ecology), verified by population growth', async () => {
  const uts = createUTS({ seed: 'r5-forest', log: { level: 'error' } });
  const before = uts.world.ecology.aliveCount();
  const report = await uts.core.processObjective('plante uma floresta com 25 arvores');
  assert.equal(report.ok, true, JSON.stringify(report.verifications));
  const after = uts.world.ecology.aliveCount();
  assert.ok(after >= before + 20, `the population grew (${before} -> ${after})`);
  const forestCheck = report.verifications.find(v => v.check === 'forest.grew');
  assert.ok(forestCheck?.ok, 'verification cites the real growth');
});
