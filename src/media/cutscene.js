// UTS :: media/cutscene — the DIRECTOR: a timeline of SHOTS (camera, caption,
// letterbox) built from a natural-language brief, driven by world time. The
// camera of the UES is moved BY the director; gameplay pauses its control.
export class Cutscene {
  constructor({ name, shots, onEnd = null } = {}) {
    this.name = name;
    this.shots = [...shots].sort((a, b) => a.t - b.t);
    this.duration = Math.max(...this.shots.map(s => s.t + (s.dur ?? 3)));
    this.onEnd = onEnd;
    this.t = null; // null = not playing
  }

  /** brief → shots (the AI stages the scene; deterministic) */
  static fromBrief(brief = {}) {
    const shots = [];
    let t = 0;
    for (const beat of brief.beats ?? []) {
      shots.push({
        t,
        dur: beat.dur ?? 2.5,
        cam: beat.cam ?? [0, 8, 14], look: beat.look ?? [0, 0, 0],
        caption: beat.caption ?? '', fade: beat.fade ?? 'in',
      });
      t += beat.dur ?? 2.5;
    }
    if (shots.length === 0) throw new Error('cutscene sem planos (beats)');
    return new Cutscene({ name: brief.name ?? 'cena', shots });
  }

  /** advance; the FIRST call starts playback. Returns the ACTIVE shot. */
  update(dt, applyCam = null) {
    if (this.t === null) this.t = 0; // play() implícito no primeiro update
    this.t += dt;
    let active = this.shots[0];
    for (const s of this.shots) if (this.t >= s.t) active = s;
    if (applyCam) applyCam(active);
    if (this.t >= this.duration) {
      this.t = null;
      if (this.onEnd) this.onEnd();
      return { ended: true };
    }
    return { shot: active, letterbox: true, time: this.t };
  }
}
