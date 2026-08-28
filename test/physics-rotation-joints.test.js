// UTS :: test/physics-rotation-joints — OUR solver, finished: planar
// rotation with inertia and impact torque, distance joints as RRW
// relations, pinned bodies, and physics that SURVIVES save/load (the
// solver caches rebuild from the single source of truth).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createUTS } from '../src/index.js';
import { save, load, serializeState } from '../src/persistence/snapshot.js';
import { MemoryStorage } from '../src/persistence/storage.js';

test('rotation: off-center contact SPINS bodies; yaw integrates; both are deterministic', () => {
  const mk = () => {
    const uts = createUTS({ seed: 'spin' });
    uts.world.terrain.forceFlat?.();
    const flat = (x, z) => 20;
    uts.world.terrain.height = flat; // deterministic flat ground for clean math
    const a = uts.world.physics.addBody({ pos: [100, 24, 100], vel: [6, 0, 0], radius: 0.6, mass: 1 });
    const b = uts.world.physics.addBody({ pos: [104, 20.5, 100.15], vel: [0, 0, 0], radius: 0.6, mass: 1, pinned: true });
    for (let i = 0; i < 120; i++) uts.world.physics.step(1 / 60, { tick: i });
    return { uts, a, b };
  };
  const r1 = mk(), r2 = mk();
  const ph1 = r1.uts.world.rrw.getComponent(r1.a.id, 'physics');
  const sp1 = r1.uts.world.rrw.getComponent(r1.a.id, 'spatial');
  assert.ok(Math.abs(ph1.omega) > 0.1, `tangential contact produced spin (omega=${ph1.omega.toFixed(2)})`);
  assert.ok(Math.abs(sp1.yaw) > 0.5, `yaw integrated over time (yaw=${sp1.yaw.toFixed(2)})`);
  // deterministic: two identical worlds produce the SAME yaw and omega
  const ph2 = r2.uts.world.rrw.getComponent(r2.a.id, 'physics');
  const sp2 = r2.uts.world.rrw.getComponent(r2.a.id, 'spatial');
  assert.equal(sp2.yaw, sp1.yaw);
  assert.equal(ph2.omega, ph1.omega);
  assert.ok(r1.uts.world.physics.report().torques > 0, 'torques are counted (measurable)');
});

test('rotation: ground spin decays (spinFriction) and sleep requires |omega| quiet', () => {
  const uts = createUTS({ seed: 'spindecay' });
  uts.world.terrain.height = () => 20;
  const a = uts.world.physics.addBody({ pos: [100, 20.62, 100], vel: [0, 0, 0], radius: 0.6, omega: 12 });
  for (let i = 0; i < 600; i++) uts.world.physics.step(1 / 60, { tick: i });
  const ph = uts.world.rrw.getComponent(a.id, 'physics');
  assert.ok(ph.omega < 1, `spin decayed on the ground (omega=${ph.omega.toFixed(3)})`);
  assert.ok(Math.abs(sp_yaw(uts, a.id)) < 30, 'yaw advanced a bounded amount, not forever');
  function sp_yaw(u, id) { return u.world.rrw.getComponent(id, 'spatial').yaw; }
});

test('joints: a pinned anchor holds a hanging chain; rest length is respected', () => {
  const uts = createUTS({ seed: 'chain' });
  uts.world.terrain.height = () => -100; // bottomless: gravity pulls, joints hold
  const anchor = uts.world.physics.addBody({ pos: [100, 30, 100], radius: 0.4, pinned: true, label: 'anchor' });
  const links = [anchor];
  for (let i = 0; i < 3; i++) {
    const l = uts.world.physics.addBody({ pos: [100, 30 - (i + 1) * 1.5, 100], radius: 0.4, mass: 0.5 });
    uts.world.physics.addJoint(links[i].id, l.id, { rest: 1.5 });
    links.push(l);
  }
  for (let i = 0; i < 240; i++) uts.world.physics.step(1 / 60, { tick: i });
  const rrw = uts.world.rrw;
  let maxErr = 0;
  for (let i = 0; i < 3; i++) {
    const pa = rrw.getComponent(links[i].id, 'spatial');
    const pb = rrw.getComponent(links[i + 1].id, 'spatial');
    const d = Math.hypot(pb.pos[0] - pa.pos[0], pb.pos[1] - pa.pos[1], pb.pos[2] - pa.pos[2]);
    maxErr = Math.max(maxErr, Math.abs(d - 1.5));
  }
  assert.ok(maxErr < 0.05, `chain holds rest length (max error ${maxErr.toFixed(4)}u)`);
  // the chain hangs BELOW the anchor (gravity won, joints shaped the path)
  const tail = rrw.getComponent(links[3].id, 'spatial');
  assert.ok(tail.pos[1] < 27, `tail hangs below the anchor (y=${tail.pos[1].toFixed(1)})`);
  assert.ok(uts.world.rrw.count('prop') >= 4);
});

test('joints are RRW relations — verifiable causal structure, not a hidden array', () => {
  const uts = createUTS({ seed: 'jointrel' });
  uts.world.terrain.height = () => 20;
  const a = uts.world.physics.addBody({ pos: [100, 21, 100] });
  const b = uts.world.physics.addBody({ pos: [101, 21, 100] });
  const rel = uts.world.physics.addJoint(a.id, b.id, { rest: 1.2, causeEvent: 'ev-x' });
  assert.equal(rel.type, 'joint');
  assert.equal(rel.data.rest, 1.2);
  assert.equal(rel.data.causeEvent, 'ev-x');
  const rels = uts.world.rrw.relations;
  const joint = [...rels.values()].find(r => r.type === 'joint');
  assert.ok(joint, 'joint exists in the RRW relation registry');
  assert.equal(joint.a, a.id);
  assert.equal(joint.b, b.id);
});

test('physics SURVIVES save/load: bodies + joints + rotation continue identically', async () => {
  const mk = async () => {
    const uts = createUTS({ seed: 'physpersist' });
    uts.world.terrain.height = () => 20;
    const a = uts.world.physics.addBody({ pos: [100, 24, 100], vel: [4, 0, 0], radius: 0.6 });
    const b = uts.world.physics.addBody({ pos: [101.5, 20.7, 100], radius: 0.6, omega: 3 });
    uts.world.physics.addJoint(a.id, b.id, { rest: 1.4 });
    for (let i = 0; i < 30; i++) uts.world.physics.step(1 / 60, { tick: i });
    return uts;
  };
  const A = await mk();
  const store = new MemoryStorage();
  await save(store, 'k', A);
  const B = await load(store, 'k');
  assert.equal(B.world.physics.bodies.size, 2, 'bodies rebuilt from the RRW');
  assert.equal(B.world.physics.joints.length, 1, 'joints rebuilt from the RRW relations');
  A.world.physics.step(1 / 60, { tick: 31 });
  B.world.physics.step(1 / 60, { tick: 31 });
  assert.deepEqual(serializeState(B), serializeState(A), 'identical reality one step after restore');
  for (let i = 0; i < 60; i++) { A.world.physics.step(1 / 60, { tick: 32 + i }); B.world.physics.step(1 / 60, { tick: 32 + i }); }
  assert.deepEqual(serializeState(B), serializeState(A), 'still identical 60 steps later (chain swings the same)');
});
