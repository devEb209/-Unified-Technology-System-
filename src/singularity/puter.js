// UTS :: singularity/puter — PuterProvider.
// Puter is an ACCESS LAYER (browser) to models — never the intelligence of UTS.
// Availability is detected at runtime; the Core treats it like any provider.
// "User Pays": o app NÃO precisa de chave — o usuário final autentica no
// Puter e consome do próprio plano; a plataforma só enxerga a camada.
export class PuterProvider {
  constructor({ model = 'auto', globalRef = globalThis } = {}) {
    this.name = 'puter';
    this.model = model;
    this.globalRef = globalRef;
  }

  _ai() {
    return this.globalRef?.puter?.ai ?? null;
  }

  capabilities() {
    return { text: true, reasoning: true, code: true, vision: true, structured: true, tools: false, context: 128000 };
  }

  cost() { return 0; }

  async availability() {
    return typeof this._ai()?.chat === 'function';
  }

  _prompt(messages) {
    return messages.map(m => `${m.role}: ${m.content}`).join('\n');
  }

  async generate({ messages, model }) {
    const ai = this._ai();
    if (!ai || typeof ai.chat !== 'function') throw new Error('puter.ai unavailable');
    const resp = await ai.chat(this._prompt(messages), { model: model ?? this.model });
    const text = typeof resp === 'string'
      ? resp
      : (resp?.message?.content ?? resp?.text ?? JSON.stringify(resp));
    let json = null;
    try { json = JSON.parse(text); } catch { /* structured output not guaranteed */ }
    return { text, json };
  }

  /** STREAM REAL da camada Puter: o chat com stream:true devolve um
   *  iterável de partes ({text}) — cada texto vira um TOKEN no fio do
   *  Core (o interpretObjectiveStream valida com a MESMA lei). */
  async *stream({ messages, model }) {
    const ai = this._ai();
    if (!ai || typeof ai.chat !== 'function') throw new Error('puter.ai unavailable');
    const resp = await ai.chat(this._prompt(messages), { model: model ?? this.model, stream: true });
    if (typeof resp === 'string') { yield resp; return; }
    for await (const part of resp) {
      const t = typeof part === 'string' ? part : (part?.text ?? '');
      if (t) yield t;
    }
  }

  /** OS MODELOS da camada (array simples ou mapa provedor→lista; a contagem
   *  é HONESTA: só o que a camada devolver, nunca número inventado) */
  async listModels() {
    const ai = this._ai();
    if (typeof ai?.listModels !== 'function') return { count: null, honest: 'listModels indisponível nesta camada' };
    const raw = await ai.listModels();
    const flat = Array.isArray(raw)
      ? raw
      : Object.values(raw ?? {}).flatMap((v) => (Array.isArray(v) ? v : (typeof v === 'string' ? [v] : [])));
    return { count: flat.length, models: flat.map(String) };
  }

  toString() { return 'PuterProvider(access-layer)'; }
}
