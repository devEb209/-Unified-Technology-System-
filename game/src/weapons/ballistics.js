import * as THREE from 'three';
import { randn } from '../core/noise.js';

/* Balística externa simplificada mas fisicamente honesta:
   - arrasto quadrático com coeficiente balístico (modelo G1 aproximado)
   - queda por gravidade real (9.80665)
   - deriva de vento (componente lateral) e vento de cauda
   - velocidade do som: o "crack" chega antes do "thump" do disparo distante
   - penetração por material com perda de energia e desvio angular
   - ricochete em ângulos rasos                                            */

const G = 9.80665;
const SPEED_OF_SOUND = 343;

export class Ballistics {
  constructor(scene, world, audio) {
    this.scene = scene; this.world = world; this.audio = audio;
    this.bullets = [];
    this.ray = new THREE.Raycaster();
    this.ray.far = 60;
    this.decals = [];
    this.tracerGeo = new THREE.BufferGeometry();
    this.impacts = [];
    this._initFx();
  }

  _initFx() {
    // faíscas / poeira de impacto — pool de pontos
    const N = 900;
    const g = new THREE.BufferGeometry();
    this.fxPos = new Float32Array(N * 3);
    this.fxVel = new Float32Array(N * 3);
    this.fxLife = new Float32Array(N);
    this.fxCol = new Float32Array(N * 3);
    g.setAttribute('position', new THREE.BufferAttribute(this.fxPos, 3));
    g.setAttribute('color', new THREE.BufferAttribute(this.fxCol, 3));
    this.fx = new THREE.Points(g, new THREE.PointsMaterial({ size: 0.045, vertexColors: true, transparent: true, opacity: 0.95, depthWrite: false, blending: THREE.AdditiveBlending }));
    this.fx.frustumCulled = false;
    this.scene.add(this.fx);
    this.fxIdx = 0;

    this.tracerMat = new THREE.LineBasicMaterial({ color: 0xffbb66, transparent: true, opacity: 0.55 });
  }

  spawnFx(pos, normal, kind) {
    const n = kind === 'metal' ? 22 : 16;
    for (let i = 0; i < n; i++) {
      const idx = this.fxIdx = (this.fxIdx + 1) % (this.fxPos.length / 3);
      this.fxPos[idx * 3] = pos.x; this.fxPos[idx * 3 + 1] = pos.y; this.fxPos[idx * 3 + 2] = pos.z;
      const spread = kind === 'metal' ? 3.5 : 1.8;
      this.fxVel[idx * 3] = normal.x * 2 + randn() * spread;
      this.fxVel[idx * 3 + 1] = normal.y * 2 + Math.abs(randn()) * spread;
      this.fxVel[idx * 3 + 2] = normal.z * 2 + randn() * spread;
      this.fxLife[idx] = kind === 'metal' ? 0.35 + Math.random() * 0.4 : 0.6 + Math.random() * 0.7;
      if (kind === 'metal') { this.fxCol[idx * 3] = 1.6; this.fxCol[idx * 3 + 1] = 0.8; this.fxCol[idx * 3 + 2] = 0.25; }
      else if (kind === 'flesh') { this.fxCol[idx * 3] = 0.5; this.fxCol[idx * 3 + 1] = 0.03; this.fxCol[idx * 3 + 2] = 0.03; }
      else { this.fxCol[idx * 3] = 0.30; this.fxCol[idx * 3 + 1] = 0.27; this.fxCol[idx * 3 + 2] = 0.23; }
    }
    this.fx.geometry.attributes.position.needsUpdate = true;
    this.fx.geometry.attributes.color.needsUpdate = true;
  }

