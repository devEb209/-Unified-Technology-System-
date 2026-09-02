import * as THREE from 'three';
import { damp, clamp, randn } from '../core/noise.js';

/* Fichas técnicas reais aproximadas. Nada de "tiro cinematográfico":
   cadência, massa do projétil, velocidade de boca e recuo saem de dados de catálogo. */
export const WEAPON_DEFS = {
  mk18: {
    name: 'MK18 CQBR 5.56×45 (supressor SOCOM)',
    caliber: '5.56x45',
    muzzleVelocity: 780, bulletMass: 0.004, bc: 0.304 /* G1, M855 */, penetration: 0.8,
    rpm: 770, auto: true, magSize: 30, moa: 2.2, tracerEvery: 0,
    adsTime: 0.20, weight: 3.4, suppressed: true,
    recoil: { up: 0.0085, side: 0.0035, kick: 0.045, recovery: 9 },
    reload: { tactical: 2.25, empty: 3.05 },
    zero: 100, scope: null, sightHeight: 0.068
  },
  m110: {
    name: 'M110 SASS 7.62×51 (Leupold 3-10×)',
    caliber: '7.62x51',
    muzzleVelocity: 838, bulletMass: 0.0108, bc: 0.500 /* G1, M118LR */, penetration: 1.0,
    rpm: 240, auto: false, magSize: 20, moa: 0.9, tracerEvery: 0,
    adsTime: 0.34, weight: 6.9, suppressed: true,
    recoil: { up: 0.021, side: 0.006, kick: 0.12, recovery: 6 },
    reload: { tactical: 2.9, empty: 3.9 },
    zero: 400, scope: { magnification: 10, exitPupil: 0.32 }, sightHeight: 0.085
  },
  g19: {
    name: 'Glock 19 9×19 (supressor Obsidian)',
    caliber: '9x19',
    muzzleVelocity: 365, bulletMass: 0.008, bc: 0.165 /* G1, 124gr */, penetration: 0.35,
    rpm: 420, auto: false, magSize: 15, moa: 4.0, tracerEvery: 0,
    adsTime: 0.16, weight: 1.1, suppressed: true,
    recoil: { up: 0.013, side: 0.007, kick: 0.06, recovery: 11 },
    reload: { tactical: 1.9, empty: 2.5 },
    zero: 25, scope: null, sightHeight: 0.032
  }
};

function mkBox(w, h, d, mat, x = 0, y = 0, z = 0) {
  const m = new THREE.Mesh(new THREE.BoxGeometry(w, h, d), mat);
  m.position.set(x, y, z); m.castShadow = false; m.receiveShadow = false;
  return m;
}
function mkCyl(r1, r2, h, mat, x = 0, y = 0, z = 0, rx = Math.PI / 2) {
  const m = new THREE.Mesh(new THREE.CylinderGeometry(r1, r2, h, 18), mat);
  m.rotation.x = rx; m.position.set(x, y, z);
  return m;
}

