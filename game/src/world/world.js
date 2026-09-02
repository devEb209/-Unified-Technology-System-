import * as THREE from 'three';
import { Sky } from 'three/examples/jsm/objects/Sky.js';
import { fbm, mulberry32, clamp } from '../core/noise.js';
import { buildMaterials } from '../core/materials.js';

const TERRAIN_SIZE = 700;
const TERRAIN_SEG = 200;

export class World {
  constructor(scene, renderer) {
    this.scene = scene;
    this.renderer = renderer;
    this.mats = buildMaterials();
    this.colliders = [];      // Box3 do mundo (paredes, contêineres...)
    this.occluders = [];      // malhas para raycast de bala/visão
    this.lightSources = [];   // {pos, radius, intensity, mesh} — usados por IA e exposição
    this.rand = mulberry32(20451);
    this.wind = new THREE.Vector3(2.6, 0, -1.4);
    this.rainAmount = 0.85;
    this.timeOfDay = 2.6; // horas
    this.group = new THREE.Group();
    scene.add(this.group);

    this._sky();
    this._terrain();
    this._facility();
    this._rain();
    this._ambienceProps();
  }

  /* ---------------- céu, sol, lua ---------------- */
  _sky() {
    this.sky = new Sky();
    this.sky.scale.setScalar(45000);
    this.scene.add(this.sky);
    const u = this.sky.material.uniforms;
    u.turbidity.value = 8.0;
    u.rayleigh.value = 1.6;
    u.mieCoefficient.value = 0.02;
    u.mieDirectionalG.value = 0.82;

    this.sun = new THREE.DirectionalLight(0xbfd0ff, 0.06);
    this.sun.castShadow = true;
    this.sun.shadow.mapSize.set(2048, 2048);
    const d = 90;
    Object.assign(this.sun.shadow.camera, { left: -d, right: d, top: d, bottom: -d, near: 1, far: 400 });
    this.sun.shadow.bias = -0.0008;
    this.sun.shadow.normalBias = 0.03;
    this.scene.add(this.sun, this.sun.target);

    this.hemi = new THREE.HemisphereLight(0x2a3550, 0x0b0c0a, 0.16);
    this.scene.add(this.hemi);

    this.scene.fog = new THREE.FogExp2(0x0a0e14, 0.0125);

    // estrelas
    const g = new THREE.BufferGeometry();
    const N = 2200, pos = new Float32Array(N * 3), sz = new Float32Array(N);
    for (let i = 0; i < N; i++) {
      const th = Math.random() * Math.PI * 2, ph = Math.acos(Math.random() * 0.9 + 0.02), R = 9000;
      pos[i * 3] = Math.sin(ph) * Math.cos(th) * R;
      pos[i * 3 + 1] = Math.cos(ph) * R;
      pos[i * 3 + 2] = Math.sin(ph) * Math.sin(th) * R;
      sz[i] = 6 + Math.random() * 26;
    }
    g.setAttribute('position', new THREE.BufferAttribute(pos, 3));
    g.setAttribute('size', new THREE.BufferAttribute(sz, 1));
    this.stars = new THREE.Points(g, new THREE.PointsMaterial({ color: 0xa8bcd8, size: 14, sizeAttenuation: true, transparent: true, opacity: 0.0, depthWrite: false }));
    this.scene.add(this.stars);
  }

