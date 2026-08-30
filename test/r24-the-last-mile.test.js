// R24 — A ÚLTIMA MILHA HONESTA: TOKEN STREAMING REAL (o provider de SSE
// atravessa o Core: os tokens chegam um a um e a lei de validação é a
// MESMA — sem chave o caminho é o mesmo código que entra em produção),
// ASSINATURA ED25519 (identidade criptográfica dos artefatos; um byte
// alterado reprova), A FORJA DE GEOMETRIA (malhas novas por regras
// determinísticas com autoteste: contagens pela fórmula, simetria exata,
// determinismo) e O VENTO EMPURRA CORPOS (acoplamento fluido-estrutura:
// arrasto ½ρ·Cd·A·v² — a lâmina leve anda, a rocha nem sente).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createUTS } from '../src/index.js';
import { ExternalLLMProvider } from '../src/singularity/external.js';
import { build, verifySelo, newSigningKey } from '../src/agent/build-system.js';
import { composeGeometry, GEOMETRY_KINDS } from '../src/agent/geometry-smith.js';

// ------------------------------------------------------ token streaming
test('r24: TOKEN STREAMING REAL — os tokens do provider chegam um a um e a validação é a mesma lei', async () => {
  const resposta = JSON.stringify({ intent: 'create_settlement', params: { name: 'Vila Rio', pop: 10 } }, null, 1);
  const pedacos = [];
  for (let i = 0; i < resposta.length; i += 13) pedacos.push(resposta.slice(i, i + 13));
  const sse = pedacos
    .map((t) => 'data: ' + JSON.stringify({ choices: [{ delta: { content: t } }] }).replace(/\n/g, ''))
    .join('\n\n') + '\n\ndata: [DONE]\n\n';
  const fakeFetch = async () => ({
    ok: true,
    body: new ReadableStream({ start(c) {
      const enc = new TextEncoder();
      c.enqueue(enc.encode(sse.slice(0, 77)));  // a rede parte no meio
      c.enqueue(enc.encode(sse.slice(77)));
      c.close();
    } }),
  });
  const provider = new ExternalLLMProvider({ apiKey: 'chave-veio-do-env', fetchImpl: fakeFetch });
  const uts = createUTS({ seed: 'stream-r24' });
  const toks = [];
  const r = await uts.core.interpretObjectiveStream('crie a vila Rio', { provider, model: { id: 'x' } }, (t) => toks.push(t));
  assert.ok(toks.length > 2, `os TOKENS chegaram em partes (${toks.length})`);
  assert.equal(r.provider, provider.name);
  assert.equal(r.intent, 'create_settlement');
  assert.equal(r.params.name, 'Vila Rio', 'o plano é válido (mesma lei de interpretação)');
  assert.deepEqual(JSON.parse(toks.join('')), { intent: r.intent, params: r.params }, 'a remontagem é o plano inteiro');
  assert.equal(r.streamed, toks.join('').length, 'o streamed é honesto (o que passou no fio)');
  // e o caminho SEM provider de stream continua funcionando (heuristic fatiado)
  const parts = [];
  const r2 = await uts.core.interpretObjectiveStream('crie uma vila', undefined, (p) => parts.push(p));
  assert.ok(parts.length > 0 && r2.intent, 'o caminho fatiado continua de pé');
});

// ------------------------------------------------------- assinatura
test('r24: ASSINATURA ED25519 — o artefato carrega identidade; um byte alterado REPROVA', async () => {
  const key = newSigningKey();
  const app = await build({ name: 'AssinadaR24', target: 'web', manifest: { title: 'X' }, signingKey: key.privateKey });
  assert.ok(app.artifact.selo.sig && app.artifact.selo.pub, 'o artefato sai assinado');
  assert.equal(verifySelo(app.artifact).ok, true, 'assinatura valida');
  const bytes = [...app.artifact.data];
  bytes[40] ^= 0xff;
  assert.equal(verifySelo({ ...app.artifact, data: new Uint8Array(bytes) }).ok, false, 'UM byte alterado reprova a identidade');
  const outro = newSigningKey();
  const trocado = { ...app.artifact, selo: { ...app.artifact.selo, pub: outro.publicKey } };
  assert.equal(verifySelo(trocado).ok, false, 'chave trocada não valida (identidade, não só hash)');
  const semChave = await build({ name: 'Livre', target: 'web', manifest: {} });
  const v = verifySelo(semChave.artifact);
  assert.equal(v.ok, true);
  assert.match(v.honest, /sem assinatura de identidade/, 'o que falta é DITO');
});

