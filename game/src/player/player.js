import * as THREE from 'three';
import { clamp, damp, randn, fbm } from '../core/noise.js';
import { Weapon, WEAPON_DEFS } from '../weapons/weapons.js';

const STANCE = {
  stand: { eye: 1.63, speed: 3.1, sprint: 5.9, sway: 1.0, noise: 1.0, hitH: 1.78 },
  crouch: { eye: 1.06, speed: 1.55, sprint: 2.4, sway: 0.62, noise: 0.45, hitH: 1.2 },
  prone: { eye: 0.34, speed: 0.62, sprint: 0.62, sway: 0.24, noise: 0.15, hitH: 0.5 }
};

export class Player {
  constructor(scene, camera, world, input, audio, ballistics, mats) {
    this.scene = scene; this.camera = camera; this.world = world;
    this.input = input; this.audio = audio; this.ballistics = ballistics; this.mats = mats;

    this.pos = new THREE.Vector3(0, 0, 96);
    this.vel = new THREE.Vector3();
    this.yaw = Math.PI; this.pitch = 0;
    this.camYaw = Math.PI; this.camPitch = 0;
    this.stance = 'stand'; this.stanceBlend = STANCE.stand.eye;
    this.lean = 0; this.leanTarget = 0;
    this.grounded = true;

    this.stamina = 1; this.heartRate = 68; this.breathPhase = 0; this.holdBreath = 0;
    this.health = 1; this.bleeding = 0; this.suppression = 0; this.pain = 0;
    this.alive = true;

    this.nv = 0; this.nvOn = false;
    this.ads = 0; this.adsWant = false;
    this.bobT = 0; this.stepDist = 0;
    this.recoil = new THREE.Vector2();
    this.recoilVel = new THREE.Vector2();
    this.viewKick = new THREE.Vector3();
    this.camImpulse = new THREE.Vector3();
    this.camImpulseVel = new THREE.Vector3();

    this.weapons = [new Weapon('mk18', mats), new Weapon('m110', mats), new Weapon('g19', mats)];
    this.wIdx = 0;
    this.wRoot = new THREE.Group();
    this.camera.add(this.wRoot);
    for (const w of this.weapons) { w.model.visible = false; this.wRoot.add(w.model); }
    this.weapon.model.visible = true;

    this.muzzleLight = new THREE.PointLight(0xffcf8a, 0, 22, 2);
    this.camera.add(this.muzzleLight);
    this.muzzleFlash = new THREE.Mesh(
      new THREE.PlaneGeometry(0.34, 0.34),
      new THREE.MeshBasicMaterial({ color: 0xffd39a, transparent: true, opacity: 0, blending: THREE.AdditiveBlending, depthWrite: false })
    );
    this.wRoot.add(this.muzzleFlash);

    this.ray = new THREE.Raycaster();
    this.noiseEmitted = 0;
    this.lastShotAt = -99;
    this.interactTarget = null;
    this.hackProgress = 0;
    this.events = [];
    this.footstepSurface = 'dirt';
  }

  get weapon() { return this.weapons[this.wIdx]; }
  get eyePos() { return new THREE.Vector3(this.pos.x, this.pos.y + this.stanceBlend, this.pos.z); }

  emit(type, data = {}) { this.events.push({ type, ...data }); }

  /* ------------ colisão ------------- */
  _collide(next) {
    const r = 0.34;
    const h = STANCE[this.stance].hitH;
    const box = new THREE.Box3(
      new THREE.Vector3(next.x - r, next.y + 0.15, next.z - r),
      new THREE.Vector3(next.x + r, next.y + h, next.z + r)
    );
    for (const c of this.world.colliders) {
      if (!c.intersectsBox(box)) continue;
      // resolve no eixo de menor penetração (horizontal)
      const dxL = box.max.x - c.min.x, dxR = c.max.x - box.min.x;
      const dzL = box.max.z - c.min.z, dzR = c.max.z - box.min.z;
      const dyUp = c.max.y - box.min.y;
      if (dyUp > 0 && dyUp < 0.42) { next.y = c.max.y; continue; } // degrau
      const m = Math.min(dxL, dxR, dzL, dzR);
      if (m === dxL) next.x -= dxL; else if (m === dxR) next.x += dxR;
      else if (m === dzL) next.z -= dzL; else next.z += dzR;
      box.setFromCenterAndSize(
        new THREE.Vector3(next.x, next.y + h / 2, next.z),
        new THREE.Vector3(r * 2, h, r * 2));
    }
    return next;
  }

