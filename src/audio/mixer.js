// UTS :: audio/mixer — OUR mixer: channels, per-voice gain/pan, soft limiter.
// Deterministic float mixing; the WAV device (ours too) turns it into bytes.

import { reverb, SPACES } from './reverb.js';

export class Mixer {
  constructor({ sr = 22050 }) {
    this.sr = sr;
    this.voices = []; // {samples, gain, pan, at}
    this.space = null; // acoustic space of the BUS (reverb on the mix)
  }

  /** the bus lives in a place: 'room' | 'valley' | 'canyon' */
  setSpace(name) {
    if (!SPACES[name]) throw new Error(`mixer: espaço desconhecido "${name}" (${Object.keys(SPACES).join(', ')})`);
    this.space = name;
    return this;
  }

  add(samples, { gain = 1, pan = 0, at = 0 } = {}) {
    this.voices.push({ samples, gain, pan, at });
    return this;
  }

  /** render to stereo buffers; constant-power pan; tanh soft limiter */
  render(durationSec) {
    const n = Math.ceil(durationSec * this.sr);
    const left = new Float32Array(n);
    const right = new Float32Array(n);
    for (const v of this.voices) {
      const start = Math.floor(v.at * this.sr);
      const gl = v.gain * Math.cos(((v.pan + 1) * Math.PI) / 4);
      const gr = v.gain * Math.sin(((v.pan + 1) * Math.PI) / 4);
      for (let i = 0; i < v.samples.length; i++) {
        const j = start + i;
        if (j >= n) break;
        if (j < 0) continue;
        const s = v.samples[i];
        left[j] += s * gl;
        right[j] += s * gr;
      }
    }
    // THE BUS IS IN A PLACE: the mixed dry signal goes through the space's
    // real reverberation (Schroeder) before the limiter — one truth.
    let dl = left, dr = right;
    if (this.space) {
      dl = reverb(left, { space: this.space, sr: this.sr });
      dr = reverb(right, { space: this.space, sr: this.sr });
    }
    for (let i = 0; i < n; i++) {
      left[i] = Math.tanh(dl[i]);
      right[i] = Math.tanh(dr[i]);
    }
    return { left, right, sr: this.sr };
  }

  peak({ left, right }) {
    let p = 0;
    for (let i = 0; i < left.length; i++) {
      p = Math.max(p, Math.abs(left[i]), Math.abs(right[i]));
    }
    return p;
  }
}
