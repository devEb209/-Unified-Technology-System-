// UTS :: audio/reverb — acoustic SPACE as physics (Schroeder reverberator:
// 4 feedback combs + 2 allpasses). The room's RT60 and pre-delay come from
// the environment's geometry: a canyon rings for seconds, a room dies fast.
// Deterministic, zero deps, same output for same input.

export const SPACES = Object.freeze({
  room:   { rt: 0.35, predelay: 8,  wet: 0.22 },
  valley: { rt: 1.3,  predelay: 22, wet: 0.34 },
  canyon: { rt: 2.9,  predelay: 48, wet: 0.45 },
});

const COMB_MS = [29.7, 37.1, 41.1, 43.7];
const AP_MS = [5.0, 1.7];

/**
 * Reverberate `samples` for the given acoustic space. Returns a NEW buffer
 * of the same length (dry + wet). Deterministic.
 */
export function reverb(samples, { space = 'room', sr = 22050, wet = null } = {}) {
  const sp = SPACES[space] ?? SPACES.room;
  const w = wet ?? sp.wet;
  const pre = Math.round((sp.predelay * sr) / 1000);
  // comb feedback from RT60: after rt seconds the energy fell 60 dB (g^N = 1e-3)
  const combs = COMB_MS.map((ms) => {
    const L = Math.max(2, Math.round(((ms * sr) / 1000) * (0.6 + sp.rt / 3)));
    return { L, g: Math.pow(10, (-3 * L) / (sp.rt * sr)) };
  });
  const aps = AP_MS.map((ms) => ({ L: Math.max(2, Math.round((ms * sr) / 1000)), g: 0.5 }));
  const n = samples.length;
  const stage = new Float32Array(n + pre);
  for (let i = 0; i < n; i++) stage[i + Math.min(pre, n)] = samples[i]; // pre-delay
  // ---- parallel combs
  const mixed = new Float32Array(n + pre);
  for (const c of combs) {
    const buf = new Float32Array(c.L);
    let idx = 0;
    for (let i = 0; i < stage.length; i++) {
      const v = stage[i] + buf[idx] * c.g;
      buf[idx] = v;
      mixed[i] += v * 0.25;
      idx = (idx + 1) % c.L;
    }
  }
  // ---- series allpasses
  let cur = mixed;
  for (const a of aps) {
    const out = new Float32Array(cur.length);
    const buf = new Float32Array(a.L);
    let idx = 0;
    for (let i = 0; i < cur.length; i++) {
      const v = cur[i];
      const bv = buf[idx];
      const y = -a.g * v + bv;
      buf[idx] = v + a.g * bv;
      out[i] = y;
      idx = (idx + 1) % a.L;
    }
    cur = out;
  }
  const out = new Float32Array(n);
  for (let i = 0; i < n; i++) out[i] = samples[i] * (1 - w) + cur[i] * w;
  return out;
}

/** energy of the TAIL after the direct sound (first `lead` samples) */
export function tailEnergy(samples, lead = 64) {
  let e = 0;
  for (let i = lead; i < samples.length; i++) e += samples[i] * samples[i];
  return e;
}
