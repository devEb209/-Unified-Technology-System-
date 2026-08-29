// UTS :: test/r3-scale — SCALE MATERIALIZED under ADR-019 + D-O15.
// The world does NOT end at the render bubble: far fire = horizon glow,
// far settlement = causal-state marker, water film = rendered cells,
// and the sea FOLLOWS the camera (waves stay fixed in the world).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createUTS, WebGL2Renderer } from '../src/index.js';
import { makeGL } from './helpers/mock-gl.js';

function nearestFuel(world, x0, z0, minR, maxR) {
  for (let r = minR; r <= maxR; r += 8) {
    for (let a = 0; a < 14; a++) {
      const x = x0 + Math.cos((a / 14) * Math.PI * 2) * r, z = z0 + Math.sin((a / 14) * Math.PI * 2) * r;
      const c = world.combustion._cell(x, z);
      if (c && c.fuel >= 0.3 && world.terrain.height(x, z) > world.terrain.seaLevel) return [x, 0, z];
    }
  }
  return null;
}

test('scale: the SEA FOLLOWS THE CAMERA — waves stay fixed in the world (uCenter)', async () => {
  const uts = createUTS({ seed: 'sea-follow' });
  uts.ues.run(3);
  const gl = makeGL();
  const r = new WebGL2Renderer(gl);
  r.init();
  uts.ues.moveCamera([700, 40, 700]);
  r.render(uts.ues.renderFrame());
  const c1 = gl._calls.filter(c => c[0] === 'uniform2f' && c[1] === 'uCenter').at(-1);
  uts.ues.moveCamera([920, 40, 810]);
  r.render(uts.ues.renderFrame());
  const c2 = gl._calls.filter(c => c[0] === 'uniform2f' && c[1] === 'uCenter').at(-1);
  assert.ok(c1 && c2, 'the water program receives its center');
  assert.deepEqual(c1[2], [700, 700], `sea centered on camera 1 (${JSON.stringify(c1[2])})`);
  assert.deepEqual(c2[2], [920, 810], `sea followed to camera 2 (${JSON.stringify(c2[2])})`);
});

test('scale: the hydrology FILM is materialized — deepest cells first, budget capped', () => {
  const uts = createUTS({ seed: 'film' });
  const w = uts.world;
  uts.ues.moveCamera([512, 30, 512]);
  // seed film cells: a deep one far-ish, a shallow one near, one outside radius
  w.hydrology.cells.set('20,20', { depth: 0.012, flow: 0 });  // ~490,490 near
  w.hydrology.cells.set('21,21', { depth: 0.035, flow: 0 });  // ~515,515 deep
  w.hydrology.cells.set('2,2', { depth: 0.05, flow: 0 });     // ~60,60 far away
  const frame = uts.ues.renderFrame();
  assert.ok(frame.waterFilm.length >= 2, `film cells materialized (${frame.waterFilm.length})`);
  assert.equal(frame.waterFilm[0].depth, 0.035, 'deepest first');
  assert.ok(frame.waterFilm.every(f => Math.hypot(f.pos[0] - 512, f.pos[2] - 512) <= 220),
    'only cells within the materialization radius');
  assert.ok(frame.waterFilm[0].pos[1] > 0, 'film sits ON the terrain (real height)');
  // the renderer draws it in the scale pass
  const gl = makeGL();
  const r = new WebGL2Renderer(gl);
  r.init();
  r.render(frame);
  assert.equal(r.stats.horizonDraws, 1, 'film + horizon share one honest pass');
});

test('scale: FAR fire = horizon glow (re-presented), NOT a dropped light', () => {
  const uts = createUTS({ seed: 'far-fire' });
  const w = uts.world;
  uts.ues.moveCamera([512, 40, 512]);
  const spot = nearestFuel(w, 512, 512, 200, 500);
  assert.ok(spot, 'burnable ground exists far away');
  const ev = w.combustion.ignite(spot[0], spot[2], {});
  assert.ok(ev, 'the far fire burns (real fuel)');
  w.reallife.updateFires(0.1); // anchors materialize FROM the field (honest path)
  const frame = uts.ues.renderFrame();
  const glow = frame.horizon.find(h => h.kind === 'fire');
  assert.ok(glow, 'far fire is RE-PRESENTED as horizon glow');
  assert.ok(glow.intensity > 0 && glow.alpha > 0, `glow carries its intensity (${glow.intensity?.toFixed(2)})`);
  assert.ok(!frame.lights.points.some(l => l.kind === 'fire'),
    'beyond 160m there is no point light — the glow IS the honest representation');
});

