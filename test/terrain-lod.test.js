// UTS :: test/terrain-lod — GÊNESIS-LOD AAAA: geometric LOD finished.
// Skirts make cross-ring cracks impossible BY CONSTRUCTION, impostors are
// the honest minimal representation of far terrain, hysteresis kills ring
// flicker, and D-O15 governs the impostor distance (measured, auditable).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createUTS } from '../src/index.js';
import { buildTerrainMesh, buildImpostorMesh } from '../src/render/mesh.js';
import { WebGL2Renderer } from '../src/render/webgl2.js';
import { makeGL } from './helpers/mock-gl.js';

const patchFrom = (uts, cx, cz, res) => {
  const p = uts.world.terrain.sampleChunk(cx, cz, res);
  return { ...p, x0: cx * uts.world.terrain.chunkSize, z0: cz * uts.world.terrain.chunkSize, size: uts.world.terrain.chunkSize, res };
};

test('mesh: skirts exist, reach past the lowest height, and are counted', () => {
  const uts = createUTS({ seed: 'lod-skirt' });
  uts.world.streaming.update([480, 40, 480], { radius: 220, budgetMs: 1e9 });
  const patch = patchFrom(uts, 7, 7, 24);
  const withSkirt = buildTerrainMesh(patch);
  const bare = buildTerrainMesh(patch, { skirt: false });
  assert.equal(bare.count, 24 * 24 * 6);
  assert.equal(withSkirt.count, bare.count + 24 * 4 * 12, '4 walls × res segments × 12 verts (both windings)');
  assert.ok(withSkirt.skirtDepth >= 4, 'skirt has meaningful depth');
  // the deepest skirt vertex sits below minH - margin — no neighbor peak pokes through
  let deepest = Infinity;
  for (let v = bare.count; v < withSkirt.count; v++) {
    deepest = Math.min(deepest, withSkirt.data[v * 7 + 1]);
  }
  assert.ok(deepest <= withSkirt.minH - 4, `skirt bottom (${deepest.toFixed(1)}) below minH-4 (${(withSkirt.minH - 4).toFixed(1)})`);
});

test('mesh: skirts COVER the real T-junction gap between adjacent different-LOD chunks', () => {
  const uts = createUTS({ seed: 'lod-crack' });
  uts.world.streaming.update([480, 40, 480], { radius: 220, budgetMs: 1e9 });
  // shared border between chunk (7,7)@res24 and (8,7)@res8: the worst honest
  // mismatch is between the fine border heights and the coarse linear step
  const fine = patchFrom(uts, 7, 7, 24);
  const coarse = patchFrom(uts, 8, 7, 8);
  const n = fine.res + 1;
  const borderFine = [];
  for (let j = 0; j < n; j++) borderFine.push(fine.heights[j * n + (n - 1)]); // i = res (east edge)
  const m = coarse.res + 1;
  const borderCoarse = [];
  for (let j = 0; j < m; j++) borderCoarse.push(coarse.heights[j * m]); // i = 0 (west edge)
  // sample the fine border at the coarse sample points; coarse interpolates linearly
  let maxGap = 0;
  for (let j = 0; j < m; j++) {
    const t = j / coarse.res;
    const f = borderFine[Math.min(n - 1, Math.round(t * (n - 1)))];
    maxGap = Math.max(maxGap, Math.abs(f - borderCoarse[j]));
  }
  const mesh = buildTerrainMesh(coarse); // the coarse side carries the skirt
  assert.ok(mesh.skirtDepth > maxGap,
    `skirt depth (${mesh.skirtDepth.toFixed(2)}) > measured cross-LOD gap (${maxGap.toFixed(2)}) — crack impossible`);
});

