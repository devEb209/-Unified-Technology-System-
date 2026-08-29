#!/usr/bin/env node
// UTS :: demos/web/server — zero-dependency static server for the WebGL2 demo.
// Serves the repository so browser ES modules can import src/ directly.

import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
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

const server = createServer(async (req, res) => {
  try {
    const url = new URL(req.url, `http://${req.headers.host}`);
    let path = decodeURIComponent(url.pathname);

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
      for (;;) {
        const { done, value } = await reader.next();
        if (done) break;
        res.write(value); // passthrough byte-exact (the UI parses the SSE)
      }
      res.end();
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

server.listen(PORT, HOST, () => {
  console.log(`UTS demo server: http://${HOST}:${PORT} (root: ${ROOT})`);
});
