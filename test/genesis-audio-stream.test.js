// UTS :: test/genesis-audio-stream — the CONTINUOUS audio system end-to-end:
// real-time stream (no seams, no clicks), device contract, deterministic
// scheduling, D-O15 governance, and honest playback (pacer + WebAudio).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createUTS } from '../src/index.js';
import { AudioDirector } from '../src/audio/uts-audio.js';
import { AudioStream } from '../src/audio/stream.js';
import {
  AudioDeviceError, MemoryDevice, NodePacerDevice, WebAudioDevice,
  createDevice, resample,
} from '../src/audio/backends.js';

const WIND_FRAME = (tick = 1) => ({
  tick,
  camera: { pos: [0, 0, 0], yaw: 0 },
  audio: { ambience: 'wind', oneShots: [] },
  lights: { points: [] },
  environment: { wind: 0.6, rain: 0, dust: 0.3 },
});

const STORM_FRAME = (tick = 1) => ({
  tick,
  camera: { pos: [0, 0, 0], yaw: 0 },
  audio: { ambience: 'storm', oneShots: [{ name: 'thunder' }] },
  lights: { points: [] },
  environment: { wind: 0.9, rain: 1, dust: 0 },
});

const FIRE_FRAME = (tick, pos = [4, 0, 0], sourceId = 'fire-1') => ({
  tick,
  camera: { pos: [0, 0, 0], yaw: 0 },
  audio: { ambience: null, oneShots: [] },
  lights: { points: [{ kind: 'fire', pos, color: [1, 0.6, 0.2], intensity: 1, radius: 30, sourceId }] },
  environment: { wind: 0, rain: 0, dust: 0 },
});

test('devices: the contract is loud — open before write, SR must match, stats are exact', () => {
  const dev = createDevice('memory');
  assert.throws(() => dev.write({ left: new Float32Array(4), right: new Float32Array(4), sr: 22050 }), AudioDeviceError);
  dev.open({ sr: 22050 });
  assert.throws(() => dev.write({ left: new Float32Array(4), right: new Float32Array(4), sr: 44100 }), /sample rate mismatch/);
  const a = new Float32Array(2205).fill(0.25); // exact in float32
  dev.write({ left: a, right: a, sr: 22050 });
  dev.write({ left: a, right: a, sr: 22050 });
  assert.equal(dev.stats.chunks, 2);
  assert.equal(dev.stats.written, 4410);
  const cat = dev.concat();
  assert.equal(cat.left.length, 4410);
  assert.equal(cat.left[0], 0.25);
  assert.equal(cat.left[2205], 0.25, 'chunks concatenate seamlessly');
  assert.throws(() => createDevice('magic'), /unknown device/);
  dev.close();
});

test('stream: continuous ambience — chunk seams are smooth (no clicks) and the timeline never lies', () => {
  const uts = createUTS({ seed: 'stream-seam' });
  const dir = new AudioDirector({ tese: uts.tese, do15: uts.do15 });
  const stream = dir.openStream();
  let prevLast = null;
  let expectedFrom = 0;
  for (let i = 0; i < 20; i++) {
    const chunk = dir.pumpStream(WIND_FRAME(i + 1), { seconds: 0.1 });
    assert.ok(Math.abs(chunk.from - expectedFrom) < 1e-9, `timeline contiguous at chunk ${i}`);
    expectedFrom = chunk.to;
    if (prevLast != null) {
      const jump = Math.abs(chunk.left[0] - prevLast);
      assert.ok(jump < 0.12, `seam ${i}: |Δ| = ${jump.toFixed(4)} must be inaudible (<0.12)`);
    }
    prevLast = chunk.left[chunk.left.length - 1];
  }
  assert.equal(uts.tese.effect('D-11').count >= 20, true, 'D-11 touched per pump');
  assert.ok(stream.stats.seconds >= 2, 'stream accounted seconds');
});

