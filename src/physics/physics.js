// UTS :: physics — OUR physics engine (no external library).
// Native fixed-step solver integrated with the UTS reality:
//   * RRW owns state: bodies are RRW entities ('prop' with physics component)
//   * spatial broadphase derives from the UTS SpatialGrid policy
//   * impacts are VERIFIABLE RRW causal events (citing their origin event)
//   * scheduled by the UES scheduler; D-O15 may halve its tick rate
//   * headless-testable, deterministic, measurable

import { dist2 } from '../core/math.js';

export const GRAVITY = -22; // slightly heroic, tuned for gameplay-scale worlds

export class PhysicsWorld {
  constructor({ world, tese = null } = {}) {
    this.world = world;
    this.tese = tese;
    /** entityId -> body */
    this.bodies = new Map();
    this.cellSize = 6;
    this.stats = { steps: 0, contacts: 0, impacts: 0, sleeps: 0 };
    this.substeps = 2;
  }

  /** create a dynamic body as an RRW entity (physics + spatial components) */
  addBody({
    pos, vel = [0, 0, 0], radius = 0.6, mass = 1,
    restitution = 0.35, friction = 0.7, causeEvent = null, label = 'rock',
  }) {
    const ent = this.world.rrw.createEntity({
      kind: 'prop',
      materialization: 'full',
      importance: 0.5,
      tags: ['physics', label],
      pos: [pos[0], pos[1] ?? 0, pos[2]],
      components: {
        physics: { vel: [...vel], radius, mass, restitution, friction, asleep: false, causeEvent },
      },
    });
    this.world.grid.update(ent.id, pos[0], pos[2]);
    this.bodies.set(ent.id, ent);
    return ent;
  }

  removeBody(id) {
    this.bodies.delete(id);
  }

  _impact(body, speed, tick) {
    this.stats.impacts++;
    const hz = this.world.rrw.getComponent(body.id, 'physics');
    this.world.rrw.emitEvent({
      type: 'physics.impact',
      subject: body.id,
      cause: hz?.causeEvent ?? null, // verifiable chain back to the origin
      data: { speed: +speed.toFixed(2), pos: [...this.world.rrw.getComponent(body.id, 'spatial').pos] },
      tick,
    });
    this.tese?.touch('D-2', `physics.impact speed=${speed.toFixed(1)}`, tick);
  }

  /** one fixed step: integrate + collide (ground + sphere-sphere) */
  step(dt, { tick = null } = {}) {
    const { terrain, rrw, grid } = this.world;
    let contacts = 0;

    for (const body of this.bodies.values()) {
      const ph = rrw.getComponent(body.id, 'physics');
      const sp = rrw.getComponent(body.id, 'spatial');
      if (ph.asleep) continue;

      // integrate (semi-implicit Euler)
      ph.vel[1] += GRAVITY * dt;
      for (let i = 0; i < 3; i++) sp.pos[i] += ph.vel[i] * dt;

      // ground collision from the REPRESENTED heightfield
      const h = terrain.height(sp.pos[0], sp.pos[2]);
      if (sp.pos[1] - ph.radius < h) {
        const impactSpeed = -ph.vel[1];
        sp.pos[1] = h + ph.radius;
        if (impactSpeed > 3) this._impact(body, impactSpeed, tick);
        ph.vel[1] = impactSpeed > 1 ? impactSpeed * ph.restitution : 0;
        ph.vel[0] *= 1 - ph.friction * dt * 8;
        ph.vel[2] *= 1 - ph.friction * dt * 8;
        contacts++;
        if (Math.abs(ph.vel[1]) < 0.4 && Math.hypot(ph.vel[0], ph.vel[2]) < 0.15) {
          ph.asleep = true;
          ph.vel[0] = ph.vel[1] = ph.vel[2] = 0;
          this.stats.sleeps++;
        }
      }
      grid.update(body.id, sp.pos[0], sp.pos[2]); // index stays synchronized
    }

    // sphere-sphere via uniform broadphase over DYNAMIC bodies only
    const cells = new Map();
    for (const body of this.bodies.values()) {
      const sp = rrw.getComponent(body.id, 'spatial');
      const k = `${Math.floor(sp.pos[0] / this.cellSize)},${Math.floor(sp.pos[2] / this.cellSize)}`;
      if (!cells.has(k)) cells.set(k, []);
      cells.get(k).push(body);
    }
    for (const bucket of cells.values()) {
      for (let i = 0; i < bucket.length; i++) {
        for (let j = i + 1; j < bucket.length; j++) this._resolvePair(bucket[i], bucket[j], (c) => contacts += c);
      }
    }
    this.stats.contacts += contacts;
    this.stats.steps++;
    return { contacts, bodies: this.bodies.size };
  }

