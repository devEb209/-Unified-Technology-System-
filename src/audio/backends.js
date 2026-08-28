// UTS :: audio/backends — OUR audio device layer (the inevitable boundary).
//
//   AudioStream (ours) → AudioDevice contract (ours) → the physical output
//
// The DEVICE is the one external inevitability (speakers/OS/browser audio).
// Everything above it — queueing, pacing, underrun accounting, resampling —
// is ours. Three devices, one contract:
//
//   MemoryDevice    dev/tests: stores chunks, validates, measures.
//   NodePacerDevice node real-time: paces writes against a clock (injectable,
//                   deterministic in tests), counts underruns/latency.
//   WebAudioDevice  browser: OUR gapless scheduler feeding AudioBufferSource-
//                   Nodes; own linear resampler when the context rate differs.
//                   Constructed lazily in the browser only — core never
//                   imports window.

export class AudioDeviceError extends Error {}

export const AUDIO_DEVICE_CONTRACT = [
  'open({sr, channels})',   // acquire the device; must precede writes
  'write({left,right,sr})', // one stream chunk; may be async (pacer)
  'close()',                // release; stats stay readable
  'stats',                  // { written, chunks, underruns, dropped, latencyMs }
];

export function resample(samples, fromSr, toSr) {
  if (fromSr === toSr) return samples;
  const ratio = fromSr / toSr;
  const n = Math.max(1, Math.round(samples.length / ratio));
  const out = new Float32Array(n);
  for (let i = 0; i < n; i++) {
    const x = i * ratio;
    const j = Math.floor(x);
    const frac = x - j;
    const a = samples[j] ?? samples[samples.length - 1] ?? 0;
    const b = samples[j + 1] ?? a;
    out[i] = a + (b - a) * frac; // OUR linear interpolation
  }
  return out;
}

function newStats() { return { written: 0, chunks: 0, underruns: 0, dropped: 0, latencyMs: 0 }; }

// ------------------------------------------------------------------ memory
export class MemoryDevice {
  constructor() { this.stats = newStats(); }
  open({ sr = 22050, channels = 2 } = {}) {
    this.sr = sr; this.channels = channels; this.chunks = [];
    this.opened = true; this.stats = newStats();
    return this;
  }
  write(chunk) {
    if (!this.opened) throw new AudioDeviceError('device not open');
    if (chunk.sr !== this.sr) throw new AudioDeviceError(`sample rate mismatch: chunk ${chunk.sr} != device ${this.sr}`);
    this.chunks.push({ left: Float32Array.from(chunk.left), right: Float32Array.from(chunk.right), sr: chunk.sr });
    this.stats.chunks++;
    this.stats.written += chunk.left.length;
    return this;
  }
  close() { this.opened = false; return this; }
  /** concatenate every chunk into one continuous buffer */
  concat() {
    const n = this.chunks.reduce((s, c) => s + c.left.length, 0);
    const left = new Float32Array(n), right = new Float32Array(n);
    let off = 0;
    for (const c of this.chunks) { left.set(c.left, off); right.set(c.right, off); off += c.left.length; }
    return { left, right, sr: this.sr };
  }
}

// ------------------------------------------------------------------- pacer
const pacerNow = () => (typeof performance !== 'undefined' && performance.now) ? performance.now() : Date.now();
const sleep = (ms) => new Promise(r => setTimeout(r, Math.max(0, ms)));

/** Node real-time sink: write() awaits the moment the audio would be heard.
 *  Late writes are counted as underruns (the measurable heartbeat of the
 *  audio pipeline). With an injected fake clock it is fully deterministic. */
export class NodePacerDevice {
  constructor({ now = pacerNow, toleranceMs = 6 } = {}) {
    this.now = now; this.toleranceMs = toleranceMs; this.stats = newStats();
  }
  open({ sr = 22050 } = {}) {
    this.sr = sr; this._written = 0; this._t0 = null;
    this.stats = newStats(); this.opened = true;
    return this;
  }
  async write(chunk) {
    if (!this.opened) throw new AudioDeviceError('device not open');
    if (chunk.sr !== this.sr) throw new AudioDeviceError(`sample rate mismatch: chunk ${chunk.sr} != device ${this.sr}`);
    if (this._t0 == null) this._t0 = this.now();
    const dueMs = this._t0 + (this._written / this.sr) * 1000; // when the first sample is due
    const earlyMs = dueMs - this.now();
    if (earlyMs > 0) await sleep(earlyMs);
    const lateMs = this.now() - dueMs;
    this.stats.latencyMs = lateMs;
    if (lateMs > this.toleranceMs) this.stats.underruns++;
    this._written += chunk.left.length;
    this.stats.chunks++;
    this.stats.written += chunk.left.length;
    return this;
  }
  close() { this.opened = false; return this; }
}

// ---------------------------------------------------------------- webaudio
/** Browser device: OUR gapless scheduler. AudioContext is the hardware
 *  boundary; scheduling, underrun detection and resampling are ours. */
export class WebAudioDevice {
  constructor(ctx) {
    if (!ctx || typeof ctx.createBuffer !== 'function') {
      throw new AudioDeviceError('WebAudioDevice needs an AudioContext (browser only)');
    }
    this.ctx = ctx; this.stats = newStats();
  }
  open() {
    this.deviceSr = this.ctx.sampleRate;
    this._nextTime = null; this._sources = new Set();
    this.stats = newStats(); this.opened = true;
    return this;
  }
  write(chunk) {
    if (!this.opened) throw new AudioDeviceError('device not open');
    const left = resample(chunk.left, chunk.sr, this.deviceSr);
    const right = resample(chunk.right, chunk.sr, this.deviceSr);
    const buf = this.ctx.createBuffer(2, left.length, this.deviceSr);
    buf.getChannelData(0).set(left);
    buf.getChannelData(1).set(right);
    const src = this.ctx.createBufferSource();
    src.buffer = buf;
    src.connect(this.ctx.destination);
    const now = this.ctx.currentTime;
    if (this._nextTime == null || this._nextTime < now) {
      if (this._nextTime != null && now - this._nextTime > 0.005) this.stats.underruns++; // scheduling gap
      this._nextTime = now + 0.03; // start with a small lead
    }
    src.start(this._nextTime);
    this._nextTime += left.length / this.deviceSr;
    this._sources.add(src);
    src.onended = () => this._sources.delete(src);
    this.stats.chunks++;
    this.stats.written += left.length;
    return this;
  }
  close() {
    for (const src of this._sources) { try { src.stop(); } catch { /* already ended */ } }
    this._sources.clear(); this.opened = false; return this;
  }
}

/** factory — kind: 'memory' | 'pacer' | 'webaudio' */
export function createDevice(kind, arg = null) {
  switch (kind) {
    case 'memory': return new MemoryDevice();
    case 'pacer': return new NodePacerDevice(arg ?? {});
    case 'webaudio': return new WebAudioDevice(arg);
    default: throw new AudioDeviceError(`unknown device kind: ${kind}`);
  }
}
