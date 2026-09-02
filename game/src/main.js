import * as THREE from 'three';
import { World } from './world/world.js';
import { Input } from './core/input.js';
import { AudioEngine } from './audio/audio.js';
import { Ballistics } from './weapons/ballistics.js';
import { Player } from './player/player.js';
import { Soldier, Squad } from './ai/soldier.js';
import { BodycamPipeline } from './render/bodycam.js';
import { Campaign, Radio } from './campaign/campaign.js';
import { Net } from './net/net.js';
import { clamp } from './core/noise.js';

const canvas = document.getElementById('c');
const renderer = new THREE.WebGLRenderer({ canvas, antialias: false, powerPreference: 'high-performance' });
renderer.setPixelRatio(Math.min(devicePixelRatio, 1.5));
renderer.setSize(innerWidth, innerHeight);
renderer.shadowMap.enabled = true;
renderer.shadowMap.type = THREE.PCFSoftShadowMap;
renderer.toneMapping = THREE.ACESFilmicToneMapping;
renderer.toneMappingExposure = 1.0;
renderer.outputColorSpace = THREE.SRGBColorSpace;

const scene = new THREE.Scene();
const camera = new THREE.PerspectiveCamera(96, innerWidth / innerHeight, 0.02, 2200);
scene.add(camera);

const input = new Input(canvas);
const audio = new AudioEngine();
const world = new World(scene, renderer);
world.setTimeOfDay(2.6);                       // 02:36 — noite fechada, chuva
world.rainAmount = 0.8;

const ballistics = new Ballistics(scene, world, audio);
const player = new Player(scene, camera, world, input, audio, ballistics, world.mats);
const pipeline = new BodycamPipeline(renderer, scene, camera);

/* ---------- overlay dieg��tico: transcrição do rádio queimada no vídeo ---------- */
const caption = document.createElement('div');
caption.style.cssText = `position:fixed;left:0;right:0;bottom:6.5vh;z-index:20;text-align:center;
  font:12px/1.7 ui-monospace,monospace;letter-spacing:.10em;color:#dfe4df;text-shadow:0 1px 3px #000;
  opacity:0;transition:opacity .35s;pointer-events:none;padding:0 12vw;mix-blend-mode:screen`;
document.body.appendChild(caption);
const radio = new Radio(audio, caption);

/* ---------- luneta (máscara óptica, sem HUD) ---------- */
const scopeMat = new THREE.ShaderMaterial({
  transparent: true, depthTest: false, depthWrite: false,
  uniforms: { uMis: { value: new THREE.Vector2() }, uT: { value: 0 }, uMil: { value: 1 } },
  vertexShader: `varying vec2 vUv; void main(){ vUv=uv; gl_Position=projectionMatrix*modelViewMatrix*vec4(position,1.0);} `,
  fragmentShader: `
    varying vec2 vUv; uniform vec2 uMis; uniform float uT;
    void main(){
      vec2 p = (vUv-0.5)*2.0;
      p.x *= 1.0;
      float r = length(p - uMis*2.2);
      float ring = smoothstep(0.86, 0.90, r);           // borda do tubo
      float black = smoothstep(0.90, 0.93, r);
      // retículo mil-dot
      float ret = 0.0;
      float w = 0.0022;
      if(abs(p.y) < 0.72 && abs(p.x) < w) ret = 1.0;
      if(abs(p.x) < 0.72 && abs(p.y) < w) ret = 1.0;
      for(int i=1;i<7;i++){
        float d = float(i)*0.09;
        if(abs(abs(p.y)-d) < 0.004 && abs(p.x) < 0.014) ret = 1.0;
        if(abs(abs(p.x)-d) < 0.004 && abs(p.y) < 0.010) ret = 1.0;
      }
      float alpha = max(black, ring*0.55);
      vec3 col = vec3(0.0);
      // aberração no anel + sujeira da ocular
      col += vec3(0.03,0.035,0.04)*ring;
      float a = max(alpha, ret*(1.0-black));
      col = mix(col, vec3(0.02), ret);
      gl_FragColor = vec4(col, a);
    }`
});
const scopeMask = new THREE.Mesh(new THREE.PlaneGeometry(2, 2), scopeMat);
scopeMask.frustumCulled = false; scopeMask.renderOrder = 998; scopeMask.visible = false;
const scopeCam = new THREE.OrthographicCamera(-1, 1, 1, -1, 0, 1);
const scopeScene = new THREE.Scene(); scopeScene.add(scopeMask);

/* ---------- guarnição inimiga ---------- */
const squad = new Squad();
const entities = [player];
function spawnEnemy(pos, alerted = false, route = null, sentry = false) {
  const s = new Soldier(scene, world, audio, ballistics, world.mats, { pos, route, sentry });
  squad.add(s); entities.push(s);
  if (alerted) { s.state = 'combat'; s.suspicion = 1; s.alert = 1; s.lastKnown = player.pos.clone(); }
  return s;
}
const V = (x, z) => new THREE.Vector3(x, 0, z);
// patrulhas do perímetro
spawnEnemy(V(-40, 30), false, [V(-40, 30), V(-40, -30), V(-10, -38), V(-40, 30)]);
spawnEnemy(V(40, -30), false, [V(40, -30), V(40, 30), V(12, 38), V(40, -30)]);
spawnEnemy(V(0, -40), false, [V(-20, -42), V(20, -42), V(20, -20), V(-20, -20)]);
spawnEnemy(V(-24, 10), false, [V(-24, 10), V(-6, 14), V(-6, -6), V(-24, 4)]);
// sentinelas fixas
for (const t of world.watchtowers) {
  const s = spawnEnemy(t.pos.clone(), false, null, true);
  s.fixedY = t.pos.y; s.pos.y = t.pos.y; s.eyeH = 1.35; s.yaw = t.ry;
}
spawnEnemy(V(26, -6), false, null, true);
spawnEnemy(V(-30, -12), false, null, true);

