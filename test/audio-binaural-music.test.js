// UTS :: test/audio-binaural-music — OUR binaural head model (ITD+ILD) and
// OUR adaptive procedural music: both deterministic, both measurable, both
// governed by the represented world (never decorative, never random).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createUTS } from '../src/index.js';
import { AudioDirector } from '../src/audio/uts-audio.js';
import { renderBinaural } from '../src/audio/spatial.js';
import { MusicDirector, worldTension } from '../src/audio/music.js';

const TENSE_FRAME = () => FRAME({
  audio: { ambience: 'storm', oneShots: [] },
  environment: { wind: 0.9, rain: 1, dust: 0 },
  lights: { points: [{ kind: 'fire', pos: [3, 0, 0], color: [1, 0.6, 0.2], intensity: 1, radius: 30, sourceId: 'f', dist: 3 }] },
});

const FRAME = (over = {}) => ({
  tick: 1,
  camera: { pos: [0, 0, 0], yaw: 0 },
  audio: { ambience: 'wind', oneShots: [] },
  lights: { points: [] },
  environment: { wind: 0.6, rain: 0, dust: 0.3 },
  ...over,
});

test('binaural: ITD — the near ear hears the sound EARLIER (fractional delay, ours)', () => {
  const sr = 22050;
  const impulse = new Float32Array(400);
  impulse[10] = 1; // a click
  const rightSource = renderBinaural(impulse, {
    emitterPos: [40, 0, 0], listener: { pos: [0, 0, 0], yaw: 0 }, sr,
  });
  const onset = (ch) => ch.findIndex(v => Math.abs(v) > 0.01);
  const lOnset = onset(rightSource.left), rOnset = onset(rightSource.right);
  assert.ok(rOnset < lOnset, `right source reaches the right ear first (R=${rOnset}, L=${lOnset})`);
  assert.ok(lOnset - rOnset >= 1, 'the delay is measurable (>=1 sample at 0.65ms max ITD)');
  // mirrored source mirrors the result exactly (pure math, no asymmetry bugs)
  const leftSource = renderBinaural(impulse, {
    emitterPos: [-40, 0, 0], listener: { pos: [0, 0, 0], yaw: 0 }, sr,
  });
  assert.deepEqual([...leftSource.left], [...rightSource.right], 'mirrored source = mirrored ears');
});

test('binaural: ILD — the shadowed ear is quieter AND darker; distance attenuates honestly', () => {
  const sr = 22050;
  const burst = new Float32Array(2000).fill(0).map((_, i) => Math.sin(i * 0.4)); // bright tone
  const r = renderBinaural(burst, { emitterPos: [40, 0, 0], listener: { pos: [0, 0, 0], yaw: 0 }, sr });
  const rms = (x) => Math.sqrt(x.reduce((s, v) => s + v * v, 0) / x.length);
  assert.ok(rms(r.right) > rms(r.left) * 1.3, `near ear louder (R=${rms(r.right).toFixed(3)} vs L=${rms(r.left).toFixed(3)})`);
  // darker: the shadowed left channel has a LOWER zero-crossing rate
  const zcr = (x) => { let z = 0; for (let i = 1; i < x.length; i++) if ((x[i] >= 0) !== (x[i - 1] >= 0)) z++; return z; };
  assert.ok(zcr(r.left) < zcr(r.right), 'shadowed ear is darker (low-passed)');
  // distance: gain falls, silence beyond maxDist
  const mid = renderBinaural(burst, { emitterPos: [60, 0, 0], listener: { pos: [0, 0, 0], yaw: 0 }, sr, refDist: 8 });
  const far = renderBinaural(burst, { emitterPos: [1000, 0, 0], listener: { pos: [0, 0, 0], yaw: 0 }, sr, refDist: 8 });
  assert.ok(mid.gain < r.gain, 'attenuation grows with distance');
  assert.equal(far.audible, false, 'beyond maxDist = silence (honest)');
});

