// UTS :: physics — OUR physics engine (no external library).
// Native fixed-step solver integrated with the UTS reality:
//   * RRW owns state: bodies are RRW entities ('prop' with physics component)
//   * spatial broadphase derives from the UTS SpatialGrid policy
//   * impacts are VERIFIABLE RRW causal events (citing their origin event)
//   * scheduled by the UES scheduler; D-O15 may halve its tick rate
//   * headless-testable, deterministic, measurable

import { dist2 } from '../core/math.js';

export const GRAVITY = -22; // slightly heroic, tuned for gameplay-scale worlds

// REAL MATERIALS: density (mass from volume), hardness (deformation
// resistance), toughness (impact energy the material absorbs without damage)
export const MATERIALS = {
  rock: { density: 2.6, hardness: 0.85, toughness: 60 },
  wood: { density: 0.7, hardness: 0.4, toughness: 18 },
  ice:  { density: 0.92, hardness: 0.18, toughness: 7 },
};

export class PhysicsWorld {
  constructor({ world, tese = null } = {}) {
    this.world = world;
    this.tese = tese;
    /** entityId -> body */
    this.bodies = new Map();
    this.cellSize = 6;
    this.stats = { steps: 0, contacts: 0, impacts: 0, sleeps: 0, torques: 0, deformations: 0 };
    this.recentImpacts = [];  // acoustic sources (pos+energy+tick), consumed by audioState
    this.substeps = 2;
    /** joint cache — the truth lives in RRW relations of type 'joint'; this is derived */
    this.joints = [];
    this.jointIters = 4;
  }

  /**
   * Distance joint between two bodies — stored as an RRW relation of type
   * 'joint' (causal state in the single source of truth; this cache is
   * derived via reattach). rest defaults to the current separation.
   */
  addJoint(aId, bId, { rest = null, stiffness = 1, causeEvent = null } = {}) {
    const rrw = this.world.rrw;
    const pa = rrw.getComponent(aId, 'spatial'), pb = rrw.getComponent(bId, 'spatial');
    if (!pa || !pb) throw new Error('addJoint needs two physics bodies');
    const d = Math.hypot(pb.pos[0] - pa.pos[0], pb.pos[1] - pa.pos[1], pb.pos[2] - pa.pos[2]);
    const rel = rrw.addRelation(aId, bId, 'joint', {
      weight: stiffness,
      data: { rest: rest ?? d, causeEvent },
    });
    this.joints.push(rel);
    return rel;
  }

  /**
   * Rebuild the derived caches (bodies + joints) FROM the RRW — called by
   * snapshot.load() so a restored world keeps its physics exactly. This is
   * the fix for "bodies vanish across save/load": RRW is the truth.
   */
  reattach() {
    const rrw = this.world.rrw;
    this.bodies.clear();
    for (const id of rrw.query({ kind: 'prop' })) {
      const ph = rrw.getComponent(id, 'physics');
      const sp = rrw.getComponent(id, 'spatial');
      if (ph && sp) this.bodies.set(id, rrw.get(id));
    }
    this.joints = [];
    for (const rel of rrw.relations.values()) {
      if (rel.type === 'joint' && this.bodies.has(rel.a) && this.bodies.has(rel.b)) {
        this.joints.push(rel);
      }
    }
    return { bodies: this.bodies.size, joints: this.joints.length };
  }

  /** create a dynamic body as an RRW entity (physics + spatial components) */
  addBody({
    pos, vel = [0, 0, 0], radius = 0.6, mass = null,
    restitution = 0.35, friction = 0.7, causeEvent = null, label = 'rock',
    omega = 0, pinned = false, material = 'rock',
  }) {
    // REALITY: mass comes from the MATERIAL's density and the body's volume
    // (rock is heavy, wood is light); deformation behavior follows the material.
    const mat = MATERIALS[material] ?? MATERIALS.rock;
    const m = mass ?? Math.max(0.2, mat.density * (4 / 3) * Math.PI * radius ** 3 / 4);
    // planar rotation (yaw) with disc inertia — matches OUR renderer's
    // instance transform; full 3D ragdoll rotation stays PLANNED (honest)
    const inertia = 0.4 * m * radius * radius;
    const ent = this.world.rrw.createEntity({
      kind: 'prop',
      materialization: 'full',
      importance: 0.5,
      tags: ['physics', label],
      pos: [pos[0], pos[1] ?? 0, pos[2]],
      yaw: 0,
      components: {
        physics: { vel: [...vel], radius, mass: m, restitution, friction, asleep: false, causeEvent,
                   omega, inertia, spinFriction: 0.9, pinned, material, deformation: 0 },
      },
    });
    this.world.grid.update(ent.id, pos[0], pos[2]);
    this.bodies.set(ent.id, ent);
    return ent;
  }

  removeBody(id) {
    this.bodies.delete(id);
  }