  setTimeOfDay(h) {
    this.timeOfDay = h;
    const a = ((h - 6) / 24) * Math.PI * 2;
    const elev = Math.sin(a);
    const dir = new THREE.Vector3(Math.cos(a) * 0.6, elev, Math.sin(a * 0.7) * 0.5).normalize();
    this.sky.material.uniforms.sunPosition.value.copy(dir.clone().multiplyScalar(1));
    const night = clamp(-elev * 3 + 0.2, 0, 1);
    this.sun.position.copy(dir.clone().multiplyScalar(180));
    if (elev < -0.05) { // lua
      this.sun.position.copy(dir.clone().negate().multiplyScalar(180));
      this.sun.color.setHex(0x93a9d6);
      this.sun.intensity = 0.22;   // luar de lua cheia — o suficiente para silhuetas, não para detalhes
    } else {
      this.sun.color.setHex(0xffe9c8);
      this.sun.intensity = clamp(elev * 3.2, 0.02, 2.6);
    }
    this.hemi.intensity = clamp(0.9 - night * 0.74, 0.16, 0.9);
    this.hemi.color.setHex(night > 0.5 ? 0x28334d : 0x9fb6d8);
    this.sky.material.uniforms.rayleigh.value = 1.0 + night * 2.2;
    this.stars.material.opacity = night;
    this.scene.fog.color.setHSL(0.58, 0.25, 0.02 + (1 - night) * 0.35);
    this.scene.fog.density = 0.010 + this.rainAmount * 0.010;
    this.nightFactor = night;
  }

  /* ---------------- terreno ---------------- */
  height(x, z) {
    const h = fbm(x * 0.0035, z * 0.0035, 5) * 16
      + fbm(x * 0.014 + 40, z * 0.014, 4) * 2.6
      + fbm(x * 0.09, z * 0.09, 3) * 0.22;
    // planalto plano onde fica a instalação
    const d = Math.hypot(x, z);
    const flat = 1 - Math.min(1, Math.max(0, (d - 55) / 55));
    return h * (1 - flat) + (-1.2) * flat;
  }

  _terrain() {
    const g = new THREE.PlaneGeometry(TERRAIN_SIZE, TERRAIN_SIZE, TERRAIN_SEG, TERRAIN_SEG);
    g.rotateX(-Math.PI / 2);
    const p = g.attributes.position;
    for (let i = 0; i < p.count; i++) p.setY(i, this.height(p.getX(i), p.getZ(i)));
    g.computeVertexNormals();
    const m = this.mats.dirt.clone();
    const mesh = new THREE.Mesh(g, m);
    mesh.receiveShadow = true;
    mesh.userData.solid = true; mesh.userData.material = 'dirt';
    this.group.add(mesh);
    this.terrain = mesh;

    // pista/asfalto do complexo
    const road = new THREE.Mesh(new THREE.PlaneGeometry(24, 260, 1, 1), this.mats.asphalt);
    road.rotation.x = -Math.PI / 2; road.position.set(0, -1.16, -20);
    road.receiveShadow = true; road.userData.solid = true; road.userData.material = 'concrete';
    this.group.add(road); this.occluders.push(road);

    // laje de concreto
    const slab = new THREE.Mesh(new THREE.BoxGeometry(120, 0.4, 96), this.mats.concrete);
    slab.position.set(0, -1.35, 0); slab.receiveShadow = true;
    slab.userData.solid = true; slab.userData.material = 'concrete';
    this.group.add(slab); this.occluders.push(slab);
  }

  _box(w, h, d, x, y, z, mat, ry = 0, meta = {}) {
    const m = new THREE.Mesh(new THREE.BoxGeometry(w, h, d), mat);
    m.position.set(x, y, z); m.rotation.y = ry;
    m.castShadow = true; m.receiveShadow = true;
    m.userData = { solid: true, material: meta.material || 'concrete', ...meta };
    this.group.add(m);
    this.occluders.push(m);
    if (meta.noCollide !== true) {
      m.updateMatrixWorld();
      const b = new THREE.Box3().setFromObject(m);
      this.colliders.push(b);
    }
    return m;
  }

