// UTS :: audio/stream — OUR continuous audio stream (D-11 real-time engine).
//
//   presentation loop → stream.pump(frame, seconds) → chunk {left,right,sr}
//   → OUR device (memory / pacer / webaudio) → the listener's ears
//
// The stream owns a CONTINUOUS timeline: ambience is generated sample-by-
// sample through persisted filter state (no chunk seams, no clicks), one-
// shots are scheduled at absolute stream times with temporal lockout, fire
// crackles loop while their light exists in the Frame. Everything is
// deterministic: the same sequence of (frame, pump) produces identical
// samples — the stream RNG is serialized in snapshot()/restore().
//
// The stream is PRESENTATION (like the renderer): it lives outside the
// deterministic simulation pipeline and never enters world snapshots.
// D-O15 governs it: sample rate (strategy.audioSr), voice cap
// (strategy.audioVoices) — measured adaptation, never random degradation.

import { RNG } from '../core/rng.js';
import { spatialize, renderBinaural } from './spatial.js';

const AMBIENCE_GAIN = { full: 0.32, reduced: 0.4, coarse: 0.5 };
// how long the ambience envelope takes to follow a change (seconds)
const AMB_TAU = 0.08;
// minimum seconds between two of the same one-shot (thunder rumble tails)
const SHOT_LOCKOUT = { thunder: 2.2 };
const FIRE_CRACKLE_DUR = 1.15;

export class AudioStream {
  constructor({ sr = 22050, seed = 'uts-audio' } = {}) {
    this.sr = sr;
    this.rng = new RNG(seed + ':stream'); // continuous phase/noise source
    this.t = 0;                            // stream timeline head (seconds)
    this.voices = [];                      // scheduled {samples, sr, gain, pan, at, end, key}
    this.ambKind = null;
    this.ambGain = 0;                      // smoothed ambience envelope
    this._lpY = 0;                         // persisted one-pole filter state (wind)
    this._lpY2 = 0;                        // second pole (rain brightness)
    this._lastShot = new Map();            // one-shot name -> last stream time
    this._crackleLoop = new Map();         // fire sourceId -> loop count
    this.synth = null;                     // voice factory (AudioDirector) — injected
    this.stats = { pumps: 0, voices: 0, seconds: 0, srChanges: 0, droppedByPressure: 0 };
  }

  setSynth(synth) { this.synth = synth; return this; }

  /** public scheduling API (music, tools, future systems): place a
   *  deterministic voice at an ABSOLUTE stream time `at` (seconds). */
  schedule(samples, { gain = 1, pan = 0, at = null, key = null } = {}) {
    if (at == null) at = this.t;
    if (at < this.t) at = this.t; // the past is gone — schedule now, honestly
    this.voices.push({ samples, sr: this.sr, gain, pan, at, end: at + samples.length / this.sr, key });
    return this;
  }

  /** D-O15 sample-rate change — timeline is in seconds, so voices survive */
  setRate(sr) {
    if (sr === this.sr) return;
    this.sr = sr;
    this.stats.srChanges++;
  }

  _ambTarget(frame, ambienceGain) {
    const kind = frame?.audio?.ambience ?? null;
    const base = kind === 'storm' ? ambienceGain * 1.5 : ambienceGain;
    return { kind, target: kind ? base : 0 };
  }

