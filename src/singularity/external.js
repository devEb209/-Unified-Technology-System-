// UTS :: singularity/external — ExternalLLMProvider (production path).
// OpenAI-compatible REST provider with generate/stream/capabilities/cost/
// availability. The API key NEVER enters logs, snapshots or memory:
// the provider object masks itself and the Core persists only its NAME.

export class ExternalLLMProvider {
  constructor({
    name = 'openai-compatible',
    baseUrl = 'https://api.openai.com/v1',
    apiKey = null,
    model = 'gpt-4o',
    fetchImpl = null,
    costPer1k = 2.5,
    context = 128000,
    caps = {},
  } = {}) {
    if (apiKey == null) {
      // key comes ONLY from secure configuration (env), never hard-coded
      apiKey = (typeof process !== 'undefined' && process.env?.OPENAI_API_KEY) || null;
    }
    this.name = name;
    this.baseUrl = baseUrl.replace(/\/$/, '');
    this._apiKey = apiKey;
    this.model = model;
    this.fetchImpl = fetchImpl ?? (typeof fetch !== 'undefined' ? fetch : null);
    this.costPer1k = costPer1k;
    this.context = context;
    this._caps = { text: true, reasoning: true, code: true, vision: false, structured: true, tools: true, ...caps };
  }

  capabilities() {
    return { ...this._caps, context: this.context };
  }

  cost(modelId, tokens = 1000) {
    return (tokens / 1000) * this.costPer1k;
  }

  _headers() {
    return {
      'content-type': 'application/json',
      ...(this._apiKey ? { authorization: `Bearer ${this._apiKey}` } : {}),
    };
  }

  async availability() {
    if (!this.fetchImpl || !this._apiKey) return false;
    try {
      const res = await this.fetchImpl(`${this.baseUrl}/models`, { method: 'GET', headers: this._headers() });
      return res.ok;
    } catch {
      return false;
    }
  }

  async generate({ messages, model, json = true }) {
    if (!this.fetchImpl) throw new Error(`${this.name}: no fetch available`);
    const body = {
      model: model ?? this.model,
      messages,
      ...(json ? { response_format: { type: 'json_object' } } : {}),
    };
    const res = await this.fetchImpl(`${this.baseUrl}/chat/completions`, {
      method: 'POST',
      headers: this._headers(),
      body: JSON.stringify(body),
    });
    if (!res.ok) {
      throw new Error(`${this.name}: HTTP ${res.status}`);
    }
    const data = await res.json();
    const text = data?.choices?.[0]?.message?.content ?? '';
    let parsed = null;
    try { parsed = JSON.parse(text); } catch { /* verifier will handle */ }
    return { text, json: parsed };
  }

  /** minimal SSE streaming (delta text) */
  async *stream({ messages, model }) {
    if (!this.fetchImpl) throw new Error(`${this.name}: no fetch available`);
    const res = await this.fetchImpl(`${this.baseUrl}/chat/completions`, {
      method: 'POST',
      headers: { ...this._headers() },
      body: JSON.stringify({ model: model ?? this.model, messages, stream: true }),
    });
    if (!res.ok || !res.body) throw new Error(`${this.name}: HTTP ${res.status}`);
    const reader = res.body.getReader();
    const decoder = new TextDecoder();
    let buf = '';
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      buf += decoder.decode(value, { stream: true });
      const lines = buf.split('\n');
      buf = lines.pop() ?? '';
      for (const line of lines) {
        const t = line.trim();
        if (!t.startsWith('data:')) continue;
        const payload = t.slice(5).trim();
        if (payload === '[DONE]') return;
        try {
          const j = JSON.parse(payload);
          const delta = j?.choices?.[0]?.delta?.content;
          if (delta) yield delta;
        } catch { /* ignore malformed chunk */ }
      }
    }
  }

  /** secrets never leak through stringification */
  toString() {
    return `ExternalLLMProvider(${this.name}, key=${this._apiKey ? '***masked***' : 'none'})`;
  }

  toJSON() {
    return { name: this.name, baseUrl: this.baseUrl, model: this.model, key: '***masked***' };
  }
}
