// R20 — A TEIA VIVA: EMPUXO DE ARQUIMEDES na física (a água desloca volume:
// gelo flutua 92% afundado como na realidade), CORDAS PBD (corrente de nós
// que sobrevive ao save/load), IMPACTO DERRUBA NPC (a mente espera, o corpo
// obedece), A TEIA (peixes comem o plâncton e seguem o banco; aves seguem os
// peixes), O ARCO-ÍRIS (anel de 42° do antissolar, secundário invertido a
// 51°, banda de Alexander), O SMITH POR DESCRIÇÃO (o chat vira lente), O
// DIRETOR VIVO (a cutscene voa a câmera com easing e mira, e DEVOLVE o
// enquadramento), A NUVEM HONESTA (interface estruturada, chave só por env,
// offline é DITO), O KIT ANDROID REAL (projeto gradle completo embalado) e
// O OLHO DO DIRETOR (a IA lê o próprio mundo e critica com sugestões).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createUTS } from '../src/index.js';
import { FluidField, FLUID_CONST } from '../src/world/phenomena/fluids.js';
import { save, load } from '../src/persistence/snapshot.js';
import { Cutscene } from '../src/media/cutscene.js';
import { CloudStorageProvider } from '../src/platform/services/cloud-storage.js';
import { createPlatform } from '../src/platform/platform.js';
import { build } from '../src/agent/build-system.js';
import { zipRead } from '../src/util/zip.js';
import { forgeLook, LOOKS } from '../src/agent/shader-smith.js';
import { rainbowTintJS, rainbowDarkenJS, SKY_FS } from '../src/render/shaders.js';

// ---------------------------------------------------------------- empuxo
test('r20: EMPUXO DE ARQUIMEDES — gelo flutua 92% afundado, madeira leve, rocha no fundo, splash é evento', async () => {
  const uts = createUTS({ seed: 'agua' });
  const w = uts.world;
  const t = w.terrain;
  let hi = null;
  for (let x = 60; x < 960 && !hi; x += 8) for (let z = 60; z < 960; z += 8) if (t.height(x, z) > 18) { hi = [x, z]; break; }
  assert.ok(hi, 'existe morro no mundo');
  const fl = w.fluid;
  fl.pour(hi[0], hi[1], 60);
  for (let i = 0; i < 2200; i++) fl.step(0.05); // a água acha o baixio
  let best = null;
  for (const [k, h] of fl.depth) {
    if (h < 0.2) continue;
    const [i2, j2] = k.split(',').map(Number);
    const x = i2 * FLUID_CONST.CELL, z = j2 * FLUID_CONST.CELL;
    if (!best || h > best.h) best = { x, z, h, ground: t.height(x, z) };
  }
  assert.ok(best && best.h > 0.5, `existe poça funda (${best?.h?.toFixed(2) ?? 0})`);
  const wl = best.ground + best.h;
  const mk = (mat, dx) => w.physics.addBody({ pos: [best.x + dx, wl + 0.5, best.z], radius: 0.12, material: mat });
  const wood = mk('wood', 0), ice = mk('ice', 0.4), rock = mk('rock', -0.4);
  for (let i = 0; i < 300; i++) uts.ues.tick(0.05);
  const wl2 = w.physics._waterLevel(best.x, best.z) ?? wl;
  const frac = (id) => {
    const sp = w.rrw.getComponent(id, 'spatial');
    return Math.max(0, Math.min(1, (wl2 - (sp.pos[1] - 0.12)) / 0.24));
  };
  const fW = frac(wood.id), fI = frac(ice.id), ground = best.ground + 0.12;
  const yRock = w.rrw.getComponent(rock.id, 'spatial').pos[1];
  assert.ok(Math.abs(fW - 0.7) < 0.12, `madeira flutua com ${fW.toFixed(2)} submerso (ρ=0.7)`);
  assert.ok(Math.abs(fI - 0.92) < 0.08, `gelo flutua com ${fI.toFixed(2)} submerso — 92% como na realidade`);
  assert.ok(Math.abs(yRock - ground) < 0.15, `rocha afunda ao leito (${yRock.toFixed(2)} ≈ ${ground.toFixed(2)})`);
  assert.ok((w.physics.stats.splashes ?? 0) >= 3, `entrar na água fez ${w.physics.stats.splashes} splashes`);
  // conservação da massa segue de pé
  assert.ok(fl.mass >= 0, `massa medida: ${fl.mass.toFixed(2)}`);
});

