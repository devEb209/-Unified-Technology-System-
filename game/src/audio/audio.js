import { clamp } from '../core/noise.js';

/* Áudio 100% procedural (WebAudio): sem samples externos.
   Cada disparo é síntese de impulso + corpo + cauda de ambiente,
   com filtro de distância, atraso do som (343 m/s) e oclusão. */
export class AudioEngine {
  constructor() {
    this.ctx = null; this.ready = false;
  }
  init() {
    if (this.ready) return;
    const C = window.AudioContext || window.webkitAudioContext;
    this.ctx = new C();
    const ctx = this.ctx;
    this.master = ctx.createGain(); this.master.gain.value = 0.85;
    this.comp = ctx.createDynamicsCompressor();
    this.comp.threshold.value = -14; this.comp.ratio.value = 6; this.comp.attack.value = 0.002;
    this.comp.connect(this.master).connect(ctx.destination);

    // reverb procedural (cauda de ambiente aberto)
    const len = ctx.sampleRate * 1.7;
    const buf = ctx.createBuffer(2, len, ctx.sampleRate);
    for (let c = 0; c < 2; c++) {
      const d = buf.getChannelData(c);
      for (let i = 0; i < len; i++) {
        const t = i / len;
        d[i] = (Math.random() * 2 - 1) * Math.pow(1 - t, 2.6) * (0.35 + 0.65 * Math.exp(-t * 6));
      }
    }
    this.verb = ctx.createConvolver(); this.verb.buffer = buf;
    this.verbGain = ctx.createGain(); this.verbGain.gain.value = 0.5;
    this.verb.connect(this.verbGain).connect(this.comp);

    this.noiseBuf = this._noise(2.0);
    this._ambience();
    this.ready = true;
  }
  _noise(sec) {
    const n = this.ctx.sampleRate * sec;
    const b = this.ctx.createBuffer(1, n, this.ctx.sampleRate);
    const d = b.getChannelData(0);
    for (let i = 0; i < n; i++) d[i] = Math.random() * 2 - 1;
    return b;
  }
  _src(loop = false) {
    const s = this.ctx.createBufferSource();
    s.buffer = this.noiseBuf; s.loop = loop; return s;
  }
  _ambience() {
    const ctx = this.ctx;
    // chuva
    const rain = this._src(true);
    const rf = ctx.createBiquadFilter(); rf.type = 'bandpass'; rf.frequency.value = 2600; rf.Q.value = 0.5;
    const rg = ctx.createGain(); rg.gain.value = 0.09;
    rain.connect(rf).connect(rg).connect(this.comp); rain.start();
    this.rainGain = rg;
    // vento
    const wind = this._src(true);
    const wf = ctx.createBiquadFilter(); wf.type = 'lowpass'; wf.frequency.value = 380;
    const wg = ctx.createGain(); wg.gain.value = 0.05;
    wind.connect(wf).connect(wg).connect(this.comp); wind.start();
    const lfo = ctx.createOscillator(); lfo.frequency.value = 0.09;
    const lg = ctx.createGain(); lg.gain.value = 0.035;
    lfo.connect(lg).connect(wg.gain); lfo.start();
    this.windGain = wg;
    // zumbido de ouvido (tinnitus) após tiro forte
    this.tin = ctx.createOscillator(); this.tin.type = 'sine'; this.tin.frequency.value = 6300;
    this.tinG = ctx.createGain(); this.tinG.gain.value = 0;
    this.tin.connect(this.tinG).connect(this.master); this.tin.start();
    // filtro de "surdez" temporária
    this.duckFilter = ctx.createBiquadFilter(); this.duckFilter.type = 'lowpass'; this.duckFilter.frequency.value = 20000;
  }

  _dist(gainNode, dist, occl = 0) {
    // atenuação + absorção do ar + oclusão
    const ctx = this.ctx;
    const f = ctx.createBiquadFilter(); f.type = 'lowpass';
    f.frequency.value = clamp(19000 / (1 + dist * 0.06) * (1 - occl * 0.7), 220, 19000);
    const g = ctx.createGain();
    g.gain.value = clamp(1 / (1 + dist * dist * 0.0022), 0.0, 1) * (1 - occl * 0.45);
    gainNode.connect(f).connect(g);
    g.connect(this.comp);
    const vs = ctx.createGain(); vs.gain.value = 0.55;
    g.connect(vs).connect(this.verb);
    return g;
  }

