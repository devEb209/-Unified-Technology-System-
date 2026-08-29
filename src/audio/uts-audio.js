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
import { AudioStream } from './stream.js';

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

  /** synthesize a thunder clap (noise burst, lowpassed, long decay).
   *  deep=true = D-O15 RE-REPRESENTATION (never just quieter): a distant or
   *  shadowed strike arrives LATE and rolls as a long dark rumble — that is
   *  what distance does to thunder in reality (HF dies on the way). */
  thunder({ sr, seed = 'thunder', deep = false }) {
    if (deep) {
      const raw = renderNoise({ dur: 3.4, gain: 1.0, sr, seed: seed + '-deep', lp: 110 });
      return applyDecay(raw, { tau: 1.5, sr });
    }
    const raw = renderNoise({ dur: 2.0, gain: 1.0, sr, seed, lp: 220 });
    return applyDecay(raw, { tau: 0.55, sr });
  }

  /** impact thud — loudness follows the REAL kinetic energy of the hit */
  impact({ sr, seed = 'thud', power = 1 }) {
    const p = Math.max(0.05, Math.min(1, power));
    const raw = renderNoise({ dur: 0.16 + 0.1 * p, gain: 0.85 * Math.sqrt(p), sr, seed: seed + '-i', lp: 240 + 260 * p });
    return applyDecay(raw, { tau: 0.1 + 0.06 * p, sr });
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

  /** open the continuous real-time stream (presentation layer, like the
   *  renderer: pumped by the presentation loop, outside the tick pipeline) */
  openStream({ seed = 'uts-audio' } = {}) {
    this.stream = new AudioStream({ sr: this._sr(), seed });
    this.stream.setSynth(this);
    this.stats.streamPumps = 0;
    return this.stream;
  }

  /** advance the stream by `seconds` of audio for `frame`; optionally push
   *  straight into one of OUR devices (memory/pacer/webaudio). D-O15 governs
   *  sample rate (strategy.audioSr) and the voice cap (strategy.audioVoices). */
  pumpStream(frame, { seconds = 0.1, device = null } = {}) {
    const strategy = this.do15?.strategy;
    const stream = this.stream ?? this.openStream();
    stream.setRate(strategy?.audioSr ?? this._sr());
    const listener = { pos: frame.camera.pos, yaw: frame.camera.yaw };
    const chunk = stream.pump(frame, {
      seconds,
      listener,
      voiceCap: strategy?.audioVoices ?? 8,
      ambienceGain: strategy?.perceptionResolution ?? 'full',
    });
    if (device) device.write(chunk);
    this.stats.streamPumps++;
    this.tese?.touch('D-11', `stream pump ${chunk.voices} voices @${chunk.sr}Hz t=${chunk.to.toFixed(1)}s`, frame.tick);
    return chunk;
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

    // spatial one-shots — REAL sources arriving through ACOUSTICS (delay =
    // speed of sound, gain = spreading+air+shadow, deep = D-O15 re-representation)
    for (const shot of audio.oneShots) {
      const ac = shot.acoustic ?? null;
      const deep = ac ? (ac.dist > 120 || ac.occlusion > 0.4) : false;
      if (ac && !ac.audible && !deep) continue; // beyond the acoustic horizon
      if (shot.name === 'thunder') {
        const arrivalGain = ac ? Math.min(1, Math.max(0.05, ac.gain)) : 1;
        let samples = this.thunder({ sr, deep });
        if (ac && ac.muffle > 1.4) samples = lowpass(samples, (deep ? 110 : 220) / Math.min(ac.muffle, 4), sr);
        mixer.add(samples, { gain: 0.9 * arrivalGain, at: 0.02 + (ac?.delay ?? 0) });
        voices++;
      } else if (shot.name === 'impact') {
        const arrivalGain = ac ? Math.min(1, Math.max(0, ac.gain)) : 1;
        if (arrivalGain <= 0.02) continue; // honestly inaudible
        let samples = this.impact({ sr, power: shot.power ?? 1 });
        if (ac && ac.muffle > 1.4) samples = lowpass(samples, 500 / Math.min(ac.muffle, 4), sr);
        mixer.add(samples, { gain: 0.75 * arrivalGain, at: 0.02 + (ac?.delay ?? 0) });
        voices++;
      }
    }

    // spatial fire crackle from actual fire lights in the Frame
    for (const light of frame.lights?.points ?? []) {
      if (light.kind !== 'fire') continue;
      const sp = spatialize({ emitterPos: light.pos, listener, refDist: 8 });
      if (!sp.audible) continue;
      const acG = light.acoustic ? Math.max(0, Math.min(1, light.acoustic.gain)) : 1;
      if (acG <= 0.02) continue; // deep acoustic shadow: honestly inaudible
      let crackle = this.fireCrackle({ sr, dur: Math.min(seconds, 1.5), seed: light.sourceId });
      if (light.acoustic && light.acoustic.muffle > 1.4) {
        crackle = lowpass(crackle, 900 / Math.min(light.acoustic.muffle, 4), sr);
      }
      mixer.add(crackle, { gain: 0.5 * sp.gain * light.intensity * acG, pan: sp.pan, at: 0 });
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
