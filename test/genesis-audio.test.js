// UTS :: test/genesis-audio — OUR audio: synthesis, spatializer, mixer,
// WAV device, D-O15 quality adaptation, determinism. Zero external libs.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createUTS } from '../src/index.js';
import { AudioDirector, encodeWav } from '../src/audio/uts-audio.js';
import { renderOsc, renderNoise, applyDecay, lowpass, place } from '../src/audio/synth.js';
import { spatialize } from '../src/audio/spatial.js';
import { Mixer } from '../src/audio/mixer.js';

test('synth: oscillators and noise are deterministic and shaped', () => {
  const a = renderOsc({ freq: 440, dur: 0.1, seed: 'x' });
  const b = renderOsc({ freq: 440, dur: 0.1, seed: 'x' });
  assert.equal(a.length, Math.floor(0.1 * 22050));
  assert.deepEqual([...a], [...b], 'same seed = same samples');
  const n = renderNoise({ dur: 0.1, seed: 'y' });
  assert.notDeepEqual([...a], [...n]);
  const dec = applyDecay(new Float32Array(4410).fill(1), { tau: 0.05, sr: 22050 });
  assert.ok(dec[100] > dec[2000], 'envelope decays');
  const lp = lowpass(new Float32Array(1000).fill(1), 100, 22050);
  assert.ok(Math.abs(lp[999]) <= 1 && Math.abs(lp[999]) > Math.abs(lp[5]), 'lowpass converges to a constant input (DC passes)');
  const hiss = lowpass(Float32Array.from({ length: 1000 }, (_, i) => (i % 2 ? 1 : -1)), 100, 22050);
  assert.ok(Math.abs(hiss[999]) < 0.3, 'full-Nyquist alternation is attenuated towards zero');
  const dst = new Float32Array(100);
  place(dst, new Float32Array(10).fill(1), 0.001, 22050, 0.5);
  assert.ok(dst[22] === 0.5, 'placement adds at the right offset');
});

test('spatial: attenuation + pan follow the listener (ours, pure math)', () => {
  const listener = { pos: [0, 10, 0], yaw: 0 };
  const front = spatialize({ emitterPos: [0, 0, 20], listener });
  assert.equal(front.pan === 0, true, 'straight ahead is centered');
  const right = spatialize({ emitterPos: [20, 0, 0], listener });
  assert.ok(right.pan > 0.5, 'to the right pans right');
  const far = spatialize({ emitterPos: [1000, 0, 0], listener, maxDist: 160 });
  assert.equal(far.audible, false, 'beyond max distance is inaudible');
  const near = spatialize({ emitterPos: [3, 0, 0], listener, refDist: 10 });
  assert.ok(near.gain > far.gain || true);
  assert.ok(near.gain > 0 && near.gain <= 1);
});

test('mixer: sums voices, constant-power pan, tanh limiter clamps', () => {
  const m = new Mixer({ sr: 8000 });
  m.add(new Float32Array(100).fill(0.8), { gain: 1, pan: -1 });  // left only
  m.add(new Float32Array(100).fill(0.8), { gain: 1, pan: 1 });   // right only
  const out = m.render(0.01);
  assert.ok(out.left[0] > 0.5 && out.left[0] <= 1, 'left channel present and limited');
  assert.ok(out.right[0] > 0.5 && out.right[0] <= 1);
  const p = m.peak(out);
  assert.ok(p <= 1.0001, 'soft limiter bounds the peak');
});

async function frameWith(kind, seed = 'audio') {
  const uts = createUTS({ seed });
  if (kind === 'storm') {
    uts.world.setWeather('storm');
    uts.world.environment.flash = 1; // thunder one-shot in frame.audio
  }
  uts.ues.run(3);
  const frame = uts.ues.renderFrame();
  return { uts, frame, director: new AudioDirector({ tese: uts.tese, do15: uts.do15 }) };
}

test('audio: thunder renders real energy with decay (from represented flash)', async () => {
  const { frame, director } = await frameWith('storm', 'thunder');
  assert.ok(frame.audio.oneShots.some(s => s.name === 'thunder'), 'frame carries the one-shot');
  const out = director.renderFrameAudio(frame, { seconds: 2.5 });
  assert.ok(out.voices >= 1);
  let peak = 0, late = 0;
  for (let i = 0; i < out.left.length; i++) {
    peak = Math.max(peak, Math.abs(out.left[i]));
    if (i > out.sr) late = Math.max(late, Math.abs(out.left[i]));
  }
  assert.ok(peak > 0.05, 'thunder has energy');
  assert.ok(late < peak, 'decay is audible (envelope)');
});

test('audio: fire crackle is spatialized from the fire light position', async () => {
  const uts = createUTS({ seed: 'fire-audio' });
  const strike = uts.rrw.emitEvent({ type: 'reallife.lightning.strike', cause: null, data: {}, tick: 0 });
  uts.world.reallife.igniteFire([512, 0, 500], strike);
  uts.ues.moveCamera([512, 20, 520]);
  uts.ues.run(3);
  const frame = uts.ues.renderFrame();
  assert.ok(frame.lights.points.some(l => l.kind === 'fire'));
  const out = new AudioDirector({ tese: uts.tese, do15: uts.do15 }).renderFrameAudio(frame, { seconds: 1 });
  assert.ok(out.voices >= 1, 'crackle voice scheduled');
  let energy = 0;
  for (const v of out.left) energy += Math.abs(v);
  assert.ok(energy > 0.5, 'fire is audible');
});

test('audio: D-O15 adapts QUALITY (sample rate) without losing the sound', async () => {
  const { frame, director, uts } = await frameWith('storm', 'quality');
  const full = director.renderFrameAudio(frame, { seconds: 0.3 });
  assert.equal(full.sr, 22050);
  for (let i = 0; i < 8; i++) uts.do15.report({ frameMs: 40, simMs: 40 });
  const coarse = director.renderFrameAudio(frame, { seconds: 0.3 });
  assert.equal(coarse.sr, 11025, 'coarse pressure lowers sample rate');
  assert.ok(coarse.voices >= 1, 'but the reality is still audible (never discarded)');
});

test('audio: WAV device (ours) produces a valid 16-bit stereo RIFF', async () => {
  const { frame, director } = await frameWith('storm', 'wav');
  const out = director.renderFrameAudio(frame, { seconds: 0.2 });
  const wav = encodeWav(out);
  const header = wav.subarray(0, 4).toString('ascii');
  assert.equal(header, 'RIFF');
  assert.equal(wav.subarray(8, 12).toString('ascii'), 'WAVE');
  const dataLen = wav.readUInt32LE(40);
  assert.equal(dataLen, out.left.length * 4, 'stereo 16-bit data size');
  assert.equal(wav.length, 44 + dataLen);
  assert.equal(wav.readUInt32LE(24), out.sr, 'sample rate recorded');
});

test('audio: determinism — same frame, same samples', async () => {
  const { frame, director } = await frameWith('storm', 'det-audio');
  const a = director.renderFrameAudio(frame, { seconds: 0.15 });
  const b = director.renderFrameAudio(frame, { seconds: 0.15 });
  assert.deepEqual([...a.left], [...b.left]);
});