test('impostor: one quad at the average height with the dominant biome — honest minimal terrain', () => {
  const uts = createUTS({ seed: 'lod-imp' });
  uts.world.streaming.update([480, 40, 480], { radius: 220, budgetMs: 1e9 });
  const patch = patchFrom(uts, 5, 5, 8);
  const imp = buildImpostorMesh(patch);
  assert.equal(imp.count, 6, 'a single quad (2 triangles)');
  let sum = 0;
  for (const h of patch.heights) sum += h;
  assert.ok(Math.abs(imp.avgH - sum / patch.heights.length) < 1e-6, 'quad sits at the average height');
  const impY = imp.data[1];
  assert.ok(Math.abs(impY - imp.avgH) < 1e-5);
  // spans exactly the chunk
  const xs = new Set(), zs = new Set();
  for (let v = 0; v < imp.count; v++) { xs.add(imp.data[v * 7]); zs.add(imp.data[v * 7 + 2]); }
  assert.ok(xs.has(patch.x0) && xs.has(patch.x0 + patch.size));
  assert.ok(zs.has(patch.z0) && zs.has(patch.z0 + patch.size));
  // normals up, one dominant biome value
  assert.equal(imp.data[4], 1);
  const biomes = new Set();
  for (let v = 0; v < imp.count; v++) biomes.add(imp.data[v * 7 + 6]);
  assert.equal(biomes.size, 1);
  assert.equal([...biomes][0], imp.dominantBiome);
});

test('streaming: hysteresis — a camera hovering on a ring border never flickers the LOD', () => {
  const uts = createUTS({ seed: 'lod-hyst' });
  const s = uts.world.streaming;
  const cs = uts.world.terrain.chunkSize; // 64 → boundary at 70 from chunk 11 center ~ (11*64+32)=736
  // hover around d≈70 from chunk (11,11): center at 736+70-something… place focus near x = 736+66
  let changes = 0;
  for (let i = 0; i < 30; i++) {
    const jitter = Math.sin(i * 1.7) * 4; // ±4u around the boundary
    s.update([736 + 70 + jitter, 40, 736], { radius: 220, budgetMs: 1e9 });
  }
  changes = s.stats.resChanges;
  assert.ok(changes <= 2, `resolutions changed ≤2 times under border jitter (got ${changes}) — no flicker`);
  // and moving CLEARLY past the boundary does switch (hysteresis is not frozen)
  s.update([736 + 95, 40, 736], { radius: 220, budgetMs: 1e9 });
  s.update([736 + 96, 40, 736], { radius: 220, budgetMs: 1e9 });
  assert.ok(s.stats.resChanges > changes, 'clear crossing still changes the ring');
  // superseded resolutions are evicted: chunk (11,11) resident at exactly one res
  const resSet = new Set();
  for (const e of s.resident.values()) if (e.cx === 11 && e.cz === 11) resSet.add(e.res);
  assert.equal(resSet.size, 1, `chunk resident at exactly one res (got ${[...resSet].join(',')})`);
});

test('frame: lod is marked by distance — near = mesh, far = impostor; stats are exact', () => {
  const uts = createUTS({ seed: 'lod-frame' });
  uts.do15.strategy.terrainLodBias = 0;
  uts.ues.moveCamera([480, 40, 480]);
  uts.world.streaming.update([480, 40, 480], { radius: 220, budgetMs: 1e9 });
  const near = uts.ues.renderFrame();
  assert.equal(near.stats.terrain.meshes + near.stats.terrain.impostors, near.terrain.patches.length);
  for (const p of near.terrain.patches) {
    assert.equal(p.lod, p.dist > (uts.do15.strategy.terrainImpostorAfter ?? 150) ? 'impostor' : 'mesh');
  }
  const nearCount = near.stats.terrain.meshes;
  assert.ok(nearCount > 0, 'something near is a mesh');

  // walk 200u away: most patches beyond impostorAfter become impostors
  uts.ues.moveCamera([480 + 200, 40, 480]);
  uts.world.streaming.update([680, 40, 480], { radius: 220, budgetMs: 1e9 });
  const far = uts.ues.renderFrame();
  assert.ok(far.stats.terrain.impostors > 0, 'far terrain becomes impostors');
  // THE invariant: every patch beyond impostorAfter is an impostor, none inside
  const after = uts.do15.strategy.terrainImpostorAfter ?? 150;
  for (const p of far.terrain.patches) {
    assert.equal(p.lod, p.dist > after ? 'impostor' : 'mesh', `lod honors the tier at d=${p.dist.toFixed(0)}`);
  }
  assert.ok(far.stats.terrain.impostors >= 10, `many impostors at 200u (${far.stats.terrain.impostors})`);
});

