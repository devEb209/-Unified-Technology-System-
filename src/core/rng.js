// UTS :: core/rng — Deterministic RNG (xoshiro128** seeded via xmur3).
// The RNG is part of the simulated reality: its full state is serializable,
// so save/load reproduces the exact same future evolution.

function xmur3(str) {
  let h = 1779033703 ^ str.length;
  for (let i = 0; i < str.length; i++) {
    h = Math.imul(h ^ str.charCodeAt(i), 3432918353);
    h = (h << 13) | (h >>> 19);
  }
  return function () {
    h = Math.imul(h ^ (h >>> 16), 2246822507);
    h = Math.imul(h ^ (h >>> 13), 3266489909);
    return (h ^= h >>> 16) >>> 0;
  };
}

function rotl(x, k) {
  return ((x << k) | (x >>> (32 - k))) >>> 0;
}

export class RNG {
  constructor(seed = 'uts') {
    const gen = xmur3(String(seed));
    this.seedLabel = String(seed);
    this.s0 = gen() >>> 0;
    this.s1 = gen() >>> 0;
    this.s2 = gen() >>> 0;
    this.s3 = gen() >>> 0;
    this.calls = 0;
  }

  static fromState(state) {
    const r = new RNG('restore');
    r.seedLabel = state.label ?? 'restore';
    r.s0 = state.s0 >>> 0;
    r.s1 = state.s1 >>> 0;
    r.s2 = state.s2 >>> 0;
    r.s3 = state.s3 >>> 0;
    r.calls = state.calls | 0;
    return r;
  }

  getState() {
    return { label: this.seedLabel, s0: this.s0, s1: this.s1, s2: this.s2, s3: this.s3, calls: this.calls };
  }

  setState(state) {
    this.seedLabel = state.label ?? this.seedLabel;
    this.s0 = state.s0 >>> 0;
    this.s1 = state.s1 >>> 0;
    this.s2 = state.s2 >>> 0;
    this.s3 = state.s3 >>> 0;
    this.calls = state.calls | 0;
  }

  /** float in [0, 1) */
  next() {
    this.calls++;
    const result = Math.imul(rotl(Math.imul(this.s1, 5), 7), 9) >>> 0;
    const t = (this.s1 << 9) >>> 0;
    this.s2 = (this.s2 ^ this.s0) >>> 0;
    this.s3 = (this.s3 ^ this.s1) >>> 0;
    this.s1 = (this.s1 ^ this.s2) >>> 0;
    this.s0 = (this.s0 ^ this.s3) >>> 0;
    this.s2 = (this.s2 ^ t) >>> 0;
    this.s3 = rotl(this.s3, 11);
    return result / 4294967296;
  }

  /** integer in [min, max] inclusive */
  int(min, max) {
    return min + Math.floor(this.next() * (max - min + 1));
  }

  /** float in [min, max) */
  range(min, max) {
    return min + this.next() * (max - min);
  }

  chance(p) {
    return this.next() < p;
  }

  pick(arr) {
    return arr[Math.floor(this.next() * arr.length)];
  }

  /** gaussian-ish via central limit (deterministic) */
  gauss(mean = 0, sd = 1) {
    const s = (this.next() + this.next() + this.next() + this.next() - 2) * 1.732;
    return mean + s * sd;
  }
}