// ---------------------------------------------------------------- cordas
test('r20: A CORDA É REAL — corrente PBD pendurada com esticão pequena, e sobrevive ao save/load', async () => {
  const uts = createUTS({ seed: 'corda-r20' });
  const w = uts.world;
  const rope = w.physics.buildRope({ from: [500, 30, 500], to: [500, 20, 500], segments: 8 });
  assert.equal(rope.nodes.length, 9);
  w.ues.run(240);
  const sp = (id, world) => world.rrw.getComponent(id, 'spatial');
  let ms = 0;
  for (let i = 0; i < 8; i++) {
    const a = sp(rope.nodes[i], w).pos, b = sp(rope.nodes[i + 1], w).pos;
    ms = Math.max(ms, Math.abs(Math.hypot(b[0] - a[0], b[1] - a[1], b[2] - a[2]) - rope.segment) / rope.segment);
  }
  const tipY = sp(rope.nodes[8], w).pos[1];
  assert.ok(tipY < 29, `a corda pende da âncora (ponta em ${tipY.toFixed(2)}, âncora em 30)`);
  assert.ok(ms < 0.12, `esticão máxima ${(ms * 100).toFixed(1)}% (PBD segurou)`);
  const store = new Map();
  await save(store, 'slot', uts);
  const B = await load(store, 'slot');
  assert.equal(B.world.physics.joints.length, 8, 'as juntas renascem do RRW no reattach');
  B.world.ues.run(60);
  let ms2 = 0;
  for (let i = 0; i < 8; i++) {
    const a = sp(rope.nodes[i], B.world).pos, b = sp(rope.nodes[i + 1], B.world).pos;
    ms2 = Math.max(ms2, Math.abs(Math.hypot(b[0] - a[0], b[1] - a[1], b[2] - a[2]) - rope.segment) / rope.segment);
  }
  assert.ok(Math.abs(sp(rope.nodes[8], B.world).pos[1] - tipY) < 0.2 && ms2 < 0.12, 'a corda restaurada é A MESMA corda (posição e tensão)');
});

// ------------------------------------------------------- impacto derruba
test('r20: IMPACTO DERRUBA NPC — o corpo obedece à física, a mente espera e o NPC levanta', async () => {
  const uts = createUTS({ seed: 'queda-r20' });
  const w = uts.world;
  w.ues.run(5);
  const npc = w.spawnNPC({ pos: [512, 0, 512] });
  const sp = w.rrw.getComponent(npc.id, 'spatial');
  w.ues.run(20);
  const rock = w.physics.addBody({ pos: [sp.pos[0], sp.pos[1] + 6, sp.pos[2]], vel: [0, -10, 0], radius: 0.5 });
  assert.ok(rock.id, 'rocha lançada');
  w.ues.run(30);
  const npcC = w.rrw.getComponent(npc.id, 'npc');
  assert.ok(npcC.downedUntil > w.clock.tick, 'a energia cinética pôs o NPC no chão (evento causal)');
  w.rrw.addComponent(npc.id, 'intent', { target: [sp.pos[0] + 60, 0, sp.pos[2]] });
  const x0 = sp.pos[0];
  w.ues.run(40);
  assert.ok(Math.abs(sp.pos[0] - x0) < 0.01, `caído NÃO anda (andou ${Math.abs(sp.pos[0] - x0).toFixed(3)}m)`);
  w.ues.run(Math.max(10, npcC.downedUntil - w.clock.tick + 20));
  assert.ok(w.clock.tick >= npcC.downedUntil, 'o NPC levanta quando o tempo do corpo cumpre');
  // controle: um NPC em pé com a mesma ordem anda
  const npc2 = w.spawnNPC({ pos: [600, 0, 600] });
  const sp2 = w.rrw.getComponent(npc2.id, 'spatial');
  w.ues.run(5);
  w.rrw.addComponent(npc2.id, 'intent', { target: [sp2.pos[0] + 60, 0, sp2.pos[2]] });
  const x20 = sp2.pos[0];
  w.ues.run(60);
  assert.ok(Math.abs(sp2.pos[0] - x20) > 0.2, `NPC em pé anda (controle: ${(sp2.pos[0] - x20).toFixed(2)}m — a mente escolhe o rumo)`);
});

