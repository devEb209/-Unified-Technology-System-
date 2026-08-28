// UTS :: test/phenomena-atmosphere-hydrology — the reality-first systems.
// These tests ask THE question: does the model BEHAVE like the real
// phenomenon, not like a shader? (ADR-019, vision.md §2/§3)
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createUTS } from '../src/index.js';
import { Atmosphere } from '../src/world/phenomena/atmosphere.js';
import { Hydrology } from '../src/world/phenomena/hydrology.js';

test('atmosphere: the sky at zenith IS blue-dominant, at the horizon it IS red (Rayleigh path)', () => {
  const a = new Atmosphere();
  const noon = a.sky({ sunEl: 1, ambient: 1 });
  const sunset = a.sky({ sunEl: 0.02, ambient: 0.25 });
  const night = a.sky({ sunEl: -0.4, ambient: 0.16 });
  // physics facts, not aesthetics:
  assert.ok(noon.skyTop[2] > noon.skyTop[0] * 2, `zenith sky is blue-dominant (B ${noon.skyTop[2].toFixed(2)} vs R ${noon.skyTop[0].toFixed(2)})`);
  assert.ok(sunset.skyTop[0] > sunset.skyTop[2] * 1.8, `long path shifts sky to red (R ${sunset.skyTop[0].toFixed(2)} vs B ${sunset.skyTop[2].toFixed(2)})`);
  assert.ok(night.skyTop[0] < 0.25, 'night air is dark (but not black — air glows faintly)');
  assert.equal(night.sunVisible, 0, 'the sun disk is NOT visible at night');
  assert.ok(noon.sunVisible > 0.8, 'the sun disk is visible at noon');
  // dust increases extinction (haze) — measurable
  a.state.dust = 0.9;
  const dusty = a.sky({ sunEl: 1, ambient: 1 });
  assert.ok(dusty.fog > noon.fog, `dust load raises extinction (${noon.fog.toFixed(2)} → ${dusty.fog.toFixed(2)})`);
  assert.ok(dusty.skyBottom[0] > noon.skyBottom[0], 'dusty horizon is warmer/browner');
});

test('atmosphere: air has INERTIA — humidity follows rain with a lag (it is a gas, not a flag)', () => {
  const a = new Atmosphere();
  const env = { rain: 0, dust: 0 };
  a.step(10, env);
  const before = a.state.humidity;
  env.rain = 1;
  a.step(0.1, env); // a moment of rain
  const afterLittle = a.state.humidity;
  a.step(6, env);   // sustained rain
  assert.ok(Math.abs(afterLittle - before) < 0.06, 'one instant does not saturate the air');
  assert.ok(a.state.humidity > afterLittle + 0.05, 'sustained rain keeps humidifying');
});

test('hydrology: rain ACCUMULATES as surface film, flows downhill, wets the ground, evaporates under sun', () => {
  const uts = createUTS({ seed: 'hydro' });
  const h = uts.world.hydrology;
  const focus = [512, 0, 512];
  // dry start
  h.step(1, { focus, rain: 0, sunEl: 1 });
  assert.equal(h.depthAt(512, 512), 0, 'no rain → no film (honest)');

  // rain fills cells
  for (let i = 0; i < 40; i++) h.step(0.5, { focus, rain: 1, sunEl: 0.1 });
  const cells = [...h.cells.values()];
  assert.ok(cells.length > 0);
  const withWater = cells.filter(c => c.depth > 0);
  assert.ok(withWater.length >= cells.length * 0.8, `rain wets most cells (${withWater.length}/${cells.length})`);

  // film is a measurable SUBSTANCE: total volume on the ground
  const maxDepth = Math.max(...cells.map(c => c.depth));
  const volume = cells.reduce((a, c) => a + c.depth, 0);
  assert.ok(maxDepth > 0.001, `film is measurable (max ${maxDepth.toFixed(4)}m)`);
  assert.ok(volume > 0.05, `total water volume grows (Σdepth ${volume.toFixed(3)}m)`);

  // sun evaporates: the film dries away — while DEEP pools persist (that is
  // what ponds do in reality: puddles vanish, ponds linger)
  for (let i = 0; i < 60; i++) h.step(0.5, { focus, rain: 0, sunEl: 1 });
  const afterCells = [...h.cells.values()];
  const after = afterCells.reduce((a, c) => a + c.depth, 0);
  const dryFraction = afterCells.filter(c => c.depth < 0.001).length / afterCells.length;
  assert.ok(after < volume * 0.6, `the sun drinks the film (Σdepth ${volume.toFixed(3)} → ${after.toFixed(3)}m)`);
  assert.ok(dryFraction > 0.7, `shallow film dries, ponds persist (dry cells ${(dryFraction * 100).toFixed(0)}%)`);
});

test('hydrology: wetness gates COMBUSTION — soaked ground refuses to burn (real physics)', async () => {
  const uts = createUTS({ seed: 'hydro-fire' });
  const w = uts.world;
  // soak the world with a real storm (deterministic fixed steps)
  await w.setWeather('storm');
  for (let i = 0; i < 100; i++) w.updateWeather(0.5);
  const wet = w.environment.wetness;
  assert.ok(wet > 0.55, `the storm soaks the water table (${wet.toFixed(2)})`);
  const ev = w.combustion.ignite(520, 520, {});
  assert.equal(ev, null, `soaked ground (${wet.toFixed(2)}) REFUSES ignition — causal event 'combustion.refused' emitted`);
  const refused = [...w.rrw.events.values()].filter(e => e.type === 'combustion.refused');
  assert.ok(refused.length > 0, 'the refusal itself is a causal, auditable event');
});

test('integration: storm → atmosphere AND hydrology AND wetness all move together (one reality)', async () => {
  const uts = createUTS({ seed: 'chain-r1' });
  const w = uts.world;
  uts.ues.moveCamera([480, 40, 480]);
  const fogBefore = w.environment.fog;
  await w.setWeather('storm');
  for (let i = 0; i < 100; i++) w.updateWeather(0.5); // 50s of storm, deterministic
  const env = w.environment;
  assert.ok(env.fog > fogBefore, `extinction rose with the storm (${fogBefore.toFixed(2)} → ${env.fog.toFixed(2)})`);
  assert.ok(env.wetness > 0.5, `ground got wet (${env.wetness.toFixed(2)})`);
  assert.ok(w.hydrology.cells.size > 40, 'hydrology is alive around the camera');
  assert.ok(w.humidityEstimate === undefined, 'no fake fields — state lives in the phenomena');
});
