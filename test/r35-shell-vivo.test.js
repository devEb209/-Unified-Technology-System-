// R35 — O SHELL VIVO: o script de apresentação da GENESIS é EXECUTADO de ponta
// a ponta com DOM simulado, no EXATO caminho do usuário (sessão restaurada +
// ?world=vale). Foi aqui que nasceu a doença da R34: a restauração de sessão
// rodava no MEIO do script, lia `chats` em TDZ e o ReferenceError matava metade
// do shell em todo reload (badge GPU eterno, __addCriacao nunca registrado,
// galeria/histórico/projetos nunca renderizados). Se essa classe voltar, ESTE
// teste morre — antes do usuário.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const RAIZ = join(dirname(fileURLToPath(import.meta.url)), '..');

// globals só de leitura no Node (ex.: navigator) — defineProperty resolve
const def = (k, v) => Object.defineProperty(globalThis, k, { value: v, configurable: true, writable: true });

test('r35: O SHELL VIVO — a casca GENESIS liga INTEIRA com sessão ativa (sem TDZ, sem metade morta)', async () => {
  const html = readFileSync(join(RAIZ, 'demos/web/index.html'), 'utf-8');
  const m = html.match(/<script>\n(\s*\/\/ ============ GENESIS[\s\S]*?)<\/script>/);
  assert.ok(m, 'o demo tem o script do shell GENESIS');
  const fonte = m[1];

  // ---- DOM simulado (o shell precisa de pouco para BOOTAR inteiro)
  const elemento = (id) => ({
    id, style: {}, dataset: {}, textContent: '', innerHTML: '', value: '',
    scrollTop: 0, scrollHeight: 0, disabled: false, hidden: false, files: [],
    classList: { add() {}, remove() {}, toggle() {}, contains() { return false; } },
    appendChild() {}, querySelectorAll: () => [], getContext: () => null,
    addEventListener() {}, focus() {}, click() {}, parentElement: null,
  });
  const elementos = new Map();
  const memStore = (inicial) => {
    const m0 = new Map(Object.entries(inicial ?? {}));
    return {
      getItem: (k) => (m0.has(k) ? m0.get(k) : null),
      setItem: (k, v) => m0.set(k, String(v)),
      removeItem: (k) => m0.delete(k),
    };
  };
  // O CAMINHO DO USUÁRIO: sessão válida + flag do mundo (pós-redirect) + log pré-escrito
  const storage = memStore({
    'uts.sessao.v1': JSON.stringify({ usuario: 'teste', exp: Date.now() + 3600e3 }),
    'uts.mundo.v1': '1',
  });
  const doc = {
    hidden: false,
    getElementById: (id) => { if (!elementos.has(id)) elementos.set(id, elemento(id)); return elementos.get(id); },
    querySelectorAll: () => [],
    createElement: (t) => elemento(t),
    addEventListener() {},
    body: elemento('body'),
    documentElement: elemento('html'),
  };
  def('document', doc);
  def('window', globalThis);
  def('localStorage', memStore());
  def('sessionStorage', storage);
  def('matchMedia', (q) => ({ matches: String(q).includes('reduce') }));
  def('navigator', { onLine: true, hardwareConcurrency: 8 });
  def('location', { search: '?world=vale', hash: '#utsai', replace() {} });
  def('history', { replaceState() {} });
  def('addEventListener', () => {});
  def('dispatchEvent', () => {});
  def('MutationObserver', class { observe() {} disconnect() {} });
  def('requestAnimationFrame', () => 0);
  def('setInterval', () => 0);   // nenhum timer roda: boot determinístico
  def('setTimeout', () => 0);
  def('clearInterval', () => {});
  def('clearTimeout', () => {});
  def('getComputedStyle', () => ({ getPropertyValue: () => '#00ff9c' }));
  def('confirm', () => false);
  def('prompt', () => null);

  // o boot do MÓDULO já aconteceu (recarregue a página): o log já tem as linhas
  doc.getElementById('log').textContent =
    'núcleo VIVO em 1ms · providers: local, puter\nIA REAL via PUTER: 876 modelos na camada de acesso\nGPU: WebGL2 real (o Frame chega à tela pela cadeia representação)';

  // A EXECUÇÃO: qualquer ReferenceError/TDZ aqui é a doença de volta
  new Function(fonte)();

  // ---- o app inteiro precisa ter LIGADO
  assert.equal(doc.getElementById('user-nome').textContent, 'teste', 'sessão restaurada → usuário no topo');
  assert.equal(typeof globalThis.window.__addCriacao, 'function', '__addCriacao registrado (galeria viva)');
  assert.ok(doc.getElementById('thread').innerHTML.includes('conversa'), 'histórico inicializou');
  assert.ok(doc.getElementById('projects-lista').innerHTML.includes('NENHUMA EXECUÇÃO'), 'PROJECTS renderizou');
  assert.ok(doc.getElementById('recent-lista').innerHTML.length > 4, 'RECENT renderizou');
  assert.ok(doc.getElementById('criacoes').innerHTML.includes('NADA CRIADO AINDA'), 'galeria de criações renderizou');

  // ---- os leitores do PASSADO do log (o bug do "detectando GPU")
  assert.equal(doc.getElementById('gpu-badge').textContent, 'GPU REAL · WEBGL2 GENESIS', 'badge GPU lê o boot que já aconteceu');
  assert.ok(doc.getElementById('ia-chip').innerHTML.includes('876'), 'chip IA mostra os modelos reais');
  assert.equal(doc.getElementById('models-n2').textContent, '876', 'MODELS recebe a contagem real');
  assert.equal(doc.getElementById('providers-n').textContent, 'local, puter', 'SERVICES mostra os providers reais');
});

