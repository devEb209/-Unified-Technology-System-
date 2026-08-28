// UTS :: audio/spatial — OUR spatializer.
// Listener-centric attenuation + stereo pan from world positions.
// Pure math; the Frame/camera feed the listener; RRW positions feed emitters.

export function spatialize({ emitterPos, listener, refDist = 12, rolloff = 1.2, maxDist = 160 }) {
  const dx = emitterPos[0] - listener.pos[0];
  const dz = emitterPos[2] - listener.pos[2];
  const dy = (emitterPos[1] ?? 0) - (listener.pos[1] ?? 0);
  const d = Math.hypot(dx, dy, dz);
  if (d > maxDist) return { gain: 0, pan: 0, dist: d, audible: false };
  const gain = Math.min(1, refDist / (refDist + Math.max(0, d - refDist) * rolloff));
  // pan from the listener's yaw: right vector = (cos yaw, -sin yaw) on (x, z)
  const rx = Math.cos(listener.yaw ?? 0);
  const rz = -Math.sin(listener.yaw ?? 0);
  const lateral = d > 0.001 ? (dx * rx + dz * rz) / d : 0;
  return { gain, pan: Math.max(-1, Math.min(1, lateral)), dist: d, audible: gain > 0.01 };
}


// ------------------------------------------------------- binaural (ours)
// Head model: ITD (interaural time difference, woodworth max ~0.65ms) via
// OUR fractional delay, + ILD (head shadow: the far ear gets a darker,
// quieter signal). Front/back is honestly ambiguous in stereo (no pinna
// spectral cues) — documented, not faked. Pure math, zero deps.

const MAX_ITD_SEC = 0.00065;
const SHADOW_LP = 750;     // Hz, contralateral head-shadow filter
const SHADOW_GAIN = 0.42;  // how quiet the shadowed ear gets

function fracDelay(samples, delaySamples) {
  if (delaySamples <= 0.0001) return samples;
  const out = new Float32Array(samples.length);
  for (let i = 0; i < samples.length; i++) {
    const x = i - delaySamples;
    const j = Math.floor(x);
    const frac = x - j;
    const a = samples[Math.max(0, j)] ?? 0;
    const b = samples[Math.max(0, j + 1)] ?? 0;
    out[i] = a + (b - a) * frac;
  }
  return out;
}

function onePole(samples, cutoffHz, sr) {
  const a = Math.exp(-2 * Math.PI * cutoffHz / sr);
  let y = 0;
  const out = new Float32Array(samples.length);
  for (let i = 0; i < samples.length; i++) {
    y = a * y + (1 - a) * samples[i];
    out[i] = y;
  }
  return out;
}

/** render an emitter's samples into LEFT/RIGHT ear signals (binaural). */
export function renderBinaural(samples, { emitterPos, listener, sr = 22050, refDist = 8, maxDist = 160 } = {}) {
  const sp = spatialize({ emitterPos, listener, refDist, maxDist });
  if (!sp.audible) return { left: new Float32Array(samples.length), right: new Float32Array(samples.length), gain: 0, audible: false };
  const lateral = sp.pan; // -1 hard left … +1 hard right
  // ITD: the NEAR ear hears instantly; the FAR ear is delayed by up to 0.65ms
  const delayL = MAX_ITD_SEC * Math.max(0, lateral);  // source right → LEFT ear delayed
  const delayR = MAX_ITD_SEC * Math.max(0, -lateral); // source left → RIGHT ear delayed
  let left = fracDelay(samples, delayL * sr);
  let right = fracDelay(samples, delayR * sr);
  // ILD: the shadowed (far) ear is quieter AND darker
  if (lateral > 0) {        // source on the right → LEFT ear is shadowed
    const dark = onePole(left, SHADOW_LP, sr);
    const mixed = new Float32Array(left.length);
    for (let i = 0; i < left.length; i++) mixed[i] = left[i] * 0.25 + dark[i] * 0.75;
    left = mixed;
  } else if (lateral < 0) { // source on the left → RIGHT ear is shadowed
    const dark = onePole(right, SHADOW_LP, sr);
    const mixed = new Float32Array(right.length);
    for (let i = 0; i < right.length; i++) mixed[i] = right[i] * 0.25 + dark[i] * 0.75;
    right = mixed;
  }
  for (let i = 0; i < samples.length; i++) {
    left[i] *= sp.gain;
    right[i] *= sp.gain;
  }
  return { left, right, gain: sp.gain, dist: sp.dist, audible: true };
}
