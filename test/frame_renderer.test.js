// UTS :: test/frame_renderer — the Frame is DERIVED from represented state;
// LOD by distance; Null/Text backends manifest it honestly.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createUTS } from '../src/index.js';
import { NullRenderer, TextRenderer } from '../src/render/backends.js';

test('frame: derived from state — npc position and weather are reflected', async () => {
  const uts = createUTS({ seed: 'frame' });
  const npc = uts.world.spawnNPC({ pos: [500, 0, 505] });
  uts.ues.moveCamera([500, 40, 500]);
  uts.world.setWeather('rain');
  uts.world.updateWeather(0.05);
  const frame = uts.ues.renderFrame();
  const fEnt = frame.entities.find(e => e.id === npc.id);
  assert.ok(fEnt, 'materialized npc is in the frame');
  assert.deepEqual(fEnt.pos, uts.rrw.getComponent(npc.id, 'spatial').pos);
  assert.equal(frame.environment.weather, uts.world.environment.weather);
  assert.ok(frame.terrain.patches.length > 0, 'terrain patches extracted');
  assert.ok(frame.audio.ambience, 'audio state derived');
});

test('frame: terrain LOD resolution decreases with distance', async () => {
  const uts = createUTS({ seed: 'lod' });
  uts.ues.moveCamera([480, 40, 480]); // inside chunk (7,7)
  uts.do15.strategy.terrainLodBias = 0;
  const frame = uts.ues.renderFrame();
  const byId = new Map(frame.terrain.patches.map(p => [p.id, p]));
  assert.equal(byId.get('7:7').res, 24, 'nearest chunk high res');
  assert.ok(byId.get('4:7').res < 24, 'distant chunk lower res');
});

test('frame: terrain cache reuse (same patch object until evicted)', async () => {
  const uts = createUTS({ seed: 'cache' });
  uts.ues.moveCamera([480, 40, 480]);
  const f1 = uts.ues.renderFrame();
  const p1 = f1.terrain.patches[0];
  const f2 = uts.ues.renderFrame();
  const p2 = f2.terrain.patches.find(p => p.id === p1.id && p.res === p1.res);
  assert.equal(p1.heights, p2.heights, 'heights come from the cache (static resource)');
});

test('frame: abstract settlements manifest as aggregates, partial as buildings', async () => {
  const uts = createUTS({ seed: 'agg' });
  const s = uts.world.createSettlement({ name: 'Agg', pos: [500, 0, 500], pop: 30 });
  uts.ues.moveCamera([700, 40, 700]); // outside materialization radius
  uts.world.updateMaterialization(uts.ues.camera.pos);
  let frame = uts.ues.renderFrame();
  assert.ok(frame.aggregates.some(a => a.id === s.id), 'abstract settlement is an aggregate blob');

  uts.ues.moveCamera([500, 40, 500]);
  uts.world.updateMaterialization(uts.ues.camera.pos);
  frame = uts.ues.renderFrame();
  assert.ok(frame.entities.some(e => e.id === s.id), 'materialized settlement is a building entity');
});

test('null renderer: counts draw calls matching frame contents', async () => {
  const uts = createUTS({ seed: 'null' });
  uts.world.spawnNPC({ pos: [500, 0, 505] });
  uts.ues.moveCamera([500, 40, 500]);
  const frame = uts.ues.renderFrame();
  const r = new NullRenderer();
  r.init();
  const { drawCalls } = r.render(frame);
  const expected = 1 + frame.terrain.patches.length + frame.entities.length + frame.aggregates.length
    + (Math.max(frame.environment.rain, frame.environment.dust) > 0.02 ? 1 : 0);
  assert.equal(drawCalls, expected);
  const before = r.stats.drawCalls;
  r.render(frame);
  assert.equal(r.stats.drawCalls - before, expected);
  r.destroy();
});

test('text renderer: output derives from state (npcs, weather header, terrain chars)', async () => {
  const uts = createUTS({ seed: 'text' });
  uts.world.spawnNPC({ pos: [512, 0, 494] }); // visible, distinct from the camera cell
  uts.ues.moveCamera([500, 40, 500]);
  uts.world.setWeather('rain');
  uts.world.updateWeather(0.05);
  const frame = uts.ues.renderFrame();
  const r = new TextRenderer({ cols: 64, rows: 24 });
  const out = r.render(frame);
  assert.ok(out.includes('weather=rain'));
  assert.ok(out.includes('N'), 'npc plotted');
  assert.ok(/[~,.t^*]/.test(out), 'terrain chars present');
  assert.ok(out.includes('@'), 'camera plotted');
});

test('frame: stats are honest about materialization levels', async () => {
  const uts = createUTS({ seed: 'stats' });
  const near = uts.world.spawnNPC({ pos: [505, 0, 500] });
  const far = uts.world.spawnNPC({ pos: [700, 0, 500] });
  uts.ues.moveCamera([500, 40, 500]);
  uts.world.updateMaterialization(uts.ues.camera.pos);
  const frame = uts.ues.renderFrame();
  assert.equal(frame.stats.npcsMaterialized, 1);
  assert.equal(frame.stats.pressure, uts.do15.pressure);
});