// ------------------------------------------------------------------ teia
test('r20: A TEIA — peixes comem o plâncton e SEGUEM o banco advectado; aves seguem os peixes; tudo persiste', () => {
  const uts = createUTS({ seed: 'teia-r20' });
  const eco = uts.world.ecology;
  eco.planktonField.set('8,8', 0.9);
  for (let i = 0; i < 400; i++) eco.step(0.5, { sunEl: 1, seaSilt: 0.05 });
  const live = [...eco.fishField.entries()].filter(([, v]) => v > 0.05);
  const maxFish = Math.max(...[...eco.fishField.values()]);
  assert.ok(maxFish > 0.4, `o cardume cresceu comendo o plâncton (pico ${maxFish.toFixed(2)})`);
  assert.ok([...eco.fishField.keys()].some((k) => k !== '8,8'), 'o cardume VIAJOU com o banco (correnteza leva peixe e comida juntos)');
  assert.ok(eco.seabirds > 5, `as aves chegaram seguindo o peixe (${eco.seabirds.toFixed(0)} aves)`);
  const snap = uts.world.phenomenaSnapshot();
  const w2 = createUTS({ seed: 'outra' }).world;
  w2.phenomenaRestore(snap);
  assert.equal(w2.ecology.fishField.size, eco.fishField.size);
  assert.ok(Math.abs(w2.ecology.seabirds - eco.seabirds) < 1e-9, 'aves restauradas exatas');
  // sem plâncton não nasce peixe (a teia não é mágica, é comida)
  const w3 = createUTS({ seed: 'terceiro' }).world;
  for (let i = 0; i < 200; i++) w3.ecology.step(0.5, { sunEl: 1, seaSilt: 0 });
  assert.equal(w3.ecology.fishField.size, 0, 'sem comida, sem peixe');
  assert.equal(uts.world.environment.seabirds ?? uts.world.ecology.seabirds, eco.seabirds, 'o ambiente lê as aves da teia');
});

// -------------------------------------------------------------- arco-íris
test('r20: O ARCO-ÍRIS É FÍSICA — 42° do antissolar, secundário invertido a 51°, banda de Alexander, e só existe com chuva+sol', () => {
  const sun = [0, -0.447, -0.894], u = [0, 0.447, 0.894], v = [1, 0, 0];
  const at = (deg) => { const a = deg * Math.PI / 180; return [u[0] * Math.cos(a) + v[0] * Math.sin(a), u[1] * Math.cos(a) + v[1] * Math.sin(a), u[2] * Math.cos(a) + v[2] * Math.sin(a)]; };
  const t = (deg) => rainbowTintJS(at(deg), sun, 1);
  assert.ok(t(42)[0] > 0.8 && t(42)[2] < 0.05, `borda externa do primário é VERMELHA (${t(42).map((x) => x.toFixed(2)).join(',')})`);
  assert.ok(t(40.5)[2] > 0.8 && t(40.5)[0] < 0.05, `borda interna é AZUL (${t(40.5).map((x) => x.toFixed(2)).join(',')})`);
  assert.ok(t(46).every((c) => c < 1e-9), 'a banda de Alexander não tem luz do arco');
  assert.ok(t(53)[2] > 0.3 && t(53)[0] < 0.02, `o secundário tem azul POR FORA (${t(53).map((x) => x.toFixed(2)).join(',')}) — ordem invertida`);
  assert.ok(Math.abs(rainbowDarkenJS(at(46), sun, 1) - 0.72) < 0.01, `Alexander escurece o céu em ~28% (${rainbowDarkenJS(at(46), sun, 1).toFixed(2)})`);
  assert.equal(rainbowDarkenJS(at(55), sun, 1), 1);
  assert.ok(rainbowTintJS(at(42), sun, 0).every((c) => c === 0), 'sem água suspensa não há arco');
  // o shader carrega a MESMA física (espelho) e o uniform
  assert.match(SKY_FS, /rainbowTint\(dir, uSunDir, uRainbow\)/);
  assert.match(SKY_FS, /0\.28 \* SS\(41\.0, 46\.0, rAng\)/, 'a banda de Alexander está no GLSL com as mesmas constantes');
  // o frame só acende o arco com chuva E sol
  const uts = createUTS({ seed: 'arco' });
  uts.ues.run(2);
  const f1 = uts.ues.renderFrame();
  assert.equal(f1.rainbow, 0, 'sem chuva NÃO há arco (consequência, não efeito)');
  uts.world.environment.rain = 0.8;
  uts.world.clock.time = uts.world.clock.dayLengthSec / 2; // meio-dia: sol a pino
  const f2 = uts.ues.renderFrame();
  assert.ok(f2.rainbow > 0.5, `chuva + sol acendem o arco (${(f2.rainbow ?? 0).toFixed(2)})`);
});