  update(dt, entities) {
    const I = this.input;
    if (!this.alive) { this._deadCam(dt); return; }

    /* --------- olhar (com massa: a câmera segue a intenção com atraso) --------- */
    const adsFactor = 1 - this.ads * 0.55 * (this.weapon.def.scope ? 0.75 : 1);
    const zoomFactor = this.ads > 0.5 && this.weapon.def.scope ? 0.22 : 1;
    this.yaw -= I.mouse.dx * adsFactor * zoomFactor;
    this.pitch -= I.mouse.dy * adsFactor * zoomFactor;
    this.pitch = clamp(this.pitch, -1.45, 1.45);

    const follow = 26 - this.ads * 8;
    this.camYaw = damp(this.camYaw, this.yaw, follow, dt);
    this.camPitch = damp(this.camPitch, this.pitch, follow, dt);

    /* --------- postura --------- */
    if (I.hit('ControlLeft')) this.stance = this.stance === 'crouch' ? 'stand' : 'crouch';
    if (I.hit('KeyC')) this.stance = this.stance === 'prone' ? 'crouch' : 'prone';
    const st = STANCE[this.stance];
    this.stanceBlend = damp(this.stanceBlend, st.eye, 7, dt);

    /* --------- movimento --------- */
    const fwd = new THREE.Vector3(-Math.sin(this.yaw), 0, -Math.cos(this.yaw));
    const right = new THREE.Vector3(Math.cos(this.yaw), 0, -Math.sin(this.yaw));
    let wish = new THREE.Vector3();
    if (I.down('KeyW')) wish.add(fwd);
    if (I.down('KeyS')) wish.sub(fwd);
    if (I.down('KeyD')) wish.add(right);
    if (I.down('KeyA')) wish.sub(right);
    const moving = wish.lengthSq() > 0.001;
    if (moving) wish.normalize();

    const wantSprint = I.down('ShiftLeft') && moving && !this.adsWant && this.stamina > 0.05 && I.down('KeyW');
    this.sprinting = wantSprint;
    let speed = wantSprint ? st.sprint : st.speed;
    if (this.ads > 0.1) speed *= 0.55;
    if (this.health < 0.5) speed *= 0.65 + this.health * 0.6;   // ferido = mais lento
    speed *= 1 - this.pain * 0.35;

    const accel = this.grounded ? 26 : 4;
    const target = wish.multiplyScalar(speed);
    this.vel.x = damp(this.vel.x, target.x, accel, dt);
    this.vel.z = damp(this.vel.z, target.z, accel, dt);

    const next = this.pos.clone().addScaledVector(this.vel, dt);
    const ground = this.world.height(next.x, next.z);
    next.y = ground;
    const solved = this._collide(next);
    const gy = this.world.height(solved.x, solved.z);
    solved.y = Math.max(gy, solved.y);
    this.pos.copy(solved);

    /* --------- fôlego / batimento --------- */
    const exertion = (this.vel.length() / 5.9) * (wantSprint ? 1.5 : 0.8) + (this.stance === 'prone' ? -0.1 : 0);
    this.stamina = clamp(this.stamina + (wantSprint ? -0.19 : 0.10 - exertion * 0.05) * dt, 0, 1);
    const targetHR = 62 + exertion * 78 + (1 - this.stamina) * 42 + this.suppression * 30 + this.pain * 25;
    this.heartRate = damp(this.heartRate, targetHR, 0.8, dt);
    this.holdBreath = I.down('KeyB') && this.stamina > 0.1 ? Math.min(this.holdBreath + dt, 7) : Math.max(0, this.holdBreath - dt * 1.6);
    if (this.holdBreath > 0.05) this.stamina = clamp(this.stamina - dt * 0.11, 0, 1);
    const breathRate = (this.heartRate / 60) * 0.34 * (this.holdBreath > 0.05 ? 0.06 : 1);
    const prevBreath = this.breathPhase;
    this.breathPhase += breathRate * dt * Math.PI * 2;
    if (Math.floor(prevBreath / (Math.PI * 2)) !== Math.floor(this.breathPhase / (Math.PI * 2)))
      this.audio.breath(clamp(exertion + (1 - this.stamina) * 0.7, 0.15, 1));

    /* --------- passos --------- */
    const spd = Math.hypot(this.vel.x, this.vel.z);
    this.stepDist += spd * dt;
    const stride = this.stance === 'prone' ? 1.1 : this.stance === 'crouch' ? 0.95 : (wantSprint ? 1.85 : 1.45);
    if (this.stepDist > stride) {
      this.stepDist = 0;
      const surf = Math.abs(this.pos.x) < 58 && Math.abs(this.pos.z) < 46 ? 'concrete' : 'dirt';
      this.footstepSurface = surf;
      this.audio.step(surf, 0.035 + spd * 0.016 * st.noise);
      this.camImpulseVel.y -= 0.55 * (wantSprint ? 1.6 : 1) * (this.ads > 0.5 ? 0.4 : 1);
      this.camImpulseVel.x += randn() * 0.25;
      this.noiseEmitted = spd * st.noise * (wantSprint ? 2.2 : 1);
      this.emit('noise', { pos: this.pos.clone(), radius: 6 + spd * 3.4 * st.noise * (wantSprint ? 2 : 1) });
    }
    this.noiseEmitted = damp(this.noiseEmitted, 0, 3, dt);

    /* --------- lean --------- */
    this.leanTarget = (I.down('KeyQ') ? 1 : 0) - (I.down('KeyE') ? 1 : 0);
    this.lean = damp(this.lean, this.leanTarget * (this.stance === 'prone' ? 0.3 : 1), 9, dt);

    /* --------- visão noturna --------- */
    if (I.hit('KeyN')) { this.nvOn = !this.nvOn; this.audio.mech('switch'); }
    this.nv = damp(this.nv, this.nvOn ? 1 : 0, 9, dt);

    /* --------- troca de arma --------- */
    for (const [k, i] of [['Digit1', 0], ['Digit2', 1], ['Digit3', 2]]) {
      if (I.hit(k) && this.wIdx !== i && this.weapon.state === 'idle') {
        this.weapon.model.visible = false;
        this.wIdx = i;
        this.weapon.model.visible = true;
        this.weapon.state = 'draw'; this.weapon.stateT = 0;
        this.audio.mech('gear');
      }
    }

    this._weapon(dt, entities);
    this._camera(dt);
    this._survival(dt);

    // supressão decai
    this.suppression = damp(this.suppression, 0, 0.55, dt);
    this.pain = damp(this.pain, 0, 0.4, dt);
  }

