// UTS :: test/spatial_perception — SpatialGrid correctness, RRW as source of
// truth, indexed perception equivalence vs brute force, resolution caps.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createUTS } from '../src/index.js';
import { SpatialGrid } from '../src/spatial/grid.js';

test('grid: insert/update/remove keeps the index synchronized', () => {
  const g = new SpatialGrid({ cellSize: 10 });
  g.update('a', 5, 5);
  g.update('b', 105, 105);
  assert.deepEqual(g.queryCircle(5, 5, 3), ['a']);
  g.update('a', 106, 106); // move across cells
  assert.deepEqual(g.queryCircle(5, 5, 50), []);
  assert.deepEqual(g.queryCircle(106, 106, 5).sort(), ['a', 'b'].sort());
  g.remove('a');
  assert.deepEqual(g.queryCircle(106, 106, 50), ['b']);
  assert.equal(g.remove('a'), false);
});

test('grid: queryCircle matches brute force on a dense world', () => {
  const g = new SpatialGrid({ cellSize: 16 });
  const pts = [];
  let s = 12345;
  const rnd = () => (s = (s * 1103515245 + 12345) & 0x7fffffff) / 0x7fffffff;
  for (let i = 0; i < 500; i++) {
    const x = rnd() * 300, z = rnd() * 300;
    pts.push([`p${i}`, x, z]);
    g.update(`p${i}`, x, z);
  }
  g.posLookup = (id) => {
    const p = pts.find(q => q[0] === id);
    return [p[1], 0, p[2]];
  };
  for (const [qx, qz] of [[50, 50], [150, 210], [299, 3]]) {
    const got = g.queryCircle(qx, qz, 60).sort();
    const want = pts.filter(([, x, z]) => (x - qx) ** 2 + (z - qz) ** 2 <= 3600).map(([id]) => id).sort();
    assert.deepEqual(got, want);
  }
});

test('grid: rebuild restores index from RRW truth (identity preserved)', () => {
  const g = new SpatialGrid({ cellSize: 16 });
  g.rebuild([['x', 1, 1], ['y', 20, 20]]);
  assert.deepEqual(g.queryCircle(1, 1, 2), ['x']);
  assert.equal(g.size, 2);
  assert.ok(g.memoryEstimate() > 0);
});

test('world: perceive() equals brute-force perception (indexed == O(n) results)', async () => {
  const uts = createUTS({ seed: 'perc-equiv' });
  const center = uts.world.spawnNPC({ pos: [500, 0, 500] });
  for (let i = 0; i < 40; i++) {
    const a = (i / 40) * Math.PI * 2;
    uts.world.spawnNPC({ pos: [500 + Math.cos(a) * (5 + (i % 7) * 2), 0, 500 + Math.sin(a) * (5 + (i % 7) * 2)] });
  }
  uts.world.grid.rebuild(
    [...uts.rrw.entities.values()].filter(e => e.components.has('spatial')).map(e => [e.id, e.components.get('spatial').pos[0], e.components.get('spatial').pos[2]]),
  );
  const model = { selfId: center.id, range: 24, fovDeg: 360, cap: 99 };
  const { entities: perceived, consulted } = uts.world.perceive([500, 0, 500], model);
  const want = [...uts.rrw.query({ kind: 'npc' })].filter(id => id !== center.id).sort();
  assert.deepEqual(perceived.map(p => p.id).sort(), want);
  assert.ok(consulted >= want.length);
});

test('world: fov filter excludes entities behind the perceiver', async () => {
  const uts = createUTS({ seed: 'fov' });
  const npc = uts.world.spawnNPC({ pos: [500, 0, 500] });
  uts.rrw.getComponent(npc.id, 'spatial').yaw = 0; // facing +z
  const front = uts.world.spawnNPC({ pos: [500, 0, 510] });
  const behind = uts.world.spawnNPC({ pos: [500, 0, 490] });
  const { entities } = uts.world.perceive([500, 0, 500], {
    selfId: npc.id, range: 30, fovDeg: 90, facing: [0, 1], cap: 99,
  });
  const ids = entities.map(e => e.id);
  assert.ok(ids.includes(front.id));
  assert.ok(!ids.includes(behind.id));
});

test('world: resolution cap drops lowest-importance candidates but NEVER hazards', async () => {
  const uts = createUTS({ seed: 'cap' });
  const npc = uts.world.spawnNPC({ pos: [500, 0, 500] });
  for (let i = 0; i < 10; i++) uts.world.spawnNPC({ pos: [502 + i, 0, 500] });
  const fire = uts.world.reallife.igniteFire([510, 0, 500], null); // importance 1
  const { entities } = uts.world.perceive([500, 0, 500], { selfId: npc.id, range: 30, fovDeg: 360, cap: 4 });
  const kinds = entities.map(e => e.kind);
  assert.ok(kinds.includes('hazard'), 'fires survive any cap');
  assert.ok(entities.length <= 5, `cap respected (got ${entities.length})`);
});

test('world: D-O15 pressure changes perception resolution (coarse < full range)', async () => {
  const uts = createUTS({ seed: 'perc-res' });
  for (let i = 0; i < 8; i++) uts.do15.report({ frameMs: 40, simMs: 40 }); // sustained overload -> extreme
  const model = { range: 24, cap: 12 };
  const adjusted = uts.do15.decidePerception(model);
  assert.ok(adjusted.range < 24, `range reduced (${adjusted.range})`);
  assert.equal(adjusted.resolution, 'coarse');
});

test('grid: moving NPC keeps index in sync automatically (no divergence)', async () => {
  const uts = createUTS({ seed: 'sync' });
  const npc = uts.world.spawnNPC({ pos: [500, 0, 500] });
  uts.rrw.getComponent(npc.id, 'mind').needs.energy = 1; // rest must not cancel the intent
  uts.rrw.addComponent(npc.id, 'intent', { target: [600, 0, 500], speed: 100 });
  uts.ues.tick();
  uts.ues.tick();
  const pos = uts.rrw.getComponent(npc.id, 'spatial').pos;
  assert.deepEqual(uts.world.grid.queryCircle(pos[0], pos[2], 0.5), [npc.id]);
  assert.ok(!uts.world.grid.queryCircle(500, 500, 0.5).includes(npc.id));
});
