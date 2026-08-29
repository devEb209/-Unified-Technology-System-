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
        cam: beat.cam ?? [0, 8, 14], cam2: beat.cam2 ?? (beat.cam ?? [0, 8, 14]), look: beat.look ?? [0, 0, 0],
        caption: beat.caption ?? '', fade: beat.fade ?? 'in',
      });
      t += beat.dur ?? 2.5;
    }
    if (shots.length === 0) throw new Error('cutscene sem planos (beats)');
    return new Cutscene({ name: brief.name ?? 'cena', shots });
  }

  /** easing suave da viagem de câmera (easeInOutQuad) */
  static ease(u) { const t = Math.max(0, Math.min(1, u)); return t < 0.5 ? 2 * t * t : 1 - ((-2 * t + 2) ** 2) / 2; }

  /**
   * POSE contínua: dentro de um plano a câmera VOA de cam→cam2 com easing
   * e MIRA o look (yaw/pitch derivados da geometria — mesma convenção do
   * renderer: fwd=[sin(yaw)cos(pitch), -sin(pitch), cos(yaw)cos(pitch)]).
   * Determinística: o mesmo t devolve a mesma pose.
   */
  pose(tNow = this.t ?? 0) {
    let active = this.shots[0];
    for (const s of this.shots) if (tNow >= s.t) active = s;
    const dur = active.dur ?? 2.5;
    const u = Math.max(0, Math.min(1, (tNow - active.t) / dur));
    const e = Cutscene.ease(u);
    const cam = active.cam ?? [0, 8, 14];
    const cam2 = active.cam2 ?? cam;
    const pos = [cam[0] + (cam2[0] - cam[0]) * e, cam[1] + (cam2[1] - cam[1]) * e, cam[2] + (cam2[2] - cam[2]) * e];
    const look = active.look ?? [0, 0, 0];
    const d = [look[0] - pos[0], look[1] - pos[1], look[2] - pos[2]];
    const len = Math.hypot(d[0], d[1], d[2]) || 1;
    const yaw = Math.atan2(d[0], d[2]);
    const pitch = -Math.asin(Math.max(-1, Math.min(1, d[1] / len)));
    return { pos, yaw, pitch, shot: active, letterbox: true, u: e, time: tNow };
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
