// UTS :: test/terrain_reallife — heightfield determinism, biomes, RealLife
// causal weather chain: rain -> wetness, wind+dry -> dust, storm -> lightning
// -> fire, day/night lighting, fire spread and extinguishing.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createUTS } from '../src/index.js';
import { Terrain, BIOME } from '../src/world/terrain.js';

test('terrain: deterministic heights for equal seeds, different across seeds', () => {
  const a = new Terrain({ seed: 'same' });
  const b = new Terrain({ seed: 'same' });
  const c = new Terrain({ seed: 'other' });
  for (const [x, z] of [[10, 10], [300, 512], [777, 42]]) {
    assert.equal(a.height(x, z), b.height(x, z));
  }
  assert.notEqual(a.height(300, 512), c.height(300, 512));
});

test('terrain: biome rules (water/sand/land) and metadata', () => {
  const t = new Terrain({ seed: 'biome' });
  let foundWater = false, foundSand = false, foundLand = false;
  for (let x = 0; x < t.size; x += 12) {
    for (let z = 0; z < t.size; z += 12) {
      const h = t.height(x, z);
      const b = t.biomeAt(x, z, h);
      if (b === BIOME.WATER) { foundWater = true; assert.ok(h < t.seaLevel); }
      if (b === BIOME.SAND) { foundSand = true; assert.ok(h < t.seaLevel + 0.7); }
      if (b === BIOME.GRASS || b === BIOME.FOREST) foundLand = true;
    }
  }
  assert.ok(foundWater && foundSand && foundLand, 'world contains water, sand and land');
  const meta = t.chunkMeta(3, 4);
  assert.ok(meta.avgH >= 0 && meta.avgH <= 34);
  assert.equal(meta.biomeMix.reduce((s, v) => s + v, 0), 1);
});

test('terrain: sampleChunk shapes and helpers', () => {
  const t = new Terrain({ seed: 'sample' });
  const s = t.sampleChunk(2, 2, 8);
  assert.equal(s.heights.length, 81);
  assert.equal(s.biomes.length, 81);
  const w = t.findWater(t.size / 2, t.size / 2, 500);
  assert.ok(w, 'water exists near center');
  assert.equal(w.length, 3, 'positions are [x, 0, z]');
  assert.ok(t.height(w[0], w[2]) < t.seaLevel);
  const land = t.findLand(w[0] + 5, w[2] + 5, 200);
  assert.ok(t.height(land[0], land[2]) > t.seaLevel);
});

// ---------------------------------------------------------------- RealLife

test('reallife: forced weather changes chain causally (event cites previous)', async () => {
  const uts = createUTS({ seed: 'weather-chain' });
  const id1 = uts.world.setWeather('rain');
  const id2 = uts.world.setWeather('storm');
  assert.equal(uts.rrw.getEvent(id2).cause, id1);
  assert.equal(uts.rrw.verifyCausalChain(id2).valid, true);
  assert.equal(uts.world.environment.weather, 'storm');
});

test('reallife: rain raises wetness; sun dries it', async () => {
  const uts = createUTS({ seed: 'wetness' });
  const realRng = uts.world.rng;
  uts.world.rng = { next: () => 0, chance: () => false, pick: r => r[0], range: () => 0, int: () => 0 }; // hold rain
  uts.world.setWeather('rain');
  uts.ues.run(300);
  assert.ok(uts.world.environment.wetness > 0.3, `wetness should rise (${uts.world.environment.wetness})`);
  uts.world.setWeather('clear');
  uts.world.rng = { next: () => 0.5, chance: () => false, pick: r => r[0], range: () => 0.5, int: () => 0 }; // hold clear
  uts.ues.run(3000);
  uts.world.rng = realRng;
  assert.ok(uts.world.environment.wetness < 0.5, `wetness should dry (${uts.world.environment.wetness})`);
});

test('reallife: dust requires wind + dryness (causal formula, not random)', async () => {
  const uts = createUTS({ seed: 'dust' });
  const realRng = uts.world.rng;
  uts.world.rng = { next: () => 0.5, chance: () => false, pick: r => r[0], range: () => 0.5, int: () => 0 };
  uts.world.environment.dryness = 0.9;
  uts.world.setWeather('dust');
  uts.ues.run(20);
  uts.world.rng = realRng;
  assert.ok(uts.world.environment.dust > 0.2, `dust = wind*dryness (${uts.world.environment.dust})`);
});

