import * as THREE from 'three';
import { clamp, damp, randn } from '../core/noise.js';

const WEAPON_AI = {
  muzzleVelocity: 715, bulletMass: 0.004, bc: 0.304, penetration: 0.7,
  moa: 9, tracerEvery: 5, suppressed: false, caliber: '5.56x45', rpm: 620
};

function humanoid(mats, palette = 0x3d4237) {
  const g = new THREE.Group();
  const cloth = new THREE.MeshStandardMaterial({ color: palette, roughness: 0.94 });
  const gear = new THREE.MeshStandardMaterial({ color: 0x22251f, roughness: 0.85 });
  const skin = mats.skin;

  const mk = (w, h, d, m, x, y, z) => {
    const o = new THREE.Mesh(new THREE.BoxGeometry(w, h, d), m);
    o.position.set(x, y, z); o.castShadow = true; o.receiveShadow = true; return o;
  };
  const hips = new THREE.Group(); hips.position.y = 0.92; g.add(hips);
  const torso = mk(0.42, 0.56, 0.24, cloth, 0, 0.28, 0); hips.add(torso);
  const rig = mk(0.44, 0.34, 0.28, gear, 0, 0.30, 0.01); hips.add(rig);       // colete
  const head = new THREE.Group(); head.position.y = 0.62; hips.add(head);
  head.add(mk(0.19, 0.23, 0.20, skin, 0, 0.1, 0));
  head.add(mk(0.23, 0.12, 0.25, gear, 0, 0.19, -0.01));                        // capacete
  const armL = new THREE.Group(); armL.position.set(-0.26, 0.5, 0); hips.add(armL);
  armL.add(mk(0.13, 0.5, 0.13, cloth, 0, -0.25, 0));
  const armR = new THREE.Group(); armR.position.set(0.26, 0.5, 0); hips.add(armR);
  armR.add(mk(0.13, 0.5, 0.13, cloth, 0, -0.25, 0));
  const legL = new THREE.Group(); legL.position.set(-0.11, 0, 0); hips.add(legL);
  legL.add(mk(0.16, 0.9, 0.16, cloth, 0, -0.45, 0));
  const legR = new THREE.Group(); legR.position.set(0.11, 0, 0); hips.add(legR);
  legR.add(mk(0.16, 0.9, 0.16, cloth, 0, -0.45, 0));

  // fuzil
  const rifle = new THREE.Group();
  rifle.add(mk(0.05, 0.09, 0.62, mats.gunmetal, 0, 0, 0));
  rifle.add(mk(0.04, 0.16, 0.06, mats.polymer, 0, -0.12, 0.02));
  rifle.position.set(0.24, 0.36, -0.28); hips.add(rifle);

  g.userData = { hips, head, armL, armR, legL, legR, rifle, torso };
  return g;
}

let NEXT_ID = 1;

export class Soldier {
  constructor(scene, world, audio, ballistics, mats, opts = {}) {
    this.id = NEXT_ID++;
    this.scene = scene; this.world = world; this.audio = audio; this.ballistics = ballistics;
    this.faction = opts.faction || 'red';
    this.pos = (opts.pos || new THREE.Vector3()).clone();
    this.pos.y = world.height(this.pos.x, this.pos.z);
    this.yaw = opts.yaw ?? Math.random() * 6.28;
    this.vel = new THREE.Vector3();
    this.alive = true;
    this.health = 1;
    this.stance = 'stand';
    this.state = 'patrol';
    this.alert = 0;              // 0 calmo -> 1 combate
    this.suspicion = 0;
    this.lastKnown = null;
    this.target = null;
    this.reactionTimer = 0;
    this.fireTimer = 0;
    this.burst = 0;
    this.mag = 30;
    this.shotCount = 0;
    this.route = opts.route || null;
    this.routeIdx = 0;
    this.waitT = 0;
    this.animT = Math.random() * 10;
    this.deadT = 0;
    this.isSentry = !!opts.sentry;
    this.squad = opts.squad || null;
    this.mesh = humanoid(mats, this.faction === 'red' ? 0x3a3f34 : 0x2d3543);
    this.mesh.position.copy(this.pos);
    scene.add(this.mesh);
    this.eyeH = 1.62;
    this.searchT = 0;
    this.radioT = 0;
  }