test('r35: sem sessão, o shell continua inteiro (login aparece; nada morre no parse)', async () => {
  const html = readFileSync(join(RAIZ, 'demos/web/index.html'), 'utf-8');
  const m = html.match(/<script>\n(\s*\/\/ ============ GENESIS[\s\S]*?)<\/script>/);
  const fonte = m[1];
  const elemento = (id) => ({
    id, style: {}, dataset: {}, textContent: '', innerHTML: '', value: '',
    scrollTop: 0, scrollHeight: 0, disabled: false, hidden: false, files: [],
    classList: { add() {}, remove() {}, toggle() {}, contains() { return false; } },
    appendChild() {}, querySelectorAll: () => [], getContext: () => null,
    addEventListener() {}, focus() {}, click() {}, parentElement: null,
  });
  const elementos = new Map();
  const memStore = () => {
    const m0 = new Map();
    return { getItem: (k) => (m0.has(k) ? m0.get(k) : null), setItem: (k, v) => m0.set(k, String(v)), removeItem: (k) => m0.delete(k) };
  };
  def('document', {
    hidden: false,
    getElementById: (id) => { if (!elementos.has(id)) elementos.set(id, elemento(id)); return elementos.get(id); },
    querySelectorAll: () => [], createElement: (t) => elemento(t), addEventListener() {}, body: elemento('body'),
    documentElement: elemento('html'),
  });
  def('window', globalThis);
  def('localStorage', memStore());
  def('sessionStorage', memStore()); // SEM sessão
  def('matchMedia', (q) => ({ matches: String(q).includes('reduce') }));
  def('navigator', { onLine: true, hardwareConcurrency: 8 });
  def('location', { search: '', hash: '', replace() {} });
  def('history', { replaceState() {} });
  def('addEventListener', () => {});
  def('dispatchEvent', () => {});
  def('MutationObserver', class { observe() {} disconnect() {} });
  def('requestAnimationFrame', () => 0);
  def('setInterval', () => 0);
  def('setTimeout', () => 0);
  def('clearInterval', () => {});
  def('clearTimeout', () => {});
  def('getComputedStyle', () => ({ getPropertyValue: () => '#00ff9c' }));
  def('confirm', () => false);
  def('prompt', () => null);

  new Function(fonte)(); // sem sessão: nenhum erro de parse/boot
  assert.equal(typeof globalThis.window.__addCriacao, 'function', '__addCriacao registrado mesmo sem sessão');
});