  /* ------------ arma ------------- */
  _weapon(dt, entities) {
    const I = this.input, w = this.weapon, d = w.def;
    w.nextShot -= dt;
    w.stateT += dt;

    this.adsWant = I.mouse.right && w.state !== 'reload' && !this.sprinting;
    const adsSpeed = 1 / d.adsTime;
    this.ads = clamp(this.ads + (this.adsWant ? adsSpeed : -adsSpeed * 1.35) * dt, 0, 1);

    // recarga
    if (I.hit('KeyR') && w.state === 'idle' && w.mag < d.magSize && w.reserve > 0) {
      w.state = 'reload'; w.stateT = 0;
      w.emptyReload = w.mag === 0 && !w.chambered;
      this.audio.mech('mag');
    }
    if (w.state === 'reload') {
      const total = w.emptyReload ? d.reload.empty : d.reload.tactical;
      if (!w._magOut && w.stateT > total * 0.35) { w._magOut = true; this.audio.mech('mag'); }
      if (!w._magIn && w.stateT > total * 0.72) { w._magIn = true; this.audio.mech('mag'); }
      if (w.stateT >= total) {
        const need = d.magSize - w.mag;
        const take = Math.min(need, w.reserve);
        w.reserve -= take; w.mag += take;
        if (w.emptyReload) { if (w.mag > 0) { w.mag--; w.chambered = true; } this.audio.mech('bolt'); }
        w.state = 'idle'; w._magOut = w._magIn = false;
      }
    }
    if (w.state === 'draw' && w.stateT > 0.45) w.state = 'idle';

    // checagem de carregador (diegética — substitui HUD de munição)
    if (I.hit('KeyV') && w.state === 'idle') { w.state = 'check'; w.stateT = 0; this.audio.mech('mag'); }
    if (w.state === 'check' && w.stateT > 1.1) { w.state = 'idle'; this.audio.mech('mag'); }

    // disparo
    const wantsFire = d.auto ? I.mouse.left : I.mouse.leftEdge;
    if (wantsFire && w.canFire && !this.sprinting) {
      if (w.chambered) this._shoot(entities);
      else this.audio.mech('bolt');
    }
    if (I.mouse.leftEdge && w.state === 'idle' && !w.chambered && w.mag === 0) this.audio.mech('bolt');

    // recuo se recupera (mola)
    const rec = d.recoil;
    this.recoilVel.multiplyScalar(Math.exp(-rec.recovery * dt));
    this.recoil.x += this.recoilVel.x * dt;
    this.recoil.y += this.recoilVel.y * dt;
    this.recoil.x = damp(this.recoil.x, 0, rec.recovery * 0.55, dt);
    this.recoil.y = damp(this.recoil.y, 0, rec.recovery * 0.55, dt);
    this.viewKick.z = damp(this.viewKick.z, 0, 12, dt);

    this.muzzleLight.intensity = damp(this.muzzleLight.intensity, 0, 34, dt);
    this.muzzleFlash.material.opacity = damp(this.muzzleFlash.material.opacity, 0, 40, dt);

    this._animateViewmodel(dt);
    this._interaction(dt);
  }