test('stream: thunder fires ONCE per rumble (temporal lockout), measured in isolation', () => {
  const uts = createUTS({ seed: 'thunder-lock' });
  const dir = new AudioDirector({ tese: uts.tese, do15: uts.do15 });
  dir.openStream();
  const rms = (c) => Math.sqrt(c.left.reduce((s, v) => s + v * v, 0) / c.left.length);
  const F = (tick, clap) => ({
    tick, camera: { pos: [0, 0, 0], yaw: 0 },
    audio: { ambience: null, oneShots: clap ? [{ name: 'thunder' }] : [] },
    lights: { points: [] }, environment: {},
  });
  // clap 1: audible immediately, tail follows
  const c0 = dir.pumpStream(F(1, true), { seconds: 0.1 });
  const c1 = dir.pumpStream(F(2, true), { seconds: 0.1 });
  assert.ok(rms(c0) > 0.015, `thunder audible (rms=${rms(c0).toFixed(4)})`);
  assert.ok(rms(c1) > 0.003, 'tail continues (voice survives the chunk boundary)');
  // storm keeps flashing for 2.0s more (frames with clap): the lockout
  // suppresses every re-attack. From t>=1.7s the legitimate tail (tau 0.55)
  // has decayed below ~0.006 — any sound there would be a forbidden re-clap.
  let attacked = false;
  for (let i = 2; i < 22; i++) {
    const c = dir.pumpStream(F(2 + i, true), { seconds: 0.1 });
    if (i >= 17 && rms(c) > 0.008) attacked = true;
  }
  assert.equal(attacked, false, 'no re-clap inside the lockout window (tail already decayed)');
  // after the lockout, a new flash CAN rumble again
  const again = dir.pumpStream(F(30, true), { seconds: 0.1 });
  assert.ok(rms(again) > 0.015, 'thunder rumbles again after lockout');
});

test('stream: fire crackle loops while the light exists and obeys the spatializer', () => {
  const uts = createUTS({ seed: 'fire-loop' });
  const dir = new AudioDirector({ tese: uts.tese, do15: uts.do15 });
  dir.openStream();
  for (let i = 0; i < 40; i++) { // 4s → at least 3 crackle loops of 1.15s
    dir.pumpStream(FIRE_FRAME(i + 1), { seconds: 0.1 });
  }
  assert.ok(dir.stream._crackleLoop.get('fire-1') >= 3,
    `crackle re-scheduled while fire lives (loops=${dir.stream._crackleLoop.get('fire-1')})`);
  // far away fire (>160u) is NOT audible: no voices beyond ambience
  const dir2 = new AudioDirector({});
  dir2.openStream();
  let heard = 0;
  for (let i = 0; i < 10; i++) {
    const c = dir2.pumpStream(FIRE_FRAME(i + 1, [500, 0, 500], 'far'), { seconds: 0.1 });
    heard += c.voices;
  }
  assert.equal(heard, 0, 'distant fire is silent (honest spatialization)');
});

test('stream: deterministic — same seed + same frames = identical samples; snapshot/restore continues identically', () => {
  const mk = () => {
    const d = new AudioDirector({});
    d.openStream({ seed: 'det' });
    return d;
  };
  // reference: 10 chunks, snapshot, 5 more
  const ref = mk();
  const refHead = [];
  for (let i = 0; i < 10; i++) refHead.push(ref.pumpStream(STORM_FRAME(i + 1), { seconds: 0.1 }));
  const snap = ref.stream.snapshot();
  const refTail = [];
  for (let i = 10; i < 15; i++) refTail.push(ref.pumpStream(STORM_FRAME(i + 1), { seconds: 0.1 }));

  // twin run: no restore → identical bytes chunk-by-chunk
  const twin = mk();
  for (let i = 0; i < 10; i++) {
    const a = twin.pumpStream(STORM_FRAME(i + 1), { seconds: 0.1 });
    assert.deepEqual([...a.left], [...refHead[i].left], `chunk ${i} identical`);
  }
  // restored run: restore at the snapshot boundary → identical continuation
  const rst = mk();
  for (let i = 0; i < 10; i++) rst.pumpStream(STORM_FRAME(i + 1), { seconds: 0.1 });
  rst.stream.restore(snap);
  for (let i = 0; i < 5; i++) {
    const got = rst.pumpStream(STORM_FRAME(11 + i), { seconds: 0.1 });
    assert.deepEqual([...got.left], [...refTail[i].left], `post-restore chunk ${i} identical`);
    assert.deepEqual([...got.right], [...refTail[i].right]);
  }
});

