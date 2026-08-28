// UTS :: audio/mixer — OUR mixer: channels, per-voice gain/pan, soft limiter.
// Deterministic float mixing; the WAV device (ours too) turns it into bytes.

export class Mixer {
  constructor({ sr = 22050 }) {
    this.sr = sr;
    this.voices = []; // {samples, gain, pan, at}
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
    for (let i = 0; i < n; i++) {
      left[i] = Math.tanh(left[i]);
      right[i] = Math.tanh(right[i]);
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