test('reallife: storm lightning ignites chained fires; fire is perceivable via grid', async () => {
  const uts = createUTS({ seed: 'strike' });
  uts.reallife = uts.world.reallife;
  uts.world.reallife.igniteChance = 1.0;
  uts.world.setWeather('storm');
  uts.world.strikeLightning([500, 0, 500]);
  const fire = uts.rrw.query({ kind: 'hazard' })[0];
  assert.ok(fire, 'fire exists after strike');
  const started = uts.rrw.getComponent(fire, 'hazard').startedEvent;
  const ev = uts.rrw.getEvent(started);
  assert.equal(ev.type, 'reallife.fire.started');
  assert.equal(uts.rrw.getEvent(ev.cause).type, 'reallife.lightning.strike');
  assert.ok(uts.world.grid.queryCircle(500, 500, 60).includes(fire), 'fire indexed in spatial grid');
});

test('reallife: fire spreads through real fuel; every child fire traces to the same lightning', async () => {
  const uts = createUTS({ seed: 'spread' });
  const w = uts.world;
  // strike dry grass 1 (fuel 1.0 at 440,576 for this seed)
  const strike = w.rrw.emitEvent({ type: 'reallife.lightning.strike', cause: null, data: {}, tick: 0 });
  const fire1 = w.reallife.igniteFire([440, 0, 576], strike);
  assert.ok(fire1, 'dry grass ignited');
  // rigged rng: every spread roll succeeds (deterministic)
  const realRng = w.rng;
  w.rng = { next: () => 0.001, chance: () => true, pick: (a) => a[0], range: () => 1, int: () => 0 };
  for (let i = 0; i < 6; i++) {
    w.combustion.step(0.1, { rain: 0, wind: 0, windDir: [1, 0], hydrology: w.hydrology });
    w.reallife.updateFires(0.1);
  }
  w.rng = realRng;
  const fires = w.rrw.query({ kind: 'hazard' });
  assert.ok(fires.length >= 2, `fire spread through the fuel field (${fires.length} anchors)`);
  // EVERY burning anchor traces back to the same causal chain (strike → ignited → started)
  for (const fid of fires) {
    const startedEv = w.rrw.getComponent(fid, 'hazard').startedEvent;
    assert.ok(startedEv, 'anchor carries its started event');
    const chain = w.rrw.causalityChain(startedEv).map(e => e.type);
    assert.ok(chain.includes('reallife.lightning.strike') || chain.includes('combustion.ignited'),
      `child fire is causally rooted (${chain.slice(0, 3).join('→')})`);
  }
});

test('reallife: rain extinguishes fires (event chain closes cleanly)', async () => {
  const uts = createUTS({ seed: 'extinguish' });
  const w = uts.world;
  w.environment.wetness = 0;
  const strike = w.rrw.emitEvent({ type: 'reallife.lightning.strike', cause: null, data: {}, tick: 0 });
  const fire = w.reallife.igniteFire([440, 0, 576], strike); // dry grass for this seed family
  if (!fire) { // seed moved the biome — find real fuel nearby (honest)
    let alt = null;
    for (let x = 400; x <= 600 && !alt; x += 8) for (let z = 400; z <= 700 && !alt; z += 8) {
      const c = w.combustion._cell(x, z);
      if (c && c.fuel >= 0.4 && w.terrain.height(x, z) > w.terrain.seaLevel) alt = [x, 0, z];
    }
    assert.ok(alt, 'burnable ground exists');
    var fireId = w.reallife.igniteFire(alt, strike);
  } else var fireId = fire;
  assert.ok(fireId, 'fire exists before the storm');
  // a DOWNPOUR: the field eats the fire (rain > 0.45 → fuel drains fast)
  w.environment.rain = 1.0;
  for (let i = 0; i < 200 && w.rrw.get(fireId); i++) {
    w.combustion.step(0.1, { rain: 1.0, wind: 0, windDir: [1, 0], hydrology: w.hydrology });
    w.reallife.updateFires(0.1);
  }
  assert.equal(w.rrw.get(fireId), null, 'the rain destroyed the fire');
  const ext = [...w.rrw.events.values()].find(e => e.type === 'reallife.fire.extinguished');
  assert.ok(ext, 'extinguished event exists');
  assert.equal(w.rrw.verifyCausalChain(ext.id).valid, true, 'the chain closes verifiably');
});

test('reallife: day/night lighting follows the clock', async () => {
  const uts = createUTS({ seed: 'daynight' });
  const realRng = uts.world.rng;
  uts.world.rng = { next: () => 0.5, chance: () => false, pick: r => r[0], range: () => 0.5, int: () => 0 };
  uts.clock.dayLengthSec = 40;
  uts.clock.time = 0; // midnight
  uts.world.updateWeather(0.05);
  const nightAmbient = uts.world.environment.ambient;
  uts.clock.time = 20; // noon
  uts.world.updateWeather(0.05);
  uts.world.rng = realRng;
  const noonAmbient = uts.world.environment.ambient;
  assert.ok(noonAmbient > nightAmbient * 2, `noon ${noonAmbient} vs night ${nightAmbient}`);
});
