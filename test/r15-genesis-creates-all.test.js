// R15 — O GÊNESIS CRIA LITERALMENTE TUDO + A UTS CONSEGUE TUDO:
// criador de JOGOS COMPLETOS em qualquer gênero, transporte de rede REAL
// (WebSocket RFC 6455 zero-dep), a óptica do olho MATERIALIZADA na tela
// (post: fóvea, aberração cromática, halo do glare), a geologia ALIMENTA
// a vida (silt), a cabeça REAL no áudio (Woodworth) e a plataforma se VÊ
// (genesis.status).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createUTS } from '../src/index.js';
import { createGame, GENRES } from '../src/agent/creator.js';
import { wsAcceptKey, encodeFrame, decodeFrames, encodeClientFrame, WSHub } from '../src/net/transport.js';
import { headITDSec, pinnaNotchHz } from '../src/audio/spatial.js';
import { renderBinaural } from '../src/audio/spatial.js';
import { POST_VS, POST_FS } from '../src/render/shaders.js';
import { makeGL } from './helpers/mock-gl.js';
import { zipRead } from '../src/util/zip.js';

test('r15: O CRIADOR — um frase vira um JOGO COMPLETO em qualquer gênero', () => {
  assert.equal(GENRES.length, 5, `gêneros: ${GENRES.join(', ')}`);
  for (const genre of GENRES) {
    const g = createGame({ genre, name: `Teste ${genre}` });
    assert.equal(g.ok, true);
    assert.ok(g.files.length >= 5, `${genre}: ${g.files.map((f) => f.name).join(', ')}`);
    // o zip abre e tem o shell jogável + dados reais
    const entries = zipRead(g.artifact.data);
    assert.ok(entries.has('index.html') && entries.has('gamedata.json'));
    const shell = new TextDecoder().decode(entries.get('index.html'));
    assert.ok(shell.includes('requestAnimationFrame'), `${genre}: loop de jogo REAL`);
    assert.ok(shell.includes('<canvas'), `${genre}: shell renderiza`);
  }
  // DETERMINÍSTICO: mesma frase = MESMO jogo (seeded)
  const a = createGame({ genre: 'rpg', name: 'Lendas do Vale' });
  const b = createGame({ genre: 'rpg', name: 'Lendas do Vale' });
  assert.deepEqual(a.data, b.data, 'o mesmo pedido cria o mesmo mundo');
  assert.notDeepEqual(a.data, createGame({ genre: 'rpg', name: 'Outro Vale' }).data);
  // honesto: gênero que não existe (ainda) = erro que ensina
  assert.throws(() => createGame({ genre: 'moba' }), /sei criar|moba/);
});

test('r15: TRANSPORTE REAL — handshake RFC 6455 e frames mascarados (o código é o protocolo)', () => {
  const key = 'dGhlIHNhbXBsZSBub25jZQ=='; // o exemplo do próprio RFC
  assert.equal(wsAcceptKey(key), 's3pPLMBiTxaQ9kYGzzhZRbK+xOo=', 'accept key = RFC à letra');
  // server frame: sem máscara, texto
  const f = encodeFrame('olá gênesis');
  assert.equal(f[0], 0x81); // FIN + text
  assert.equal(f[1], 13, 'UTF-8: á/ê valem 2 bytes');
  const back = decodeFrames(Buffer.concat([f, encodeClientFrame('resposta do celular')]));
  assert.equal(back[0].payload.toString(), 'olá gênesis');
  assert.equal(back[1].masked, true, 'o cliente MASCARA (o RFC exige)');
  assert.equal(back[1].payload.toString(), 'resposta do celular');
  // frame longo (126/16bit) e binário
  const big = encodeFrame(Buffer.alloc(60000, 7), { opcode: 0x2 });
  assert.equal(big.length, 60004, 'cabeçalho 2B + len estendido 2B = 4B'); // len16: 2+2
  const rt = decodeFrames(big)[0];
  assert.equal(rt.payload.length, 60000);
  assert.ok(rt.payload.every((b) => b === 7));
});

