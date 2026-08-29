// UTS :: test/r4-representation — D-O15 RE-REPRESENTATION closed under ADR-019.
// Muffle is a REAL filter (not a guess); ash fades with TIME; under pressure
// precipitation is re-represented as fewer/faster/bigger streaks — the
// PERCEIVED intensity survives, the particle count is not the reality.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createUTS, WebGL2Renderer } from '../src/index.js';
import { makeGL } from './helpers/mock-gl.js';
import { AudioDirector } from '../src/audio/uts-audio.js';

function zeroCrossings(samples) {
  let z = 0;
  for (let i = 1; i < samples.length; i++) if ((samples[i] >= 0) !== (samples[i - 1] >= 0)) z++;
  return z / samples.length;
}

test('ash: burnt ground is MATERIALIZED (real field state) and fades with its age', () => {
  const uts = createUTS({ seed: 'ash' });
  const w = uts.world;
  uts.ues.moveCamera([512, 30, 512]);
  // burn a cell out honestly: ignite dry grass, then let the storm kill it
  const spot = (() => {
    for (let x = 440; x <= 600; x += 8) for (let z = 440; z <= 600; z += 8) {
      const c = w.combustion._cell(x, z);
      if (c && c.fuel >= 0.4 && w.terrain.height(x, z) > w.terrain.seaLevel) return [x, z];
    }
    return null;
  })();
  assert.ok(spot, 'burnable ground near camera');
  w.combustion.ignite(spot[0], spot[1], {});
  const cell = w.combustion.cells.get(w.combustion._key(spot[0], spot[1]));
  cell.fuel = 0.01; // the fire eats the last of it this step
  w.combustion.step(0.5, { rain: 0, wind: 0 });
  assert.equal(cell.burning, false, 'the fire consumed its fuel and died');
  assert.equal(cell.burnt, true, 'the scar persists');
  const frame = uts.ues.renderFrame();
  const scar = frame.burntGround.find(b => Math.abs(b.pos[0] - spot[0]) < 30 && Math.abs(b.pos[2] - spot[1]) < 30);
  assert.ok(scar, 'the burn scar is materialized for the renderer');
  assert.ok(scar.alpha > 0.9, `fresh ash is dark (${scar.alpha.toFixed(2)})`);
  // TIME passes → the ash fades (honest timescale, not a permanent decal)
  cell.burntAt = w.clock.tick - 2500;
  const aged = w.combustion.burntNear([spot[0], 0, spot[1]], 100);
  assert.ok(aged[0].alpha < 0.25, `old ash has faded (${aged[0].alpha.toFixed(2)})`);
});

test('muffle: a shadowed arrival is spectrally DULLER (real filter, not just quieter)', async () => {
  const uts = createUTS({ seed: 'muffle' });
  const director = new AudioDirector({ tese: uts.tese, do15: uts.do15 });
  const cam = { pos: [512, 26, 512], yaw: 0 };
  const base = {
    camera: cam, tick: 0, time: 0,
    environment: { rain: 0, wind: 0.2, fog: 0.1, wetness: 0, skyTop: [0.2, 0.3, 0.6], skyBottom: [0.5, 0.6, 0.8] },
    lights: { points: [], sun: { dir: [0.5, 0.8, 0.3], color: [1, 0.95, 0.8], ambient: 1, castShadow: false } },
    stats: { particles: 1 },
    terrain: { seaLevel: null },
  };
  const near = { ...base, audio: { ambience: null, oneShots: [{ name: 'thunder', pos: [532, 0, 512], power: 1, acoustic: { gain: 0.9, muffle: 1.1, delay: 0.06, occlusion: 0, dist: 20, audible: true } }] } };
  const dull = { ...base, audio: { ambience: null, oneShots: [{ name: 'thunder', pos: [812, 0, 512], power: 1, acoustic: { gain: 0.2, muffle: 3.4, delay: 0.88, occlusion: 0.6, dist: 300, audible: true } }] } };
  const a = director.renderFrameAudio(near, { seconds: 2.5 });
  const b = director.renderFrameAudio(dull, { seconds: 2.5 });
  const zcA = zeroCrossings(a.left), zcB = zeroCrossings(b.left);
  assert.ok(zcB < zcA, `the shadowed rumble has fewer HF crossings (${zcB.toFixed(4)} < ${zcA.toFixed(4)})`);
  assert.ok(b.voices >= 1 && a.voices >= 1, 'both arrive (re-presented, not dropped)');
});

test('particles: under D-O15 pressure rain is RE-REPRESENTED (fewer, faster, bigger streaks)', async () => {
  const uts = createUTS({ seed: 'rain-pressure' });
  uts.ues.run(3);
  uts.world.setWeather('rain');
  uts.world.environment.rain = 1;
  const frame = uts.ues.renderFrame();
  frame.stats.particles = 0.25; // D-O15 measured pressure
  const gl = makeGL();
  const r = new WebGL2Renderer(gl);
  r.init();
  r.render(frame);
  const u = Object.fromEntries(gl._calls.filter(c => c[0] === 'uniform1f').map(c => [c[1], c[2]]));
  assert.ok(u.uCount <= 125 + 1e-6, `count follows the pressure budget (${u.uCount})`);
  assert.ok(u.uSize > 4.0, `each streak is BIGGER (perceived intensity preserved: ${u.uSize?.toFixed(2)})`);
  assert.ok(u.uFall > 1.5, `streaks fall FASTER (${u.uFall?.toFixed(2)}) — sheets, not drizzle`);
});

test('scale pass: film + burnt + horizon share ONE honest draw', async () => {
  const uts = createUTS({ seed: 'one-pass' });
  const w = uts.world;
  uts.ues.moveCamera([512, 30, 512]);
  w.hydrology.cells.set('21,21', { depth: 0.03, flow: 0 });
  const cell = w.combustion.cells.get(w.combustion._key(500, 520)) ?? w.combustion._cell(500, 520);
  if (cell && cell.fuel > 0.2) { cell.burnt = true; cell.burntAt = w.clock.tick; cell.burning = false; }
  const frame = uts.ues.renderFrame();
  const gl = makeGL();
  const r = new WebGL2Renderer(gl);
  r.init();
  r.render(frame);
  const scalePointDraws = gl._calls.filter(c => c[0] === 'drawArrays' && c[2] === frame.waterFilm.length + frame.burntGround.length + frame.horizon.length);
  assert.equal(r.stats.horizonDraws, 1, 'one scale pass');
  assert.equal(scalePointDraws.length, 1, 'film+burnt+horizon drawn together');
});