  /** generate the continuous ambience bed into left/right for n samples */
  _renderAmbience(frame, n, ambienceGain) {
    const { kind, target } = this._ambTarget(frame, ambienceGain);
    const left = new Float32Array(n);
    const right = new Float32Array(n);
    const follow = 1 - Math.exp(-(n / this.sr) / AMB_TAU);
    this.ambGain += (target - this.ambGain) * follow;

    if (kind === 'wind' || kind === 'rain' || kind === 'storm') {
      const windy = kind === 'wind';
      const a = Math.exp(-2 * Math.PI * (windy ? 380 : 1350) / this.sr);
      // wind breathes: slow amplitude LFO driven by the stream RNG order
      const lfoInc = (2 * Math.PI * (windy ? 0.13 : 0.31)) / this.sr;
      let lfo = this._ambLfo ?? 0;
      for (let i = 0; i < n; i++) {
        const w = this.rng.next() * 2 - 1;
        this._lpY = a * this._lpY + (1 - a) * w;
        this._lpY2 = a * this._lpY2 + (1 - a) * this._lpY;
        lfo += lfoInc;
        const breath = windy ? 0.72 + 0.28 * Math.sin(lfo) : 1;
        left[i] += this._lpY2 * breath * this.ambGain;
        right[i] += this._lpY * 0.97 * breath * this.ambGain;
      }
      this._ambLfo = lfo % (Math.PI * 2 * 1000);
    }
    // birds / crickets are DISCRETE events, scheduled below
    if (kind === 'birds' || kind === 'crickets') {
      const density = (kind === 'birds' ? 3.2 : 7.5) * ambienceGain * 4;
      const expected = density * (n / this.sr);
      let count = Math.floor(expected);
      if (this.rng.chance(expected - count)) count++;
      for (let k = 0; k < count; k++) {
        const at = this.t + this.rng.next() * (n / this.sr);
        const pan = this.rng.range(-0.7, 0.7);
        const voice = kind === 'birds'
          ? this.synth?.birdChirp({ sr: this.sr, seed: 'bird' + Math.floor(this.rng.next() * 7) })
          : this.synth?.cricket({ sr: this.sr, seed: 'cr' + Math.floor(this.rng.next() * 9) });
        if (voice) this.voices.push({ samples: voice, sr: this.sr, gain: ambienceGain * 1.25, pan, at, end: at + voice.length / this.sr, key: null });
      }
    }
    this.ambKind = kind;
    return { left, right };
  }

  /** schedule one-shots + spatial fire loops from the represented Frame */
  _scheduleFromFrame(frame, { from, listener, voiceCap }) {
    // thunder with temporal lockout (a storm flashes over several ticks)
    for (const shot of frame?.audio?.oneShots ?? []) {
      const last = this._lastShot.get(shot.name);
      if (last != null && from - last < (SHOT_LOCKOUT[shot.name] ?? 1.0)) continue;
      const samples = shot.name === 'thunder'
        ? this.synth?.thunder({ sr: this.sr })
        : null;
      if (!samples) continue;
      const at = from + 0.02;
      this.voices.push({ samples, sr: this.sr, gain: 0.9, pan: 0, at, end: at + samples.length / this.sr, key: shot.name });
      this._lastShot.set(shot.name, from);
    }

    // fire crackle: loops while the light exists — rendered BINAURALLY
    // (our ITD+ILD head model): the crackle comes FROM where the fire is.
    for (const light of frame?.lights?.points ?? []) {
      if (light.kind !== 'fire') continue;
      const key = 'fire:' + light.sourceId;
      const alive = this.voices.some(v => v.key === key && v.end > this.t);
      const probe = spatialize({ emitterPos: light.pos, listener, refDist: 8 });
      if (!probe.audible || alive) continue;
      const loop = (this._crackleLoop.get(light.sourceId) ?? 0) + 1;
      this._crackleLoop.set(light.sourceId, loop);
      const samples = this.synth?.fireCrackle({ sr: this.sr, dur: FIRE_CRACKLE_DUR, seed: `${light.sourceId}:${loop}` });
      if (!samples) continue;
      const bin = renderBinaural(samples, { emitterPos: light.pos, listener, sr: this.sr, refDist: 8 });
      if (!bin.audible) continue;
      const at = from + 0.01;
      this.voices.push({
        samplesL: bin.left, samplesR: bin.right, sr: this.sr,
        gain: 0.5 * (light.intensity ?? 1), pan: 0,
        at, end: at + samples.length / this.sr, key,
      });
    }

    // D-O15 voice cap: ambience bed + newest voices win; farthest/oldest drop
    const cap = voiceCap ?? Infinity;
    if (this.voices.length > cap) {
      const ordered = [...this.voices].sort((a, b) => (a.end - b.end));
      this.stats.droppedByPressure += this.voices.length - cap;
      this.voices = ordered.slice(this.voices.length - cap);
    }
  }