  /**
   * An impact converts KINETIC ENERGY (½mv²) into deformation, sound and
   * heat — the body's story is written ON the body as persistent state
   * (RRW physics component), never on a prop scoreboard.
   */
  _impact(body, speed, tick) {
    this.stats.impacts++;
    const rrw = this.world.rrw;
    const ph = rrw.getComponent(body.id, 'physics');
    const sp = rrw.getComponent(body.id, 'spatial');
    const energy = 0.5 * (ph.mass ?? 1) * speed * speed;            // joules (scaled world)
    // ---- DEFORMATION: energy above the material's toughness permanently
    // changes the body (restitution decays, wear accumulates). Hard rock
    // shrugs off hits that shatter ice.
    const mat = MATERIALS[ph.material ?? 'rock'];
    let deformed = 0;
    if (energy > mat.toughness) {
      deformed = Math.min(0.7, ((energy - mat.toughness) / mat.toughness) * 0.3) * (1 - mat.hardness * 0.85);
      ph.deformation = Math.min(1, (ph.deformation ?? 0) + deformed);
      ph.restitution = Math.max(0.04, ph.restitution * (1 - 0.35 * deformed)); // damaged bodies bounce less
      this.stats.deformations = (this.stats.deformations ?? 0) + 1;
    }
    rrw.emitEvent({
      type: 'physics.impact',
      subject: body.id,
      cause: ph?.causeEvent ?? null, // verifiable chain back to the origin
      data: { speed: +speed.toFixed(2), energy: +energy.toFixed(1), deformed: +deformed.toFixed(3),
              deformation: +(ph.deformation ?? 0).toFixed(3), pos: [...sp.pos] },
      tick,
    });
    // ---- SOUND energy is real: recent impacts become audible one-shots
    // (reallife.audioState converts them through ACOUSTICS — distance, shadow)
    this.recentImpacts = this.recentImpacts ?? [];
    this.recentImpacts.push({ pos: [...sp.pos], energy, tick, key: `${body.id}:${this.stats.impacts}` });
    if (this.recentImpacts.length > 8) this.recentImpacts.shift();
    this.tese?.touch('D-2', `physics.impact energy=${energy.toFixed(1)}`, tick);
  }