/* ---------- campanha ---------- */
const campaign = new Campaign({
  player, world, squad, audio, radio, spawnEnemy,
  spawnOfficer: () => {
    const o = spawnEnemy(V(-30, -18), false, null, true);
    o.isOfficer = true;
    o.mesh.userData.hips.children[0].material = new THREE.MeshStandardMaterial({ color: 0x1d2430, roughness: 0.7 });
  },
  onEnd: (reason, summary) => endMission(reason, summary)
});
squad.onAlarm = () => { };

ballistics.onGeoHit = (obj) => {
  if (obj.userData.objective === 'radar') campaign.radarHits = (campaign.radarHits || 0) + 1;
};
// patch: contabiliza acertos no radar
const _addDecal = ballistics.addDecal.bind(ballistics);
ballistics.addDecal = (p, n, m) => _addDecal(p, n, m);

/* ---------- multiplayer opcional ---------- */
const net = new Net(scene, world, world.mats);
if (new URLSearchParams(location.search).has('mp')) net.connect(player);

/* ---------- boot ---------- */
const boot = document.getElementById('boot');
const fade = document.getElementById('fade');
let running = false;
boot.addEventListener('click', () => {
  audio.init();
  audio.setEnvironment({ rain: world.rainAmount, wind: 0.5 });
  boot.style.display = 'none';
  fade.style.opacity = 0;
  input.lock();
  running = true;
  campaign.begin();
});
canvas.addEventListener('click', () => { if (running && !input.locked) input.lock(); });

document.getElementById('exit').addEventListener('click', () => {
  document.exitPointerLock?.();
  endMission('abort', campaign.summary());
});

function endMission(reason, summary) {
  running = false;
  fade.style.opacity = 1;
  const box = document.createElement('div');
  box.style.cssText = `position:fixed;inset:0;z-index:70;background:#000;color:#c9cfc9;display:flex;
    align-items:center;justify-content:center;flex-direction:column;gap:16px;font:12px/2 ui-monospace,monospace;
    letter-spacing:.14em;text-align:center;padding:6vh 8vw`;
  const choices = summary.escolhas.map(c => `— ${c.taken}`).join('<br>') || '— nenhuma decisão registrada';
  box.innerHTML = `<div style="font-size:20px;letter-spacing:.5em">GRAVAÇÃO ENCERRADA</div>
    <div style="opacity:.55">MOTIVO: ${reason.toUpperCase()} · TEMPO EM CAMPO ${(campaign.t / 60).toFixed(1)} MIN</div>
    <div style="opacity:.8;max-width:760px">${choices}</div>
    <div style="opacity:.45">DETECTADO: ${summary.detectado ? 'SIM' : 'NÃO'} · ARQUIVO ENVIADO AO COMANDO</div>
    <div style="opacity:.35">RECARREGUE A PÁGINA PARA REINICIAR O ATO</div>`;
  document.body.appendChild(box);
}

/* ---------- loop ---------- */
addEventListener('resize', () => {
  camera.aspect = innerWidth / innerHeight; camera.updateProjectionMatrix();
  renderer.setSize(innerWidth, innerHeight);
  pipeline.setSize(innerWidth, innerHeight);
});

let last = performance.now() / 1000;
let warT = 6 + Math.random() * 8;

function frame() {
  requestAnimationFrame(frame);
  const now = performance.now() / 1000;
  let dt = Math.min(0.05, now - last);
  last = now;
  if (!running) { input.endFrame(); return; }

  player.update(dt, entities);

  // eventos do jogador -> percepção da IA
  for (const ev of player.events) {
    if (ev.type === 'noise' || ev.type === 'shot') {
      const e = { pos: ev.pos, radius: ev.radius, type: ev.type, suppressed: ev.suppressed };
      for (const s of squad.members) if (s.alive) s.hear(e);
    }
    if (ev.type === 'powercut') { for (const s of squad.members) if (s.alive) s.hear({ pos: ev.pos, radius: 70, type: 'noise' }); }
    if (ev.type === 'death') setTimeout(() => endMission('operador morto em combate', campaign.summary()), 5200);
  }
  player.events.length = 0;

  for (const s of squad.members) s.update(dt, player, world, entities);
  ballistics.update(dt, player.eyePos);
  world.update(dt, player.pos);
  radio.update(dt);
  campaign.update(dt, input);
  net.update(dt, player);

  // guerra ao longe: artilharia esporádica
  warT -= dt;
  if (warT <= 0) { warT = 7 + Math.random() * 22; audio.distantWar(); }

  // luneta
  const w = player.weapon;
  scopeMask.visible = !!(w.def.scope && player.ads > 0.72);
  if (scopeMask.visible) {
    scopeMat.uniforms.uMis.value.set(
      (player.yaw - player.camYaw) * 1.6 + Math.sin(player.breathPhase) * 0.006,
      (player.pitch - player.camPitch) * 1.6);
  }

  const st = player.cameraState();
  st.glitch = clamp(st.glitch + (player.health < 0.4 ? 0.25 : 0) + (net.jitter || 0), 0, 1);
  pipeline.render(dt, st);
  if (scopeMask.visible) {
    renderer.setRenderTarget(null);
    renderer.autoClear = false;
    renderer.render(scopeScene, scopeCam);
    renderer.autoClear = true;
  }

  input.endFrame();
}
frame();

// exposto para depuração/telemetria
window.TZ = { player, world, campaign, squad, audio, renderer, scene };