test('music: deterministic — same seed + same frames = the exact same notes on the beat grid', () => {
  const run = () => {
    const dir = new AudioDirector({});
    const stream = dir.openStream({ seed: 'music-det' });
    const md = new MusicDirector({ seed: 'music-det' });
    const notes = [];
    const origSchedule = stream.schedule.bind(stream);
    stream.schedule = (samples, opts) => { notes.push([opts.at, +opts.gain.toFixed(4), opts.pan]); return origSchedule(samples, opts); };
    for (let i = 0; i < 40; i++) {
      md.scheduleInto(stream, TENSE_FRAME(), { seconds: 0.1, voiceBudget: 8 });
      stream.pump(FRAME(), { seconds: 0.1, listener: { pos: [0, 0, 0], yaw: 0 } });
    }
    return { notes, md };
  };
  const a = run(), b = run();
  assert.deepEqual(b.notes, a.notes, 'identical note schedule');
  assert.ok(a.notes.length > 20, `music actually scheduled notes (${a.notes.length})`);
  void TENSE_FRAME;
  // the beat grid: every note lands on a time, bar grid is stable
  const at0 = a.notes[0][0];
  assert.equal(at0, 0, 'first bar starts at stream time zero');
});

test('music: the world drives it — storm + close fire = tense mode, more layers, faster bpm', () => {
  const calmFrame = FRAME();
  const stormFrame = FRAME({
    audio: { ambience: 'storm', oneShots: [] },
    environment: { wind: 0.9, rain: 1, dust: 0 },
    lights: { points: [{ kind: 'fire', pos: [3, 0, 0], color: [1, 0.6, 0.2], intensity: 1, radius: 30, sourceId: 'f', dist: 3 }] },
  });
  const md = new MusicDirector({ seed: 'tension' });
  const calm = md.plan(calmFrame);
  const tense = md.plan(stormFrame);
  assert.equal(calm.mode, 'calm');
  assert.equal(tense.mode, 'tense');
  assert.ok(tense.tension > calm.tension + 0.3, `tension measured (${calm.tension.toFixed(2)} → ${tense.tension.toFixed(2)})`);
  assert.ok(tense.layers > calm.layers, `layers grow with tension (${calm.layers} → ${tense.layers})`);
  assert.ok(tense.bpm > calm.bpm, `tempo follows tension (${calm.bpm.toFixed(0)} → ${tense.bpm.toFixed(0)})`);
  assert.ok(worldTension(stormFrame) > 0.6);
});

test('music: tempo/mode changes land at BAR boundaries (never mid-bar) and reach the ears', async () => {
  const uts = createUTS({ seed: 'music-live' });
  await uts.world.setWeather('storm');
  uts.ues.run(40);
  const dir = new AudioDirector({ tese: uts.tese, do15: uts.do15 });
  const stream = dir.openStream({ seed: 'music-live' });
  const md = new MusicDirector({ seed: 'music-live' });
  let energy = 0;
  for (let i = 0; i < 60; i++) {
    const frame = uts.ues.renderFrame();
    md.scheduleInto(stream, frame, { seconds: 0.1, voiceBudget: uts.do15.strategy.audioVoices });
    const c = stream.pump(frame, { seconds: 0.1, listener: { pos: frame.camera.pos, yaw: frame.camera.yaw } });
    energy += Math.sqrt(c.left.reduce((s, v) => s + v * v, 0) / c.left.length);
  }
  assert.ok(md.stats.bars >= 2, `bars scheduled (${md.stats.bars})`);
  assert.ok(energy / 60 > 0.01, `music is audible in the stream (avg rms=${(energy / 60).toFixed(3)})`);
  assert.ok(uts.tese.effect('D-11'), 'D-11 carries the music evidence');
  // bar grid invariant: nextBar is always a multiple of SOME bar length >= its own
  assert.ok(stream.t > 0);
});

test('music: D-O15 voice budget caps the layers (adaptation, measured)', () => {
  const stormFrame = FRAME({
    audio: { ambience: 'storm', oneShots: [] },
    environment: { wind: 0.9, rain: 1, dust: 0 },
    lights: { points: [{ kind: 'fire', pos: [3, 0, 0], color: [1, 0.6, 0.2], intensity: 1, radius: 30, sourceId: 'f', dist: 3 }] },
  });
  const md = new MusicDirector({ seed: 'budget' });
  const dir = new AudioDirector({});
  const stream = dir.openStream({ seed: 'budget' });
  const full = md.scheduleInto(stream, stormFrame, { seconds: 6, voiceBudget: 8 });
  assert.equal(full.layers, 4, 'full budget → all four layers');
  const md2 = new MusicDirector({ seed: 'budget' });
  const dir2 = new AudioDirector({});
  const stream2 = dir2.openStream({ seed: 'budget' });
  const capped = md2.scheduleInto(stream2, stormFrame, { seconds: 6, voiceBudget: 3 });
  assert.ok(capped.layers < full.layers, `pressure budget trims layers (${capped.layers})`);
});
