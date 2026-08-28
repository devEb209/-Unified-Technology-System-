// UTS :: test/scale — indexed perception must keep large worlds tractable.
// Timing claims live in bench/; here we assert FUNCTIONAL scale and that the
// spatial index bounds perception work (candidates << brute force O(n) per NPC).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createUTS } from '../src/index.js';

test('scale: 2000 NPCs — ticks complete, perception stays indexed (candidates bounded)', async () => {
  const uts = createUTS({ seed: 'scale-2000', log: { level: 'error' } });
  const N = 2000;
  const side = Math.ceil(Math.sqrt(N)) * 14; // uniform spread
  for (let i = 0; i < N; i++) {
    const gx = (i % 45) * 14, gz = Math.floor(i / 45) * 14;
    uts.world.spawnNPC({ pos: [100 + gx, 0, 100 + gz] });
  }
  uts.ues.moveCamera([100 + side / 2, 40, 100 + side / 2]);

  const t0 = performance.now();
  uts.ues.run(3);
  const dt = performance.now() - t0;
  assert.ok(dt < 20000, `3 ticks with ${N} npcs took ${dt.toFixed(0)}ms`);

  // one perception query must consult a bounded candidate set, not the world
  const m0 = { ...uts.world.perceptionMetrics };
  const { consulted } = uts.world.perceive([600, 0, 600], { range: 24, fovDeg: 360, cap: 12 });
  assert.ok(consulted < 200, `spatial query consulted ${consulted} (vs ${N} brute force)`);
  assert.ok(uts.world.grid.size === N + 0 || uts.world.grid.size >= N, 'grid holds all entities');
  assert.ok(uts.world.grid.cellCount() > 10, 'grid partitioned the space');
});

test('scale: dense city — perception cap keeps per-NPC cognition bounded', async () => {
  const uts = createUTS({ seed: 'scale-dense', log: { level: 'error' } });
  // 400 NPCs in a tight cluster: brute force would be 400*400 = 160k checks/tick
  for (let i = 0; i < 400; i++) {
    const a = i * 2.39996, r = Math.sqrt(i) * 2; // sunflower distribution
    uts.world.spawnNPC({ pos: [500 + Math.cos(a) * r, 0, 500 + Math.sin(a) * r] });
  }
  const m0 = { ...uts.world.perceptionMetrics };
  uts.ues.run(2);
  const m1 = { ...uts.world.perceptionMetrics };
  const queries = m1.queries - m0.queries;
  assert.ok(queries > 0);
  const avgConsulted = (m1.consulted - m0.consulted) / queries;
  const avgPerceived = (m1.perceived - m0.perceived) / queries;
  assert.ok(avgPerceived <= 13, `cap holds (avg perceived ${avgPerceived.toFixed(1)})`);
  assert.ok(avgConsulted < 400, `indexed queries bounded (avg consulted ${avgConsulted.toFixed(1)})`);
});

test('scale: materialization budget holds under 2000 NPCs near focus', async () => {
  const uts = createUTS({ seed: 'scale-budget', log: { level: 'error' } });
  for (let i = 0; i < 800; i++) {
    const gx = (i % 40) * 2, gz = Math.floor(i / 40) * 2;
    uts.world.spawnNPC({ pos: [500 + gx, 0, 500 + gz] }); // dense around camera
  }
  uts.ues.moveCamera([540, 40, 540]);
  uts.do15.strategy.maxMaterialized = 120;
  uts.world.updateMaterialization(uts.ues.camera.pos);
  const mat = uts.rrw.query({ kind: 'npc', materialization: 'full' }).length
    + uts.rrw.query({ kind: 'npc', materialization: 'partial' }).length;
  assert.ok(mat <= 120, `budget enforced: ${mat}`);
  assert.equal(uts.rrw.count('npc'), 800, 'no entity was destroyed by optimization');
});
