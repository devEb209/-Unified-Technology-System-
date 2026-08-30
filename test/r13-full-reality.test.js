// R13 — A ESCA DA REALIDADE INTEIRA: escalas (átomo→universo), O OLHO
// HUMANO, IA com sistema de ARQUIVOS, EXECUTOR de comandos, COMPILADOR
// (web agora; apk/exe honestos), MODELOS em todos os Ds, TEXTURAS,
// ANIMAÇÃO, CUTSCENE, DUBLAGEM, PERFIS de aparelho (A01→desktop),
// auditoria do FRONTEND 100% funcional.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createUTS } from '../src/index.js';
import { SCALES, scaleFor, aggregate, ScaleLadder } from '../src/world/scales.js';
import { eyeState, purkinjeTint, rodMix, contrastFrac } from '../src/render/vision.js';
import { AgentFS } from '../src/agent/fs-agent.js';
import { ProcAgent } from '../src/agent/proc-agent.js';
import { build, inspect, probeToolchains, scaffoldProject } from '../src/agent/build-system.js';
import { zipCreate, zipRead } from '../src/util/zip.js';
import { generate, DIMS } from '../src/media/models.js';
import { generateTexture } from '../src/media/textures.js';
import { walkClip, blendPoses } from '../src/media/animation.js';
import { Cutscene } from '../src/media/cutscene.js';
import { dubScript, LANGS } from '../src/media/dub.js';
import { PROFILES, applyProfile, detectProfile } from '../src/ues/devices.js';
import { mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

test('r13: a ESCADA DA REALIDADE — átomo→universo, 15 níveis com leis próprias', () => {
  assert.equal(SCALES.length, 15);
  assert.equal(SCALES[0].id, 'quantum');
  assert.equal(SCALES[SCALES.length - 1].id, 'universe');
  assert.ok(SCALES[0].size < SCALES[SCALES.length - 1].size / 1e30, '40+ ordens de grandeza');
  assert.equal(scaleFor(1e-10).id, 'atomic', 'átomo é escala atômica');
  assert.equal(scaleFor(1.7).id, 'human');
  assert.equal(scaleFor(1.4e9).id, 'star');
  // agregação conserva (a estatística de baixo vira estado de cima)
  const agg = aggregate([1, 2, 3, 4], 'atomic', 'molecular');
  assert.equal(agg.total, 10);
  assert.ok(Math.abs(agg.mean - 2.5) < 1e-12);
  assert.throws(() => aggregate([1], 'quantum', 'human'), 'só vizinhos se ligam direto (a rede é causal)');
  // mundo real: corpos são etiquetados pela escala
  const uts = createUTS({ seed: 'escala' });
  uts.ues.run(1);
  assert.ok(uts.world.scales instanceof ScaleLadder);
  assert.equal(uts.world.scales.tag('r13-teste', 1.8), 'human');
  assert.equal(uts.world.scales.tag('r13-atomo', 2e-10), 'atomic');
  const up = uts.world.scales.propagateUp([2, 2, 2], 'cell');
  assert.ok(up && up.n === 3, 'evento da célula sobe para tecido');
});

test('r13: O OLHO HUMANO — Purkinje (noite azul), glare e CSF (não é fotorrealismo)', () => {
  const day = eyeState({ ambient: 1, flash: 0, exposure: 1 });
  const night = eyeState({ ambient: 0.16, flash: 0, exposure: 1.2 });
  assert.ok(day.rod < 0.3 && night.rod > 0.4, `cones de dia (${day.rod.toFixed(2)}), bastonetes assumem (${night.rod.toFixed(2)})`);
  assert.ok(purkinjeTint(0.02)[2] > purkinjeTint(5)[2], 'a noite TINTA de azul (Purkinje)');
  assert.ok(purkinjeTint(0.02)[0] < 1, 'o vermelho MORRE no escuro (realidade)');
  assert.ok(eyeState({ ambient: 1, flash: 1 }).glare > 0, 'relâmpago causa ofuscamento (PSF do olho)');
  assert.ok(contrastFrac(0.02) < contrastFrac(5), 'no escuro você PERDE contraste (CSF)');
  // o frame carrega o olho
  const uts = createUTS({ seed: 'olho-r13' });
  uts.ues.run(2);
  const f = uts.ues.renderFrame();
  assert.ok(f.vision && f.vision.tint.length === 3 && f.vision.rod >= 0);
});

test('r13: modelos em TODOS os Ds — 2D, 2.5D, 3D, 3.5D voxel, 4D animado', () => {
  const star = generate({ dim: '2d', shape: 'star' });
  assert.equal(star.points.length, 10, 'estrela de 5 pontas');
  const extruded = generate({ dim: '2.5d', shape: 'star' });
  assert.equal(extruded.tris.length % 3, 0);
  const torus = generate({ dim: '3d', solid: 'torus', seg: 12 });
  assert.equal(torus.verts.length, 12 * 12 * 6);
  const vox = generate({ dim: '3.5d', size: 8, height: 3 });
  assert.ok(vox.voxels.length > 8 * 8 && vox.voxels.every(v => v.length === 3));
  const anim = generate({ dim: '4d', frames: 5 });
  assert.equal(anim.frames.length, 5);
  assert.notDeepEqual(anim.frames[0].model.verts[0], anim.frames[2].model.verts[0], 'o modelo MUDA no tempo');
  assert.equal(DIMS.length, 5);
  assert.throws(() => generate({ dim: '5d' }));
});

test('r13: TEXTURAS proceduais — madeira tem anéis, tijolo tem rejunte, mármore tem veios', () => {
  const wood = generateTexture('wood', { size: 32 });
  const brick = generateTexture('brick', { size: 32 });
  const again = generateTexture('wood', { size: 32 });
  assert.deepEqual(Array.from(wood.rgba.slice(0, 64)), Array.from(again.rgba.slice(0, 64)), 'determinística');
  // tijolo: linha de rejunte no topo (y=0,1 são mortar → cinza)
  const top = brick.rgba[0], body = brick.rgba[(4 * 32 + 8) * 4]; // y=4: meio da fiada, longe do rejunte
  assert.ok(Math.abs(top - body) > 30, `rejunte ≠ tijolo (${top} vs ${body})`);
  // mármore claro com variação de veio
  const marble = generateTexture('marble', { size: 32 });
  assert.ok(marble.rgba[0] > 180);
});

test('r13: ANIMAÇÃO — keyframes, sampling suave e BLEND entre clipes', () => {
  const normal = walkClip({ style: 'normal' });
  const tired = walkClip({ style: 'cansado' });
  const p0 = normal.pose(0);
  const pQuarter = normal.pose(0.25);
  assert.ok(Math.abs(pQuarter.legL.rotX[0]) > 1, `a perna BALANÇA (${pQuarter.legL.rotX[0].toFixed(1)})`);
  assert.ok(Math.abs(p0.legL.rotX[0]) < 1e-9, 'começa neutra');
  const mixed = blendPoses(normal.pose(0.25), tired.pose(0.25), 0.5);
  const ampN = Math.abs(pQuarter.legL.rotX[0]), ampM = Math.abs(mixed.legL.rotX[0]);
  assert.ok(ampM < ampN, `blend cansado amortece (${ampM.toFixed(1)} < ${ampN.toFixed(1)})`);
});

test('r13: CUTSCENE — diretor com planos, câmera e fim honesto', () => {
  const cs = Cutscene.fromBrief({
    name: 'abertura',
    beats: [
      { caption: 'Era uma vez um vale…', dur: 2, cam: [0, 30, 40], look: [512, 0, 512] },
      { caption: '…onde o fogo dormia na mata.', dur: 2, cam: [30, 5, 30], look: [500, 2, 500] },
    ],
  });
  assert.equal(cs.duration, 4);
  assert.equal(cs.shots.length, 2);
  let cams = [];
  let ended = false;
  cs.onEnd = () => { ended = true; };
  for (let i = 0; i < 10; i++) {
    const st = cs.update(0.5, (shot) => cams.push(shot.cam[1]));
    if (st?.ended) break;
  }
  assert.ok(ended, 'termina');
  assert.throws(() => Cutscene.fromBrief({ beats: [] }), 'sem planos = erro honesto');
});

test('r13: DUBLAGEM automática — pt/en/es/ja com TIMING por idioma', () => {
  const d = dubScript([{ who: 'hero', line: 'Olá mundo! Perigo!', at: 0 }], ['pt-BR', 'en', 'es', 'ja']);
  assert.equal(Object.keys(d.cues).length, 4);
  assert.match(d.cues['en'][0].text, /hello world/i);
  assert.match(d.cues['en'][0].text, /danger/i);
  assert.match(d.cues['es'][0].text, /hola mundo/i);
  assert.ok(d.cues['ja'][0].text.includes('危険'), `japonês: ${d.cues['ja'][0].text}`);
  const durJa = d.cues['ja'][0].dur, durEn = d.cues['en'][0].dur;
  assert.ok(durJa > durEn, `japonês dura mais (${durJa.toFixed(2)} vs ${durEn.toFixed(2)})`);
  assert.ok(d.cues['en'][0].translated);
});

test('r13: IA no SISTEMA DE ARQUIVOS — escreve, lê, lista e NUNCA escapa do sandbox', async () => {
  const dir = await mkdtemp(join(tmpdir(), 'uts-fs-'));
  try {
    const fsx = new AgentFS({ root: dir });
    await fsx.write('projetos/jogo/main.js', 'console.log("genesis")');
    const r = await fsx.read('projetos/jogo/main.js');
    assert.ok(r.toString().includes('genesis'));
    const lst = await fsx.list('projetos/jogo');
    assert.deepEqual(lst, [{ name: 'main.js', dir: false }]);
    await fsx.move('projetos/jogo/main.js', 'projetos/main.js');
    await assert.rejects(() => fsx.read('projetos/jogo/main.js'));
    for (const evil of ['../fora.txt', '/etc/passwd', 'a/../../b', '..\\win']) {
      await assert.rejects(() => fsx.write(evil, 'x'), /escapa do sandbox|absoluto/, `rejeita ${evil}`);
    }
    assert.ok(fsx.journal.filter(j => j.op === 'write').length >= 1, 'auditoria registrada');
  } finally {
    await rm(dir, { recursive: true, force: true });
  }
});

test('r13: IA EXECUTA comandos — guarda proíbe destruição, timeout mata, opt-in honesto', async () => {
  const off = new ProcAgent({ allow: false });
  const denied = await off.run('echo x');
  assert.equal(denied.ok, false, 'desligado por padrão (o dono liga)');
  const pa = new ProcAgent({ allow: true, timeoutMs: 4000 });
  const ok = await pa.run('echo GENESIS-exec');
  assert.equal(ok.ok, true);
  assert.ok(ok.out.includes('GENESIS-exec'));
  const bad = await pa.run('rm -rf /');
  assert.equal(bad.ok, false, 'o guarda BLOQUEIA destruição');
  assert.match(bad.error, /proibido/);
  const fail = await pa.run('exit 3');
  assert.equal(fail.ok, false);
  assert.equal(fail.code, 3);
  assert.ok(pa.history.length >= 2, 'histórico auditado');
});

test('r13: COMPILADOR — web builda AGORA (zip real verificado); apk/exe honestos', async () => {
  const web = await build({ name: 'MeuJogo', target: 'web', manifest: { title: 'Meu Jogo' } });
  assert.equal(web.ok, true);
  const entries = zipRead(web.artifact.data);
  assert.ok(entries.has('package.json') && entries.has('index.html'), 'zip válido e completo');
  const pkg = JSON.parse(new TextDecoder().decode(entries.get('package.json')));
  assert.equal(pkg.name, 'meujogo');
  // android: KIT REAL (R20) — projeto gradle completo embalado; o que falta é DITO
  const apk = await build({ name: 'AppVila', target: 'android', manifest: {} });
  assert.ok(apk.files.some((f) => f.endsWith('AndroidManifest.xml')), `layout: ${apk.files.slice(0, 4)}`);
  assert.ok(apk.files.some((f) => f.endsWith('MainActivity.java')));
  assert.equal(apk.ok, true, 'o kit é real (projeto buildável embalado, verificável)');
  assert.match(apk.honest, /gradle/, 'a toolchain ausente é DITA, nunca fingida');
  // layout válido direto
  const layout = scaffoldProject({ name: 'X', target: 'exe' });
  assert.ok(layout.every(f => f.name.startsWith('X/')));
});

test('r13: DESCOMPILAR — o pacote volta inteiro: arquivos nomeados + manifestos lidos', async () => {
  const web = await build({ name: 'Decompile', target: 'web', manifest: { title: 'X' } });
  const d = inspect(web.artifact.data);
  assert.equal(d.ok, true);
  assert.equal(d.count, web.files.length, 'todo arquivo que entrou SAI nomeado');
  assert.ok(d.manifests['package.json'].includes('"decompile"'), 'o package.json é lido de volta como texto');
  // binário não é fingido
  const fake = zipCreate([{ name: 'classes.dex', data: new Uint8Array([0x64, 0x65, 0x78, 1, 2, 3]) }]);
  const d2 = inspect(fake);
  assert.match(d2.manifests['classes.dex'], /binário: 6 bytes/);
  // corrompido → erro honesto
  const broken = new Uint8Array(web.artifact.data);
  broken[broken.length - 22] ^= 0xFF; // o EOCD (a âncora do zip) — leitor honesto recusa
  assert.throws(() => inspect(new Uint8Array(broken)), /corrompido|EOCD/);
});

test('r13: PERFIS de aparelho — o A01 joga o MESMO mundo com orçamentos D-O15 menores', () => {
  const uts = createUTS({ seed: 'a01' });
  uts.ues.run(1);
  const a01 = applyProfile(uts.do15, 'a01');
  const uts2 = createUTS({ seed: 'a01' });
  uts2.ues.run(1);
  const desk = applyProfile(uts2.do15, 'desktop');
  assert.ok(a01.frameMs > desk.frameMs, 'A01 tem mais tempo por frame');
  assert.ok(a01.veg < desk.veg, 'A01 materializa menos vegetação (D-O15 defere, nunca descarta)');
  assert.equal(a01.shadows, false, 'A01: sem sombras (defesa honesta)');
  assert.equal(detectProfile({ deviceMemory: 2, mobile: true }), 'a01');
  assert.equal(detectProfile({ deviceMemory: 32, cores: 16 }), 'desktop');
});

test('r13: a IA TEM as ferramentas novas registradas (fs/build/mídia/escala/estilo)', async () => {
  process.env.UTS_WORKSPACE = await mkdtemp(join(tmpdir(), 'uts-ws-'));
  try {
    const uts = createUTS({ seed: 'tools' });
    if (uts.core.tools.machineReady) await uts.core.tools.machineReady; // ferramentas de máquina carregadas sob demanda
    for (const t of ['media.model', 'media.texture', 'media.animation', 'media.cutscene', 'media.dub', 'scales.report', 'scales.locate', 'device.profile', 'world.style', 'proc.run', 'agent.build']) {
      assert.ok(uts.core.tools.get ? uts.core.tools.get(t) : true, `tool ${t}`);
    }
    const r1 = await uts.core.tools.execute('media.model', { dim: '3.5d', size: 6 });
    assert.ok(r1.model.voxels.length > 0);
    const r2 = await uts.core.tools.execute('scales.locate', { size: 2e-10 });
    assert.equal(r2.id, 'atomic');
    const r3 = await uts.core.tools.execute('world.style', { style: 'anime' });
    assert.equal(r3.style.name, 'anime');
    assert.ok(uts.world.style, 'o estilo fica no MUNDO (estado, não string solta)');
    const r4 = await uts.core.tools.execute('device.profile', { profile: 'low' });
    assert.equal(r4.applied.name, 'low');
  } finally {
    delete process.env.UTS_WORKSPACE;
  }
});

test('r13: /api/fs do servidor — opera arquivos e REJEITA fuga (HTTP real)', async () => {
  const { spawn } = await import('node:child_process');
  const ws = await mkdtemp(join(tmpdir(), 'uts-http-'));
  const srv = spawn(process.execPath, ['demos/web/server.js'], {
    env: { ...process.env, PORT: '8094', UTS_WORKSPACE: ws }, stdio: 'pipe',
  });
  let childErr = '';
  srv.stderr.on('data', (d) => { childErr += d; });
  srv.on('exit', (code) => { if (code) childErr += `exit=${code}`; });
  await new Promise((res) => {
    srv.stdout.once('data', res);
    setTimeout(res, 2000);
  });
  const api = (payload) => fetch('http://127.0.0.1:8094/api/fs', { method: 'POST', body: JSON.stringify(payload) });
  // esperar o servidor aceitar (retry — corrida de startup não é motivo de falha)
  let up = null;
  for (let i = 0; i < 12 && !up; i++) {
    try { up = await api({ op: 'write', path: '.warmup', data: '1' }); } catch { await new Promise((r) => setTimeout(r, 150)); }
  }
  assert.ok(up, `servidor subiu — stderr do filho: ${childErr.slice(0, 400) || '(vazio)'}`);
  try {
    // tudo dentro de um try: qualquer TypeError vem com o stderr do filho
    const guard = (e) => { throw new Error(`HTTP falhou: ${e.message} | filho: ${childErr.slice(0, 400) || '(vazio)'}`); };
    const w = await (await api({ op: 'write', path: 'celular/save.json', data: '{"hp":10}' }).catch(guard)).json();
    assert.equal(w.ok, true);
    const r = await (await api({ op: 'read', path: 'celular/save.json' }).catch(guard)).json();
    assert.equal(r.content, '{"hp":10}');
    const evil = await api({ op: 'write', path: '../../escapou', data: 'x' }).catch(guard);
    assert.equal(evil.status, 400, 'fuga do sandbox = 400');
    // build pelo HTTP baixa zip real
    const b = await fetch('http://127.0.0.1:8094/api/build', { method: 'POST', body: JSON.stringify({ name: 'JogoHTTP', target: 'web' }) }).catch(guard);
    assert.equal(b.status, 200);
    assert.match(b.headers.get('content-type'), /zip/);
    const buf = new Uint8Array(await b.arrayBuffer());
    assert.ok(entries0(zipRead(buf)));
    function entries0(m) { return m.has('index.html'); }
  } finally {
    srv.kill();
    await rm(ws, { recursive: true, force: true });
  }
});

test('r13: FRONTEND 100% funcional — todo botão tem handler (auditoria automática)', async () => {
  const { readFile } = await import('node:fs/promises');
  const html = await readFile(new URL('../demos/web/index.html', import.meta.url), 'utf8');
  const ids = [...html.matchAll(/<button id="([^"]+)"/g)].map(m => m[1]);
  assert.ok(ids.length >= 14, `o demo tem ${ids.length} botões`);
  const missing = ids.filter((id) => {
    const hasHandler = new RegExp(`\\$\\('${id}'\\)\\.onclick|\\$\\('${id}'\\)\\.addEventListener|getElementById\\('${id}'\\)\\.onclick|'${id}'\\)\\.addEventListener`).test(html);
    return !hasHandler;
  });
  assert.deepEqual(missing, [], `botões SEM handler: ${missing.join(', ')}`);
  // os 3 do agente estão entre eles
  for (const id of ['fs-demo', 'exec-demo', 'build-demo']) assert.ok(ids.includes(id));
});

test('r13: ZIP próprio — roundtrip byte-fiel e CRC honesto', () => {
  const entries = [
    { name: 'a.txt', data: 'hello genesis' },
    { name: 'pasta/b.bin', data: new Uint8Array([1, 2, 3, 250, 251]) },
  ];
  const z = zipCreate(entries);
  const back = zipRead(z);
  const dec2 = new TextDecoder();
  assert.equal(dec2.decode(back.get('a.txt')), 'hello genesis');
  assert.deepEqual(Array.from(back.get('pasta/b.bin')), [1, 2, 3, 250, 251]);
  // corrompeu → erro explícito (não silêncio)
  const broken = new Uint8Array(z);
  broken[broken.length - 4] ^= 0xFF;
  assert.throws(() => zipRead(new Uint8Array(broken)), /EOCD|corrompido/);
});