test('pacer: real-time pacing measured — late writes are underruns, the device never lies', async () => {
  let clock = 0;
  const dev = new NodePacerDevice({ now: () => clock, toleranceMs: 6 });
  dev.open({ sr: 22050 });
  const half = new Float32Array(1102).fill(0.05); // 0.05s
  await dev.write({ left: half, right: half, sr: 22050 }); // due at t0=0 → on time
  clock = 200; // 150ms after the second chunk was due (50ms)
  await dev.write({ left: half, right: half, sr: 22050 });
  assert.equal(dev.stats.underruns, 1, 'late write counted as underrun');
  assert.ok(dev.stats.latencyMs > 100, `latency recorded (${dev.stats.latencyMs.toFixed(0)}ms)`);
  clock = 205; // still past every due moment — the device keeps counting honestly
  await dev.write({ left: half, right: half, sr: 22050 });
  assert.equal(dev.stats.underruns, 2, 'still starved → still counted');
  assert.equal(dev.stats.written, 3306);
  dev.close();
  await assert.rejects(() => dev.write({ left: half, right: half, sr: 22050 }), AudioDeviceError);
});

test('webaudio: OUR scheduler queues gapless buffers, resamples natively, counts underruns', () => {
  const starts = [];
  let now = 0;
  const makeCtx = () => ({
    sampleRate: 44100,
    currentTime: now,
    createBuffer: (ch, n) => ({ channels: Array.from({ length: ch }, () => new Float32Array(n)) }),
    getChannelDataSide: null,
    destination: 'DEST',
    createBufferSource: () => {
      const src = { connect() {}, start: (t) => starts.push(t), stop() {}, onended: null, buffer: null };
      return src;
    },
  });
  const ctx = makeCtx();
  ctx.createBuffer = (ch, n, sr) => ({
    length: n, sampleRate: sr,
    getChannelData: (c) => (ctx._data ??= { 0: new Float32Array(n), 1: new Float32Array(n) })[c],
  });
  const dev = new WebAudioDevice(ctx);
  assert.throws(() => new WebAudioDevice({}), AudioDeviceError);
  dev.open();
  assert.equal(dev.deviceSr, 44100);
  const tenth = new Float32Array(2205).fill(0.2); // 0.1s @ 22050 → same seconds @ 44100
  dev.write({ left: tenth, right: tenth, sr: 22050 });
  const len0 = Math.round(2205 * (44100 / 22050));
  assert.equal(dev.stats.written, len0, 'resampled length (native linear interpolation)');
  dev.write({ left: tenth, right: tenth, sr: 22050 });
  assert.equal(starts.length, 2);
  const gap = starts[1] - starts[0];
  assert.ok(Math.abs(gap - 0.1) < 0.001, `scheduled gapless (Δ=${gap.toFixed(4)}s)`);
  ctx.currentTime = starts[1] + 0.5; // the queue starved (mutate the CONTEXT clock)
  dev.write({ left: tenth, right: tenth, sr: 22050 });
  assert.equal(dev.stats.underruns, 1, 'starved queue = underrun (measured)');
  dev.close();
  assert.equal(dev.opened, false);
});