  _shoot(entities) {
    const w = this.weapon, d = w.def;
    w.nextShot = 60 / d.rpm;
    w.mag = Math.max(0, w.mag);
    w.chambered = false;
    if (w.mag > 0) { w.mag--; w.chambered = true; }

    const origin = this.eyePos.clone();
    const dir = this.aimDirection();
    // ponto de mira: sem retículo, quem não usa ADS atira "por instinto" (dispersão maior)
    const hip = 1 - this.ads;
    const w2 = { ...d, moa: d.moa + hip * 55 + this.suppression * 8 + (1 - this.stamina) * 5 };
    this.ballistics.fire(origin, dir, w2, this, entities);

    const rec = d.recoil;
    const mult = (this.stance === 'prone' ? 0.45 : this.stance === 'crouch' ? 0.75 : 1) * (this.ads > 0.5 ? 0.8 : 1.15);
    this.recoilVel.y += rec.up * 60 * mult;
    this.recoilVel.x += randn() * rec.side * 60 * mult;
    this.pitch += rec.up * mult;
    this.yaw += randn() * rec.side * mult;
    this.viewKick.z += rec.kick;
    this.camImpulseVel.add(new THREE.Vector3(randn() * 0.5, 0.4, 2.4).multiplyScalar(rec.kick));

    this.muzzleLight.intensity = d.suppressed ? 6 : 26;
    this.muzzleLight.position.copy(w.model.userData.muzzle);
    this.muzzleFlash.position.copy(w.model.userData.muzzle).add(new THREE.Vector3(0, 0, -0.04));
    this.muzzleFlash.material.opacity = d.suppressed ? 0.22 : 0.9;
    this.muzzleFlash.rotation.z = Math.random() * 6.28;
    this.muzzleFlash.scale.setScalar(0.5 + Math.random() * 0.6);

    this.audio.shot(0, { suppressed: d.suppressed, caliber: d.caliber });
    this.lastShotAt = performance.now() / 1000;
    this.emit('shot', {
      pos: this.pos.clone(),
      radius: d.suppressed ? 42 : 240,
      suppressed: d.suppressed
    });
  }