  _building(x, z, w, d, h, ry = 0, tag = '') {
    const g = new THREE.Group();
    const t = 0.35;
    const mk = (ww, hh, dd, px, py, pz) => {
      const m = new THREE.Mesh(new THREE.BoxGeometry(ww, hh, dd), this.mats.concrete);
      m.position.set(px, py, pz); m.castShadow = true; m.receiveShadow = true;
      m.userData = { solid: true, material: 'concrete', penetration: 0.06 };
      g.add(m); return m;
    };
    // paredes com vão de porta na face -Z
    mk(w, h, t, 0, h / 2, -d / 2);            // norte (fechada)
    mk(w, h, t, 0, h / 2, d / 2);             // sul
    mk(t, h, d, -w / 2, h / 2, 0);
    mk(t, h, d, w / 2, h / 2, 0);
    const roof = mk(w + 0.4, 0.35, d + 0.4, 0, h, 0);
    roof.userData.material = 'concrete';
    // recorte de porta: buraco fake com dois blocos
    g.children[0].geometry.dispose();
    g.children[0].geometry = new THREE.BoxGeometry((w - 1.4) / 2, h, t);
    g.children[0].position.x = -(w + 1.4) / 4;
    const p2 = mk((w - 1.4) / 2, h, t, (w + 1.4) / 4, h / 2, -d / 2);
    const lint = mk(1.4, h - 2.1, t, 0, 2.1 + (h - 2.1) / 2, -d / 2);
    void p2; void lint;
    g.position.set(x, -1.15, z); g.rotation.y = ry;
    g.userData.tag = tag;
    this.group.add(g);
    g.updateMatrixWorld(true);
    g.traverse(o => {
      if (o.isMesh) {
        this.occluders.push(o);
        this.colliders.push(new THREE.Box3().setFromObject(o));
      }
    });
    return g;
  }

  _floodlight(x, z, ry = 0, on = true) {
    const pole = this._box(0.22, 7.2, 0.22, x, 2.4, z, this.mats.metal, 0, { material: 'metal' });
    void pole;
    const head = this._box(1.1, 0.5, 0.5, x, 6.1, z, this.mats.metal, ry, { material: 'metal', noCollide: true });
    const lampMat = new THREE.MeshStandardMaterial({ color: 0xfff0d0, emissive: 0xffe6b8, emissiveIntensity: on ? 6 : 0, roughness: 0.3 });
    const lamp = new THREE.Mesh(new THREE.PlaneGeometry(0.9, 0.36), lampMat);
    lamp.position.set(x + Math.sin(ry) * 0.28, 6.1, z + Math.cos(ry) * 0.28);
    lamp.rotation.y = ry; lamp.rotateX(-0.5);
    this.group.add(lamp);
    const spot = new THREE.SpotLight(0xffe7c0, on ? 55 : 0, 60, 0.62, 0.45, 1.4);
    spot.position.set(x, 6.1, z);
    spot.target.position.set(x + Math.sin(ry) * 22, -1.2, z + Math.cos(ry) * 22);
    this.scene.add(spot, spot.target);
    const src = { pos: spot.position.clone(), radius: 34, on, spot, lamp, head, dir: new THREE.Vector3(Math.sin(ry), -0.35, Math.cos(ry)).normalize() };
    this.lightSources.push(src);
    return src;
  }