  get eye() { return new THREE.Vector3(this.pos.x, this.pos.y + (this.stance === 'crouch' ? 1.05 : this.eyeH), this.pos.z); }

  raycastCapsule(origin, dir, len) {
    if (!this.alive) return null;
    const h = this.stance === 'crouch' ? 1.2 : 1.8;
    const c = new THREE.Vector3(this.pos.x, this.pos.y + h * 0.52, this.pos.z);
    const r = 0.3;
    const oc = origin.clone().sub(c);
    const b = 2 * oc.dot(dir);
    const cc = oc.dot(oc) - (r + h * 0.32) ** 2;
    const disc = b * b - 4 * cc;
    if (disc < 0) return null;
    const t = (-b - Math.sqrt(disc)) / 2;
    if (t < 0 || t > len) return null;
    const p = origin.clone().addScaledVector(dir, t);
    const rel = p.y - this.pos.y;
    const part = rel > h * 0.85 ? 'head' : rel > h * 0.45 ? 'torso' : 'legs';
    return { t, point: p, part };
  }

  applyBullet(point, dir, energy, part, shooter) {
    if (!this.alive) return;
    const mult = part === 'head' ? 8 : part === 'torso' ? 1.25 : 0.5;
    const dmg = clamp(energy / 2200, 0.05, 1.2) * mult;
    this.health -= dmg;
    this.alert = 1;
    this.suspicion = 1;
    if (shooter) this.lastKnown = shooter.pos.clone();
    this.hitImpulse = dir.clone().multiplyScalar(clamp(energy / 3000, 0.2, 2));
    if (this.health <= 0) this.die(part === 'head');
    else { this.state = 'combat'; this.stance = 'crouch'; }
  }

  die(instant) {
    this.alive = false;
    this.deadT = 0;
    this.instantDeath = instant;
    this.squad?.onDeath(this);
  }

  /* ---------- percepção ---------- */
  canSee(target, world) {
    const eye = this.eye;
    const tp = target.eyePos ? target.eyePos.clone() : target.eye;
    const to = tp.clone().sub(eye);
    const dist = to.length();
    if (dist > 140) return 0;
    const dir = to.clone().divideScalar(dist);
    const facing = new THREE.Vector3(-Math.sin(this.yaw), 0, -Math.cos(this.yaw));
    const cos = facing.dot(dir.clone().setY(0).normalize());
    const fovCos = this.alert > 0.5 ? Math.cos(1.5) : Math.cos(1.05);
    if (cos < fovCos) return 0;

    if (this._losRay === undefined) this._losRay = new THREE.Raycaster();
    this._losRay.set(eye, dir); this._losRay.near = 0.4; this._losRay.far = dist - 0.4;
    if (this._losRay.intersectObjects(world.occluders, false).length) return 0;
    const tHit = world.raycastTerrain(eye, dir, dist - 0.4);
    if (tHit) return 0;

    const light = world.lightAt(tp);
    const stanceFactor = target.stance === 'prone' ? 0.28 : target.stance === 'crouch' ? 0.62 : 1;
    const motion = Math.hypot(target.vel?.x || 0, target.vel?.z || 0) / 5;
    let vis = clamp((1 - dist / 120), 0, 1) * light * stanceFactor * (0.45 + motion * 0.9 + (target.nvOn ? 0 : 0));
    if (this.alert > 0.5) vis *= 1.8;
    return clamp(vis, 0, 1);
  }

  hear(ev) {
    const d = this.pos.distanceTo(ev.pos);
    if (d > ev.radius) return;
    const strength = 1 - d / ev.radius;
    this.suspicion = clamp(this.suspicion + strength * (ev.type === 'shot' ? 1.6 : 0.55), 0, 1.2);
    if (this.suspicion > 0.45) {
      this.lastKnown = ev.pos.clone().add(new THREE.Vector3(randn() * 3, 0, randn() * 3));
      if (this.state === 'patrol' || this.state === 'idle') { this.state = 'investigate'; this.searchT = 0; }
    }
    if (ev.type === 'shot' && !ev.suppressed && strength > 0.25) {
      this.alert = Math.max(this.alert, 0.85);
      this.state = 'combat';
      this.squad?.alertAll(ev.pos, 0.8);
    }
  }

