#!/usr/bin/env node
// UTS :: demos/web/server — zero-dependency static server for the WebGL2 demo.
// Serves the repository so browser ES modules can import src/ directly.

import { createServer } from 'node:http';
import { AgentFS } from '../../src/agent/fs-agent.js';
import { ProcAgent } from '../../src/agent/proc-agent.js';
import { build as buildApp } from '../../src/agent/build-system.js';
import { styleParams } from '../../src/render/style.js';
import { createGame, GENRES } from '../../src/agent/creator.js';
import { WSHub } from '../../src/net/transport.js';
import { UserApps } from '../../src/platform/user-apps.js';
import { createSSEParser } from '../../src/net/sse.js';
import { readFile } from 'node:fs/promises';
import os from 'node:os';
import { extname, join, normalize } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = fileURLToPath(new URL('../..', import.meta.url));
const PORT = Number(process.env.PORT ?? 8080);
const HOST = process.env.HOST ?? '0.0.0.0';

const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.json': 'application/json',
  '.css': 'text/css',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.svg': 'image/svg+xml',
  '.txt': 'text/plain; charset=utf-8',
  '.md': 'text/plain; charset=utf-8',
};

const WORKSPACE = process.env.UTS_WORKSPACE || join(ROOT, 'workspace');
const agentFS = new AgentFS({ root: WORKSPACE });
const agentProc = new ProcAgent({ allow: process.env.UTS_ALLOW_EXEC === '1' });
const styleState = { name: 'realista', params: null }; // o estilo dito no chat (estado do módulo)
const userApps = new UserApps({ fs: agentFS }); // APPS DE USUÁRIO: criar → instalar → jogar na plataforma