  /* ---------------- instalação militar ---------------- */
  _facility() {
    const M = this.mats;
    const R = this.rand;

    // muro perimetral com portão
    const wallH = 3.2;
    for (const [sx, sz, w, d] of [[0, -48, 120, 0.5], [0, 48, 120, 0.5], [-60, 0, 0.5, 96], [60, 0, 0.5, 96]]) {
      if (sz === -48) {
        this._box(48, wallH, 0.5, -36, wallH / 2 - 1.15, sz, M.concrete);
        this._box(48, wallH, 0.5, 36, wallH / 2 - 1.15, sz, M.concrete);
      } else this._box(w, wallH, d, sx, wallH / 2 - 1.15, sz, M.concrete);
    }

    // prédios
    this.buildings = [
      this._building(-30, -18, 18, 14, 6.5, 0, 'barracks'),
      this._building(26, -14, 22, 16, 7.5, 0, 'command'),
      this._building(-24, 22, 16, 12, 5.5, Math.PI, 'garage'),
      this._building(24, 26, 14, 12, 5.0, Math.PI, 'comms')
    ];

    // torre de radar / antena
    const tower = new THREE.Group();
    const mast = this._box(1.4, 22, 1.4, 6, 9.5, 8, M.metal, 0, { material: 'metal' });
    void mast;
    const dish = new THREE.Mesh(new THREE.SphereGeometry(4.2, 28, 16, 0, Math.PI * 2, 0, Math.PI / 2.4), M.metal);
    dish.position.set(6, 21.5, 8); dish.rotation.x = Math.PI * 0.62; dish.castShadow = true;
    dish.userData = { solid: true, material: 'metal', objective: 'radar' };
    this.group.add(dish); this.occluders.push(dish);
    this.radarDish = dish;
    this.group.add(tower);

    // torres de vigia
    this.watchtowers = [];
    for (const [x, z, ry] of [[-52, -40, 0.8], [52, -40, -0.8], [-52, 40, 2.4], [52, 40, -2.4]]) {
      const legs = 6.5;
      for (const [ox, oz] of [[-1.2, -1.2], [1.2, -1.2], [-1.2, 1.2], [1.2, 1.2]])
        this._box(0.25, legs, 0.25, x + ox, legs / 2 - 1.15, z + oz, M.metal, 0, { material: 'metal' });
      const deck = this._box(3.6, 0.25, 3.6, x, legs - 1.15, z, M.metal, 0, { material: 'metal' });
      void deck;
      this._box(3.6, 1.0, 0.2, x, legs - 0.5, z - 1.7, M.metal, 0, { material: 'metal' });
      this._box(3.6, 1.0, 0.2, x, legs - 0.5, z + 1.7, M.metal, 0, { material: 'metal' });
      this._box(0.2, 1.0, 3.6, x - 1.7, legs - 0.5, z, M.metal, 0, { material: 'metal' });
      this._box(0.2, 1.0, 3.6, x + 1.7, legs - 0.5, z, M.metal, 0, { material: 'metal' });
      this._box(4.2, 0.2, 4.2, x, legs + 1.6 - 1.15, z, M.metal, 0, { material: 'metal', noCollide: true });
      this.watchtowers.push({ pos: new THREE.Vector3(x, legs - 1.15 + 1.7, z), ry });
    }

    // contêineres
    this.containerColors = [0x3a4a3a, 0x5a3a2a, 0x27343f, 0x4a4436];
    for (let i = 0; i < 26; i++) {
      const x = (R() - 0.5) * 96, z = (R() - 0.5) * 76;
      if (Math.abs(x) < 14 && Math.abs(z) < 30) continue;
      const stack = R() > 0.72 ? 2 : 1;
      const ry = R() > 0.5 ? 0 : Math.PI / 2 + (R() - 0.5) * 0.2;
      for (let s = 0; s < stack; s++) {
        const mat = M.metal.clone();
        mat.color = new THREE.Color(this.containerColors[(R() * 4) | 0]).multiplyScalar(0.8);
        this._box(6.05, 2.59, 2.44, x, -1.15 + 1.3 + s * 2.6, z, mat, ry, { material: 'metal', penetration: 0.02 });
      }
    }

    // sacos de areia / barricadas
    for (let i = 0; i < 40; i++) {
      const a = R() * Math.PI * 2, rr = 30 + R() * 26;
      const x = Math.cos(a) * rr, z = Math.sin(a) * rr;
      const m = new THREE.Mesh(new THREE.CapsuleGeometry(0.32, 0.7, 4, 8), M.fabric);
      m.rotation.z = Math.PI / 2; m.rotation.y = R() * Math.PI;
      m.position.set(x, -0.85, z); m.castShadow = true; m.receiveShadow = true;
      m.userData = { solid: true, material: 'sandbag', penetration: 0.9 };
      this.group.add(m); this.occluders.push(m);
    }

    // veículos (blocos com silhueta militar)
    this.vehicles = [];
    for (const [x, z, ry] of [[-8, 34, 0.2], [4, 36, -0.3], [-40, -34, 1.2], [40, 10, 2.0]]) {
      const g = new THREE.Group();
      const body = new THREE.Mesh(new THREE.BoxGeometry(5.6, 1.6, 2.4), M.metal);
      body.position.y = 0.9;
      const cab = new THREE.Mesh(new THREE.BoxGeometry(2.2, 1.3, 2.3), M.metal);
      cab.position.set(1.5, 2.1, 0);
      for (const m of [body, cab]) { m.castShadow = true; m.receiveShadow = true; m.userData = { solid: true, material: 'metal', penetration: 0.35 }; g.add(m); this.occluders.push(m); }
      for (const [wx, wz] of [[-1.8, -1.15], [-1.8, 1.15], [1.6, -1.15], [1.6, 1.15]]) {
        const w = new THREE.Mesh(new THREE.CylinderGeometry(0.62, 0.62, 0.42, 16), M.polymer);
        w.rotation.x = Math.PI / 2; w.position.set(wx, 0.62, wz); w.castShadow = true; g.add(w);
      }
      g.position.set(x, -1.35, z); g.rotation.y = ry;
      this.group.add(g); g.updateMatrixWorld(true);
      g.traverse(o => { if (o.isMesh) this.colliders.push(new THREE.Box3().setFromObject(o)); });
      this.vehicles.push(g);
    }

    // holofotes
    this.floods = [
      this._floodlight(-44, -30, 0.9),
      this._floodlight(44, -30, -0.9),
      this._floodlight(-44, 30, 2.3),
      this._floodlight(44, 30, -2.3),
      this._floodlight(0, -44, 0.0)
    ];

    // terminal de invasão cibernética (objetivo hackável)
    const term = this._box(0.9, 1.5, 0.7, 24, -0.4, -14 + 6.5, M.gunmetal, 0, { material: 'metal', interact: 'hack', label: 'TERMINAL SIGINT' });
    const scr = new THREE.Mesh(new THREE.PlaneGeometry(0.62, 0.42),
      new THREE.MeshStandardMaterial({ color: 0x0a1a12, emissive: 0x1e7f4a, emissiveIntensity: 2.2 }));
    scr.position.set(24, 0.05, -14 + 6.86);
    this.group.add(scr);
    this.hackTerminal = term; this.hackScreen = scr;
    term.userData.interact = 'hack';

    // gerador (objetivo: cortar energia -> apaga holofotes)
    const gen = this._box(2.2, 1.6, 1.4, -18, -0.35, 6, M.metal, 0, { material: 'metal', interact: 'generator', label: 'GERADOR PRINCIPAL' });
    this.generator = gen;
  }