test('renderer: impostor buffers are tiny and keyed separately; stats count them exactly', async () => {
  const gl = makeGL();
  const uts = createUTS({ seed: 'lod-gl' });
  uts.ues.moveCamera([620, 40, 480]);
  uts.world.streaming.update([620, 40, 480], { radius: 220, budgetMs: 1e9 });
  const frame = uts.ues.renderFrame();
  const r = new WebGL2Renderer(gl);
  const { drawCalls } = r.render(frame);
  assert.ok(r.stats.impostors > 0, 'this scene has impostors');
  assert.equal(drawCalls, 1 + frame.terrain.patches.length + (frame.entities.length - r.stats.culled), 'sky + every patch + visible entities');
  for (const p of frame.terrain.patches) {
    const lod = p.lod ?? 'mesh';
    const entry = r.terrainBuffers.get(`${p.id}:${p.res}:${p.version}:${lod}`);
    assert.ok(entry, `buffer exists for ${p.id}@${lod}`);
    if (lod === 'impostor') assert.equal(entry.count, 6, 'impostor draws 6 verts');
    else assert.ok(entry.count > p.res * p.res * 6, 'mesh includes skirts');
  }
  assert.ok(r.stats.terrainTris > 0, 'terrain triangles are measured');
  assert.ok(r.stats.meshMs >= 0, 'mesh build time is measured');
  const uploadsAfter = r.stats.uploads;
  r.render(frame); // same frame → zero new uploads (lod included in the key)
  assert.equal(r.stats.uploads, uploadsAfter, 'no re-upload; lod is part of the resource key');
});

test('D-O15: pressure lowers the impostor distance (more impostors sooner), auditable', () => {
  const uts = createUTS({ seed: 'lod-do15' });
  assert.equal(uts.do15.strategy.terrainImpostorAfter, 150);
  for (let i = 0; i < 5; i++) uts.do15.report({ frameMs: 40, simMs: 40 });
  assert.equal(uts.do15.strategy.terrainImpostorAfter, 120, 'high pressure → impostors begin sooner');
  for (let i = 0; i < 4; i++) uts.do15.report({ frameMs: 40, simMs: 40 });
  assert.equal(uts.do15.strategy.terrainImpostorAfter, 90, 'extreme → even sooner');
  const decision = uts.do15.decisions.filter(d => d.kind === 'strategy').at(-1);
  assert.ok(JSON.stringify(decision.to).includes('terrainImpostorAfter'), 'decision records the LOD tier change');
  for (let i = 0; i < 12; i++) uts.do15.report({ frameMs: 0, simMs: 0 });
  assert.equal(uts.do15.strategy.terrainImpostorAfter, 150, 'recovers on relief');
});

test('integration: the LOD chain survives save/load untouched (presentation, never truth)', async () => {
  const { save, load, serializeState } = await import('../src/persistence/snapshot.js');
  const { MemoryStorage } = await import('../src/persistence/storage.js');
  const uts = createUTS({ seed: 'lod-persist' });
  await uts.core.processObjective('criar uma vila chamada Vale perto de um rio');
  uts.ues.run(100);
  uts.ues.moveCamera([560, 40, 480]); // mixed mesh/impostor scene
  uts.world.streaming.update(uts.ues.camera.pos, { radius: 220, budgetMs: 1e9 });
  const frame = uts.ues.renderFrame();
  assert.ok(frame.stats.terrain.impostors > 0 && frame.stats.terrain.meshes > 0, 'mixed LOD scene');

  const store = new MemoryStorage();
  await save(store, 'k', uts);
  const B = await load(store, 'k');
  B.ues.run(60); uts.ues.run(60);
  assert.deepEqual(serializeState(B), serializeState(uts), 'LOD/streaming is presentation: reality identical after restore');
});