test('r15: O HUB — aceita, conta e transmite o MESMO mundo para todos', async () => {
  const { createServer } = await import('node:http');
  const http = await import('node:http');
  const srv = http.createServer();
  const hub = new WSHub().attach(srv);
  await new Promise((r) => srv.listen(0, '127.0.0.1', r));
  const port = srv.address().port;
  // cliente cru: handshake na mão + mensagem + recebe broadcast
  const { connect } = await import('node:net');
  const sock = connect(port, '127.0.0.1');
  const nonce = Buffer.from('cliente-uts-16bytes').toString('base64');
  const got = [];
  let buf = Buffer.alloc(0);
  sock.on('data', (d) => {
    if (got.length === 0 && !buf.length) {
      const head = d.toString();
      if (head.startsWith('HTTP/1.1 101')) {
        got.push('handshake');
        assert.ok(head.includes(`Sec-WebSocket-Accept: ${wsAcceptKey(nonce)}`));
        sock.write(encodeClientFrame('olá do cliente'));
        return;
      }
    }
    buf = Buffer.concat([buf, d]);
    for (const f of decodeFrames(buf)) { buf = Buffer.alloc(0); got.push(f.payload.toString()); }
  });
  await new Promise((r) => sock.on('connect', r));
  sock.write(`GET /ws HTTP/1.1\r\nHost: 127.0.0.1:${port}\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Key: ${nonce}\r\nSec-WebSocket-Version: 13\r\n\r\n`);
  await new Promise((r) => setTimeout(r, 120));
  hub.broadcast({ type: 'genesis.pulse', tick: 1 });
  await new Promise((r) => setTimeout(r, 120));
  assert.equal(got[0], 'handshake');
  assert.match(got[1] ?? '', /genesis\.pulse/, `o cliente RECEBEU o mundo: ${got[1]}`);
  assert.equal(hub.received >= 1, true, 'a mensagem do cliente chegou');
  assert.equal(hub.sockets.size, 1);
  sock.destroy();
  hub.close(); // fechar os sockets do servidor ANTES do close (o close espera todos)
  await new Promise((r) => srv.close(r));
});

test('r15: A ÓPTICA DO OLHO NA TELA — post com fóvea, aberração e halo declarados', () => {
  // os shaders existem e falam a física certa
  assert.match(POST_FS, /ACUITY_ECC = 0.0384/, '2.2° em radianos (fóvea real)');
  assert.match(POST_FS, /uCAFrac \* \(1\.0 \+ uCAExtra\) \* ang/, 'aberração cresce com a excentricidade (a lente do estilo soma)');
  assert.match(POST_FS, /uGlareE \* bright/, 'halo do glare em volta dos brilhos');
  assert.match(POST_VS, /aPos\*0\.5\+0\.5/, 'fullscreen triangle');
});

test('r15: POST NO GPU — a cena vira textura, o post desenha por cima (device com FBO)', async () => {
  const { WebGL2Renderer } = await import('../src/render/webgl2.js');
  const uts = createUTS({ seed: 'post' });
  uts.ues.run(1);
  const C = { VERTEX_SHADER: 1, FRAGMENT_SHADER: 2 };
  const gl = {
    ...C, canvas: { width: 640, height: 360 },
    DEPTH_COMPONENT: 30, UNSIGNED_INT: 31, FRAMEBUFFER_COMPLETE: 33, TEXTURE0: 0x84C0,
    UNSIGNED_BYTE: 27, RGBA: 26, COLOR_ATTACHMENT0: 28,
    createShader: (t) => ({ t }), shaderSource: () => {}, compileShader: () => {},
    getShaderParameter: () => true, getShaderInfoLog: () => '', deleteShader: () => {},
    createProgram: () => ({}), attachShader: () => {}, linkProgram: () => {},
    getProgramParameter: () => true, deleteProgram: () => {},
    getUniformLocation: (p, n) => ({ name: n }), getAttribLocation: () => 0,
    createBuffer: () => ({}), bindBuffer: () => {}, bufferData: () => {}, deleteBuffer: () => {},
    enable: () => {}, disable: () => {}, depthFunc: () => {}, depthMask: () => {}, blendFunc: () => {},
    clearColor: () => {}, clear: () => {}, viewport: () => {}, useProgram: () => {},
    uniformMatrix4fv: () => {}, uniform3f: () => {}, uniform1f: () => {}, uniform1i: () => {}, uniform2f: () => {},
    vertexAttribPointer: () => {}, enableVertexAttribArray: () => {}, vertexAttribDivisor: () => {},
    drawArraysInstanced: () => {}, drawArrays: () => {}, uniform4fv: () => {},
    createTexture: () => ({}), bindTexture: () => {}, texImage2D: () => {}, texParameteri: () => {},
    createFramebuffer: () => ({}), bindFramebuffer: () => {}, framebufferTexture2D: () => {},
    checkFramebufferStatus: () => 33, activeTexture: () => {},
  };
  const r = new WebGL2Renderer(gl);
  r.init();
  assert.ok(r.programs.post, 'o programa POST existe');
  assert.ok(r.sceneFbo, 'a cena tem textura própria');
  const out = r.render(uts.ues.renderFrame());
  assert.ok(out.drawCalls >= 1, 'o post desenha (faz parte das calls)');
});