  /* ---------- comportamento ---------- */
  update(dt, player, world, entities) {
    if (!this.alive) return this._dead(dt);

    this._percT = (this._percT || 0) - dt;
    if (this._percT <= 0) { this._percT = 0.1 + Math.random() * 0.05; this._vis = this.canSee(player, world); }
    const vis = this._vis || 0;
    if (vis > 0.02) {
      this.suspicion = clamp(this.suspicion + vis * dt * (2.2 + this.alert * 3), 0, 1.4);
      if (this.suspicion > 0.55) this.lastKnown = player.pos.clone();
    } else {
      this.suspicion = clamp(this.suspicion - dt * 0.18, 0, 1.4);
    }

    if (this.suspicion >= 1.0 && this.state !== 'combat') {
      this.state = 'combat';
      this.reactionTimer = 0.22 + Math.random() * 0.45;    // tempo de reação humano
      this.squad?.alertAll(player.pos.clone(), 1.0);
      this.radioT = 0.1;
    }
    this.alert = damp(this.alert, this.state === 'combat' ? 1 : this.suspicion > 0.5 ? 0.6 : 0, 1.4, dt);

    switch (this.state) {
      case 'patrol': this._patrol(dt); break;
      case 'investigate': this._investigate(dt); break;
      case 'combat': this._combat(dt, player, world, entities, vis); break;
      case 'suppressed': this._suppressed(dt); break;
    }

    if (this.radioT > 0) {
      this.radioT -= dt;
      if (this.radioT <= 0) this.audio.radio(this.id, 0.9 + Math.random());
    }

    this._move(dt, world);
    this._animate(dt);
  }

  _patrol(dt) {
    this.stance = 'stand';
    if (this.isSentry || !this.route) {
      this.waitT -= dt;
      if (this.waitT <= 0) { this.waitT = 3 + Math.random() * 5; this.yawTarget = this.yaw + (Math.random() - 0.5) * 2.4; }
      this.yaw = damp(this.yaw, this.yawTarget ?? this.yaw, 1.6, dt);
      this.moveTarget = null;
      return;
    }
    const wp = this.route[this.routeIdx];
    this.moveTarget = wp;
    this.speed = 1.35;
    if (this.pos.distanceTo(wp) < 1.6) {
      this.routeIdx = (this.routeIdx + 1) % this.route.length;
      this.waitT = Math.random() * 3;
    }
  }

  _investigate(dt) {
    this.stance = 'stand';
    this.speed = 2.2;
    this.searchT += dt;
    this.moveTarget = this.lastKnown;
    if (!this.lastKnown || this.pos.distanceTo(this.lastKnown) < 2.2) {
      this.moveTarget = null;
      this.yaw += dt * 1.1 * Math.sin(this.searchT * 0.8);
    }
    if (this.searchT > 16 && this.suspicion < 0.35) { this.state = 'patrol'; this.searchT = 0; }
  }

  _combat(dt, player, world, entities, vis) {
    this.stance = this.health < 0.6 || Math.random() < 0.0008 ? 'crouch' : this.stance;
    this.reactionTimer -= dt;
    const hasLos = vis > 0.02;
    const tp = player.eyePos;

    if (hasLos) {
      this.lastKnown = player.pos.clone();
      const to = tp.clone().sub(this.eye);
      this.yaw = damp(this.yaw, Math.atan2(-to.x, -to.z), 7, dt);
      const dist = to.length();
      // manobra: aproxima se longe, procura cobertura se perto
      this.speed = dist > 34 ? 2.6 : 1.1;
      this.moveTarget = dist > 30 ? player.pos.clone() : this._flank(player, dt);
      if (this.reactionTimer <= 0) this._shoot(dt, player, entities, dist);
    } else {
      this.speed = 2.8;
      this.moveTarget = this.lastKnown;
      if (this.lastKnown && this.pos.distanceTo(this.lastKnown) < 2.5) {
        this.searchT += dt;
        this.yaw += dt * 1.4 * Math.sin(this.searchT);
        if (this.searchT > 22) { this.state = 'investigate'; this.suspicion = 0.6; this.searchT = 0; }
      }
    }
  }