  _ambienceProps() {
    // fumaça/vapor de dutos
    this.smokes = [];
    for (const [x, z] of [[26, -6], [-30, -10], [10, 30]]) {
      const geo = new THREE.BufferGeometry();
      const N = 90, pos = new Float32Array(N * 3), seed = new Float32Array(N);
      for (let i = 0; i < N; i++) { pos[i * 3] = x; pos[i * 3 + 1] = 0; pos[i * 3 + 2] = z; seed[i] = Math.random(); }
      geo.setAttribute('position', new THREE.BufferAttribute(pos, 3));
      const p = new THREE.Points(geo, new THREE.PointsMaterial({ color: 0x9aa3a8, size: 2.6, transparent: true, opacity: 0.055, depthWrite: false, sizeAttenuation: true }));
      p.userData = { origin: new THREE.Vector3(x, -0.9, z), seed };
      this.scene.add(p); this.smokes.push(p);
    }
  }

  _rain() {
    const N = 9000;
    const g = new THREE.BufferGeometry();
    const pos = new Float32Array(N * 3);
    const vel = new Float32Array(N);
    for (let i = 0; i < N; i++) {
      pos[i * 3] = (Math.random() - 0.5) * 90;
      pos[i * 3 + 1] = Math.random() * 40;
      pos[i * 3 + 2] = (Math.random() - 0.5) * 90;
      vel[i] = 22 + Math.random() * 14;
    }
    g.setAttribute('position', new THREE.BufferAttribute(pos, 3));
    this.rainVel = vel;
    const m = new THREE.PointsMaterial({ color: 0x8fa4b8, size: 0.045, transparent: true, opacity: 0.5, depthWrite: false });
    this.rain = new THREE.Points(g, m);
    this.rain.frustumCulled = false;
    this.scene.add(this.rain);
  }

