// UTS :: physics — OUR physics engine (no external library).
// Native fixed-step solver integrated with the UTS reality:
//   * RRW owns state: bodies are RRW entities ('prop' with physics component)
//   * spatial broadphase derives from the UTS SpatialGrid policy
//   * impacts are VERIFIABLE RRW causal events (citing their origin event)
//   * scheduled by the UES scheduler; D-O15 may halve its tick rate
//   * headless-testable, deterministic, measurable

import { dist2 } from '../core/math.js';
import { FLUID_CONST } from '../world/phenomena/fluids.js';

export const GRAVITY = -22; // slightly heroic, tuned for gameplay-scale worlds

// REAL MATERIALS: density (mass from volume), hardness (deformation
// resistance), toughness (impact energy the material absorbs without damage)
export const MATERIALS = {
  rock: { density: 2.6, hardness: 0.85, toughness: 60 },
  wood: { density: 0.7, hardness: 0.4, toughness: 18 },
  ice:  { density: 0.92, hardness: 0.18, toughness: 7 },
  flesh: { density: 1.05, hardness: 0.08, toughness: 3.5 },
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
   * A RAGDOLL is real anatomy: rigid segments linked by distance joints
   * (PBD), flesh material (deforms easily, barely bounces). All state in
   * the RRW — it survives save/load through reattach().
   */
  buildRagdoll(pos, { causeEvent = null, scale = 1 } = {}) {
    const mk = (dx, dy, dz, r, label) => this.addBody({
      pos: [pos[0] + dx * scale, pos[1] + dy * scale, pos[2] + dz * scale],
      radius: r * scale, material: 'flesh', label: `ragdoll-${label}`,
      restitution: 0.05, friction: 0.92, causeEvent,
    });
    const head = mk(0, 1.45, 0, 0.22, 'head');
    const torso = mk(0, 1.0, 0, 0.30, 'torso');
    const pelvis = mk(0, 0.55, 0, 0.26, 'pelvis');
    const armL = mk(-0.45, 1.0, 0, 0.12, 'arm');
    const armR = mk(0.45, 1.0, 0, 0.12, 'arm');
    const legL = mk(-0.18, 0.18, 0, 0.14, 'leg');
    const legR = mk(0.18, 0.18, 0, 0.14, 'leg');
    const j = (a, b) => this.addJoint(a.id, b.id, { stiffness: 0.9, causeEvent });
    j(head, torso); j(torso, pelvis); j(torso, armL); j(torso, armR); j(pelvis, legL); j(pelvis, legR);
    return { head: head.id, torso: torso.id, pelvis: pelvis.id, arms: [armL.id, armR.id], legs: [legL.id, legR.id] };
  }

  /**
   * NPC de pé = CÁPSULA para a física: corpo rápido que atravessa a pessoa
   * derruba (mesma lei do impacto) e PERDE MOMENTO (o corpo sente a
   * pessoa — conservação honesta, não fantasmo atravessando gente).
   */
  _collideNPCs(body, ph, sp, tick) {
    const rrw = this.world.rrw;
    const grid = this.world.grid;
    if (!grid?.queryCircle) return 0;
    const speed = Math.hypot(ph.vel[0], ph.vel[1], ph.vel[2]);
    if (speed < 2) return 0;
    let hits = 0;
    const r = ph.radius + 0.6;
    for (const id of grid.queryCircle(sp.pos[0], sp.pos[2], r)) {
      const npcC = rrw.getComponent(id, 'npc');
      if (!npcC) continue;
      const nsp = rrw.getComponent(id, 'spatial');
      const dx = nsp.pos[0] - sp.pos[0], dz = nsp.pos[2] - sp.pos[2];
      // a cápsula do NPC nasce NO TERRENO (o y guardado pode ser stale)
      const dv = (this.world.terrain.height(nsp.pos[0], nsp.pos[2]) ?? nsp.pos[1]) - sp.pos[1];
      if (dx * dx + dz * dz > r * r || Math.abs(dv) > 1.9) continue;
      hits++;
      const energy = 0.5 * (ph.mass ?? 1) * speed * speed;
      if (tick >= (npcC.downedUntil ?? 0)) {
        npcC.downedUntil = tick + 120;
        rrw.emitEvent({ type: 'npc.downed', subject: id, cause: null,
                        data: { energy: +energy.toFixed(1), by: 'corpo' }, tick });
      }
      ph.vel[0] *= 0.45; ph.vel[2] *= 0.45; // o corpo SENTIU a pessoa
      ph.vel[1] *= 0.7;
    }
    if (hits) this.stats.npcHits = (this.stats.npcHits ?? 0) + hits;
    return hits;
  }

  /** NÍVEL D'ÁGUA real sob (x,z): superfície = terreno + lâmina do fluido */
  _waterLevel(x, z) {
    const f = this.world.fluid;
    if (!f || !f.depth || f.depth.size === 0) return null;
    const k = f.key(Math.round(x / FLUID_CONST.CELL), Math.round(z / FLUID_CONST.CELL));
    const d = f.depth.get(k);
    if (!d || d <= 0.01) return null;
    return (this.world.terrain.height(x, z) ?? 0) + d;
  }

  /** ENTRAR NA ÁGUA com velocidade é um SOM e um evento causal (a água abafa ~metade da energia) */
  _splash(body, speed, tick, frac) {
    this.stats.splashes = (this.stats.splashes ?? 0) + 1;
    const rrw = this.world.rrw;
    const sp = rrw.getComponent(body.id, 'spatial');
    const mass = rrw.getComponent(body.id, 'physics')?.mass ?? 1;
    const energy = 0.5 * mass * speed * speed * (0.4 + 0.6 * frac);
    rrw.emitEvent({ type: 'physics.splash', subject: body.id, cause: null,
                    data: { speed: +speed.toFixed(2), energy: +energy.toFixed(1), frac: +frac.toFixed(2) }, tick });
    this.recentImpacts.push({ pos: [...sp.pos], energy: energy * 0.5, tick, key: `${body.id}:splash${this.stats.splashes}` });
    if (this.recentImpacts.length > 8) this.recentImpacts.shift();
  }

  /**
   * EMPUXO DE ARQUIMEDES + CORDAS vivem aqui embaixo (a água desloca
   * volume; corda = corrente de nós com juntas de distância PBD).
   */

  /**
   * A CORDA é real: corrente de nós (corpos pequenos) ligados por juntas
   * de distância PBD com comprimento de repouso = segmento. Tudo em RRW
   * (props + relações 'joint') ⇒ sobrevive a save/load via reattach().
   */
  buildRope({ from, to, segments = 8, causeEvent = null } = {}) {
    const n = Math.max(2, segments | 0);
    const seg = Math.hypot(to[0] - from[0], to[1] - from[1], to[2] - from[2]) / n;
    const nodes = [];
    for (let i = 0; i <= n; i++) {
      const t = i / n;
      const b = this.addBody({
        pos: [from[0] + (to[0] - from[0]) * t, from[1] + (to[1] - from[1]) * t, from[2] + (to[2] - from[2]) * t],
        radius: Math.max(0.08, seg * 0.12), material: 'wood', label: `rope-${i}`,
        restitution: 0.02, friction: 0.85, pinned: i === 0, causeEvent,
      });
      nodes.push(b.id);
    }
    for (let i = 0; i < n; i++) this.addJoint(nodes[i], nodes[i + 1], { rest: seg, stiffness: 1, causeEvent });
    // HONESTO: a corda é real PENDURADA (ponte, balanço, poliage); empilhar
    // nós no chão luta contra o contato e injeta energia no PBD implícito —
    // limite documentado do solver, não escondido.
    return { nodes, segment: +seg.toFixed(4) };
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
    omega = 0, pinned = false, material = 'rock', spin = null,
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
                   omega, inertia, spinFriction: 0.9, pinned, material, deformation: 0,
                   spin: spin ? [...spin] : [0, 0, 0], quat: [0, 0, 0, 1] },
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

      // ---- EMPUXO DE ARQUIMEDES (força, ANTES da integração — ordem
      // correta de Euler semi-implícito): a água desloca volume e o corpo
      // perde peso. Na convenção de massa do motor (m = ρV/4) a água tem
      // ρ=0.25, logo a fração submersa de equilíbrio É a densidade do
      // material: gelo (0.92) flutua 92% afundado como na realidade;
      // madeira (0.7) flutua leve; rocha (2.6) e carne (1.05) afundam.
      // Arrasto viscoso ∝ fração submersa (a água freia em toda direção).
      const wl = this._waterLevel(sp.pos[0], sp.pos[2]);
      let waterFrac = 0;
      if (wl !== null && sp.pos[1] - ph.radius < wl) {
        const sub = Math.min(2 * ph.radius, wl - (sp.pos[1] - ph.radius));
        waterFrac = Math.max(0, Math.min(1, sub / (2 * ph.radius)));
        const rho = (MATERIALS[ph.material ?? 'rock'] ?? MATERIALS.rock).density;
        ph.vel[1] += (-GRAVITY * waterFrac / rho) * dt;   // ρ_w·|G|·V_sub / m
        const wd = Math.exp(-2.2 * waterFrac * dt);
        ph.vel[0] *= wd; ph.vel[1] *= wd; ph.vel[2] *= wd;
        const inWater = waterFrac > 0.05;
        if (inWater && !ph._wasInWater) this._splash(body, Math.hypot(ph.vel[0], ph.vel[1], ph.vel[2]), tick, waterFrac);
        ph._wasInWater = inWater;
        // REALIDADE: corpo flutuando NÃO dorme — o empuxo é força viva
        // (o que repousa no leito sob lâmina fina pode dormir)
        if (waterFrac > 0.15) ph.asleep = false;
      } else if (ph._wasInWater) ph._wasInWater = false;

      // integrate (semi-implicit Euler) + planar rotation
      ph.vel[1] += GRAVITY * dt;
      for (let i = 0; i < 3; i++) sp.pos[i] += ph.vel[i] * dt;
      sp.yaw = (sp.yaw ?? 0) + ph.omega * dt;
      sp.__v = tick ?? sp.__v; // stamped for per-entity deltas
      // ---- FREE 3D ROTATION (quaternion): q̇ = ½·ω⊗q, renormalized. The
      // renderer's planar yaw is DERIVED from q (one truth, no double state).
      const w = ph.spin;
      if (w && (w[0] !== 0 || w[1] !== 0 || w[2] !== 0)) {
        const q = ph.quat;
        const hx = w[0] * dt * 0.5, hy = w[1] * dt * 0.5, hz = w[2] * dt * 0.5;
        const x = q[0], y = q[1], z = q[2], qw = q[3];
        q[0] = x + (hx * qw + hy * z - hz * y);
        q[1] = y + (hy * qw + hz * x - hx * z);
        q[2] = z + (hz * qw + hx * y - hy * x);
        q[3] = qw - (hx * x + hy * y + hz * z);
        const lq = Math.hypot(q[0], q[1], q[2], q[3]) || 1;
        q[0] /= lq; q[1] /= lq; q[2] /= lq; q[3] /= lq;
        // yaw DERIVED from the UPDATED orientation (one truth, no stale frame)
        sp.yaw = Math.atan2(2 * (q[3] * q[2] + q[0] * q[1]), 1 - 2 * (q[1] * q[1] + q[2] * q[2]));
        ph.omega = w[1];
      }

      this._collideNPCs(body, ph, sp, tick);
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
        const gd = 1 - Math.min(0.9, ph.friction * dt * 4); // the ground brakes the spin
        ph.spin[0] *= gd; ph.spin[1] *= gd; ph.spin[2] *= gd;
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
