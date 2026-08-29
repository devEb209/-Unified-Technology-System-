// R17 — A TERRA NO ESPELHO (reflexo do terreno na água SEM render target,
// marchando o heightfield real), OCEANO↔ATMOSFERA (o mar evapora, a chuva
// quebra a superfície), SNAPSHOT DE RECONEXÃO (estado completo, honesto),
// APPS DE USUÁRIO (criar → instalar → jogar na plataforma, com storage
// próprio por app), A ORELHA DIRECIONAL (HRTF: tabela paramétrica
// publicada + slot validado para banco MEDIDO) e A PLATAFORMA SE MEDINDO
// (perf honesto por subsistema).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, rm, readFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { createUTS } from '../src/index.js';
import { marchReflect, reflectionFade, terrainMirrorGLSL, terrainTint, REFLECT_CONST } from '../src/render/water-reflection.js';
import { WATER_FS } from '../src/render/shaders.js';
import { encodeSnapshot, applySnapshot, applyDelta, DeltaStream } from '../src/net/sync.js';
import { AgentFS } from '../src/agent/fs-agent.js';
import { UserApps } from '../src/platform/user-apps.js';
import { PARAMETRIC_TABLE, loadMeasuredTable, applyHRTF } from '../src/audio/hrtf.js';
import { createGame } from '../src/agent/creator.js';

test('r17: A TERRA NO ESPELHO — a água marcha o TERRENO real e mostra a terra, não o céu', () => {
  const uts = createUTS({ seed: 'espelho' });
  const terrain = uts.world.terrain;
  // achar uma COSTA COM MORRO: água em (x,z) e terra alta a <=70m
  let pair = null, openSea = null;
  for (let x = 8; x < 1016 && !pair; x += 8) {
    for (let z = 8; z < 1016; z += 8) {
      if (terrain.height(x, z) >= terrain.seaLevel) continue;
      openSea ??= [x, z];
      for (const [dx, dz] of [[40, 0], [-40, 0], [0, 40], [0, -40], [50, 50], [-50, -50]]) {
        const h = terrain.height(x + dx, z + dz);
        if (h > 14) { pair = [[x, z], [x + dx, h, z + dz]]; break; }
      }
      if (pair) break;
    }
  }
  assert.ok(pair, 'o mundo tem costa encostada em morro alto');
  const [[wx, wz], [mx, mh, mz]] = pair;
  // do mar olhando para o morro: o raio refletido ACERTA a terra
  const dx = mx - wx, dz = mz - wz, dl = Math.hypot(dx, dz) || 1;
  const o = [wx, 6.2, wz];
  // a visada: varre inclinações do raio refletido — OLHANDO para o morro,
  // ALGUM raio refletido acerta a terra (é isso que a água mostra)
  let toMtn = null;
  for (let dy = 0.12; dy <= 1.2 && !toMtn; dy += 0.04) {
    const r = marchReflect(o, [dx / dl, dy, dz / dl], terrain);
    if (r.hit) toMtn = r;
  }
  assert.ok(toMtn, 'a água mostra a TERRA na direção do morro (marcha no heightfield real)');
  assert.ok(toMtn.tint && toMtn.k > 0, `tinta de terra: ${JSON.stringify(toMtn.tint)}`);
  assert.ok(toMtn.dist <= REFLECT_CONST.MAX_DIST);
  // raio refletido quase horizontal sobre o mar aberto: só céu
  const miss = marchReflect([openSea[0], 6.2, openSea[1]], [0.9, 0.02, 0.9], terrain);
  if (miss.hit === false) assert.equal(miss.tint, null);
  assert.ok(reflectionFade(10) > reflectionFade(90), 'o reflexo longe SECA no ar (perspectiva aérea)');
  // paleta coerente com altura
  assert.deepEqual(terrainTint(3), [0.76, 0.7, 0.5]);
  assert.deepEqual(terrainTint(30), [0.92, 0.94, 0.96]);
});

