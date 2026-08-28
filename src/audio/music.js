// UTS :: audio/music — OUR adaptive procedural music engine (D-11).
//
//   represented world → tension (weather/hazards/night, honest formula)
//   → mode + tempo + layers → notes on an ABSOLUTE beat grid → stream
//
// Everything is deterministic (seeded RNG, no wall time): the same world
// state evolution produces the same music, forever. Music is presentation
// (like the renderer): it consumes the Frame and schedules into OUR
// AudioStream — it never mutates reality and never enters snapshots.
//
// Structure: 4-bar loop over a diatonic mode; pad (chord root stack) +
// bass (root/fifth) + arp (chord tones) + pulse (filtered tick). Layers
// are added by tension; D-O15 caps the music voice budget (audioVoices).

import { RNG } from '../core/rng.js';
import { renderOsc, applyShape } from './synth.js';

export const MODES = {
  calm: [0, 2, 4, 7, 9],        // major pentatonic
  night: [0, 3, 5, 7, 10],      // minor pentatonic
  tense: [0, 1, 5, 7, 8],       // phrygian-flavored
};

const ROOT_HZ = { calm: 130.81, night: 110.0, tense: 98.0 }; // C3 / A2 / G2

/** world tension 0..1 from the REPRESENTED frame (documented, honest) */
export function worldTension(frame) {
  let t = 0;
  const env = frame?.environment ?? {};
  t += (env.rain ?? 0) * 0.3;
  t += (env.wind ?? 0) * 0.15;
  t += (env.storm ?? 0) * 0.2;
  const near = frame?.lights?.points?.reduce((m, l) => Math.min(m, l.dist ?? 30), 30) ?? 30;
  t += Math.max(0, 1 - near / 30) * 0.45; // a fire close to you is tension
  if ((frame?.audio?.ambience ?? '') === 'storm') t += 0.35;
  return Math.max(0, Math.min(1, t));
}

export class MusicDirector {
  constructor({ seed = 'uts-music', tese = null } = {}) {
    this.rng = new RNG(seed + ':music');
    this.tese = tese;
    this.beat = 0;            // absolute musical time (seconds at current tempo)
    this.nextBar = 0;         // stream time when the next bar begins
    this.barIndex = 0;
    this.stats = { bars: 0, notes: 0, modeChanges: 0, tempoChanges: 0 };
    this._lastMode = null;
    this._lastTempo = null;
  }

  /** musical plan for the CURRENT world state (pure function of the frame) */
  plan(frame) {
    const tension = worldTension(frame);
    const mode = tension > 0.6 ? 'tense' : ((frame?.camera?.pos?.[1] ?? 0, null), (this._isNight(frame) ? 'night' : 'calm'));
    const bpm = 84 + tension * 72;           // 84 … 156
    const layers = tension > 0.75 ? 4 : tension > 0.45 ? 3 : tension > 0.2 ? 2 : 1;
    return { tension, mode, bpm, layers };
  }

  _isNight(frame) {
    // the frame carries no clock; night is signaled by the ambience channel
    return (frame?.audio?.ambience ?? '') === 'crickets';
  }

