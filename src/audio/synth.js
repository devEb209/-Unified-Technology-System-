// UTS :: audio/synth — OUR synthesis primitives (pure DSP, zero deps).
// Oscillators, noise (deterministic), envelopes — the UTS generates its
// own sound; no external audio library.

import { RNG } from '../core/rng.js';

/** band-limited-ish sine, saw and square oscillators (phase-accumulated) */
export function renderOsc({ freq = 440, dur = 0.2, type = 'sine', gain = 0.5, sr = 22050, seed = 'osc', sweepTo = null }) {
  const n = Math.floor(dur * sr);
  const out = new Float32Array(n);
  const rng = new RNG(seed);
  let phase = 0;
  const inc0 = (Math.PI * 2 * freq) / sr;
  const inc1 = sweepTo ? (Math.PI * 2 * sweepTo) / sr : inc0;
  for (let i = 0; i < n; i++) {
    const t = i / n;
    const inc = inc0 + (inc1 - inc0) * t;
    phase += inc;
    const ph = phase % (Math.PI * 2);
    switch (type) {
      case 'saw': out[i] = (ph / Math.PI - 1) * gain; break;
      case 'square': out[i] = (ph < Math.PI ? 1 : -1) * gain; break;
      case 'noise': out[i] = (rng.next() * 2 - 1) * gain; break;
      default: out[i] = Math.sin(ph) * gain;
    }
  }
  return out;
}

/** deterministic white/pink-ish noise buffer */
export function renderNoise({ dur = 0.5, gain = 0.5, sr = 22050, seed = 'noise', lp = 0 } = {}) {
  const n = Math.floor(dur * sr);
  const out = new Float32Array(n);
  const rng = new RNG(seed);
  let y = 0;
  const a = lp > 0 ? Math.exp(-2 * Math.PI * lp / sr) : 0;
  for (let i = 0; i < n; i++) {
    const w = (rng.next() * 2 - 1);
    y = a * y + (1 - a) * w;
    out[i] = (lp > 0 ? y : w) * gain;
  }
  return out;
}

/** exponential decay envelope applied in place-ish (returns new) */
export function applyDecay(samples, { tau = 0.25, sr = 22050 } = {}) {
  const out = new Float32Array(samples.length);
  for (let i = 0; i < samples.length; i++) {
    out[i] = samples[i] * Math.exp(-i / (tau * sr));
  }
  return out;
}

/** ADSR-ish attack/release shaping */
export function applyShape(samples, { attack = 0.01, release = 0.05, sr = 22050 } = {}) {
  const out = new Float32Array(samples.length);
  const aN = Math.max(1, Math.floor(attack * sr));
  const rN = Math.max(1, Math.floor(release * sr));
  for (let i = 0; i < samples.length; i++) {
    let g = 1;
    if (i < aN) g = i / aN;
    if (i > samples.length - rN) g = (samples.length - i) / rN;
    out[i] = samples[i] * Math.min(1, Math.max(0, g));
  }
  return out;
}

/** simple one-pole lowpass */
export function lowpass(samples, cutoffHz, sr = 22050) {
  const a = Math.exp(-2 * Math.PI * cutoffHz / sr);
  const out = new Float32Array(samples.length);
  let y = 0;
  for (let i = 0; i < samples.length; i++) {
    y = a * y + (1 - a) * samples[i];
    out[i] = y;
  }
  return out;
}

/** deterministic mixture at offsets — the building block of ambience */
export function place(dst, src, offsetSec, sr = 22050, gain = 1) {
  const start = Math.floor(offsetSec * sr);
  for (let i = 0; i < src.length; i++) {
    const j = start + i;
    if (j < 0 || j >= dst.length) continue;
    dst[j] += src[i] * gain;
  }
  return dst;
}