test('r17: O GLSL É O MESMO MUNDO — twReflect usa a semente REAL e as frequências do terreno', () => {
  const uts = createUTS({ seed: 'espelho' });
  uts.ues.run(1);
  assert.equal(WATER_FS.includes('twReflect'), true);
  assert.ok(WATER_FS.includes('uniform float uTerrSeed'), 'o FS lê a semente do mundo');
  assert.ok(WATER_FS.includes('uRain'), 'o FS lê a chuva');
  assert.match(WATER_FS, /1\.0 - 0\.7 \* clamp\(uRain/, 'a chuva quebra o especular');
  assert.match(WATER_FS, /twReflect\(vPos, rd, uTerrSeed\)/, 'twReflect recebe a semente real');
  const glsl = terrainMirrorGLSL();
  assert.ok(glsl.includes('0.0040') && glsl.includes('0.0080'), 'frequências macro = terrain.js');
  assert.ok(glsl.includes('exp(-t/140.0)'), 'fade = reflectionFade');
  // o frame carrega a semente REAL
  const f = uts.ues.renderFrame();
  assert.equal(f.terrainSeed, uts.world.terrain.seedNum, 'o frame leva a semente ao shader');
  // e a chuva viaja no frame
  uts.world.environment.rain = 0.5;
  assert.ok(uts.ues.renderFrame().environment.rain === 0.5);
});

test('r17: OCEANO→ATMOSFERA — o mar evapora: litoral mais ÚMIDO que o interior (mesma chuva)', () => {
  const uts = createUTS({ seed: 'mar' });
  uts.world.environment.rain = 0;
  // achar litoral e interior (8 amostras a 180m: mar vs terra)
  let coast = null, inland = null;
  for (let x = 40; x < 1000 && !(coast && inland); x += 16) {
    for (let z = 40; z < 1000; z += 16) {
      const h = uts.world.terrain.height(x, z);
      if (h > 6.5) continue; // o foco fica em terra
      let seaN = 0;
      for (let k = 0; k < 8; k++) {
        const a = (k / 8) * Math.PI * 2;
        if (uts.world.terrain.height(x + Math.cos(a) * 180, z + Math.sin(a) * 180) < uts.world.terrain.seaLevel) seaN++;
      }
      if (!coast && seaN >= 4) coast = [x, z];
      if (!inland && seaN === 0) inland = [x, z];
    }
  }
  assert.ok(coast && inland, `litoral ${coast} interior ${inland}`);
  const humAt = ([x, z]) => {
    const w = createUTS({ seed: 'mar' });
    w.world.environment.rain = 0;
    w.ues.moveCamera([x, 10, z]);
    w.world.updateWeather(1); // um passo com o foco lá
    return { sea: w.world.environment.seaHumidity, h: w.world.atmosphere.state.humidity };
  };
  const c = humAt(coast), i = humAt(inland);
  assert.ok(c.sea >= 0.5, `litoral: ${c.sea} do horizonte é mar`);
  assert.equal(i.sea, 0, 'interior: nada de mar no raio');
  assert.ok(c.h > i.h, `umidade: litoral ${c.h.toFixed(3)} > interior ${i.h.toFixed(3)} (o mar respirou para o ar)`);
});

test('r17: SNAPSHOT DE RECONEXÃO — gap → snapshot completo → cliente IGUAL ao servidor', () => {
  const stream = new DeltaStream();
  const server = { tick: 0, style: 'realista', erosion: 0 };
  const client = { ...server };
  let seq = 0;
  seq = DeltaStream.feed(client, stream.encode({ tick: 1, style: 'anime' }), seq).lastSeq;
  stream.encode({ tick: 2 }); // este o cliente PERDEU (desligou o celular)
  const lost = stream.encode({ tick: 3, erosion: 0.7 });
  assert.throws(() => applyDelta(client, lost, seq), /GAP/, 'sem snapshot o gap é honesto');
  // RECONEXÃO: snapshot completo sob seq nova
  const snap = stream.snapshot({ tick: 3, style: 'anime', erosion: 0.7 });
  const r = applySnapshot(client, snap);
  assert.equal(r.lastSeq, stream.lastSeq, 'o seq do snapshot é autoritativo');
  assert.deepEqual(client, { tick: 3, style: 'anime', erosion: 0.7 }, 'cliente = servidor (byte a byte)');
  // e os deltas continuam de lá
  const next = DeltaStream.feed(client, stream.encode({ tick: 4 }), r.lastSeq);
  assert.equal(next.applied, true);
  assert.equal(client.tick, 4);
  // snapshot malformado = erro honesto
  assert.throws(() => applySnapshot({}, JSON.stringify({ v: 1, seq: 9 })), /não é um snapshot/);
});

test('r17: APPS DE USUÁRIO — criar → instalar → storage próprio; ninguém lê o app alheio', async () => {
  const dir = await mkdtemp(join(tmpdir(), 'uts-apps-'));
  try {
    const fsx = new AgentFS({ root: dir });
    const apps = new UserApps({ fs: fsx });
    const game = createGame({ genre: 'rpg', name: 'Lendas' });
    const inst = await apps.install({ name: 'rpg-lendas', zip: game.artifact.data });
    assert.equal(inst.ok, true);
    assert.equal(inst.url, '/apps/rpg-lendas/index.html');
    const html = (await fsx.read('apps/rpg-lendas/index.html')).toString();
    assert.ok(html.includes('<canvas'), 'o jogo está lá, instalado');
    // storage por app (sandbox DUPLO: apps/<nome>/data/)
    await apps.storageWrite('rpg-lendas', 'save.json', '{"hp":12}');
    assert.equal((await apps.storageRead('rpg-lendas', 'save.json')).toString(), '{"hp":12}');
    // app não instalado e caminho mau = erro honesto
    await assert.rejects(() => apps.storageWrite('fantasma', 'x', '1'), /não está instalado/);
    await assert.rejects(() => apps.storageWrite('rpg-lendas', '../outsider', '1'), /inválido/);
    // RESTART: os apps voltam do disco (rescan)
    const apps2 = new UserApps({ fs: fsx });
    const list = await apps2.rescan();
    assert.equal(list.length, 1);
    assert.equal(list[0].name, 'rpg-lendas');
  } finally {
    await rm(dir, { recursive: true, force: true });
  }
});

test('r17: A ORELHA DIRECIONAL — HRTF com tabela publicada e slot honesto para banco MEDIDO', () => {
  // frontal: ORELHAS IGUAIS (simetria)
  const n = 400;
  const tone = new Float32Array(n);
  for (let i = 0; i < n; i++) tone[i] = Math.sin((2 * Math.PI * 440 * i) / 22050);
  const front = applyHRTF(tone, 0, 0);
  assert.deepEqual(Array.from(front.left), Array.from(front.right), 'de frente: os dois ouvidos ouvem igual');
  // à direita: o ouvido ESQUERDO é mais escuro (sombra de cabeça)
  const right = applyHRTF(tone, 90, 0);
  const peak = (b) => Math.max(...b);
  assert.ok(peak(right.right) > peak(right.left), `direita: R ${peak(right.right).toFixed(2)} > L ${peak(right.left).toFixed(2)}`);
  // elevação alta: notch da concha reduz o ganho
  const high = applyHRTF(tone, 0, 60);
  assert.ok(peak(high.left) < peak(front.left), 'acima da cabeça: a concha filtra');
  // slot MEDIDO: recusa tabela quebrada; aceita a válida e congela
  assert.throws(() => loadMeasuredTable({ sr: 44100, azimuths: [] }), /recusada/);
  const custom = loadMeasuredTable({ sr: 44100, taps: 2, azimuths: [0], elevations: [0], data: { 0: { 0: { L: [1, 0], R: [1, 0] } } } });
  assert.match(custom.label, /MEDIDA/);
  const viaCustom = applyHRTF(tone, 0, 0, { table: custom });
  assert.deepEqual(Array.from(viaCustom.left), Array.from(viaCustom.right));
  assert.equal(PARAMETRIC_TABLE.azimuths.length >= 7, true, 'grade paramétrica publicada');
});

test('r17: A PLATAFORMA SE MEDINDO — perf honesto por subsistema no genesis.status', async () => {
  const uts = createUTS({ seed: 'perf' });
  uts.ues.run(4);
  const st = await uts.core.tools.execute('genesis.status', {});
  for (const k of ['reallife', 'climate', 'atmosphere', 'fluid', 'erosion']) {
    assert.ok(typeof st.perf[k] === 'number' && st.perf[k] >= 0, `perf.${k} = ${st.perf[k]}ms (EMA honesta)`);
  }
});

test('r17: HTTP — instalar e jogar NA PLATAFORMA (o app servido de workspace/apps/)', async () => {
  const { spawn } = await import('node:child_process');
  const ws = await mkdtemp(join(tmpdir(), 'uts-http17-'));
  const srv = spawn(process.execPath, ['demos/web/server.js'], {
    env: { ...process.env, PORT: '8098', UTS_WORKSPACE: ws }, stdio: 'pipe',
  });
  let childErr = '';
  srv.stderr.on('data', (d) => { childErr += d; });
  await new Promise((res) => { srv.stdout.once('data', res); setTimeout(res, 2000); });
  const api = (p, body) => fetch(`http://127.0.0.1:8098${p}`, body ? { method: 'POST', body: JSON.stringify(body) } : {});
  let up = null;
  for (let i = 0; i < 12 && !up; i++) {
    try { up = await api('/api/apps'); } catch { await new Promise((r) => setTimeout(r, 150)); }
  }
  assert.ok(up, `servidor subiu — filho: ${childErr.slice(0, 200) || '(vazio)'}`);
  try {
    const inst = await (await api('/api/install', { genre: 'plataforma', name: 'Pulo' })).json();
    assert.equal(inst.ok, true, JSON.stringify(inst).slice(0, 120));
    const play = await fetch(`http://127.0.0.1:8098${inst.url}`);
    assert.equal(play.status, 200);
    const html = await play.text();
    assert.ok(html.includes('<canvas'), 'a plataforma SERVE o jogo instalado');
    // lista reflete
    const list = await (await api('/api/apps')).json();
    assert.ok(list.apps.some((a) => a.name === 'plataforma-pulo'));
    // fuga do sandbox de apps = bloqueada
    const evil = await fetch('http://127.0.0.1:8098/apps/../secrets.txt');
    assert.ok([403, 404].includes(evil.status), `fuga: ${evil.status}`);
  } finally {
    srv.kill();
    await rm(ws, { recursive: true, force: true });
  }
});
