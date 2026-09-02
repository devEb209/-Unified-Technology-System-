// Teste de simulação headless: roda mundo, IA, balística e campanha sem GPU.
// node tools/smoke.js
import * as THREE from 'three';
globalThis.window = globalThis; globalThis.self = globalThis;
globalThis.performance = globalThis.performance || { now: () => Date.now() };
globalThis.devicePixelRatio = 1;
globalThis.addEventListener = () => { };
globalThis.document = { createElement: () => ({ style: {}, getContext: () => null, addEventListener: () => { } }), addEventListener: () => { }, body: { appendChild: () => { } } };

const { World } = await import('../src/world/world.js');
const { Ballistics } = await import('../src/weapons/ballistics.js');
const { Soldier, Squad } = await import('../src/ai/soldier.js');
const { Campaign, Radio } = await import('../src/campaign/campaign.js');
const { WEAPON_DEFS } = await import('../src/weapons/weapons.js');

const scene = new THREE.Scene();
const world = new World(scene, { getSize: (v) => v.set(1280, 720), getPixelRatio: () => 1 });
world.setTimeOfDay(2.6);
console.log(`mundo: ${world.colliders.length} colisores, ${world.occluders.length} oclusores, luz@centro=${world.lightAt(new THREE.Vector3(0, 1.6, 0)).toFixed(2)}`);

const audioStub = new Proxy({}, { get: () => () => { } });
const bal = new Ballistics(scene, world, audioStub);

// jogador falso
const player = {
  pos: new THREE.Vector3(0, 0, 40), vel: new THREE.Vector3(), stance: 'stand',
  alive: true, health: 1, suppression: 0, nvOn: true, camImpulseVel: new THREE.Vector3(),
  get eyePos() { return new THREE.Vector3(this.pos.x, this.pos.y + 1.63, this.pos.z); },
  raycastCapsule: () => null, applyBullet(p, d, e, part) { this.health -= 0.3; }, events: [],
  _powerCut: false, _hacked: false, breathPhase: 0, yaw: 0, camYaw: 0, pitch: 0, camPitch: 0
};

const squad = new Squad();
const entities = [player];
const mk = (x, z) => { const s = new Soldier(scene, world, audioStub, bal, world.mats, { pos: new THREE.Vector3(x, 0, z) }); squad.add(s); entities.push(s); return s; };
for (let i = 0; i < 8; i++) mk(-30 + i * 8, -20 + (i % 3) * 10);

// balística: verificar queda de bala a 400 m com o M110
const d = WEAPON_DEFS.m110;
const origin = new THREE.Vector3(0, 1.6, 0);
const b = bal.fire(origin, new THREE.Vector3(0, 0, -1), { ...d, moa: 0 }, { pos: origin }, []);
let t = 0, dropAt400 = null;
while (t < 3 && dropAt400 === null) {
  bal.update(1 / 240, origin); t += 1 / 240;
  if (b.pos.length() > 400 && dropAt400 === null) dropAt400 = 1.6 - b.pos.y;
  if (!bal.bullets.includes(b)) break;
}
console.log(`M110: queda a ~400 m = ${dropAt400 ? dropAt400.toFixed(2) + ' m' : 'projétil parou antes'} (esperado ~1.2-2.5 m com zero de boca)`);

const radio = new Radio(audioStub, { style: {}, textContent: '' });
const campaign = new Campaign({ player, world, squad, audio: audioStub, radio, spawnEnemy: (p) => mk(p.x, p.z), onEnd: (r) => console.log('fim:', r) });
campaign.begin();

let alarmed = 0;
for (let i = 0; i < 60 * 30; i++) {
  const dt = 1 / 60;
  player.pos.z -= dt * 3;                     // avança para o complexo
  for (const s of squad.members) s.update(dt, player, world, entities);
  bal.update(dt, player.eyePos);
  radio.update(dt);
  campaign.update(dt, { hit: () => false });
  if (i === 1200) { player._powerCut = true; }
  if (i === 1800) { player._hacked = true; }
  if (squad.alertLevel >= 1 && !alarmed) alarmed = i;
}
console.log(`30 s simulados: fase=${campaign.phase}, objetivos=${campaign.objectives.map(o => o.id + (o.done ? '✓' : '·')).join(' ')}`);
console.log(`IA: ${squad.alive.length}/${squad.members.length} vivos, estados=${[...new Set(squad.members.map(s => s.state))].join(',')}, alarme=${alarmed ? 'sim' : 'não'}`);
console.log(`decisões pendentes: ${campaign.decision ? campaign.decision.prompt : 'nenhuma'} | escolhas: ${campaign.state.choices.length}`);
console.log('OK — simulação estável, sem exceções.');