  /**
   * Render the NEXT `seconds` of the continuous timeline for `frame`.
   * Returns { left, right, sr, from, to, voices, ambience }.
   */
  pump(frame, { seconds = 0.1, listener = { pos: [0, 0, 0], yaw: 0 }, voiceCap = 8, ambienceGain = null } = {}) {
    if (!this.synth) throw new Error('AudioStream needs a voice synth (stream.setSynth) before pumping');
    const n = Math.max(1, Math.round(seconds * this.sr));
    const from = this.t;
    const to = from + n / this.sr;
    const amb = AMBIENCE_GAIN[ambienceGain ?? 'full'] ?? 0.32;

    const { left, right } = this._renderAmbience(frame, n, amb);
    this._scheduleFromFrame(frame, { from, listener, voiceCap });

    let voices = this.ambGain > 0.001 ? 1 : 0;
    const survivors = []; // voices with content beyond `to` live on the timeline
    for (const v of this.voices) {
      const start = Math.round((v.at - from) * this.sr);
      if (start >= n) { survivors.push(v); continue; } // entirely future
      const stereo = v.samplesL != null; // binaural voices carry their own ears
      const gl = stereo ? v.gain : v.gain * Math.cos(((v.pan + 1) * Math.PI) / 4);
      const gr = stereo ? v.gain : v.gain * Math.sin(((v.pan + 1) * Math.PI) / 4);
      const mono = stereo ? null : v.samples;
      const step = v.sr / this.sr; // D-O15 rate change: voices resample by step
      let mixed = false;
      for (let i = 0; i < (stereo ? v.samplesL.length : v.samples.length); i++) {
        const j = start + Math.round(i * step);
        if (j >= n) break;
        if (j < 0) continue;
        mixed = true;
        left[j] += (stereo ? v.samplesL[i] : mono[i]) * gl;
        right[j] += (stereo ? v.samplesR[i] : mono[i]) * gr;
      }
      if (mixed) voices++;
      if (v.end > to) survivors.push(v); // consumed ones drop; loops re-schedule on the next pump
    }
    this.voices = survivors;

    for (let i = 0; i < n; i++) {           // OUR soft limiter (stateless → seamless)
      left[i] = Math.tanh(left[i]);
      right[i] = Math.tanh(right[i]);
    }

    this.t = to;
    this.stats.pumps++;
    this.stats.voices += voices;
    this.stats.seconds += n / this.sr;
    return { left, right, sr: this.sr, from, to, voices, ambience: this.ambKind };
  }

  /** presentation state (never enters world snapshots) — voices serialized
   *  so a restore is seamless even mid-thunder */
  snapshot() {
    return {
      t: this.t, sr: this.sr, rng: this.rng.getState(),
      ambKind: this.ambKind, ambGain: this.ambGain,
      lp: [this._lpY, this._lpY2], ambLfo: this._ambLfo ?? 0,
      lastShot: [...this._lastShot], crackle: [...this._crackleLoop], stats: { ...this.stats },
      voices: this.voices.map(v => ({
        samples: [...v.samples], sr: v.sr, gain: v.gain, pan: v.pan, at: v.at, end: v.end, key: v.key,
      })),
    };
  }

  restore(s) {
    this.t = s.t; this.sr = s.sr; this.rng = RNG.fromState(s.rng);
    this.ambKind = s.ambKind; this.ambGain = s.ambGain;
    this._lpY = s.lp?.[0] ?? 0; this._lpY2 = s.lp?.[1] ?? 0; this._ambLfo = s.ambLfo ?? 0;
    this._lastShot = new Map(s.lastShot ?? []);
    this._crackleLoop = new Map(s.crackle ?? []);
    this.voices = (s.voices ?? []).map(v => ({ ...v, samples: Float32Array.from(v.samples) }));
    this.stats = { ...this.stats, ...(s.stats ?? {}) };
    return this;
  }
}