  shot(dist = 0, { suppressed = false, caliber = '5.56x45', indoor = false } = {}) {
    if (!this.ready) return;
    const ctx = this.ctx, t0 = ctx.currentTime + Math.min(1.2, dist / 343);
    const big = caliber === '7.62x51';
    const out = ctx.createGain(); out.gain.value = suppressed ? 0.35 : 1.0;

    // impulso de boca
    const n = this._src(); const nf = ctx.createBiquadFilter();
    nf.type = suppressed ? 'bandpass' : 'highpass';
    nf.frequency.value = suppressed ? 900 : 180;
    const ng = ctx.createGain();
    const peak = suppressed ? 0.35 : (big ? 1.0 : 0.8);
    ng.gain.setValueAtTime(0.0001, t0);
    ng.gain.exponentialRampToValueAtTime(peak, t0 + 0.0012);
    ng.gain.exponentialRampToValueAtTime(0.0001, t0 + (suppressed ? 0.11 : big ? 0.32 : 0.22));
    n.connect(nf).connect(ng).connect(out);
    n.start(t0); n.stop(t0 + 0.6);

    // corpo grave (pressão)
    const o = ctx.createOscillator(); o.type = 'sine';
    o.frequency.setValueAtTime(big ? 118 : 150, t0);
    o.frequency.exponentialRampToValueAtTime(42, t0 + 0.14);
    const og = ctx.createGain();
    og.gain.setValueAtTime(suppressed ? 0.10 : (big ? 0.55 : 0.36), t0);
    og.gain.exponentialRampToValueAtTime(0.0001, t0 + 0.24);
    o.connect(og).connect(out); o.start(t0); o.stop(t0 + 0.3);

    // mecanismo (ferrolho) — audível principalmente com supressor
    const m = this._src(); const mf = ctx.createBiquadFilter();
    mf.type = 'bandpass'; mf.frequency.value = 3400; mf.Q.value = 2.2;
    const mg = ctx.createGain();
    mg.gain.setValueAtTime(0.0001, t0 + 0.012);
    mg.gain.exponentialRampToValueAtTime(suppressed ? 0.22 : 0.10, t0 + 0.02);
    mg.gain.exponentialRampToValueAtTime(0.0001, t0 + 0.10);
    m.connect(mf).connect(mg).connect(out); m.start(t0); m.stop(t0 + 0.2);

    this._dist(out, dist, indoor ? 0.3 : 0);

    if (dist < 3 && !suppressed) this.deafen(big ? 0.9 : 0.6);
  }

  crack(dist) { // estampido supersônico passando perto
    if (!this.ready) return;
    const ctx = this.ctx, t0 = ctx.currentTime;
    const n = this._src(); const f = ctx.createBiquadFilter();
    f.type = 'highpass'; f.frequency.value = 1500;
    const g = ctx.createGain();
    const amp = clamp(1.2 - dist / 7, 0.05, 1);
    g.gain.setValueAtTime(0.0001, t0);
    g.gain.exponentialRampToValueAtTime(amp, t0 + 0.0008);
    g.gain.exponentialRampToValueAtTime(0.0001, t0 + 0.05);
    n.connect(f).connect(g).connect(this.comp); n.start(t0); n.stop(t0 + 0.1);
    if (dist < 2.2) this.deafen(0.35);
  }

  impact(pos, mat, listener) {
    if (!this.ready || !listener) return;
    const d = pos.distanceTo(listener);
    if (d > 90) return;
    const ctx = this.ctx, t0 = ctx.currentTime + d / 343;
    const n = this._src(); const f = ctx.createBiquadFilter();
    f.type = 'bandpass';
    f.frequency.value = mat === 'metal' ? 4200 : mat === 'sandbag' ? 500 : 1500;
    f.Q.value = mat === 'metal' ? 3 : 1;
    const g = ctx.createGain();
    g.gain.setValueAtTime(0.0001, t0);
    g.gain.exponentialRampToValueAtTime(mat === 'flesh' ? 0.4 : 0.5, t0 + 0.002);
    g.gain.exponentialRampToValueAtTime(0.0001, t0 + (mat === 'metal' ? 0.35 : 0.09));
    n.connect(f).connect(g); n.start(t0); n.stop(t0 + 0.5);
    this._dist(g, d);
  }

  ricochet(pos, listener) {
    if (!this.ready || !listener) return;
    const d = pos.distanceTo(listener);
    const ctx = this.ctx, t0 = ctx.currentTime + d / 343;
    const o = ctx.createOscillator(); o.type = 'sawtooth';
    o.frequency.setValueAtTime(1800 + Math.random() * 1400, t0);
    o.frequency.exponentialRampToValueAtTime(320, t0 + 0.4);
    const g = ctx.createGain();
    g.gain.setValueAtTime(0.14, t0);
    g.gain.exponentialRampToValueAtTime(0.0001, t0 + 0.45);
    o.connect(g); o.start(t0); o.stop(t0 + 0.5);
    this._dist(g, d);
  }

  mech(kind = 'mag') {
    if (!this.ready) return;
    const ctx = this.ctx, t0 = ctx.currentTime;
    const n = this._src(); const f = ctx.createBiquadFilter();
    f.type = 'bandpass';
    f.frequency.value = kind === 'mag' ? 2200 : kind === 'bolt' ? 3600 : 1400;
    f.Q.value = 3;
    const g = ctx.createGain();
    g.gain.setValueAtTime(0.0001, t0);
    g.gain.exponentialRampToValueAtTime(0.22, t0 + 0.003);
    g.gain.exponentialRampToValueAtTime(0.0001, t0 + 0.09);
    n.connect(f).connect(g).connect(this.comp); n.start(t0); n.stop(t0 + 0.2);
  }

