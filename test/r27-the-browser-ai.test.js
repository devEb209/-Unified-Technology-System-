// R27 — A IA DO NAVEGADOR PELA CAMADA PUTER (User Pays, SEM CHAVE): o
// provider entra no registro quando a camada existe, o STREAM dela atravessa
// o Core (tokens um a um, MESMA lei de validação) e a LISTA DE MODELOS é a
// que a camada devolver — nunca número inventado. A página carrega o
// script do Puter e o banner de boot denuncia qualquer morte na tela.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createUTS } from '../src/index.js';
import { PuterProvider } from '../src/singularity/puter.js';

/** camada puter.ai FALSA mas fiel ao protocolo real: chat com stream:true
 *  devolve iterável de partes {text}; listModels devolve N nomes */
function camadaFake(nModelos) {
  const nomes = Array.from({ length: nModelos }, (_, i) => `modelo-${i + 1}`);
  const plano = JSON.stringify({ intent: 'create_settlement', params: { name: 'Vila Puter', pop: 6 } }, null, 1);
  return {
    listModels: async () => nomes,
    chat: async (prompt, opts = {}) => {
      if (!opts.stream) return plano;
      const partes = [];
      for (let i = 0; i < plano.length; i += 9) partes.push({ text: plano.slice(i, i + 9) });
      return (async function* () { for (const p of partes) yield p; })();
    },
  };
}

test('r27: A IA DO NAVEGADOR — Puter entra no registro, STREAMA no fio do Core e conta os modelos da camada', async () => {
  globalThis.puter = { ai: camadaFake(876) };
  try {
    const uts = createUTS({ seed: 'puter' });
    assert.ok(uts.core.providers.names().includes('puter'), 'o provider Puter entrou no registro');

    // a lista de modelos é a da CAMADA (876), reportada com honestidade
    const pp = new PuterProvider();
    const lista = await pp.listModels();
    assert.equal(lista.count, 876, `a camada devolve ${lista.count} modelos`);

    // o STREAM da camada atravessa o interpretObjectiveStream (mesma lei)
    const toks = [];
    const provider = new PuterProvider();
    const r = await uts.core.interpretObjectiveStream('crie a vila Puter', { provider, model: { id: 'auto' } }, (t) => toks.push(t));
    assert.equal(r.provider, 'puter');
    assert.equal(r.intent, 'create_settlement');
    assert.equal(r.params.name, 'Vila Puter', 'o plano sai válido do fio Puter');
    assert.ok(toks.length > 5, `os TOKENS chegam em partes (${toks.length})`);
    assert.deepEqual(JSON.parse(toks.join('')), { intent: r.intent, params: r.params });

    // SEM a camada, o provider nem registra (honesto — o navegador carrega
    // o script do Puter; quem não tem, fica no interpretador nativo)
    delete globalThis.puter;
    const uts2 = createUTS({ seed: 'sem-puter' });
    assert.ok(!uts2.core.providers.names().includes('puter'), 'sem camada, sem registro (nada fingido)');
  } finally {
    delete globalThis.puter;
  }
});
