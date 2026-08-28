// UTS :: singularity/puter — PuterProvider.
// Puter is an ACCESS LAYER (browser) to models — never the intelligence of UTS.
// Availability is detected at runtime; the Core treats it like any provider.

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
    return { text: true, reasoning: true, code: true, vision: false, structured: true, tools: false, context: 32000 };
  }

  cost() { return 0; }

  async availability() {
    return typeof this._ai()?.chat === 'function';
  }

  async generate({ messages, model }) {
    const ai = this._ai();
    if (!ai || typeof ai.chat !== 'function') throw new Error('puter.ai unavailable');
    const prompt = messages.map(m => `${m.role}: ${m.content}`).join('\n');
    const resp = await ai.chat(prompt, { model: model ?? this.model });
    const text = typeof resp === 'string'
      ? resp
      : (resp?.message?.content ?? resp?.text ?? JSON.stringify(resp));
    let json = null;
    try { json = JSON.parse(text); } catch { /* structured output not guaranteed */ }
    return { text, json };
  }

  toString() { return 'PuterProvider(access-layer)'; }
}