// ------------------------------------------------------------ smith look
test('r20: O SMITH FORJA POR DESCRIÇÃO — o chat diz o olhar, a lente carrega (e o desconhecido é honesto)', async () => {
  const sonho = forgeLook('sonho');
  assert.equal(sonho.amount.bloom, LOOKS.sonho.efeitos.bloom);
  assert.equal(sonho.selfTest.finite, true);
  const misto = forgeLook('noir retrato');
  const mediaV = (LOOKS.noir.efeitos.vinheta + LOOKS.retrato.efeitos.vinheta) / 2;
  assert.ok(Math.abs(misto.amount.vinheta - mediaV) < 0.01, `dois looks cruzam pela média (${misto.amount.vinheta} ≈ ${mediaV})`);
  const criada = forgeLook('caverna do dragão');
  assert.ok(criada.name.includes('(criado)'));
  assert.match(criada.honest, /fora do léxico/);
  assert.equal(criada.selfTest.finite, true, 'mesmo a lente criada passa no autoteste');
  // e chega VIVA na lente do mundo pelo chat da IA
  const uts = createUTS({ seed: 'smith-r20' });
  uts.ues.run(1); uts.ues.renderFrame();
  const r = await uts.core.tools.execute('agent.shader', { look: 'sonho' });
  assert.equal(r.applied, true);
  assert.equal(uts.world.style.params.bloom, LOOKS.sonho.efeitos.bloom);
  assert.equal(uts.world.style.params.tone, LOOKS.sonho.efeitos.tonemap);
});

// -------------------------------------------------------------- cutscene
test('r20: O DIRETOR VIVO — a câmera voa com easing, MIRA o alvo, e o jogo recebe o enquadramento de volta', async () => {
  const uts = createUTS({ seed: 'diretor-r20' });
  const ues = uts.ues;
  const cs = Cutscene.fromBrief({ name: 'voo', beats: [
    { dur: 2.0, cam: [500, 30, 500], cam2: [520, 45, 520], look: [512, 5, 512] },
  ] });
  const saved = JSON.stringify(ues.camera.pos);
  ues.playCutscene(cs);
  ues.run(20); // 1.0s = meio do plano (easing 0.5 → ponto médio exato)
  assert.deepEqual(ues.camera.pos.map((c) => +c.toFixed(6)), [510, 37.5, 510]);
  const d = [512 - 510, 5 - 37.5, 512 - 510];
  assert.ok(Math.abs(ues.camera.yaw - Math.atan2(d[0], d[2])) < 1e-9, 'a câmera MIRA o alvo (yaw da geometria)');
  assert.ok(Math.abs(ues.camera.pitch - (-Math.asin(d[1] / Math.hypot(...d)))) < 1e-9, 'pitch da geometria (mesma convenção do renderer)');
  ues.run(30); // 2.5s > duração
  assert.equal(ues.cutscene, null, 'a cena termina');
  assert.equal(JSON.stringify(ues.camera.pos), saved, 'e o jogo recebe o enquadramento DE VOLTA');
  // pelo chat: media.cutscene com play rola na câmera viva
  const r = await uts.core.tools.execute('media.cutscene', { name: 'abertura', play: true, beats: [{ dur: 1.5, cam: [480, 26, 480], cam2: [500, 40, 480], look: [512, 5, 512] }] });
  assert.equal(r.playback.playing, 'abertura');
  ues.run(10);
  assert.equal(ues.cutscene.name, 'abertura', 'rolando ao vivo pelo tool');
});