  aimDirection() {
    // direção real do cano: mira + recuo acumulado + oscilação de respiração/arma
    const sway = this.swayVector();
    const yaw = this.yaw + this.recoil.x + sway.x;
    const pitch = this.pitch + this.recoil.y + sway.y;
    const zero = this.weapon.zeroDistance;
    const drop = 0; // compensação: o operador já mira zerado; queda real acontece na balística
    void zero; void drop;
    return new THREE.Vector3(
      -Math.sin(yaw) * Math.cos(pitch),
      Math.sin(pitch),
      -Math.cos(yaw) * Math.cos(pitch)
    ).normalize();
  }

  swayVector() {
    const st = STANCE[this.stance];
    const hold = this.holdBreath > 0.05 ? 0.12 : 1;
    const t = performance.now() / 1000;
    const fat = 1 + (1 - this.stamina) * 2.2 + this.suppression * 1.5;
    const amp = 0.0022 * st.sway * fat * hold * (1 - this.ads * 0.55);
    const breath = Math.sin(this.breathPhase) * amp * 1.4;
    const wobble = fbm(t * 0.7, 13.2, 3) * amp * 2.2;
    const wobble2 = fbm(t * 0.63 + 40, 3.7, 3) * amp * 2.2;
    return { x: wobble, y: breath + wobble2 };
  }

  _animateViewmodel(dt) {
    const w = this.weapon, d = w.def, m = w.model;
    const st = STANCE[this.stance];
    const spd = Math.hypot(this.vel.x, this.vel.z);
    this.bobT += dt * (2.4 + spd * 1.7);

    const sight = m.userData.sight;
    // posição de porte (hip) e de mira (alinhando o aparelho de pontaria ao olho)
    const hipPos = new THREE.Vector3(0.135, -0.115, -0.30);
    const adsPos = new THREE.Vector3(-sight.x, -sight.y, -0.16 - (d.scope ? 0.02 : 0));
    const target = hipPos.clone().lerp(adsPos, this.ads);

    // bob de caminhada, mais forte sem mira
    const bobAmp = (1 - this.ads * 0.86) * clamp(spd / 4, 0, 1.5) * st.sway;
    target.x += Math.sin(this.bobT) * 0.022 * bobAmp;
    target.y += Math.abs(Math.cos(this.bobT)) * -0.018 * bobAmp;
    target.z += Math.sin(this.bobT * 0.5) * 0.010 * bobAmp;

    // respiração no cano
    target.y += Math.sin(this.breathPhase) * 0.006 * (1 - this.ads * 0.7) * (this.holdBreath > 0.05 ? 0.15 : 1);

    // recuo mecânico da arma
    target.z += this.viewKick.z;
    target.y += this.viewKick.z * 0.25;

    // corrida: arma baixa e de lado
    if (this.sprinting) {
      target.set(0.20, -0.22, -0.24);
      m.rotation.set(damp(m.rotation.x, -0.35, 10, dt), damp(m.rotation.y, 0.7, 10, dt), damp(m.rotation.z, 0.5, 10, dt));
    } else {
      const swayLag = new THREE.Vector2(this.yaw - this.camYaw, this.pitch - this.camPitch);
      m.rotation.x = damp(m.rotation.x, -swayLag.y * 0.9 - this.viewKick.z * 2.2, 14, dt);
      m.rotation.y = damp(m.rotation.y, swayLag.x * 0.9, 14, dt);
      m.rotation.z = damp(m.rotation.z, -this.lean * 0.12 + swayLag.x * 0.4, 12, dt);
    }

    // animações de estado
    if (w.state === 'reload') {
      const total = w.emptyReload ? d.reload.empty : d.reload.tactical;
      const p = clamp(w.stateT / total, 0, 1);
      const curve = Math.sin(p * Math.PI);
      target.y -= curve * 0.13; target.x += curve * 0.05; target.z += curve * 0.06;
      m.rotation.x += curve * 0.55; m.rotation.z += curve * 0.35;
      const mag = m.getObjectByName('mag');
      if (mag) {
        const out = clamp((p - 0.30) / 0.16, 0, 1) * (1 - clamp((p - 0.62) / 0.16, 0, 1));
        mag.position.y = mag.userData.y0 ?? (mag.userData.y0 = mag.position.y);
        mag.position.y -= out * 0.22;
        mag.visible = !(p > 0.46 && p < 0.62);
      }
    } else if (w.state === 'check') {
      const p = clamp(w.stateT / 1.1, 0, 1);
      const curve = Math.sin(p * Math.PI);
      target.y -= curve * 0.06; target.x -= curve * 0.05;
      m.rotation.z += curve * 0.9; m.rotation.x += curve * 0.25;
    } else if (w.state === 'draw') {
      const p = clamp(w.stateT / 0.45, 0, 1);
      target.y -= (1 - p) * 0.3;
      m.rotation.x += (1 - p) * 0.6;
    }

    m.position.lerp(target, 1 - Math.exp(-(this.ads > 0.1 ? 26 : 17) * dt));

    const dot = m.getObjectByName('dot');
    if (dot) dot.material.opacity = 0.55 + Math.random() * 0.35;
  }

