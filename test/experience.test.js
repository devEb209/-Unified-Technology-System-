// UTS :: test/experience — UES as a GENERAL engine: manifests -> worlds,
// rulesets (genres), and app experiences on platform infrastructure.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createUTS, createPlatform, defineExperience, bootExperience, ExperienceError } from '../src/index.js';

test('experience: manifest validation is strict (no silent garbage)', () => {
  assert.throws(() => defineExperience({}), ExperienceError);
  assert.throws(() => defineExperience({ name: 'x', kind: 'mmo' }), /unknown experience kind/);
  assert.throws(() => defineExperience({ name: 'x', ruleset: { bruxaria: true } }), /unknown ruleset key/);
  const exp = defineExperience({ name: 'Vale', world: { settlements: [{ name: 'A', pop: 9999 }] } });
  assert.equal(exp.world.settlements[0].pop, 300, 'params clamped');
  assert.equal(exp.ruleset.nmn, true, 'rules default enabled');
});

test('experience: world-sim boots a declared world through validated tools', async () => {
  const uts = createUTS({ seed: 'exp-world' });
  const exp = defineExperience({
    name: 'Dois Reinos',
    world: {
      settlements: [
        { name: 'Reino Norte', pop: 30, nearRiver: true },
        { name: 'Reino Sul', pop: 20, nearRiver: false },
      ],
      population: 10,
      weather: 'rain',
    },
  });
  const boot = await bootExperience(uts, exp);
  assert.equal(boot.created.length, 2);
  assert.ok(uts.rrw.count('settlement') === 2);
  assert.ok(uts.rrw.count('npc') > 20, 'settlement population + extra population');
  assert.ok(uts.rrw.count('bush') + uts.rrw.count('tree') > 20, 'nature substrate grown');
  assert.equal(uts.world.environment.weather, 'rain');
  uts.ues.run(30); // the experience runs as a living world
  const frame = uts.ues.renderFrame();
  assert.ok(frame.entities.length > 0);
});

test('experience: rulesets are engine system toggles (genres, not new engines)', async () => {
  const uts = createUTS({ seed: 'exp-rules' });
  const exp = defineExperience({
    name: 'Mundo Estático',
    ruleset: { ecology: false, trade: false, nmn: false },
  });
  await bootExperience(uts, exp);
  uts.ues.run(60);
  const sched = uts.ues.scheduler;
  const eco = sched.getSystem('ecology');
  const trade = sched.getSystem('trade');
  const nmn = sched.getSystem('nmn');
  const weather = sched.getSystem('weather');
  assert.equal(eco.runs, 0, 'disabled system never runs');
  assert.equal(trade.runs, 0);
  assert.equal(nmn.runs, 0);
  assert.ok(weather.runs === 60, 'other systems keep the world alive');
  assert.equal(eco.disabledTicks, 60, 'disabled systems are counted, not forgotten');
  // re-enabling brings the system back (live rule changes)
  uts.ues.setSystemEnabled('ecology', true);
  uts.ues.run(5);
  assert.ok(sched.getSystem('ecology').runs > 0);
});

test('experience: APP experiences run on the UTS platform (UES hosts any experience)', async () => {
  const platform = createPlatform();
  const uts = createUTS({ seed: 'exp-app', platform });
  const boot = await bootExperience(uts, {
    name: 'Lista da Guilda',
    kind: 'app',
    app: {
      kind: 'tasks',
      name: 'Guilda',
      actions: [
        { action: 'add', payload: { text: 'derrotar o dragão' } },
        { action: 'add', payload: { text: 'coletar 10 ervas' } },
      ],
    },
  }, { platform });
  const view = boot.view();
  assert.equal(view.total, 2);
  assert.equal(view.items[0].text, 'derrotar o dragão');
  await assert.rejects(() => bootExperience(createUTS({ seed: 'no-plat' }), { name: 'x', kind: 'app' }), /platform/);
});

test('experience: world-sim experience saves through platform storage', async () => {
  const platform = createPlatform();
  const uts = createUTS({ seed: 'exp-save', platform });
  const boot = await bootExperience(uts, {
    name: 'Salvável',
    world: { settlements: [{ name: 'Checkpoint', pop: 12 }] },
  });
  await boot.saveTo(platform.storage, 'exp-slot');
  const { load } = await import('../src/persistence/snapshot.js');
  const restored = await load(platform.storage, 'exp-slot');
  assert.equal(restored.rrw.count('settlement'), 1);
  const names = [...restored.rrw.query({ kind: 'settlement' })].map(id => restored.rrw.get(id).name);
  assert.deepEqual(names, ['Checkpoint']);
});