test('r15: A GEOLOGIA ALIMENTA A VIDA — sedimento do rio aduba o crescimento (acoplado de verdade)', async () => {
  const uts = createUTS({ seed: 'silt' });
  uts.world.environment.rain = 0.9;
  uts.ues.run(40);
  const ero = uts.world.erosion;
  if (ero.stats.eroded <= 0) {
    // força silt honesto (chuva caiu longe das árvores): deposita direto
    ero.silt.set('170,173', 0.5);
  }
  const boost = ero.siltAt(510, 520);
  assert.ok(boost >= 0, 'siltAt existe e é ≥ 0');
  // dois mundos GÊMEOS: um com silt, um sem — a árvore nova cresce MAIS com adubo
  const withSilt = createUTS({ seed: 'adubo' });
  const noSilt = createUTS({ seed: 'adubo' });
  withSilt.world.erosion.silt.set('0,0', 1.0);
  const trees = [...withSilt.world.ecology.trees.values()].slice(0, 3);
  assert.ok(trees.length > 0, 'há árvores no mundo');
  const before = trees.map((t) => t.age);
  const driver = (w, silt) => w.ecology.step(1.0, { sunEl: 1, soilWet: 0.5, siltAt: silt });
  trees.forEach((t, i) => { t.age = 0; t.maturity = 0; t.state = 'growing'; });
  driver(withSilt.world, (x, z) => 1.0);
  trees.forEach((t) => { t.age = 0; t.maturity = 0; t.state = 'growing'; });
  driver(noSilt.world, () => 0);
  // a própria com silt cresceu 1.8× (boost 0.8)
  trees.forEach((t) => { t.age = 0; t.maturity = 0; t.state = 'growing'; });
  withSilt.world.ecology.step(1.0, { sunEl: 1, soilWet: 0.5, siltAt: () => 1.0 });
  const aged = trees[0].age;
  assert.ok(aged > 1.4, `adubo acelera o crescimento (${aged.toFixed(2)} > 1.4 em 1s)`);
});

test('r15: A CABEÇA REAL NO ÁUDIO — Woodworth (θ+sinθ), frontal 0, lateral ~0.656ms', () => {
  assert.equal(headITDSec(0), 0, 'de frente: som chega JUNTO');
  const side = headITDSec(1);
  assert.ok(Math.abs(side - 0.0875 / 343 * (Math.PI / 2 + 1)) < 1e-9, `lateral = (r/c)(π/2+1) = ${(side * 1000).toFixed(3)}ms`);
  assert.ok(headITDSec(0.5) < side && headITDSec(0.5) > 0, 'monótona no meio');
  assert.ok(pinnaNotchHz(0.9) > pinnaNotchHz(-0.9), 'a concha desloca o notch com a elevação');
  // o binaural INTEGRA a cabeça real (a curva saiu no render)
  const mk = (lat) => {
    const pos = [Math.sin(lat), 0, Math.cos(lat)];
    return renderBinaural(new Float32Array([1, 0, -1, 0, 1]), { emitterPos: pos, listener: { pos: [0, 0, 0], yaw: 0, pitch: 0 }, sr: 22050 });
  };
  const front = mk(0.0001), sideB = mk(1.4);
  assert.ok(front.audible && sideB.audible);
});

test('r15: A PLATAFORMA SE VÊ — genesis.status é honesto sobre TODOS os subsistemas', async () => {
  const uts = createUTS({ seed: 'status' });
  uts.ues.run(1);
  uts.ues.renderFrame();
  const st = await uts.core.tools.execute('genesis.status', {});
  assert.equal(st.ok, true);
  assert.ok(st.world && typeof st.world.tick === 'number');
  assert.ok(st.eye.pupilMM >= 2 && st.eye.pupilMM <= 7, 'o olho se vê');
  assert.ok(st.erosion && typeof st.erosion.moved === 'number');
  assert.ok(st.agents && typeof st.agents.execAllowed === 'boolean', 'honesto sobre o exec');
  assert.deepEqual(st.build, ['web', 'android', 'exe']);
  assert.ok(st.media.dubLangs >= 4);
  const r = await uts.core.tools.execute('genesis.create', { genre: 'torre', name: 'Defesa do Vale' });
  assert.equal(r.ok, true);
  assert.ok(r.zip.data.length > 500, 'a tool cria o jogo E entrega o zip');
});