  // interseção rápida raio x heightfield (marcha adaptativa) — evita raycast em 80k triângulos
  raycastTerrain(origin, dir, maxDist) {
    let t = 0;
    let py = origin.y - this.height(origin.x, origin.z);
    if (py < 0) return { dist: 0, point: origin.clone() };
    while (t < maxDist) {
      const step = Math.max(0.35, Math.min(6, py * 0.9));
      t += step;
      const p = origin.clone().addScaledVector(dir, t);
      const h = this.height(p.x, p.z);
      const d = p.y - h;
      if (d <= 0) {
        // refino por bisseção
        let lo = t - step, hi = t;
        for (let i = 0; i < 8; i++) {
          const mid = (lo + hi) / 2;
          const pm = origin.clone().addScaledVector(dir, mid);
          if (pm.y - this.height(pm.x, pm.z) <= 0) hi = mid; else lo = mid;
        }
        return { dist: hi, point: origin.clone().addScaledVector(dir, hi) };
      }
      py = d;
    }
    return null;
  }

  cutPower() {
    for (const f of this.floods) { f.on = false; f.spot.intensity = 0; f.lamp.material.emissiveIntensity = 0; }
    this.hackScreen.material.emissiveIntensity = 0.2;
  }

  update(dt, playerPos) {
    // chuva segue o jogador
    const p = this.rain.geometry.attributes.position;
    const w = this.wind;
    for (let i = 0; i < p.count; i++) {
      let y = p.getY(i) - this.rainVel[i] * dt;
      let x = p.getX(i) + w.x * dt, z = p.getZ(i) + w.z * dt;
      if (y < -2 || Math.abs(x - playerPos.x) > 45 || Math.abs(z - playerPos.z) > 45) {
        x = playerPos.x + (Math.random() - 0.5) * 90;
        z = playerPos.z + (Math.random() - 0.5) * 90;
        y = playerPos.y + 24 + Math.random() * 14;
      }
      p.setXYZ(i, x, y, z);
    }
    p.needsUpdate = true;
    this.rain.material.opacity = 0.5 * this.rainAmount;

    for (const s of this.smokes) {
      const pp = s.geometry.attributes.position, sd = s.userData.seed, o = s.userData.origin;
      for (let i = 0; i < pp.count; i++) {
        let y = pp.getY(i) + (0.5 + sd[i]) * dt * 0.9;
        let x = pp.getX(i) + (w.x * 0.25 + Math.sin(y * 0.6 + sd[i] * 9)) * dt * 0.6;
        let z = pp.getZ(i) + (w.z * 0.25) * dt * 0.6;
        if (y > o.y + 9) { y = o.y; x = o.x + (Math.random() - 0.5) * 0.6; z = o.z + (Math.random() - 0.5) * 0.6; }
        pp.setXYZ(i, x, y, z);
      }
      pp.needsUpdate = true;
    }

    // sol/lua acompanham o jogador para sombras estáveis
    this.sun.target.position.set(playerPos.x, 0, playerPos.z);
    const off = this.sun.position.clone().normalize().multiplyScalar(160);
    this.sun.position.copy(new THREE.Vector3(playerPos.x, 0, playerPos.z).add(off));
  }

  // iluminação percebida em um ponto (0..1) — usada pela IA e pelo auto-exposição
  lightAt(pos) {
    let l = this.nightFactor !== undefined ? (1 - this.nightFactor) * 0.8 + 0.04 : 0.5;
    for (const s of this.lightSources) {
      if (!s.on) continue;
      const d = s.pos.distanceTo(pos);
      if (d < s.radius) l += (1 - d / s.radius) * 0.9;
    }
    return Math.min(1.6, l);
  }
}
