// UTS :: audio/uts-audio — UTS AUDIO: our native audio system.
//
//   Frame (represented state) → AudioDirector (ambience + one-shots, spatial)
//   → Mixer → WAV device (OUR encoder) → playable bytes
//
// D-O15 governs quality: perceived-pressure chooses the sample rate
// (full 22050 / reduced 16000 / coarse 11025) — adaptation, not random
// degradation. No external audio library anywhere.

import { renderOsc, renderNoise, applyDecay, applyShape, lowpass, place } from './synth.js';
import { spatialize } from './spatial.js';
import { Mixer } from './mixer.js';

const SR_BY_RESOLUTION = { full: 22050, reduced: 16000, coarse: 11025 };

export class AudioDirector {
  constructor({ tese = null, do15 = null } = {}) {
    this.tese = tese;
    this.do15 = do15;
    this.rendered = 0;
    this.stats = { renders: 0, voices: 0, seconds: 0, sr: 0 };
  }

  _sr() {
    const res = this.do15?.strategy?.perceptionResolution ?? 'full';
    return SR_BY_RESOLUTION[res] ?? 22050;
  }

  /** synthesize a thunder clap (noise burst, lowpassed, long decay) */
  thunder({ sr, seed = 'thunder' }) {
    const raw = renderNoise({ dur: 2.0, gain: 1.0, sr, seed, lp: 220 });
    return applyDecay(raw, { tau: 0.55, sr });
  }

  fireCrackle({ sr, dur = 1.0, seed = 'crackle' }) {
    const raw = renderNoise({ dur, gain: 0.8, sr, seed: seed + '-n', lp: 900 });
    const shaped = applyShape(raw, { attack: 0.05, release: 0.2, sr });
    return applyDecay(shaped, { tau: 0.9, sr });
  }

  birdChirp({ sr, seed }) {
    const f = 2800 + (seed.charCodeAt(seed.length - 1) % 10) * 120;
    const raw = renderOsc({ freq: f, sweepTo: f * 1.5, dur: 0.09, gain: 0.5, sr, type: 'sine', seed });
    return applyShape(raw, { attack: 0.005, release: 0.03, sr });
  }

  cricket({ sr, seed }) {
    const raw = renderOsc({ freq: 4300, dur: 0.05, gain: 0.35, sr, type: 'sine', seed });
    return applyShape(raw, { attack: 0.004, release: 0.02, sr });
  }

  /**
   * Render the audio of a Frame into stereo float buffers.
   * Everything derives from the represented state (weather, day/night,
   * hazards, camera) — nothing is decorative or random-by-accident.
   */
  renderFrameAudio(frame, { seconds = 2 } = {}) {
    const sr = this._sr();
    const env = frame.environment;
    const audio = frame.audio;
    const mixer = new Mixer({ sr });
    const cam = frame.camera;
    const listener = { pos: cam.pos, yaw: cam.yaw };
    let voices = 0;

    const ambienceGain = { full: 0.32, reduced: 0.4, coarse: 0.5 }[this.do15?.strategy?.perceptionResolution ?? 'full'];
    const amb = audio.ambience;
    if (amb === 'rain' || amb === 'storm') {
      const rain = lowpass(renderNoise({ dur: seconds, gain: 1, sr, seed: 'rain', lp: 1400 }), 1100, sr);
      mixer.add(rain, { gain: amb === 'storm' ? ambienceGain * 1.5 : ambienceGain, at: 0 });
      voices++;
    }
    if (amb === 'wind') {
      const wind = lowpass(renderNoise({ dur: seconds, gain: 1, sr, seed: 'wind', lp: 420 }), 380, sr);
      mixer.add(wind, { gain: ambienceGain, at: 0 });
      voices++;
    }
    if (amb === 'birds') {
      for (let i = 0; i < 4; i++) {
        const at = 0.25 + i * (seconds / 5);
        const chirp = this.birdChirp({ sr, seed: 'bird' + i });
        mixer.add(chirp, { gain: ambienceGain * 1.2, pan: (i % 2 ? 0.5 : -0.5), at });
        voices++;
      }
    }
    if (amb === 'crickets') {
      for (let i = 0; i < 8; i++) {
        mixer.add(this.cricket({ sr, seed: 'cr' + i }), { gain: ambienceGain, pan: (i % 3 - 1) * 0.6, at: i * (seconds / 9) });
        voices++;
      }
    }

    // spatial one-shots (thunder) — position = world flash => from the sky
    for (const shot of audio.oneShots) {
      if (shot.name === 'thunder') {
        mixer.add(this.thunder({ sr }), { gain: 0.9, at: 0.02 });
        voices++;
      }
    }

    // spatial fire crackle from actual fire lights in the Frame
    for (const light of frame.lights?.points ?? []) {
      if (light.kind !== 'fire') continue;
      const sp = spatialize({ emitterPos: light.pos, listener, refDist: 8 });
      if (!sp.audible) continue;
      const crackle = this.fireCrackle({ sr, dur: Math.min(seconds, 1.5), seed: light.sourceId });
      mixer.add(crackle, { gain: 0.5 * sp.gain * light.intensity, pan: sp.pan, at: 0 });
      voices++;
    }

    const rendered = mixer.render(seconds);
    this.stats.renders++;
    this.stats.voices += voices;
    this.stats.seconds += seconds;
    this.stats.sr = sr;
    this.rendered++;
    this.tese?.touch('D-11', `audio render ${voices} voices @${sr}Hz amb=${amb}`, frame.tick);
    return { ...rendered, voices, sr };
  }
}

// ------------------------------------------------------------ WAV device
// OUR file device: 16-bit PCM RIFF encoder (no external encoder).

export function encodeWav({ left, right, sr }) {
  const n = left.length;
  const bytesPerSample = 2;
  const dataBytes = n * 2 * bytesPerSample;
  const buf = new ArrayBuffer(44 + dataBytes);
  const view = new DataView(buf);
  const wstr = (off, s) => { for (let i = 0; i < s.length; i++) view.setUint8(off + i, s.charCodeAt(i)); };
  wstr(0, 'RIFF');
  view.setUint32(4, 36 + dataBytes, true);
  wstr(8, 'WAVE');
  wstr(12, 'fmt ');
  view.setUint32(16, 16, true);
  view.setUint16(20, 1, true);          // PCM
  view.setUint16(22, 2, true);          // stereo
  view.setUint32(24, sr, true);
  view.setUint32(28, sr * 2 * bytesPerSample, true);
  view.setUint16(32, 2 * bytesPerSample, true);
  view.setUint16(34, 16, true);
  wstr(36, 'data');
  view.setUint32(40, dataBytes, true);
  let off = 44;
  for (let i = 0; i < n; i++) {
    const l = Math.max(-1, Math.min(1, left[i]));
    const r = Math.max(-1, Math.min(1, right[i]));
    view.setInt16(off, l < 0 ? l * 0x8000 : l * 0x7FFF, true); off += 2;
    view.setInt16(off, r < 0 ? r * 0x8000 : r * 0x7FFF, true); off += 2;
  }
  return Buffer.from(buf);
}