  _resolvePair(a, b, addContact) {
    const rrw = this.world.rrw;
    const pa = rrw.getComponent(a.id, 'spatial'), pb = rrw.getComponent(b.id, 'spatial');
    const ba = rrw.getComponent(a.id, 'physics'), bb = rrw.getComponent(b.id, 'physics');
    if (ba.asleep && bb.asleep) return;
    const dx = pb.pos[0] - pa.pos[0], dy = pb.pos[1] - pa.pos[1], dz = pb.pos[2] - pa.pos[2];
    const d = Math.hypot(dx, dy, dz) || 0.0001;
    const minD = ba.radius + bb.radius;
    if (d >= minD) return;
    addContact(1);
    // separate + impulse along the contact normal (equal treatment by mass)
    const nx = dx / d, ny = dy / d, nz = dz / d;
    const overlap = (minD - d) / 2;
    pa.pos[0] -= nx * overlap; pa.pos[1] -= ny * overlap; pa.pos[2] -= nz * overlap;
    pb.pos[0] += nx * overlap; pb.pos[1] += ny * overlap; pb.pos[2] += nz * overlap;
    const rel = (bb.vel[0] - ba.vel[0]) * nx + (bb.vel[1] - ba.vel[1]) * ny + (bb.vel[2] - ba.vel[2]) * nz;
    if (rel < 0) {
      const e = Math.min(ba.restitution, bb.restitution);
      const jimp = -(1 + e) * rel / 2;
      ba.vel[0] -= jimp * nx; ba.vel[1] -= jimp * ny; ba.vel[2] -= jimp * nz;
      bb.vel[0] += jimp * nx; bb.vel[1] += jimp * ny; bb.vel[2] += jimp * nz;
      ba.asleep = bb.asleep = false;
    }
  }

  /** ray vs bodies (spheres) + terrain heightmarch — used by tools/AI queries */
  raycast(origin, dir, maxDist = 200) {
    const rrw = this.world.rrw;
    let best = null;
    for (const body of this.bodies.values()) {
      const sp = rrw.getComponent(body.id, 'spatial');
      const ph = rrw.getComponent(body.id, 'physics');
      const ox = sp.pos[0] - origin[0], oy = sp.pos[1] - origin[1], oz = sp.pos[2] - origin[2];
      const t = ox * dir[0] + oy * dir[1] + oz * dir[2];
      if (t < 0) continue;
      const px = origin[0] + dir[0] * t, py = origin[1] + dir[1] * t, pz = origin[2] + dir[2] * t;
      const dd = (px - sp.pos[0]) ** 2 + (py - sp.pos[1]) ** 2 + (pz - sp.pos[2]) ** 2;
      if (dd <= ph.radius * ph.radius && (!best || t < best.dist)) {
        best = { dist: t, id: body.id, kind: 'body', point: [px, py, pz] };
      }
    }
    // terrain march
    const stepLen = 2;
    for (let s = stepLen; s <= maxDist; s += stepLen) {
      const x = origin[0] + dir[0] * s, y = origin[1] + dir[1] * s, z = origin[2] + dir[2] * s;
      if (y <= this.world.terrain.height(x, z)) {
        if (!best || s < best.dist) best = { dist: s, id: null, kind: 'terrain', point: [x, y, z] };
        break;
      }
    }
    return best;
  }

  report() {
    return { ...this.stats, bodies: this.bodies.size };
  }
}