// ---------------------------------------------------- forja de geometria
test('r24: A FORJA DE GEOMETRIA — malhas novas por regras, contagens pela fórmula, determinismo', async () => {
  const arvore = composeGeometry({ kind: 'arvore', params: { 'níveis': 3, comprimento: 3, galhos: 3 } });
  assert.equal(arvore.selfTest.contagem, true, `L-system: ${arvore.stats.triângulos} índices = 2·(1+3+9)`);
  assert.equal(arvore.selfTest.cresce, true, 'a copa subiu acima do solo');
  const cristal = composeGeometry({ kind: 'cristal', params: { faces: 8, altura: 2, raio: 1 } });
  assert.equal(cristal.selfTest.simetria, true, 'o cristal de 8 faces é SIMÉTRICO a 1e-9');
  assert.equal(cristal.selfTest.faces, true, 'fundo + 2·lateral + topo = 4f faces');
  const rocha = composeGeometry({ kind: 'rocha', params: { subdiv: 2, rugosidade: 0.3 } });
  assert.equal(rocha.selfTest.fechada, true, 'icosaesfera: 20·4² triângulos');
  for (const g of [arvore, cristal, rocha]) {
    assert.equal(g.selfTest.finite, true);
    assert.equal(g.selfTest.determinístico, true, 'a mesma semente devolve a mesma malha byte a byte');
  }
  assert.throws(() => composeGeometry({ kind: 'esfera' }), /desconhecido/);
  assert.throws(() => composeGeometry({ kind: 'cristal', params: { faces: 99 } }), /fora de/);
  assert.ok(GEOMETRY_KINDS.arvore.desc.includes('L-SYSTEM'));
  // pelo chat: o tool entrega a malha com o autoteste
  const uts = createUTS({ seed: 'geo-r24' });
  const t = await uts.core.tools.execute('agent.geometry', { kind: 'cristal', faces: 6 });
  assert.equal(t.ok, true);
  assert.equal(t.stats.vertices, 14, '1 + 6 + 6 + 1 vértices');
});

// -------------------------------------------------- vento em corpos
test('r24: O VENTO EMPURRA CORPOS — a lâmina leve anda com a tempestade, a rocha nem sente', () => {
  const run = (wind) => {
    const uts = createUTS({ seed: 'vento-r24' });
    const w = uts.world;
    w.ues.run(3);
    w.environment.wind = wind; // o clima relaxa devagar: a ventania dura o teste
    const t = w.terrain;
    let flat = null;
    for (let x = 200; x < 840 && !flat; x += 8) for (let z = 200; z < 840; z += 8) {
      const h = t.height(x, z);
      if ([6, -6].every((dz) => Math.abs(t.height(x, z + dz) - h) < 0.06) && [6, -6].every((dx) => Math.abs(t.height(x + dx, z) - h) < 0.06)) { flat = [x, z]; break; }
    }
    assert.ok(flat, 'existe terreno plano');
    w.ues.moveCamera([flat[0], 40, flat[2]]);
    const wood = w.physics.addBody({ pos: [flat[0], t.height(flat[0], flat[1]) + 3, flat[1]], radius: 0.15, material: 'wood', friction: 0.3 });
    const rock = w.physics.addBody({ pos: [flat[0] + 8, t.height(flat[0] + 8, flat[1]) + 3, flat[1]], radius: 0.15, material: 'rock', friction: 0.3 });
    w.ues.run(120);
    const wd = w.environment.windDir;
    const along = (id, x0, z0) => {
      const sp = w.rrw.getComponent(id, 'spatial');
      return (sp.pos[0] - x0) * wd[0] + (sp.pos[2] - z0) * wd[1];
    };
    return { wood: along(wood.id, flat[0], flat[1]), rock: along(rock.id, flat[0] + 8, flat[1]) };
  };
  const storm = run(0.9), calm = run(0.05);
  assert.ok(storm.wood > calm.wood + 1, `a tempestade levou a lâmina (${storm.wood.toFixed(2)}m vs calmaria ${calm.wood.toFixed(2)}m)`);
  assert.ok(storm.rock < storm.wood * 0.5, `a rocha quase não sente (${storm.rock.toFixed(2)}m)`);
});
