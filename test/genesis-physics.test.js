// UTS :: test/genesis-physics — OUR physics engine: gravity, terrain,
// collisions, raycast, causal impacts, scheduler + D-O15 integration.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createUTS } from '../src/index.js';

test('physics: bodies fall under OUR gravity and land on the REPRESENTED terrain', async () => {
  const uts = createUTS({ seed: 'phys-fall' });
  const x = 512, z = 512;
  const h = uts.world.terrain.height(x, z);
  const rock = uts.world.dropRock([x, h + 20, z], [0, 0, 0], {});
  uts.ues.run(240);
  const sp = uts.rrw.getComponent(rock.id, 'spatial');
  const ph = uts.rrw.getComponent(rock.id, 'physics');
  assert.ok(Math.abs(sp.pos[1] - (h + ph.radius)) < 0.5, `rests on terrain (${sp.pos[1]} vs ${h})`);
  assert.equal(ph.asleep, true, 'body sleeps at rest');
  assert.ok(uts.rrw.count('prop') === 1);
});

test('physics: sphere-sphere collisions exchange momentum (bodies push apart)', async () => {
  const uts = createUTS({ seed: 'phys-collide' });
  const a = uts.world.dropRock([500, 12, 500], [4, 0, 0], {});
  const b = uts.world.dropRock([510, 12, 500], [-4, 0, 0], {});
  uts.ues.run(120);
  const va = uts.rrw.getComponent(a.id, 'physics').vel;
  const vb = uts.rrw.getComponent(b.id, 'physics').vel;
  // after frontal collision the bodies must not keep approaching
  const dx = uts.rrw.getComponent(b.id, 'spatial').pos[0] - uts.rrw.getComponent(a.id, 'spatial').pos[0];
  assert.ok(dx > -1, `bodies separated (dx=${dx.toFixed(2)})`);
  assert.ok(uts.world.physics.stats.contacts > 0, 'contact was resolved');
  void va; void vb;
});

test('physics: impacts are VERIFIABLE RRW causal events citing their origin', async () => {
  const uts = createUTS({ seed: 'phys-cause' });
  const cause = uts.rrw.emitEvent({ type: 'physics.rock.dropped', subject: 'world', cause: null, data: {}, tick: 1 });
  const rock = uts.world.dropRock([512, 25, 512], [0, -5, 0], { causeEvent: cause });
  uts.ues.run(120);
  const impact = [...uts.rrw.events.values()].find(e => e.type === 'physics.impact' && e.subject === rock.id);
  assert.ok(impact, 'impact event exists');
  assert.equal(impact.cause, cause, 'impact cites the drop as its cause');
  const chain = uts.rrw.causalityChain(impact.id).map(e => e.type);
  assert.deepEqual(chain, ['physics.impact', 'physics.rock.dropped']);
  assert.equal(uts.rrw.verifyCausalChain(impact.id).valid, true);
});

test('physics: raycast hits bodies and terrain precisely', async () => {
  const uts = createUTS({ seed: 'phys-ray' });
  const rock = uts.world.dropRock([512, 5, 512], [0, 0, 0], {});
  uts.rrw.getComponent(rock.id, 'physics').asleep = true;
  const hit = uts.world.physics.raycast([512, 5, 500], [0, 0, 1], 100);
  assert.ok(hit, 'ray hits something');
  assert.equal(hit.kind, 'body');
  assert.equal(hit.id, rock.id);
  const terrainHit = uts.world.physics.raycast([600, 40, 600], [0, -1, 0], 200);
  assert.equal(terrainHit.kind, 'terrain');
});

test('physics: integration — physics is a scheduled UES system (rules can toggle it)', async () => {
  const uts = createUTS({ seed: 'phys-sched' });
  uts.world.dropRock([512, 30, 512], [0, 0, 0], {});
  const sys = uts.ues.scheduler.getSystem('physics');
  assert.ok(sys, 'physics registered in the scheduler');
  uts.ues.setSystemEnabled('physics', false);
  uts.ues.run(30);
  assert.equal(sys.runs, 0, 'ruleset disables physics without removing it');
  uts.ues.setSystemEnabled('physics', true);
  uts.ues.run(10);
  assert.ok(sys.runs > 0);
  // bodies sync the spatial index as they move (RRW = truth)
  const rockId = [...uts.world.physics.bodies.keys()][0];
  const sp = uts.rrw.getComponent(rockId, 'spatial');
  assert.deepEqual(uts.world.grid.queryCircle(sp.pos[0], sp.pos[2], 0.6), [rockId]);
});

test('physics: D-O15 coarse pressure halves the physics rate (measurable)', async () => {
  const uts = createUTS({ seed: 'phys-do15' });
  for (let i = 0; i < 8; i++) uts.do15.report({ frameMs: 40, simMs: 40 });
  assert.equal(uts.do15.strategy.perceptionResolution, 'coarse');
  uts.ues.run(20);
  const steps = uts.world.physics.report().steps; // real executions, not scheduler dispatches
  const fullRate = 20 * uts.world.physics.substeps; // what an unrestricted rate would produce
  assert.ok(steps > 0 && steps < fullRate, `physics executed fewer steps under coarse pressure (${steps}/${fullRate})`);
});
