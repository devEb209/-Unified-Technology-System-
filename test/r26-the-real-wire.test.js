// R26 — A PROVA DO FIO REAL E O TEMPO DE CONSTRUÇÃO: o token streaming
// atravessa um SERVIDOR HTTP DE VERDADE (socket, chunks partidos no meio
// dos bytes, SSE OpenAI-compatível) até o Core — o mesmo protocolo da
// nuvem, provado ponta a ponta nesta máquina; e a vantagem de TEMPO: a IA
// constrói mundo e jogo em SEGUNDOS, com o limite forçado por teste.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { createUTS } from '../src/index.js';
import { ExternalLLMProvider } from '../src/singularity/external.js';
import { createGame } from '../src/agent/creator.js';

/** servidor SSE real: escreve a resposta em FRAGMENTOS que cortam linhas
 *  e payloads no meio (a rede não entrega blocos arrumados) */
function servidorSSE(port) {
  const resposta = JSON.stringify({ intent: 'create_settlement', params: { name: 'Vila Fio Real', pop: 8 } }, null, 1);
  const sse = resposta.split('').map((c, i) => (i % 17 === 0 ? `data: {"choices":[{"delta":{"content":""}}]}\n\n` : '')).join('');
  const corpo = [];
  for (const ch of resposta) {
    corpo.push(`data: ${JSON.stringify({ choices: [{ delta: { content: ch } }] })}\n\n`);
  }
  corpo.push('data: [DONE]\n\n');
  const tudo = corpo.join('');
  // fragmenta no MEIO dos bytes: pedaços de 7 chars com lacunas assíncronas
  const fragmentos = [];
  for (let i = 0; i < tudo.length; i += 7) fragmentos.push(tudo.slice(i, i + 7));
  const server = createServer((req, res) => {
    if (req.method !== 'POST' || !req.url.endsWith('/chat/completions')) {
      res.writeHead(404).end();
      return;
    }
    let body = '';
    req.on('data', (b) => (body += b));
    req.on('end', () => {
      const pedido = JSON.parse(body);
      assert.equal(pedido.stream, true, 'o provider pede stream:true');
      res.writeHead(200, { 'content-type': 'text/event-stream', 'cache-control': 'no-cache', connection: 'keep-alive' });
      let i = 0;
      const escreve = () => {
        // três fragmentos por tique — corta no meio de linhas/payloads
        for (let k = 0; k < 3 && i < fragmentos.length; k++) res.write(fragmentos[i++]);
        if (i < fragmentos.length) setTimeout(escreve, 1);
        else res.end();
      };
      escreve();
    });
  });
  return new Promise((resolve) => server.listen(port, '127.0.0.1', () => resolve(server)));
}

test('r26: O FIO REAL — SSE por SOCKET (não mock): tokens atravessam, a lei é a mesma', async () => {
  const server = await servidorSSE(0);
  const porta = server.address().port;
  const provider = new ExternalLLMProvider({
    baseUrl: `http://127.0.0.1:${porta}/v1`,
    apiKey: 'prova-local',
    fetchImpl: (...a) => fetch(...a), // fetch GLOBAL: rede de verdade
  });
  const uts = createUTS({ seed: 'fio-real' });
  const toks = [];
  const r = await uts.core.interpretObjectiveStream('crie a vila Fio Real', { provider, model: { id: 'x' } }, (t) => toks.push(t));
  assert.equal(r.provider, provider.name);
  assert.equal(r.intent, 'create_settlement');
  assert.equal(r.params.name, 'Vila Fio Real', 'o plano sai válido do fio real');
  assert.ok(toks.length > 50, `os TOKENS chegam um a um do socket (${toks.length})`);
  assert.deepEqual(JSON.parse(toks.join('')), { intent: r.intent, params: r.params }, 'a remontagem é o plano inteiro');
  assert.equal(r.streamed, toks.join('').length);
  await new Promise((res) => server.close(res));
});

test('r26: O TEMPO DE CONSTRUÇÃO — a IA constrói mundo e jogo em SEGUNDOS (limite forçado)', async () => {
  const uts = createUTS({ seed: 'tempo' });
  const t0 = performance.now();
  const vila = await uts.core.processObjective('criar uma pequena vila próxima a um rio chamada Vila Turbo');
  const tVila = performance.now() - t0;
  assert.ok(vila.ok, 'a vila foi criada e VERIFICADA');
  assert.ok(tVila < 5000, `mundo criado pela IA em ${tVila.toFixed(0)}ms (limite 5000ms)`);

  const t1 = performance.now();
  const jogo = createGame({ genre: 'corrida', name: 'Turbo Gênesis' });
  const tJogo = performance.now() - t1;
  assert.ok(jogo && jogo.files?.length > 0, 'o jogo completo saiu com arquivos reais');
  assert.ok(tJogo < 5000, `jogo completo construído em ${tJogo.toFixed(0)}ms (limite 5000ms)`);

  console.log(`   [r26] TEMPO DE CONSTRUÇÃO medido: vila verificada ${tVila.toFixed(0)}ms · jogo completo ${tJogo.toFixed(0)}ms — a IA desenvolve, o humano descreve`);
});