  fire(origin, dir, weapon, shooter, targets) {
    const spreadRad = (weapon.moa / 60) * (Math.PI / 180) / 2;
    const d = dir.clone();
    // dispersão gaussiana (não uniforme — arma real agrupa em torno do centro)
    d.x += randn() * spreadRad; d.y += randn() * spreadRad; d.z += randn() * spreadRad;
    d.normalize();
    const b = {
      pos: origin.clone(),
      vel: d.multiplyScalar(weapon.muzzleVelocity),
      mass: weapon.bulletMass,      // kg
      bc: weapon.bc,
      energy: 0.5 * weapon.bulletMass * weapon.muzzleVelocity ** 2,
      life: 6,
      shooter, weapon,
      targets,
      trail: [origin.clone()],
      tracer: weapon.tracerEvery > 0 && (shooter.shotCount = (shooter.shotCount || 0) + 1) % weapon.tracerEvery === 0,
      supersonicNotified: false
    };
    if (b.tracer) {
      const geo = new THREE.BufferGeometry().setFromPoints([origin.clone(), origin.clone()]);
      b.line = new THREE.Line(geo, this.tracerMat.clone());
      b.line.frustumCulled = false;
      this.scene.add(b.line);
    }
    this.bullets.push(b);
    return b;
  }

