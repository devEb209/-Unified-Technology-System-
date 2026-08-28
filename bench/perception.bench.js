#!/usr/bin/env node
// UTS :: bench/perception — REAL comparative benchmark: O(n) brute-force
// perception vs the indexed SpatialGrid path, at 500/2000/5000/10000 NPCs.
// No fake numbers: wall-clock via performance.now, candidate counts from the
// actual query, index memory estimated from the live structure.

import { createUTS } from '../src/index.js';

const SIZES = [500, 2000, 5000, 10000];
const WARM = 5, SAMPLES = 20;

function bruteForcePerceive(rrw, pos, range, selfId) {
  const out = [];
  for (const id of rrw.query({ kind: 'npc' })) {
    if (id === selfId) continue;
    const sp = rrw.getComponent(id, 'spatial');
    const dx = sp.pos[0] - pos[0], dz = sp.pos[2] - pos[2];
    if (dx * dx + dz * dz <= range * range) out.push(id);
  }
  return out;
}

console.log('\n=== UTS :: perception benchmark (indexed vs brute force) ===\n');
console.log('n'.padStart(6), 'brute ms/tick'.padStart(14), 'grid ms/tick'.padStart(13),
  'speedup'.padStart(8), 'cand/query'.padStart(11), 'kept/query'.padStart(10), 'grid mem'.padStart(10), 'idx update'.padStart(10));

for (const n of SIZES) {
  const uts = createUTS({ seed: `bench-${n}`, log: { level: 'error' } });
  const side = Math.ceil(Math.sqrt(n)) * 14;
  for (let i = 0; i < n; i++) {
    const gx = (i % 45) * 14, gz = Math.floor(i / 45) * 14;
    uts.world.spawnNPC({ pos: [100 + gx, 0, 100 + gz] });
  }
  const center = [100 + side / 2, 0, 100 + side / 2];
  const rrw = uts.rrw;
  const probe = rrw.query({ kind: 'npc' })[0];

  // warmup
  for (let i = 0; i < WARM; i++) {
    bruteForcePerceive(rrw, center, 24, probe);
    uts.world.perceive(center, { range: 24, fovDeg: 360, cap: 12, selfId: probe });
  }

  // brute force: n scans (one per NPC, like the old O(n^2) tick)
  let t0 = performance.now();
  for (let s = 0; s < SAMPLES; s++) {
    for (const id of rrw.query({ kind: 'npc' })) {
      const sp = rrw.getComponent(id, 'spatial');
      bruteForcePerceive(rrw, sp.pos, 24, id);
    }
  }
  const bruteMs = (performance.now() - t0) / SAMPLES;

  // indexed: n queries through the grid
  const m0 = { ...uts.world.grid.metrics };
  const pm0 = { ...uts.world.perceptionMetrics };
  t0 = performance.now();
  for (let s = 0; s < SAMPLES; s++) {
    for (const id of rrw.query({ kind: 'npc' })) {
      const sp = rrw.getComponent(id, 'spatial');
      uts.world.perceive(sp.pos, { range: 24, fovDeg: 360, cap: 12, selfId: id });
    }
  }
  const gridMs = (performance.now() - t0) / SAMPLES;
  const m1 = { ...uts.world.grid.metrics };
  const pm1 = { ...uts.world.perceptionMetrics };

  const queries = pm1.queries - pm0.queries;
  const candQ = (pm1.consulted - pm0.consulted) / queries;
  const keptQ = (pm1.perceived - pm0.perceived) / queries;
  const updates = m1.moves + m1.inserts - m0.moves - m0.inserts;

  console.log(
    String(n).padStart(6),
    bruteMs.toFixed(2).padStart(14),
    gridMs.toFixed(2).padStart(13),
    (bruteMs / Math.max(gridMs, 0.01)).toFixed(1) + 'x'.padStart(7),
    candQ.toFixed(1).padStart(11),
    keptQ.toFixed(1).padStart(10),
    ((uts.world.grid.memoryEstimate() / 1024).toFixed(0) + 'KB').padStart(10),
    String(updates).padStart(10),
  );
}
console.log('\n(deterministic seeds; absolute times depend on the host machine)\n');
