// UTS :: media/animation — keyframe tracks with interpolation and blending
// (walk/idle/jump as DATA, sampled deterministically).
export class Track {
  constructor({ target, prop, keys }) {
    this.target = target; this.prop = prop;
    this.keys = [...keys].sort((a, b) => a.t - b.t);
  }
  sample(t, ease = 'smooth') {
    const k = this.keys;
    if (t <= k[0].t) return k[0].v;
    if (t >= k[k.length - 1].t) return k[k.length - 1].v;
    let i = 0;
    while (k[i + 1].t < t) i++;
    const a = k[i], b = k[i + 1];
    let f = (t - a.t) / (b.t - a.t);
    if (ease === 'smooth') f = f * f * (3 - 2 * f);
    return a.v.map((v, j) => v + (b.v[j] - v) * f);
  }
}

export class Clip {
  constructor({ name, duration, tracks = [] }) {
    this.name = name; this.duration = duration; this.tracks = tracks;
  }
  pose(t) {
    const out = {};
    for (const tr of this.tracks) {
      out[tr.target] = out[tr.target] ?? {};
      out[tr.target][tr.prop] = tr.sample(((t % this.duration) + this.duration) % this.duration);
    }
    return out;
  }
}

export function blendPoses(a, b, w) {
  const out = {};
  const bones = new Set([...Object.keys(a), ...Object.keys(b)]);
  for (const bone of bones) {
    out[bone] = {};
    const props = new Set([...Object.keys(a[bone] ?? {}), ...Object.keys(b[bone] ?? {})]);
    for (const p of props) {
      const va = a[bone]?.[p], vb = b[bone]?.[p];
      out[bone][p] = va && vb ? va.map((v, i) => v + (vb[i] - v) * w) : (va ?? vb);
    }
  }
  return out;
}

/** the AI builds a walk clip from a style ("cansado", "marcial") */
export function walkClip({ style = 'normal', cadence = 1 } = {}) {
  const damp = style === 'cansado' ? 0.4 : style === 'marcial' ? 1.3 : 1;
  const T = 1 / cadence;
  const A = 28 * damp;
  const leg = (sign) => [
    { t: 0, v: [0, 0, 0] },
    { t: T / 4, v: [sign * A, 0, 0] },
    { t: T / 2, v: [0, 0, 0] },
    { t: 3 * T / 4, v: [-sign * A, 0, 0] },
    { t: T, v: [0, 0, 0] },
  ];
  return new Clip({
    name: `walk-${style}`,
    duration: T,
    tracks: [
      new Track({ target: 'legL', prop: 'rotX', keys: leg(1) }),
      new Track({ target: 'legR', prop: 'rotX', keys: leg(-1) }),
      new Track({ target: 'torso', prop: 'posY', keys: [{ t: 0, v: [0] }, { t: T / 4, v: [1.4 * damp] }, { t: T / 2, v: [0] }, { t: 3 * T / 4, v: [1.4 * damp] }, { t: T, v: [0] }] }),
    ],
  });
}