export function buildViewmodel(key, mats) {
  const g = new THREE.Group();
  const gm = mats.gunmetal, pl = mats.polymer;
  const glove = new THREE.MeshStandardMaterial({ color: 0x1a1c19, roughness: 0.9 });

  if (key === 'g19') {
    g.add(mkBox(0.032, 0.052, 0.19, gm, 0, 0, -0.02));
    g.add(mkBox(0.030, 0.10, 0.038, pl, 0, -0.075, 0.035));
    g.add(mkCyl(0.021, 0.021, 0.17, gm, 0, -0.004, -0.19));
    g.add(mkBox(0.020, 0.02, 0.012, gm, 0, 0.031, -0.10));
    g.add(mkBox(0.024, 0.02, 0.012, gm, 0, 0.031, 0.05));
    const mag = mkBox(0.026, 0.09, 0.032, pl, 0, -0.075, 0.035); mag.name = 'mag'; g.add(mag);
    const hand = mkBox(0.055, 0.10, 0.07, glove, 0.01, -0.075, 0.04); hand.name = 'handR'; g.add(hand);
    g.userData.muzzle = new THREE.Vector3(0, -0.004, -0.28);
    g.userData.ejection = new THREE.Vector3(0.035, 0.02, 0);
    g.userData.sight = new THREE.Vector3(0, 0.032, -0.05);
  } else if (key === 'm110') {
    g.add(mkBox(0.045, 0.075, 0.42, gm, 0, 0, 0));
    g.add(mkBox(0.055, 0.07, 0.30, pl, 0, -0.005, -0.34));          // handguard
    g.add(mkCyl(0.013, 0.013, 0.62, gm, 0, 0.004, -0.42));           // cano
    g.add(mkCyl(0.026, 0.026, 0.22, gm, 0, 0.004, -0.80));           // supressor
    g.add(mkBox(0.05, 0.12, 0.18, pl, 0, -0.03, 0.28));              // coronha
    g.add(mkBox(0.06, 0.045, 0.10, pl, 0, 0.035, 0.24));             // face rest
    g.add(mkBox(0.035, 0.11, 0.045, pl, 0, -0.085, 0.10));           // punho
    const mag = mkBox(0.030, 0.15, 0.075, pl, 0, -0.10, -0.04); mag.name = 'mag'; g.add(mag);
    const scope = mkCyl(0.031, 0.031, 0.34, gm, 0, 0.085, -0.06); scope.name = 'scope'; g.add(scope);
    g.add(mkCyl(0.042, 0.042, 0.06, gm, 0, 0.085, -0.22));
    g.add(mkBox(0.02, 0.045, 0.02, gm, 0, 0.06, 0.02));
    g.add(mkBox(0.02, 0.045, 0.02, gm, 0, 0.06, -0.12));
    const bolt = mkBox(0.024, 0.024, 0.09, gm, 0.032, 0.012, 0.10); bolt.name = 'bolt'; g.add(bolt);
    const hand = mkBox(0.06, 0.10, 0.08, glove, 0.012, -0.09, 0.10); hand.name = 'handR'; g.add(hand);
    const hand2 = mkBox(0.07, 0.07, 0.11, glove, -0.01, -0.055, -0.34); hand2.name = 'handL'; g.add(hand2);
    g.userData.muzzle = new THREE.Vector3(0, 0.004, -0.92);
    g.userData.ejection = new THREE.Vector3(0.05, 0.02, 0.02);
    g.userData.sight = new THREE.Vector3(0, 0.085, -0.02);
  } else {
    g.add(mkBox(0.042, 0.075, 0.32, gm, 0, 0, 0.02));
    g.add(mkBox(0.052, 0.062, 0.24, pl, 0, -0.004, -0.24));
    g.add(mkCyl(0.011, 0.011, 0.30, gm, 0, 0.005, -0.30));
    g.add(mkCyl(0.024, 0.024, 0.19, gm, 0, 0.005, -0.52));           // supressor
    g.add(mkBox(0.048, 0.09, 0.16, pl, 0, -0.012, 0.26));            // coronha retrátil
    g.add(mkBox(0.034, 0.105, 0.042, pl, 0, -0.082, 0.13));
    const mag = mkBox(0.028, 0.16, 0.07, pl, 0, -0.11, -0.01); mag.name = 'mag';
    mag.rotation.x = 0.12; g.add(mag);
    const rds = mkBox(0.032, 0.038, 0.055, gm, 0, 0.068, -0.02); rds.name = 'optic'; g.add(rds);
    const lens = new THREE.Mesh(new THREE.PlaneGeometry(0.026, 0.026),
      new THREE.MeshPhysicalMaterial({ color: 0x14202a, roughness: 0.05, metalness: 0.2, transparent: true, opacity: 0.55 }));
    lens.position.set(0, 0.068, 0.004); g.add(lens);
    const dot = new THREE.Mesh(new THREE.CircleGeometry(0.0011, 10),
      new THREE.MeshBasicMaterial({ color: 0xff2a12, transparent: true, opacity: 0.95, depthTest: false }));
    dot.position.set(0, 0.068, -0.02); dot.renderOrder = 999; dot.name = 'dot'; g.add(dot);
    const ch = mkBox(0.05, 0.014, 0.02, gm, 0, 0.036, 0.17); ch.name = 'charging'; g.add(ch);
    const hand = mkBox(0.058, 0.10, 0.075, glove, 0.012, -0.085, 0.13); hand.name = 'handR'; g.add(hand);
    const hand2 = mkBox(0.07, 0.07, 0.11, glove, -0.012, -0.05, -0.26); hand2.name = 'handL'; g.add(hand2);
    g.userData.muzzle = new THREE.Vector3(0, 0.005, -0.62);
    g.userData.ejection = new THREE.Vector3(0.04, 0.02, 0.06);
    g.userData.sight = new THREE.Vector3(0, 0.068, -0.02);
  }
  g.traverse(o => { o.frustumCulled = false; if (o.isMesh) o.renderOrder = 10; });
  return g;
}

export class Weapon {
  constructor(key, mats) {
    this.key = key;
    this.def = WEAPON_DEFS[key];
    this.model = buildViewmodel(key, mats);
    this.mag = this.def.magSize;
    this.chambered = true;
    this.reserve = this.def.magSize * (key === 'm110' ? 4 : 6);
    this.state = 'idle';
    this.stateT = 0;
    this.nextShot = 0;
    this.heat = 0;
    this.boltBack = false;
    this.zeroDistance = this.def.zero;
  }
  get rounds() { return this.mag + (this.chambered ? 1 : 0); }
  get canFire() { return this.state === 'idle' && this.chambered && this.nextShot <= 0; }
}
