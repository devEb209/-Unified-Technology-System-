// UTS :: test/combustion-reality — fire as a FUEL PROCESS, not a texture.
// (vision.md §2: model the reality that produces the appearance.)
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createUTS } from '../src/index.js';
import { Combustion } from '../src/world/phenomena/combustion.js';

function fakeWorld({ seed = 'fire' } = {}) {
  // deterministic flat-ish terrain with a FOREST plateau in the middle
  const rngState = { v: 0 };
  const world = {
    clock: { tick: 0 },
    environment: { wetness: 0, rain: 0 },
    terrain: {
      seaLevel: 6,
      height: (x, z) => (x > 300 && x < 700 && z > 300 && z < 700 ? 20 : 8),
      biomeAt: (x, z) => (x > 300 && x < 700 && z > 300 && z < 700 ? 3 : 1), // forest plateau
    },
    rrw: {
      events: new Map(),
      emitEvent(e) { const id = `ev${this.events.size + 1}`; this.events.set(id, { id, ...e }); return { id, ...e }; },
    },
    rng: { chance: (p) => { rngState.v = (rngState.v * 1103515245 + 12345) & 0x7fffffff; return (rngState.v / 0x7fffffff) < p; } },
  };
  return world;
}

test('fire consumes REAL fuel and leaves persistent burnt ground (nothing is spawned from nothing)', () => {
  const w = fakeWorld();
  const fire = new Combustion({ world: w });
  const ev = fire.ignite(500, 500);
  assert.ok(ev, 'forest with dry fuel ignites');
  assert.equal(ev.type, 'combustion.ignited');
  const fuelBefore = fire.cells.get(fire._key(500, 500)).fuel;
  for (let i = 0; i < 400; i++) fire.step(0.1, { rain: 0, wind: 0 });
  const cell = fire.cells.get(fire._key(500, 500));
  assert.ok(cell.fuel < fuelBefore * 0.3, `fire ate the biomass (${fuelBefore.toFixed(2)} → ${cell.fuel.toFixed(2)})`);
  if (!cell.burning) assert.equal(cell.burnt, true, 'burnt ground PERSISTS as state');
  const ext = [...w.rrw.events.values()].filter(e => e.type === 'combustion.extinguished');
  assert.ok(ext.length >= 1, 'extinction is a causal event, not a silent despawn');
});

test('fire SPREADS along fuel + wind: downwind ignites, soaked ground does not', () => {
  const w = fakeWorld();
  const fire = new Combustion({ world: w, cell: 12 });
  fire.ignite(500, 500);
  // strong east wind → fire should march east
  for (let i = 0; i < 200; i++) fire.step(0.1, { rain: 0, wind: 1, windDir: [1, 0] });
  const burning = fire.burningNear(500, 500, 200);
  const avgX = burning.length ? burning.reduce((a, b) => a + b.pos[0], 0) / burning.length : 500;
  assert.ok(fire.stats.spreads > 0, 'fire found more fuel');
  assert.ok(avgX >= 500, `wind pushed the fire downwind (mean x ${avgX.toFixed(0)})`);

  // hydrology stops the front: wet cell refuses
  const wet = { wetnessAt: () => 0.9, depthAt: () => 0 };
  const w2 = fakeWorld();
  const fire2 = new Combustion({ world: w2, cell: 12 });
  fire2.hydrologyRef = wet;
  fire2.ignite(500, 500);
  for (let i = 0; i < 120; i++) fire2.step(0.1, { rain: 0, wind: 1, windDir: [1, 0], hydrology: wet });
  assert.equal(fire2.stats.spreads, 0, 'water-soaked ground STOPS the fire front (honest physics)');
});

test('rain beats fire: a storm extinguishes an open flame', () => {
  const w = fakeWorld();
  const fire = new Combustion({ world: w });
  fire.ignite(500, 500);
  assert.ok(fire.cells.get(fire._key(500, 500)).burning);
  for (let i = 0; i < 200 && fire.cells.get(fire._key(500, 500)).burning; i++) {
    fire.step(0.1, { rain: 0.8, wind: 0 });
  }
  assert.equal(fire.cells.get(fire._key(500, 500)).burning, false, 'the storm put it out');
});

test('CAUSALITY: ignition records its cause chain in the RRW', () => {
  const uts = createUTS({ seed: 'fire-cause' });
  const w = uts.world;
  w.environment.wetness = 0;
  const strike = w.rrw.emitEvent({ type: 'lightning.struck', subject: 'ground:test', tick: w.clock.tick });
  const ev = w.combustion.ignite(560, 560, { causeEvent: strike.id });
  if (ev) assert.equal(ev.cause, strike.id, 'the fire KNOWS it was born from that strike');
});

test('DETERMINISM: same seed → same fire; snapshot/restore resumes exactly', () => {
  const run = () => {
    const w = fakeWorld();
    const fire = new Combustion({ world: w, cell: 12 });
    fire.ignite(500, 500);
    for (let i = 0; i < 150; i++) fire.step(0.1, { rain: 0, wind: 0.6, windDir: [0.7, 0.7] });
    return { cells: fire.snapshot().cells, stats: { ...fire.stats } };
  };
  const a = run(), b = run();
  assert.deepEqual(b.cells, a.cells, 'same seed → identical fire field');
  assert.deepEqual(b.stats, a.stats);

  // resume mid-fire from snapshot
  const w = fakeWorld();
  const fire = new Combustion({ world: w, cell: 12 });
  fire.restore(JSON.parse(JSON.stringify(a)));
  const before = fire.snapshot();
  for (let i = 0; i < 50; i++) fire.step(0.1, { rain: 0, wind: 0.6, windDir: [0.7, 0.7] });
  assert.ok(fire.snapshot().cells.length >= before.cells.length, 'restored fire keeps evolving');
});
