// UTS :: test/nmn — Natural Mindset of NPCs: needs, decisions with reasons,
// memory, relations, gossip, fear with VERIFIABLE causal chains.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createUTS } from '../src/index.js';
import { updateMind } from '../src/nmn/nmn.js';

test('nmn: hunger drives eating and the need is satisfied', async () => {
  const uts = createUTS({ seed: 'eat' });
  const npc = uts.world.spawnNPC({ pos: [500, 0, 500] });
  const bush = uts.world.spawnResource('bush', [500, 0, 501.5], { amount: 1, cap: 1, regrowDelay: 40 }); // in front, within reach
  uts.rrw.getComponent(npc.id, 'mind').needs.hunger = 0.95;
  updateMind(uts.world, npc.id, 0.05);
  const mind = uts.rrw.getComponent(npc.id, 'mind');
  assert.equal(mind.lastDecision.action, 'eat');
  assert.ok(mind.needs.hunger < 0.95, 'hunger decreased');
  assert.ok(uts.rrw.getComponent(bush.id, 'resource').amount < 1, 'bush was consumed');
  assert.ok(uts.rrw.query({ kind: 'npc', predicate: e => false }).length === 0);
  const ate = [...uts.rrw.events.values()].find(e => e.type === 'npc.ate');
  assert.ok(ate, 'npc.ate event emitted');
  assert.ok(mind.knowledge.includes(bush.id), 'food location becomes knowledge');
});

test('nmn: distant food creates intent (movement toward target)', async () => {
  const uts = createUTS({ seed: 'intent' });
  const npc = uts.world.spawnNPC({ pos: [500, 0, 500] });
  uts.world.spawnResource('bush', [500, 0, 520], { amount: 1, cap: 1, regrowDelay: 40 }); // straight ahead
  uts.rrw.getComponent(npc.id, 'mind').needs.hunger = 0.95;
  updateMind(uts.world, npc.id, 0.05);
  assert.equal(uts.rrw.getComponent(npc.id, 'mind').lastDecision.action, 'eat');
  const intent = uts.rrw.getComponent(npc.id, 'intent');
  assert.ok(intent, 'movement intent created toward food');
  const before = uts.rrw.getComponent(npc.id, 'spatial').pos[2];
  uts.ues.tick(); // movement system integrates the intent
  assert.ok(uts.rrw.getComponent(npc.id, 'spatial').pos[2] > before, 'npc moved toward food');
});

test('nmn: every decision is explainable (because) and counted', async () => {
  const uts = createUTS({ seed: 'explain' });
  const npc = uts.world.spawnNPC({ pos: [500, 0, 500] });
  for (let i = 0; i < 12; i++) uts.ues.tick();
  const mind = uts.rrw.getComponent(npc.id, 'mind');
  assert.ok(mind.decisionCount > 0);
  assert.ok(mind.lastDecision, 'has last decision');
  assert.ok(Array.isArray(mind.lastDecision.because) && mind.lastDecision.because.length > 0);
  assert.ok(Array.isArray(mind.memory) && mind.memory.length > 0);
  assert.equal(mind.memory.at(-1).kind, 'decision');
});

test('nmn: fire near NPC -> flee with verifiable causal chain', async () => {
  const uts = createUTS({ seed: 'flee' });
  const npc = uts.world.spawnNPC({ pos: [500, 0, 500] });
  const strikeId = uts.rrw.emitEvent({ type: 'reallife.lightning.strike', subject: 'world', cause: null, data: {}, tick: 0 });
  const fireId = uts.world.reallife.igniteFire([506, 0, 500], strikeId);
  updateMind(uts.world, npc.id, 0.05);
  const mind = uts.rrw.getComponent(npc.id, 'mind');
  assert.equal(mind.lastDecision.action, 'flee', 'npc flees from fire');
  assert.ok(mind.needs.safety < 1, 'safety need dropped');
  const sightedId = mind.fear[fireId];
  assert.ok(sightedId, 'fear memory links fire to a sighted event');
  const verdict = uts.rrw.verifyCausalChain(sightedId);
  assert.equal(verdict.valid, true);
  const chain = uts.rrw.causalityChain(sightedId).map(e => e.type);
  assert.deepEqual(chain, ['npc.hazard.sighted', 'reallife.fire.started', 'reallife.lightning.strike']);
});

test('nmn: socializing builds relations and satisfies loneliness', async () => {
  const uts = createUTS({ seed: 'social' });
  const a = uts.world.spawnNPC({ pos: [500, 0, 500] });
  const b = uts.world.spawnNPC({ pos: [500, 0, 502] });
  uts.rrw.getComponent(a.id, 'mind').needs.social = 0.95;
  uts.rrw.getComponent(a.id, 'mind').needs.hunger = 0.1;
  uts.rrw.getComponent(a.id, 'mind').needs.energy = 1; // rest must not win
  updateMind(uts.world, a.id, 0.05);
  const mind = uts.rrw.getComponent(a.id, 'mind');
  assert.equal(mind.lastDecision.action, 'socialize');
  assert.ok(uts.rrw.getRelation(a.id < b.id ? a.id : b.id, a.id < b.id ? b.id : a.id, 'knows'), 'knows relation created');
  assert.ok(mind.needs.social < 0.95);
  assert.ok([...uts.rrw.events.values()].some(e => e.type === 'npc.socialized'));
});

test('nmn: gossip spreads knowledge through relations (D-13 verified again via mind state)', async () => {
  const uts = createUTS({ seed: 'gossip2' });
  const a = uts.world.spawnNPC({ pos: [500, 0, 500] });
  const b = uts.world.spawnNPC({ pos: [500, 0, 501.5] });
  uts.rrw.getComponent(a.id, 'mind').knowledge.push('lake-monster');
  uts.rrw.getComponent(a.id, 'mind').needs.social = 0.99;
  for (let i = 0; i < 8; i++) updateMind(uts.world, a.id, 0.05);
  assert.ok(uts.rrw.getComponent(b.id, 'mind').knowledge.includes('lake-monster'));
});

test('nmn: needs evolve over time (hunger grows, energy decays with activity)', async () => {
  const uts = createUTS({ seed: 'needs' });
  const npc = uts.world.spawnNPC({ pos: [500, 0, 500] });
  const h0 = uts.rrw.getComponent(npc.id, 'mind').needs.hunger;
  for (let i = 0; i < 40; i++) uts.ues.tick();
  const h1 = uts.rrw.getComponent(npc.id, 'mind').needs.hunger;
  assert.ok(h1 > h0, 'hunger increases with time');
});

test('nmn: abstract NPCs do not burn cognition (tiering), full ones do', async () => {
  const uts = createUTS({ seed: 'tier' });
  const near = uts.world.spawnNPC({ pos: [500, 0, 500] });
  const far = uts.world.spawnNPC({ pos: [900, 0, 900] });
  uts.world.updateMaterialization([500, 40, 500]);
  assert.equal(uts.rrw.get(near.id).materialization, 'full');
  assert.equal(uts.rrw.get(far.id).materialization, 'abstract');
  uts.ues.tick(); uts.ues.tick();
  assert.ok(uts.rrw.getComponent(near.id, 'mind').decisionCount > 0);
  assert.equal(uts.rrw.getComponent(far.id, 'mind').decisionCount, 0, 'abstract minds are aggregate-handled');
});