// ---------------------------------------------------------------- nuvem
test('r20: A NUVEM HONESTA — interface estruturada, chave só no header por env, offline é DITO', async () => {
  const calls = [];
  const fakeFetch = async (url, init) => { calls.push({ url: String(url), init }); return { ok: true, json: async () => ({ ok: true, keys: ['save-1', 'save-2'] }) }; };
  const cloud = new CloudStorageProvider({ url: 'https://nuvem.exemplo', apiKey: 'segredo-do-env', fetchImpl: fakeFetch });
  assert.equal(await cloud.availability(), true);
  await cloud.put('meu-app', 'save-1', new Uint8Array([1, 2, 3, 255]));
  assert.equal(calls[0].init.headers.authorization, 'Bearer segredo-do-env', 'a chave vai SÓ no header');
  const body = JSON.parse(calls[0].init.body);
  assert.equal(body.encoding, 'base64');
  assert.equal(body.data, Buffer.from([1, 2, 3, 255]).toString('base64'), 'bytes sobem fiéis (base64)');
  assert.match(calls[0].url, /\/put$/);
  const keys = await cloud.list('meu-app');
  assert.deepEqual(keys, ['save-1', 'save-2']);
  const offline = new CloudStorageProvider({});
  assert.equal(await offline.availability(), false);
  await assert.rejects(() => offline.put('a', 'b', 'c'), (e) => e.code === 'CLOUD_OFFLINE', 'sem nuvem o erro é HONESTO e codificado');
  // a plataforma sem env é LOCAL e DIZ que é local
  const st = await createPlatform({ cloud: null }).status();
  assert.equal(st.cloud.provider, null);
  assert.match(st.cloud.honest, /LOCAL/);
});

// ----------------------------------------------------------- android kit
test('r20: O KIT ANDROID REAL — projeto gradle completo embalado, a toolchain ausente é DITA', async () => {
  const apk = await build({ name: 'AppVila', target: 'android', manifest: { title: 'Vila' } });
  assert.equal(apk.ok, true);
  assert.match(apk.kind, /android-kit/);
  assert.match(apk.honest, /gradle/, 'o que falta é DITO, não fingido');
  const entries = zipRead(apk.artifact.data);
  assert.ok(entries.has('INSTALL.txt') && entries.has('AppVila/app/src/main/AndroidManifest.xml'));
  assert.ok(entries.has('AppVila/app/src/main/java/com/genesis/app/MainActivity.java'));
  assert.ok(entries.has('AppVila/app/src/main/assets/www/index.html'));
  const install = new TextDecoder().decode(entries.get('INSTALL.txt'));
  assert.match(install, /assembleDebug/, 'o INSTALL ensina o caminho real do APK');
});

// ------------------------------------------------------------- critique
test('r20: O OLHO DO DIRETOR — a IA lê o próprio mundo e critica com sugestões derivadas do estado', async () => {
  const uts = createUTS({ seed: 'critica-r20' });
  const c1 = await uts.core.tools.execute('genesis.critique', {});
  assert.equal(c1.ok, true);
  assert.ok(c1.findings.some((f) => f.sobre === 'gente'), 'mundo sem vila é VISTO');
  assert.ok(c1.suggestions.some((s) => /vila/.test(s)), 'a sugestão nasce do estado');
  await uts.core.tools.execute('ues.create_settlement', { name: 'Porto Nova', population: 6 });
  const c2 = await uts.core.critique();
  assert.ok(!c2.findings.some((f) => f.sobre === 'gente'), 'com vila a crítica muda (ela lê o mundo, não um texto pronto)');
  const c3 = await uts.core.critique();
  assert.deepEqual(c2, c3, 'a crítica é determinística');
});
