// R28 — A PÁGINA VIVA: o script REAL do demo (extraído do index.html) é
// EXECUTADO de ponta a ponta com DOM simulado — qualquer TDZ, ReferenceError
// ou morte de boot quebra o teste. É a guarda que impede, para sempre, que
// "a mesma tela sem nada funcionar" volte: se o módulo da página não chega
// ao último linha (o requestAnimationFrame do loop), o teste falha.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, writeFileSync, mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, dirname } from 'node:path';
import { pathToFileURL, fileURLToPath } from 'node:url';

const RAIZ = join(dirname(fileURLToPath(import.meta.url)), '..');

test('r28: A PÁGINA VIVA — o módulo do demo executa ATÉ O FIM (sem TDZ, sem morte de boot)', async () => {
  const html = readFileSync(join(RAIZ, 'demos/web/index.html'), 'utf-8');
  const m = html.match(/<script type="module">\n([\s\S]*?)<\/script>/);
  assert.ok(m, 'o demo tem módulo inline');
  const fonte = m[1];

  // ---- DOM simulado (o suficiente para o boot INTEIRO rodar)
  const elemento = (id) => ({
    id, style: {}, innerHTML: '', textContent: '', scrollTop: 0, value: '',
    addEventListener: () => {}, setPointerCapture: () => {}, removeEventListener: () => {},
    appendChild: () => {}, querySelectorAll: () => [], getContext: () => null, // sem GPU → caminho de TEXTO honesto
    onclick: null, clientWidth: 800, clientHeight: 600, width: 300, height: 150,
    classList: { add: () => {}, remove: () => {} },
  });
  const elementos = new Map();
  globalThis.document = {
    getElementById: (id) => { if (!elementos.has(id)) elementos.set(id, elemento(id)); return elementos.get(id); },
    querySelectorAll: () => [], createElement: () => elemento('x'),
    addEventListener: () => {}, body: elemento('body'),
  };
  globalThis.window = globalThis;
  globalThis.addEventListener = () => {};
  globalThis.devicePixelRatio = 2;
  let rafCallback = null;
  globalThis.requestAnimationFrame = (cb) => { rafCallback = cb; return 0; }; // captura o agendamento FINAL
  globalThis.WebSocket = class { addEventListener() {} close() {} };
  globalThis.fetch = async () => ({ ok: true, json: async () => ({ apps: [] }), blob: async () => new Blob() });
  globalThis.localStorage = { getItem: () => null, setItem: () => {}, removeItem: () => {} };
  globalThis.matchMedia = () => ({ matches: false, addEventListener: () => {} });
  // TIMERS rastreados: o mundo pode agendar autosave/pulse — nada pode
  // sobreviver ao teste (o runner morre com timer órfão)
  const timers = new Set();
  const si = globalThis.setInterval, st = globalThis.setTimeout;
  globalThis.setInterval = (fn, ms, ...a) => { const id = si(fn, ms, ...a); timers.add(id); return id; };
  globalThis.setTimeout = (fn, ms, ...a) => { const id = st(fn, ms, ...a); timers.add(id); return id; };
  globalThis.__limpaTimers = () => { for (const id of timers) { clearInterval(id); clearTimeout(id); } timers.clear(); };
  globalThis.location = { search: '', protocol: 'http:', host: 'localhost:8080', pathname: '/' };
  globalThis.history = { replaceState: () => {}, pushState: () => {} };

  // ---- o módulo REAL da página, com o import apontado para o src da raiz
  const dir = mkdtempSync(join(tmpdir(), 'pagina-viva-'));
  const alvo = join(dir, 'pagina.mjs');
  const srcAbs = pathToFileURL(join(RAIZ, 'src')).href;
  // TODOS os imports relativos do demo apontam para o src real da raiz
  // (mantém a aspa de fechamento original do import)
  writeFileSync(alvo, fonte.replaceAll("from '../../src/", `from '${srcAbs}/`));

  try {
    await import(pathToFileURL(alvo).href);
    assert.equal(typeof rafCallback, 'function', 'o módulo chegou ao ÚLTIMO linha (loop agendado) — a página inteira vive');
  } finally {
    globalThis.__limpaTimers?.();
    rmSync(dir, { recursive: true, force: true });
    delete globalThis.document; delete globalThis.window; delete globalThis.location;
    delete globalThis.localStorage; delete globalThis.matchMedia; delete globalThis.history;
  }
});