  _flank(player, dt) {
    if (!this._flankSide) this._flankSide = Math.random() > 0.5 ? 1 : -1;
    const to = player.pos.clone().sub(this.pos).setY(0).normalize();
    const perp = new THREE.Vector3(-to.z, 0, to.x).multiplyScalar(this._flankSide * 6);
    return player.pos.clone().sub(to.multiplyScalar(14)).add(perp);
  }

  _shoot(dt, player, entities, dist) {
    this.fireTimer -= dt;
    if (this.fireTimer > 0) return;
    if (this.mag <= 0) { this.mag = 30; this.fireTimer = 2.6; this.audio.mech('mag'); return; }
    if (this.burst <= 0) { this.burst = 2 + ((Math.random() * 4) | 0); this.fireTimer = 0.35 + Math.random() * 0.9; return; }

    this.burst--; this.mag--;
    this.fireTimer = 60 / WEAPON_AI.rpm;
    const origin = this.eye.clone().addScaledVector(new THREE.Vector3(-Math.sin(this.yaw), 0, -Math.cos(this.yaw)), 0.45);
    const aim = player.eyePos.clone();
    // erro de mira: distância, movimento do alvo, estresse
    const err = 0.012 + dist * 0.0016 + Math.hypot(player.vel.x, player.vel.z) * 0.006;
    aim.x += randn() * err * dist * 0.35;
    aim.y += randn() * err * dist * 0.30 - 0.15;
    aim.z += randn() * err * dist * 0.35;
    const dir = aim.sub(origin).normalize();
    this.ballistics.fire(origin, dir, WEAPON_AI, this, entities);
    this.audio.shot(this.pos.distanceTo(player.pos), { suppressed: false, caliber: '5.56x45' });
    player.suppression = clamp(player.suppression + 0.10, 0, 1);
    this.muzzleT = 0.05;
  }

  _suppressed(dt) {
    this.stance = 'crouch';
    this.moveTarget = null;
    this.suppT = (this.suppT || 1.4) - dt;
    if (this.suppT <= 0) { this.state = 'combat'; this.suppT = null; }
  }

  _move(dt, world) {
    if (this.moveTarget) {
      const to = this.moveTarget.clone().sub(this.pos).setY(0);
      const d = to.length();
      if (d > 0.6) {
        to.divideScalar(d);
        const spd = (this.speed || 1.4) * (this.stance === 'crouch' ? 0.5 : 1);
        this.vel.x = damp(this.vel.x, to.x * spd, 8, dt);
        this.vel.z = damp(this.vel.z, to.z * spd, 8, dt);
        if (this.state !== 'combat') this.yaw = damp(this.yaw, Math.atan2(-to.x, -to.z), 5, dt);
      } else { this.vel.multiplyScalar(Math.exp(-8 * dt)); }
    } else this.vel.multiplyScalar(Math.exp(-8 * dt));

    const next = this.pos.clone().addScaledVector(this.vel, dt);
    // desvio simples de obstáculos
    const r = 0.4;
    const box = new THREE.Box3(
      new THREE.Vector3(next.x - r, next.y + 0.2, next.z - r),
      new THREE.Vector3(next.x + r, next.y + 1.7, next.z + r));
    for (const c of world.colliders) {
      if (!c.intersectsBox(box)) continue;
      const dxL = box.max.x - c.min.x, dxR = c.max.x - box.min.x;
      const dzL = box.max.z - c.min.z, dzR = c.max.z - box.min.z;
      const m = Math.min(dxL, dxR, dzL, dzR);
      if (m === dxL) next.x -= dxL; else if (m === dxR) next.x += dxR;
      else if (m === dzL) next.z -= dzL; else next.z += dzR;
      // desliza lateralmente
      this.vel.x += (Math.random() - 0.5) * 0.6;
      this.vel.z += (Math.random() - 0.5) * 0.6;
    }
    next.y = this.fixedY !== undefined ? this.fixedY : world.height(next.x, next.z);
    this.pos.copy(next);
    this.mesh.position.copy(this.pos);
    this.mesh.rotation.y = this.yaw;
  }