  /** one fixed step: integrate + collide (ground + sphere-sphere) */
  step(dt, { tick = null } = {}) {
    const { terrain, rrw, grid } = this.world;
    let contacts = 0;

    for (const body of this.bodies.values()) {
      const ph = rrw.getComponent(body.id, 'physics');
      const sp = rrw.getComponent(body.id, 'spatial');
      if (ph.asleep || ph.pinned) continue;

      // integrate (semi-implicit Euler) + planar rotation
      ph.vel[1] += GRAVITY * dt;
      for (let i = 0; i < 3; i++) sp.pos[i] += ph.vel[i] * dt;
      sp.yaw = (sp.yaw ?? 0) + ph.omega * dt;

      // ground collision from the REPRESENTED heightfield
      const h = terrain.height(sp.pos[0], sp.pos[2]);
      if (sp.pos[1] - ph.radius < h) {
        const impactSpeed = -ph.vel[1];
        sp.pos[1] = h + ph.radius;
        if (impactSpeed > 3) this._impact(body, impactSpeed, tick);
        // off-center ground impact TUMBLES the body: horizontal velocity
        // against the ground plane converts to spin (r × J / inertia), all
        // deterministic from the geometry — no randomness.
        const hSpeed = Math.hypot(ph.vel[0], ph.vel[2]);
        if (impactSpeed > 1 && hSpeed > 0.1) {
          const torque = (ph.vel[2] * -1 + ph.vel[0]) * hSpeed * ph.radius / ph.inertia;
          ph.omega += torque * 0.12;
          this.stats.torques++;
        }
        ph.vel[1] = impactSpeed > 1 ? impactSpeed * ph.restitution : 0;
        // rolling contact: spin decays slower than sliding; rolling couples
        const rolling = Math.abs(ph.omega) * ph.radius;
        const damp = Math.exp(-ph.friction * dt * (hSpeed > rolling + 0.05 ? 8 : 1.2));
        ph.vel[0] *= damp; ph.vel[2] *= damp;
        ph.omega *= Math.exp(-ph.spinFriction * dt * 1.5);
        contacts++;
        if (Math.abs(ph.vel[1]) < 0.4 && Math.hypot(ph.vel[0], ph.vel[2]) < 0.15 && Math.abs(ph.omega) < 0.15) {
          ph.asleep = true;
          ph.vel[0] = ph.vel[1] = ph.vel[2] = 0;
          ph.omega = 0;
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
    this._solveJoints(dt);
    this.stats.contacts += contacts;
    this.stats.steps++;
    return { contacts, bodies: this.bodies.size };
  }

  /** position-based distance joints (sequential, mass-weighted, stable).
   *  Velocities are IMPLIED by the position corrections (textbook PBD):
   *  this kills both residual stretch and oscillation deterministically. */
  _solveJoints(dt) {
    const rrw = this.world.rrw;
    if (this.joints.length === 0) return;
    const pre = new Map(); // id -> [x,y,z,vx,vy,vz]
    const record = (id) => {
      const sp = rrw.getComponent(id, 'spatial'), ph = rrw.getComponent(id, 'physics');
      pre.set(id, [sp.pos[0], sp.pos[1], sp.pos[2], ph.vel[0], ph.vel[1], ph.vel[2]]);
    };
    for (const rel of this.joints) { record(rel.a); record(rel.b); }
    for (let iter = 0; iter < this.jointIters; iter++) {
      for (const rel of this.joints) {
        const a = this.bodies.get(rel.a), b = this.bodies.get(rel.b);
        if (!a || !b) continue;
        const ba = rrw.getComponent(rel.a, 'physics'), bb = rrw.getComponent(rel.b, 'physics');
        const pa = rrw.getComponent(rel.a, 'spatial'), pb = rrw.getComponent(rel.b, 'spatial');
        if (ba.pinned && bb.pinned) continue;
        const dx = pb.pos[0] - pa.pos[0], dy = pb.pos[1] - pa.pos[1], dz = pb.pos[2] - pa.pos[2];
        const d = Math.hypot(dx, dy, dz) || 1e-6;
        const err = d - rel.data.rest;
        if (Math.abs(err) < 1e-5) continue;
        const ma = ba.pinned ? 0 : ba.mass, mb = bb.pinned ? 0 : bb.mass;
        const wSum = (ma + mb) || 1;
        const k = rel.weight ?? 1;
        const corr = (err / d) * k / this.jointIters;
        pa.pos[0] += dx * corr * (ma / wSum); pa.pos[1] += dy * corr * (ma / wSum); pa.pos[2] += dz * corr * (ma / wSum);
        pb.pos[0] -= dx * corr * (mb / wSum); pb.pos[1] -= dy * corr * (mb / wSum); pb.pos[2] -= dz * corr * (mb / wSum);
        if (ba.asleep && !bb.pinned) ba.asleep = false;
        if (bb.asleep && !ba.pinned) bb.asleep = false;
      }
    }
    // implied velocity: the position the solver produced IS the motion
    for (const [id, p0] of pre) {
      const ph = rrw.getComponent(id, 'physics');
      if (ph.pinned) continue;
      const sp = rrw.getComponent(id, 'spatial');
      ph.vel[0] = (sp.pos[0] - p0[0]) / dt;
      ph.vel[1] = (sp.pos[1] - p0[1]) / dt;
      ph.vel[2] = (sp.pos[2] - p0[2]) / dt;
      if (ph.asleep && Math.hypot(ph.vel[0], ph.vel[2]) > 2) ph.asleep = false;
    }
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
    // separate + impulse along the contact normal (mass-weighted below)
    const nx = dx / d, ny = dy / d, nz = dz / d;
    // mass-weighted separation (pinned = infinite mass)
    const wa = ba.pinned ? 0 : 1, wb = bb.pinned ? 0 : 1;
    const wSum = (wa + wb) || 1;
    const overlap = minD - d;
    pa.pos[0] -= nx * overlap * (wa / wSum); pa.pos[1] -= ny * overlap * (wa / wSum); pa.pos[2] -= nz * overlap * (wa / wSum);
    pb.pos[0] += nx * overlap * (wb / wSum); pb.pos[1] += ny * overlap * (wb / wSum); pb.pos[2] += nz * overlap * (wb / wSum);
    const rel = (bb.vel[0] - ba.vel[0]) * nx + (bb.vel[1] - ba.vel[1]) * ny + (bb.vel[2] - ba.vel[2]) * nz;
    if (rel < 0) {
      const e = Math.min(ba.restitution, bb.restitution);
      const ma = ba.pinned ? 0 : ba.mass, mb = bb.pinned ? 0 : bb.mass;
      const mSum = (ma + mb) || 1;
      const jimp = -(1 + e) * rel / mSum;
      ba.vel[0] -= jimp * nx * mb; ba.vel[1] -= jimp * ny * mb; ba.vel[2] -= jimp * nz * mb;
      bb.vel[0] += jimp * nx * ma; bb.vel[1] += jimp * ny * ma; bb.vel[2] += jimp * nz * ma;
      // tangential relative velocity at the contact SPINS the bodies (r×J/θ)
      const tx = (bb.vel[0] - ba.vel[0]) - rel * nx;
      const tz = (bb.vel[2] - ba.vel[2]) - rel * nz;
      const tangent = tx * -nz + tz * nx; // y-component of the cross product
      ba.omega += -tangent * ba.radius / ba.inertia * 0.5;
      bb.omega += -tangent * bb.radius / bb.inertia * 0.5;
      this.stats.torques++;
      if (!ba.pinned) ba.asleep = false;
      if (!bb.pinned) bb.asleep = false;
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
    return { ...this.stats, bodies: this.bodies.size, recentImpacts: this.recentImpacts.length };
  }
}