test('scale: FAR settlement = causal-state marker sized by population (never a texture)', () => {
  const uts = createUTS({ seed: 'far-town' });
  const w = uts.world;
  uts.ues.moveCamera([512, 40, 512]);
  const ent = w.createSettlement({ name: 'Terra Longe', pos: [1150, 0, 640], pop: 90 });
  const frame = uts.ues.renderFrame();
  const marker = frame.horizon.find(h => h.kind === 'settlement');
  assert.ok(marker, 'the distant town is visible on the horizon');
  assert.equal(marker.id, ent.id, 'IDENTITY preserved in the marker');
  assert.equal(marker.pop, 90, 'the marker carries the causal state (population)');
  assert.ok(marker.size > 18 + Math.sqrt(90) * 2.2 - 1e-6, 'size grows with population');
});

test('scale: NEAR reality is NOT doubled — no double representation', () => {
  const uts = createUTS({ seed: 'no-double' });
  const w = uts.world;
  uts.ues.moveCamera([512, 40, 512]);
  const nearFire = nearestFuel(w, 512, 512, 6, 120);
  assert.ok(nearFire, 'near fuel exists');
  w.combustion.ignite(nearFire[0], nearFire[2], {});
  w.reallife.updateFires(0.1); // near fire gets its anchor (and thus its light)
  w.createSettlement({ name: 'Perto', pos: [560, 0, 530], pop: 30 });
  const frame = uts.ues.renderFrame();
  assert.ok(frame.lights.points.some(l => l.kind === 'fire'), 'near fire = point light (full detail)');
  assert.ok(!frame.horizon.some(h => h.kind === 'fire'), 'near fire is NOT a horizon glow (no doubling)');
  assert.ok(!frame.horizon.some(h => h.kind === 'settlement'), 'near settlement = aggregate, not horizon marker');
});

test('scale: D-O15 budget — the horizon never materializes more than 24 markers', () => {
  const uts = createUTS({ seed: 'horizon-cap' });
  const w = uts.world;
  uts.ues.moveCamera([512, 40, 512]);
  for (let i = 0; i < 30; i++) {
    const a = (i / 30) * Math.PI * 2;
    w.createSettlement({ name: `T${i}`, pos: [512 + Math.cos(a) * 900, 0, 512 + Math.sin(a) * 900], pop: 10 + i });
  }
  const frame = uts.ues.renderFrame();
  assert.ok(frame.horizon.length <= 24, `budget respected (${frame.horizon.length})`);
  const ids = new Set(frame.horizon.map(h => h.id));
  assert.equal(ids.size, frame.horizon.length, 'identity is unique per marker');
});

test('scale: determinism intact — far town + far fire survive save/load byte-identically', async () => {
  const { Persistence } = await import('../src/index.js');
  const uts = createUTS({ seed: 'scale-det' });
  const w = uts.world;
  uts.ues.run(5);
  const spot = nearestFuel(w, 512, 512, 200, 500);
  if (spot) w.combustion.ignite(spot[0], spot[2], {});
  w.createSettlement({ name: 'Det', pos: [1000, 0, 700], pop: 50 });
  uts.ues.run(10);
  const a = createUTS({ seed: 'scale-det-b' });
  const snap = JSON.parse(JSON.stringify(Persistence.serializeState(uts)));
  const b = Persistence.restoreState(snap);
  b.ues.run(10); uts.ues.run(10);
  const sa = JSON.stringify(Persistence.serializeState(uts));
  const sb = JSON.stringify(Persistence.serializeState(b));
  assert.equal(sa, sb, 'A and B evolve byte-identically (scale features are derived, truth is RRW)');
});