  step(surface = 'dirt', vol = 0.1) {
    if (!this.ready) return;
    const ctx = this.ctx, t0 = ctx.currentTime;
    const n = this._src(); const f = ctx.createBiquadFilter();
    f.type = surface === 'concrete' ? 'bandpass' : 'lowpass';
    f.frequency.value = surface === 'concrete' ? 1800 : 700;
    const g = ctx.createGain();
    g.gain.setValueAtTime(0.0001, t0);
    g.gain.exponentialRampToValueAtTime(vol, t0 + 0.006);
    g.gain.exponentialRampToValueAtTime(0.0001, t0 + 0.16);
    n.connect(f).connect(g).connect(this.comp); n.start(t0); n.stop(t0 + 0.25);
  }

  breath(intensity = 0.3) {
    if (!this.ready) return;
    const ctx = this.ctx, t0 = ctx.currentTime;
    const n = this._src(); const f = ctx.createBiquadFilter();
    f.type = 'bandpass'; f.frequency.value = 700 + intensity * 500; f.Q.value = 0.8;
    const g = ctx.createGain();
    g.gain.setValueAtTime(0.0001, t0);
    g.gain.linearRampToValueAtTime(0.05 * intensity, t0 + 0.22);
    g.gain.exponentialRampToValueAtTime(0.0001, t0 + 0.7);
    n.connect(f).connect(g).connect(this.master); n.start(t0); n.stop(t0 + 0.8);
  }

  radio(seed = 0, dur = 1.4) {
    if (!this.ready) return;
    const ctx = this.ctx, t0 = ctx.currentTime;
    // "voz" filtrada de rádio: formantes ruidosos modulados
    const n = this._src(); const bp = ctx.createBiquadFilter();
    bp.type = 'bandpass'; bp.frequency.value = 1400; bp.Q.value = 1.4;
    const g = ctx.createGain(); g.gain.value = 0.0;
    const lfo = ctx.createOscillator(); lfo.type = 'square'; lfo.frequency.value = 6 + (seed % 5);
    const lg = ctx.createGain(); lg.gain.value = 0.05;
    lfo.connect(lg).connect(g.gain); lfo.start(t0); lfo.stop(t0 + dur);
    g.gain.setValueAtTime(0.05, t0);
    g.gain.setValueAtTime(0.0, t0 + dur);
    const dist = ctx.createWaveShaper();
    const curve = new Float32Array(256);
    for (let i = 0; i < 256; i++) { const x = i / 128 - 1; curve[i] = Math.tanh(x * 3); }
    dist.curve = curve;
    n.connect(bp).connect(dist).connect(g).connect(this.comp);
    n.start(t0); n.stop(t0 + dur);
    // squelch
    this.beep(t0, 1200, 0.05); this.beep(t0 + dur, 800, 0.05);
  }
  beep(at, freq, dur) {
    const ctx = this.ctx;
    const o = ctx.createOscillator(); o.frequency.value = freq;
    const g = ctx.createGain(); g.gain.setValueAtTime(0.03, at);
    g.gain.exponentialRampToValueAtTime(0.0001, at + dur);
    o.connect(g).connect(this.comp); o.start(at); o.stop(at + dur + 0.02);
  }

  distantWar() { // artilharia longínqua, ambiente de guerra total
    if (!this.ready) return;
    const ctx = this.ctx, t0 = ctx.currentTime + Math.random() * 2;
    const n = this._src(); const f = ctx.createBiquadFilter();
    f.type = 'lowpass'; f.frequency.value = 140 + Math.random() * 90;
    const g = ctx.createGain();
    g.gain.setValueAtTime(0.0001, t0);
    g.gain.exponentialRampToValueAtTime(0.10 + Math.random() * 0.14, t0 + 0.06);
    g.gain.exponentialRampToValueAtTime(0.0001, t0 + 1.6 + Math.random());
    n.connect(f).connect(g).connect(this.comp); n.start(t0); n.stop(t0 + 3);
  }

  deafen(amount) {
    if (!this.ready) return;
    const t = this.ctx.currentTime;
    this.tinG.gain.cancelScheduledValues(t);
    this.tinG.gain.setValueAtTime(0.02 * amount, t);
    this.tinG.gain.exponentialRampToValueAtTime(0.00001, t + 3.5 * amount);
    this.master.gain.cancelScheduledValues(t);
    this.master.gain.setValueAtTime(0.30, t);
    this.master.gain.linearRampToValueAtTime(0.85, t + 2.2 * amount);
  }

  setEnvironment({ rain = 0.5, wind = 0.4 }) {
    if (!this.ready) return;
    this.rainGain.gain.value = 0.02 + rain * 0.10;
    this.windGain.gain.value = 0.02 + wind * 0.06;
  }
}