  _animate(dt) {
    const u = this.mesh.userData;
    const spd = Math.hypot(this.vel.x, this.vel.z);
    this.animT += dt * (2 + spd * 2.6);
    const amp = clamp(spd / 2.6, 0, 1.2);
    u.legL.rotation.x = Math.sin(this.animT) * 0.75 * amp;
    u.legR.rotation.x = -Math.sin(this.animT) * 0.75 * amp;
    u.armL.rotation.x = -Math.sin(this.animT) * 0.4 * amp;
    u.armR.rotation.x = Math.sin(this.animT) * 0.15 * amp;
    const crouch = this.stance === 'crouch' ? 1 : 0;
    u.hips.position.y = damp(u.hips.position.y, 0.92 - crouch * 0.42, 8, dt);
    u.legL.rotation.x += crouch * 0.5; u.legR.rotation.x += crouch * 0.5;
    u.hips.rotation.x = damp(u.hips.rotation.x, crouch * 0.25 + (this.state === 'combat' ? 0.12 : 0), 6, dt);
    // arma na linha de tiro quando em combate
    u.rifle.position.set(0.24, 0.36 + (this.alert > 0.4 ? 0.05 : 0), -0.28);
    u.rifle.rotation.x = damp(u.rifle.rotation.x, this.alert > 0.4 ? 0 : 0.6, 6, dt);
    u.armR.rotation.x = damp(u.armR.rotation.x, this.alert > 0.4 ? -1.35 : u.armR.rotation.x, 8, dt);
    u.armL.rotation.x = damp(u.armL.rotation.x, this.alert > 0.4 ? -1.15 : u.armL.rotation.x, 8, dt);
    u.head.rotation.y = Math.sin(this.animT * 0.3) * (this.state === 'patrol' ? 0.35 : 0.08);
  }

  _dead(dt) {
    this.deadT += dt;
    const u = this.mesh.userData;
    const p = clamp(this.deadT / (this.instantDeath ? 0.5 : 1.1), 0, 1);
    // colapso: sem "voo cinematográfico", o corpo cai onde estava
    this.mesh.rotation.z = damp(this.mesh.rotation.z, Math.PI / 2 * 0.92, 4, dt);
    u.hips.position.y = damp(u.hips.position.y, 0.34, 3.2, dt);
    u.legL.rotation.x = damp(u.legL.rotation.x, 0.3, 3, dt);
    u.legR.rotation.x = damp(u.legR.rotation.x, -0.15, 3, dt);
    u.armR.rotation.x = damp(u.armR.rotation.x, 0.9, 3, dt);
    u.armL.rotation.x = damp(u.armL.rotation.x, 0.4, 3, dt);
    if (p >= 1 && u.rifle.parent === u.hips) {
      u.hips.remove(u.rifle);
      this.scene.add(u.rifle);
      u.rifle.position.copy(this.pos).add(new THREE.Vector3(randn() * 0.4, 0.05, randn() * 0.4));
      u.rifle.rotation.set(0, Math.random() * 6.28, Math.PI / 2);
    }
  }
}

export class Squad {
  constructor() { this.members = []; this.alertLevel = 0; this.onAlarm = null; }
  add(s) { s.squad = this; this.members.push(s); return s; }
  alertAll(pos, level) {
    this.alertLevel = Math.max(this.alertLevel, level);
    for (const m of this.members) {
      if (!m.alive) continue;
      if (m.pos.distanceTo(pos) < 160) {
        m.suspicion = Math.max(m.suspicion, 0.75);
        m.lastKnown = pos.clone();
        if (m.state === 'patrol' || m.state === 'idle') { m.state = 'investigate'; m.searchT = 0; }
      }
    }
    if (level >= 1 && this.onAlarm) this.onAlarm(pos);
  }
  onDeath(s) {
    // corpos são notados: quem estiver perto entra em alerta em alguns segundos
    setTimeout(() => this.alertAll(s.pos, 0.7), 2500 + Math.random() * 4000);
  }
  get alive() { return this.members.filter(m => m.alive); }
}