const server = createServer(async (req, res) => {
  try {
    const url = new URL(req.url, `http://${req.headers.host}`);
    let path = decodeURIComponent(url.pathname);

    // ---- /api/fs: the AI's files on the CONNECTED folder (sandboxed hard)
    if (path === '/api/fs' && req.method === 'POST') {
      let body = '';
      for await (const ch of req) body += ch;
      const { op, path: vp, data, to } = JSON.parse(body || '{}');
      try {
        // IMPORTANTE: o trabalho PRIMEIRO, o writeHead DEPOIS — se o await
        // lançar depois do header 200, o catch não pode mais responder.
        let out;
        if (op === 'write') out = await agentFS.write(vp, data ?? '');
        else if (op === 'read') out = { content: (await agentFS.read(vp)).toString() };
        else if (op === 'list') out = { entries: await agentFS.list(vp) };
        else if (op === 'mkdir') out = await agentFS.mkdir(vp);
        else if (op === 'remove') out = await agentFS.remove(vp);
        else if (op === 'move') out = await agentFS.move(vp, to);
        else { res.writeHead(400, { 'content-type': 'application/json' }).end(JSON.stringify({ error: `operação desconhecida: ${op}` })); return; }
        res.writeHead(200, { 'content-type': 'application/json' }).end(JSON.stringify(out));
      } catch (e) {
        if (!res.headersSent) res.writeHead(400, { 'content-type': 'application/json' }).end(JSON.stringify({ error: e.message }));
      }
      return;
    }

    // ---- /api/style: o usuário DIZ o estilo no chat; validação honesta
    if (path === '/api/style') {
      if (req.method === 'GET') {
        res.writeHead(200, { 'content-type': 'application/json' }).end(JSON.stringify(styleState));
        return;
      }
      if (req.method === 'POST') {
        let body = '';
        for await (const ch of req) body += ch;
        try {
          const { style, params } = JSON.parse(body || '{}');
          const r = styleParams(style, params ?? {});
          styleState.name = r.name; styleState.params = r.params;
          res.writeHead(200, { 'content-type': 'application/json' }).end(JSON.stringify(styleState));
        } catch (e) {
          res.writeHead(400, { 'content-type': 'application/json' }).end(JSON.stringify({ error: e.message }));
        }
        return;
      }
    }

    // ---- /api/exec: the AI runs commands (HONEST: default OFF)
    if (path === '/api/exec' && req.method === 'POST') {
      let body = '';
      for await (const ch of req) body += ch;
      const { cmd, cwd } = JSON.parse(body || '{}');
      const r = await agentProc.run(String(cmd ?? '').slice(0, 2000), { cwd });
      res.writeHead(r.ok ? 200 : 403).end(JSON.stringify(r));
      return;
    }

    // ---- /api/create: o GENESIS CRIA UM JOGO COMPLETO de uma frase
    if (path === '/api/create' && req.method === 'POST') {
      let body = '';
      for await (const ch of req) body += ch;
      try {
        const { genre, name } = JSON.parse(body || '{}');
        const r = createGame({ genre, name: name ?? 'MeuJogo' });
        res.writeHead(200, { 'content-type': 'application/zip', 'content-disposition': `attachment; filename="${r.artifact.name}"` });
        res.end(Buffer.from(r.artifact.data));
      } catch (e) {
        res.writeHead(400, { 'content-type': 'application/json' }).end(JSON.stringify({ error: e.message, genres: GENRES }));
      }
      return;
    }

    // ---- /api/install: instala um app criado na PLATAFORMA (com storage próprio)
    if (path === '/api/install' && req.method === 'POST') {
      let body = '';
      for await (const ch of req) body += ch;
      try {
        const { name, genre } = JSON.parse(body || '{}');
        const game = createGame({ genre, name: name ?? 'AppGenesis' });
        const r = await userApps.install({ name: game.genre + '-' + (name ?? 'app').toLowerCase().replace(/[^a-z0-9-]+/g, '-'), zip: game.artifact.data });
        res.writeHead(200, { 'content-type': 'application/json' }).end(JSON.stringify(r));
      } catch (e) {
        res.writeHead(400, { 'content-type': 'application/json' }).end(JSON.stringify({ error: e.message }));
      }
      return;
    }
    // ---- lista de apps instalados
    if (path === '/api/apps' && req.method === 'GET') {
      await userApps.rescan();
      res.writeHead(200, { 'content-type': 'application/json' }).end(JSON.stringify({ apps: userApps.list() }));
      return;
    }
    // ---- app instalado servido PELA PLATAFORMA (workspace/apps/<nome>/…)
    if (path.startsWith('/apps/')) {
      const rel = path.slice('/apps/'.length);
      const file = normalize(join(WORKSPACE, 'apps', rel));
      if (!file.startsWith(join(WORKSPACE, 'apps'))) {
        res.writeHead(403).end('forbidden');
        return;
      }
      try {
        const data = await readFile(file);
        res.writeHead(200, { 'content-type': MIME[extname(file)] ?? 'application/octet-stream', 'cache-control': 'no-cache' });
        res.end(data);
      } catch (e) {
        res.writeHead(404, { 'content-type': 'text/plain' }).end(`app não encontrado: ${e.message}`);
      }
      return;
    }

    // ---- /api/build: apk/exe/web — web builda AGORA (zip real)
    if (path === '/api/build' && req.method === 'POST') {
      let body = '';
      for await (const ch of req) body += ch;
      const { name, target, title } = JSON.parse(body || '{}');
      const r = await buildApp({ name: name ?? 'GenesisApp', target: target ?? 'web', manifest: { title: title ?? name }, fs: agentFS });
      if (r.artifact) {
        res.writeHead(200, { 'content-type': 'application/zip', 'content-disposition': `attachment; filename="${r.artifact.name}"` });
        res.end(Buffer.from(r.artifact.data));
      } else res.writeHead(200, { 'content-type': 'application/json' }).end(JSON.stringify(r));
      return;
    }


    // ---- SSE: real LLM token streaming (env-configured), honest 503 without
    if (path === '/api/llm/stream' && req.method === 'POST') {
      const key = process.env.UTS_LLM_API_KEY || process.env.OPENAI_API_KEY;
      if (!key) {
        res.writeHead(503, { 'content-type': 'application/json' });
        res.end(JSON.stringify({ error: 'no LLM configured', hint: 'set UTS_LLM_API_KEY (+UTS_LLM_BASE_URL/UTS_LLM_MODEL)' }));
        return;
      }
      let body = '';
      for await (const ch of req) body += ch;
      const { objective } = JSON.parse(body || '{}');
      const base = process.env.UTS_LLM_BASE_URL || 'https://api.openai.com/v1';
      const model = process.env.UTS_LLM_MODEL || 'gpt-4o-mini';
      const upstream = await fetch(`${base}/chat/completions`, {
        method: 'POST',
        headers: { 'content-type': 'application/json', authorization: `Bearer ${key}` },
        body: JSON.stringify({ model, stream: true, messages: [{ role: 'user', content: String(objective ?? '').slice(0, 2000) }] }),
      });
      if (!upstream.ok || !upstream.body) {
        res.writeHead(502, { 'content-type': 'application/json' });
        res.end(JSON.stringify({ error: `upstream ${upstream.status}` }));
        return;
      }
      res.writeHead(200, { 'content-type': 'text/event-stream', 'cache-control': 'no-cache', connection: 'keep-alive' });
      const reader = upstream.body.getReader();
      const sse = createSSEParser(); // a verdade sobre o fio (conta, vê [DONE])
      for (;;) {
        const { done, value } = await reader.next();
        if (done) break;
        sse.feed(value); // PASSTHROUGH byte-exato + contagem honesta
        res.write(value);
      }
      res.end();
      console.log(`[sse] stream completo: ${sse.events.length} eventos, done=${sse.done}`);
      return;
    }

    if (path === '/' || path === '/index.html') path = '/demos/web/index.html';
    const file = normalize(join(ROOT, path));
    if (!file.startsWith(ROOT)) {
      res.writeHead(403).end('forbidden');
      return;
    }
    const data = await readFile(file);
    res.writeHead(200, {
      'content-type': MIME[extname(file)] ?? 'application/octet-stream',
      'cache-control': 'no-cache',
    });
    res.end(data);
  } catch (e) {
    res.writeHead(404, { 'content-type': 'text/plain' }).end(`not found: ${e.message}`);
  }
});

// TRANSPORTE REAL (RFC 6455): o mundo sai daqui por WebSocket
const hub = new WSHub().attach(server);
const startedAt = Date.now();
setInterval(() => {
  hub.broadcast({ type: 'genesis.pulse', clients: hub.sockets.size, style: styleState.name, uptimeSec: Math.round((Date.now() - startedAt) / 1000), sent: hub.sent });
}, 2000).unref?.();

server.listen(PORT, HOST, () => {
  // HONESTO: 0.0.0.0 é "escutando em todas as interfaces" — NÃO é URL.
  // O que abre no navegador é localhost (mesmo aparelho) ou o IP local
  // (outro aparelho na mesma rede Wi-Fi).
  const ips = [];
  for (const lista of Object.values(os.networkInterfaces())) {
    for (const r of lista ?? []) if (r.family === 'IPv4' && !r.internal) ips.push(r.address);
  }
  console.log(`UTS demo server (root: ${ROOT})`);
  console.log(`  no navegador DESTE aparelho: http://localhost:${PORT}`);
  if (ips.length) console.log(`  em OUTRO aparelho na mesma rede: http://${ips[0]}:${PORT}`);
  console.log(`  (escutando em ${HOST}:${PORT} — 0.0.0.0 é "todas as interfaces", não é endereço para digitar)`);
});