test('D-O15: pressure changes the audio strategy — SR drops stepwise and recovers (measured)', () => {
  const uts = createUTS({ seed: 'audio-do15' });
  const dir = new AudioDirector({ tese: uts.tese, do15: uts.do15 });
  dir.openStream();
  const c1 = dir.pumpStream(WIND_FRAME(1), { seconds: 0.1 });
  assert.equal(c1.sr, 22050, 'full strategy = 22050Hz');
  for (let i = 0; i < 5; i++) uts.do15.report({ frameMs: 40, simMs: 40 }); // p≈0.83 → high
  assert.equal(uts.do15.strategy.audioSr, 16000);
  const c2 = dir.pumpStream(WIND_FRAME(2), { seconds: 0.1 });
  assert.equal(c2.sr, 16000, 'next chunk honors the new rate');
  for (let i = 0; i < 4; i++) uts.do15.report({ frameMs: 40, simMs: 40 }); // p≈0.94 → extreme
  assert.equal(uts.do15.strategy.audioSr, 11025);
  assert.equal(uts.do15.strategy.audioVoices, 3, 'voice cap shrinks to 3');
  const c3 = dir.pumpStream(WIND_FRAME(3), { seconds: 0.1 });
  assert.equal(c3.sr, 11025, 'extreme → coarse audio');
  for (let i = 0; i < 12; i++) uts.do15.report({ frameMs: 0, simMs: 0 }); // relief
  assert.equal(uts.do15.strategy.audioSr, 22050, 'recovers when the pressure is gone');
  const c4 = dir.pumpStream(WIND_FRAME(4), { seconds: 0.1 });
  assert.equal(c4.sr, 22050);
  assert.equal(dir.stream.stats.srChanges, 3, 'every rate change is measured');
});

test('integration: UTS storm → continuous stream → WAV — the world is AUDIBLE end-to-end', async () => {
  const boot = async () => {
    const uts = createUTS({ seed: 'audible' });
    await uts.world.setWeather('storm'); // causal chain: weather → flash → thunder (D-5 → D-2)
    uts.ues.run(30);
    return uts;
  };
  const withClap = await boot();
  withClap.world.strikeLightning(withClap.ues.camera.pos); // real causal lightning strike
  const dir = new AudioDirector({ tese: withClap.tese, do15: withClap.do15 });
  const dev = createDevice('memory').open({ sr: withClap.do15.strategy.audioSr });
  const frame = withClap.ues.renderFrame();
  assert.ok(frame.audio.oneShots.some(s => s.name === 'thunder'), 'strike → thunder in the represented Frame');
  for (let i = 0; i < 30; i++) dir.pumpStream(frame, { seconds: 0.1, device: dev });
  const { left, right, sr } = dev.concat();
  assert.equal(sr, withClap.do15.strategy.audioSr);
  const rms = (x) => Math.sqrt(x.reduce((s, v) => s + v * v, 0) / x.length);
  assert.ok(rms(left) > 0.02, `storm bed audible (rms=${rms(left).toFixed(3)})`);

  // the SAME world without the strike must be strictly quieter at the start
  const withoutClap = await boot();
  const dir2 = new AudioDirector({ tese: withoutClap.tese, do15: withoutClap.do15 });
  const dev2 = createDevice('memory').open({ sr: withoutClap.do15.strategy.audioSr });
  const frame2 = withoutClap.ues.renderFrame();
  assert.equal(frame2.audio.oneShots.some(s => s.name === 'thunder'), false);
  for (let i = 0; i < 3; i++) dir2.pumpStream(frame2, { seconds: 0.1, device: dev2 });
  const cat2 = dev2.concat();
  const head = rms(left.slice(0, cat2.left.length));
  assert.ok(head > rms(cat2.left) * 1.1, `strike makes the beginning louder (${head.toFixed(3)} vs ${rms(cat2.left).toFixed(3)})`);

  const { encodeWav } = await import('../src/audio/uts-audio.js');
  const wav = encodeWav({ left, right, sr });
  assert.equal(wav.length, 44 + left.length * 4, 'RIFF 16-bit stereo bytes');
  assert.equal(wav.readUInt32LE(24), sr);
});