  /**
   * Schedule the bars that fit into [stream.t, stream.t + seconds] using the
   * represented frame's plan. Tempo/mode changes land at BAR boundaries only
   * (a tempo change mid-bar would glitch the beat grid).
   */
  scheduleInto(stream, frame, { seconds = 0.5, voiceBudget = 4 } = {}) {
    const plan = this.plan(frame);
    if (plan.mode !== this._lastMode) { this._lastMode = plan.mode; this.stats.modeChanges++; }
    const layers = Math.min(plan.layers, Math.max(1, Math.floor(voiceBudget / 2)));
    const barSec = (60 / plan.bpm) * 4;
    const sr = stream.sr;
    const root = ROOT_HZ[plan.mode];
    const scale = MODES[plan.mode];
    let scheduled = 0;

    while (this.nextBar < stream.t + seconds) {
      const at = this.nextBar;
      const bar = this.barIndex;
      const chordRoot = [0, 3, 4, 1][bar % 4]; // degrees into the scale
      const chord = [0, 2, 4].map(k => scale[(chordRoot + k) % scale.length] + 12 * Math.floor((chordRoot + k) / scale.length));

      // layer 1 — pad: soft chord stack, one voice per bar
      if (layers >= 1) {
        const dur = Math.min(barSec * 1.05, 3);
        const pad = this._pad(chord.map(c => root * Math.pow(2, c / 12)), dur, sr, `${plan.mode}${bar}`);
        stream.schedule(pad, { gain: 0.16, pan: 0, at });
        scheduled++;
      }
      // layer 2 — bass: root/fifth eighth pulse
      if (layers >= 2) {
        const eighth = (60 / plan.bpm) / 2;
        for (let i = 0; i < 8; i++) {
          const deg = i % 4 === 0 ? chord[0] : chord[0] + 7;
          const note = this._pluck(root * Math.pow(2, (deg - 12) / 12), eighth * 0.9, sr, `b${bar}x${i}`);
          stream.schedule(note, { gain: 0.2, pan: 0, at: at + i * eighth });
          scheduled++;
        }
      }
      // layer 3 — arp: chord tones riding the beat (RNG-ordered, seeded)
      if (layers >= 3) {
        const sixteenth = (60 / plan.bpm) / 4;
        for (let i = 0; i < 8; i++) {
          const tone = chord[this.rng.int(0, 2)] + 12;
          const note = this._pluck(root * 2 * Math.pow(2, tone / 12), sixteenth * 1.6, sr, `a${bar}x${i}`);
          stream.schedule(note, { gain: 0.12, pan: (i % 2 ? 0.35 : -0.35), at: at + i * sixteenth * 2 + sixteenth });
          scheduled++;
        }
      }
      // layer 4 — pulse: filtered noise tick on the quarter
      if (layers >= 4) {
        const quarter = 60 / plan.bpm;
        for (let i = 0; i < 4; i++) {
          const tick = this._tick(sr, `p${bar}x${i}`);
          stream.schedule(tick, { gain: i % 2 ? 0.1 : 0.16, pan: 0, at: at + i * quarter });
          scheduled++;
        }
      }

      this.stats.bars++;
      this.barIndex++;
      if (plan.bpm !== this._lastTempo) { if (this._lastTempo != null) this.stats.tempoChanges++; this._lastTempo = plan.bpm; }
      this.nextBar += barSec; // the grid advances by THE CURRENT bar's length
    }
    this.stats.notes += scheduled; // cumulative (per-call count is the return value)
    this._lastScheduled = scheduled;
    this.tese?.touch('D-11', `music ${plan.mode} ${plan.bpm.toFixed(0)}bpm ${layers} layers`, frame?.tick ?? null);
    return { ...plan, layers, scheduled };
  }

  // ---- voices (all through OUR synth, all deterministic) ------------------
  _pad(freqs, dur, sr, seed) {
    const n = Math.floor(dur * sr);
    const out = new Float32Array(n);
    for (let f = 0; f < freqs.length; f++) {
      const osc = renderOsc({ freq: freqs[f], dur, gain: 0.32, sr, type: 'sine', seed: seed + 'p' + f });
      for (let i = 0; i < n; i++) out[i] += osc[i] ?? 0;
    }
    return applyShape(out, { attack: Math.min(0.4, dur * 0.25), release: dur * 0.5, sr });
  }

  _pluck(freq, dur, sr, seed) {
    const osc = renderOsc({ freq, dur, gain: 0.5, sr, type: 'saw', sweepTo: freq * 0.995, seed });
    return applyShape(osc, { attack: 0.004, release: dur * 0.55, sr });
  }

  _tick(sr, seed) {
    const osc = renderOsc({ freq: 2100, dur: 0.03, gain: 0.4, sr, type: 'square', seed });
    return applyShape(osc, { attack: 0.001, release: 0.02, sr });
  }
}