  /* ------------ interação / hacking ------------- */
  _interaction(dt) {
    this.ray.set(this.eyePos, this.aimDirection());
    this.ray.far = 2.6;
    const hits = this.ray.intersectObjects(this.world.occluders, false);
    const t = hits.find(h => h.object.userData.interact);
    this.interactTarget = t ? t.object : null;

    if (this.interactTarget && this.input.down('KeyF')) {
      const kind = this.interactTarget.userData.interact;
      if (kind === 'hack') {
        this.hackProgress = clamp(this.hackProgress + dt / 9, 0, 1);
        this.world.hackScreen.material.emissiveIntensity = 2 + Math.sin(performance.now() / 60) * 1.5;
        if (this.hackProgress >= 1 && !this._hacked) { this._hacked = true; this.emit('hacked'); }
      } else if (kind === 'generator' && !this._powerCut) {
        this._powerCut = true;
        this.world.cutPower();
        this.audio.mech('gear');
        this.emit('powercut', { pos: this.pos.clone() });
      }
    }
  }

  /* ------------ dano / sobrevivência ------------- */
  raycastCapsule(origin, dir, len) {
    const h = STANCE[this.stance].hitH;
    const c = new THREE.Vector3(this.pos.x, this.pos.y + h * 0.5, this.pos.z);
    const r = 0.32;
    const oc = origin.clone().sub(c);
    const a = dir.dot(dir);
    const b = 2 * oc.dot(dir);
    const cc = oc.dot(oc) - (r + h * 0.35) ** 2;
    const disc = b * b - 4 * a * cc;
    if (disc < 0) return null;
    const t = (-b - Math.sqrt(disc)) / (2 * a);
    if (t < 0 || t > len) return null;
    const p = origin.clone().addScaledVector(dir, t);
    const rel = p.y - this.pos.y;
    const part = rel > h * 0.86 ? 'head' : rel > h * 0.45 ? 'torso' : 'legs';
    return { t, point: p, part };
  }

  applyBullet(point, dir, energy, part) {
    const mult = part === 'head' ? 6 : part === 'torso' ? 1 : 0.55;
    const dmg = clamp(energy / 2600, 0.05, 1) * mult;
    this.health = clamp(this.health - dmg, 0, 1);
    this.bleeding = clamp(this.bleeding + dmg * 0.6, 0, 1);
    this.pain = 1;
    this.camImpulseVel.add(dir.clone().multiplyScalar(6).setY(2 + Math.random() * 3));
    this.audio.deafen(0.4);
    this.emit('hurt', { part, dmg });
    if (this.health <= 0) this.die();
  }

  die() {
    if (!this.alive) return;
    this.alive = false;
    this.deathT = 0;
    this.emit('death');
  }

  _deadCam(dt) {
    this.deathT += dt;
    // a câmera cai com o corpo e continua gravando
    this.camPitch = damp(this.camPitch, -1.1, 1.6, dt);
    this.stanceBlend = damp(this.stanceBlend, 0.22, 1.4, dt);
    this.camera.position.set(this.pos.x, this.pos.y + this.stanceBlend, this.pos.z);
    this.camera.rotation.set(this.camPitch, this.camYaw + Math.sin(this.deathT) * 0.02, 0.6, 'YXZ');
  }