  update(dt, listener) {
    const wind = this.world.wind;
    for (let i = this.bullets.length - 1; i >= 0; i--) {
      const b = this.bullets[i];
      const steps = 3;
      const h = dt / steps;
      for (let s = 0; s < steps; s++) {
        const rel = b.vel.clone().sub(wind);
        const v = rel.length();
        // arrasto: a = -(v^2 * rho * Cd * A)/(2m) ~ v^2/(bc*k)
        const k = 0.000302 / Math.max(0.05, b.bc); // calibrado: 7.62 M118LR retém ~660 m/s a 400 m
        const drag = rel.clone().normalize().multiplyScalar(-k * v * v);
        b.vel.addScaledVector(drag, h);
        b.vel.y -= G * h;
        const prev = b.pos.clone();
        b.pos.addScaledVector(b.vel, h);

        const seg = b.pos.clone().sub(prev);
        const len = seg.length();
        if (len <= 0) continue;
        const dirn = seg.clone().divideScalar(len);

        // impacto em personagens (cápsulas)
        let hitEntity = null, hitT = Infinity, hitPoint = null, part = 'torso';
        for (const t of b.targets) {
          if (!t.alive || t === b.shooter) continue;
          const hit = t.raycastCapsule(prev, dirn, len);
          if (hit && hit.t < hitT) { hitT = hit.t; hitEntity = t; hitPoint = hit.point; part = hit.part; }
        }

        // impacto em geometria
        this.ray.set(prev, dirn); this.ray.far = len;
        const hits = this.ray.intersectObjects(this.world.occluders, false);
        let geoHit = hits.length ? hits[0] : null;

        // terreno (heightfield analítico)
        const th = this.world.raycastTerrain(prev, dirn, len);
        if (th && (!geoHit || th.dist < geoHit.distance)) {
          geoHit = {
            distance: th.dist, point: th.point, object: { userData: { material: 'dirt', penetration: 0.05 } },
            face: null
          };
          geoHit.normal = new THREE.Vector3(0, 1, 0);
        }

        if (hitEntity && (!geoHit || hitT < geoHit.distance)) {
          const energy = 0.5 * b.mass * b.vel.lengthSq();
          hitEntity.applyBullet(hitPoint, dirn, energy, part, b.shooter);
          this.spawnFx(hitPoint, dirn.clone().negate(), 'flesh');
          this.audio?.impact(hitPoint, 'flesh', listener);
          this._kill(b, i);
          break;
        }
        if (geoHit) {
          const mat = geoHit.object.userData.material || 'concrete';
          this.onGeoHit?.(geoHit.object, geoHit.point);
          const nrm = geoHit.normal ? geoHit.normal.clone()
            : geoHit.face ? geoHit.face.normal.clone().transformDirection(geoHit.object.matrixWorld)
            : dirn.clone().negate();
          const inc = Math.abs(dirn.dot(nrm));
          const pen = geoHit.object.userData.penetration ?? (mat === 'metal' ? 0.25 : mat === 'sandbag' ? 0.8 : 0.1);
          const energy = 0.5 * b.mass * b.vel.lengthSq();
          this.spawnFx(geoHit.point, nrm, mat === 'metal' ? 'metal' : 'dust');
          this.audio?.impact(geoHit.point, mat, listener);
          this.addDecal(geoHit.point, nrm, mat);

          if (inc < 0.28 && Math.random() < 0.55 && mat !== 'sandbag') {
            // ricochete
            b.vel.reflect(nrm).multiplyScalar(0.45);
            b.pos.copy(geoHit.point).addScaledVector(nrm, 0.02);
            this.audio?.ricochet(geoHit.point, listener);
            continue;
          }
          const survives = energy * pen > 900 && b.weapon.penetration > 0.4;
          if (survives) {
            b.vel.multiplyScalar(0.55 * pen + 0.25);
            b.vel.x += randn() * 4; b.vel.y += randn() * 4; b.vel.z += randn() * 4;
            b.pos.copy(geoHit.point).addScaledVector(dirn, 0.45);
            continue;
          }
          this._kill(b, i);
          break;
        }

        // estrondo supersônico ao passar perto do ouvinte
        if (!b.supersonicNotified && listener && b.vel.length() > SPEED_OF_SOUND) {
          const dist = new THREE.Line3(prev, b.pos).closestPointToPoint(listener, true, new THREE.Vector3()).distanceTo(listener);
          if (dist < 6) { this.audio?.crack(dist); b.supersonicNotified = true; }
        }
      }

      if (!this.bullets[i]) continue;
      b.life -= dt;
      if (b.line) {
        const p = b.line.geometry.attributes.position;
        const tail = b.pos.clone().addScaledVector(b.vel.clone().normalize(), -Math.min(28, b.vel.length() * 0.035));
        p.setXYZ(0, tail.x, tail.y, tail.z); p.setXYZ(1, b.pos.x, b.pos.y, b.pos.z);
        p.needsUpdate = true;
      }
      if (b.life <= 0 || b.pos.y < -30) this._kill(b, i);
    }

    // partículas
    const pos = this.fxPos;
    for (let i = 0; i < this.fxLife.length; i++) {
      if (this.fxLife[i] <= 0) continue;
      this.fxLife[i] -= dt;
      this.fxVel[i * 3 + 1] -= G * dt * 0.8;
      pos[i * 3] += this.fxVel[i * 3] * dt;
      pos[i * 3 + 1] += this.fxVel[i * 3 + 1] * dt;
      pos[i * 3 + 2] += this.fxVel[i * 3 + 2] * dt;
      const f = Math.max(0, this.fxLife[i]);
      this.fxCol[i * 3] *= (0.986 + f * 0.01);
      if (this.fxLife[i] <= 0) { pos[i * 3 + 1] = -999; }
    }
    this.fx.geometry.attributes.position.needsUpdate = true;
    this.fx.geometry.attributes.color.needsUpdate = true;

    for (let i = this.decals.length - 1; i >= 0; i--) {
      const d = this.decals[i];
      d.life -= dt;
      if (d.life < 3) d.mesh.material.opacity = Math.max(0, d.life / 3) * 0.9;
      if (d.life <= 0) { this.scene.remove(d.mesh); d.mesh.geometry.dispose(); d.mesh.material.dispose(); this.decals.splice(i, 1); }
    }
  }

  _kill(b, i) {
    if (b.line) { this.scene.remove(b.line); b.line.geometry.dispose(); b.line.material.dispose(); }
    this.bullets.splice(i, 1);
  }

  addDecal(point, normal, mat) {
    if (this.decals.length > 120) {
      const d = this.decals.shift();
      this.scene.remove(d.mesh);
    }
    const size = 0.055 + Math.random() * 0.05;
    const g = new THREE.CircleGeometry(size, 8);
    const m = new THREE.MeshBasicMaterial({
      color: mat === 'metal' ? 0x1a1a1a : 0x111010, transparent: true, opacity: 0.9,
      depthWrite: false, polygonOffset: true, polygonOffsetFactor: -4
    });
    const mesh = new THREE.Mesh(g, m);
    mesh.position.copy(point).addScaledVector(normal, 0.012);
    mesh.lookAt(point.clone().add(normal));
    this.scene.add(mesh);
    this.decals.push({ mesh, life: 30 });
  }
}