  _survival(dt) {
    if (this.bleeding > 0) {
      this.health = clamp(this.health - this.bleeding * 0.012 * dt, 0, 1);
      this.bleeding = clamp(this.bleeding - dt * 0.012, 0, 1);
      if (this.health <= 0) this.die();
    } else if (this.health < 1) {
      this.health = clamp(this.health + dt * 0.006, 0, 1); // recuperação lenta e parcial
    }
  }

  /* ------------ câmera corporal ------------- */
  _camera(dt) {
    // molas do arnês da câmera (massa presa ao corpo)
    const k = 42, c = 9.5;
    this.camImpulseVel.addScaledVector(this.camImpulse, -k * dt);
    this.camImpulseVel.multiplyScalar(Math.exp(-c * dt));
    this.camImpulse.addScaledVector(this.camImpulseVel, dt);

    const spd = Math.hypot(this.vel.x, this.vel.z);
    const walkAmp = clamp(spd / 5, 0, 1.3) * (1 - this.ads * 0.72);
    const t = this.bobT;
    const bobX = Math.sin(t) * 0.030 * walkAmp;
    const bobY = Math.abs(Math.cos(t)) * 0.028 * walkAmp;
    const bobRoll = Math.sin(t) * 0.021 * walkAmp;

    const breath = Math.sin(this.breathPhase) * 0.006 * (this.holdBreath > 0.05 ? 0.15 : 1);
    const heart = Math.sin(performance.now() / 1000 * (this.heartRate / 60) * Math.PI * 2) * 0.0016 * (1 + this.suppression * 2);

    const leanOff = new THREE.Vector3(Math.cos(this.camYaw), 0, -Math.sin(this.camYaw)).multiplyScalar(this.lean * 0.42);

    this.camera.position.set(
      this.pos.x + bobX * 0.6 + this.camImpulse.x * 0.02 + leanOff.x,
      this.pos.y + this.stanceBlend - bobY + breath + heart + this.camImpulse.y * 0.02,
      this.pos.z + this.camImpulse.z * 0.004 + leanOff.z
    );
    this.camera.rotation.set(
      this.camPitch + this.camImpulse.y * 0.010 + this.recoil.y * 0.4,
      this.camYaw + this.camImpulse.x * 0.006 + this.recoil.x * 0.4,
      bobRoll - this.lean * 0.30 + this.camImpulse.x * 0.004,
      'YXZ'
    );

    // FOV: grande-angular de bodycam; ADS aproxima levemente (óptica faz o resto)
    const baseFov = 96 - (this.sprinting ? -4 : 0);
    const adsFov = this.weapon.def.scope ? 26 : 62;
    this.camera.fov = damp(this.camera.fov, baseFov + (adsFov - baseFov) * this.ads, 12, dt);
    this.camera.updateProjectionMatrix();
  }

  cameraState() {
    const spd = Math.hypot(this.vel.x, this.vel.z);
    const angVel = Math.abs(this.yaw - this.camYaw) + Math.abs(this.pitch - this.camPitch);
    const light = this.world.lightAt(this.eyePos);
    return {
      iso: clamp(1.15 - light * 0.7, 0.18, 1.15),
      targetExposure: clamp(0.95 / Math.max(0.12, light * 0.9), 0.55, 4.2) * (this.nv > 0.5 ? 0.55 : 1),
      shutter: clamp(angVel * 2.4 + spd * 0.012, 0, 0.55),
      motion: clamp(angVel * 1.5 + spd * 0.035, 0, 0.5),
      nv: this.nv,
      wet: this.world.rainAmount * 0.9,
      blood: clamp((1 - this.health) * 1.15 - 0.15, 0, 1),
      breath: clamp((1 - this.stamina) * 0.8 + this.suppression * 0.5, 0, 1),
      glitch: this.glitch || 0,
      focus: clamp(1 - this.ads, 0, 1) * 0.35 + (this.ads > 0.5 ? 0 : 0.1),
      damage: clamp(1 - this.health, 0, 1) * 0.8,
      barrel: 0.17 - this.ads * 0.10
    };
  }
}
