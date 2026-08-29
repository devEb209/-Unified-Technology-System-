// UTS :: platform/services/cloud-storage — STORAGE EM NUVEM como interface
// estruturada: a plataforma SINCRONIZA apps/mundos com uma nuvem quando
// ela existir (env: UTS_CLOUD_URL + UTS_CLOUD_KEY opcional) e é HONESTA
// quando não existe (nunca fingimos backup). Nenhuma chave no código —
// a chave viaja só no header Authorization, configurada por ambiente.
// O transporte é INJETÁVEL (fetchImpl) — determinístico em teste.

export class CloudError extends Error {
  constructor(code, message) { super(message); this.code = code; }
}

export class CloudStorageProvider {
  constructor({ url = null, apiKey = null, fetchImpl = null, timeoutMs = 6000 } = {}) {
    this.url = url ?? (typeof process !== 'undefined' ? process.env?.UTS_CLOUD_URL ?? null : null);
    this.apiKey = apiKey ?? (typeof process !== 'undefined' ? process.env?.UTS_CLOUD_KEY ?? null : null);
    this.fetchImpl = fetchImpl ?? (typeof fetch !== 'undefined' ? fetch : null);
    this.timeoutMs = timeoutMs;
    this.name = 'cloud-storage';
  }

  static available() {
    return typeof process !== 'undefined' && !!process.env?.UTS_CLOUD_URL;
  }

  /** honesto: sem URL/transporte não há nuvem — a plataforma segue LOCAL */
  async availability() {
    return !!(this.url && this.fetchImpl);
  }

  _headers(extra = {}) {
    // a chave NUNCA vai no corpo nem no código — só no header, por ambiente
    return { 'content-type': 'application/json', ...(this.apiKey ? { authorization: `Bearer ${this.apiKey}` } : {}), ...extra };
  }

  async _send(path, init = {}) {
    if (!this.url || !this.fetchImpl) throw new CloudError('CLOUD_OFFLINE', 'nenhuma nuvem configurada (env: UTS_CLOUD_URL) — o estado segue LOCAL, nada é fingido');
    let res;
    try {
      res = await this.fetchImpl(`${this.url.replace(/\/$/, '')}${path}`, {
        ...init,
        headers: this._headers(init.headers ?? {}),
        signal: AbortSignal.timeout(this.timeoutMs),
      });
    } catch (err) {
      throw new CloudError('CLOUD_UNREACHABLE', `nuvem inalcançável: ${err.message}`);
    }
    if (!res.ok) throw new CloudError('CLOUD_HTTP', `nuvem respondeu ${res.status}`);
    return res.json();
  }

  /** bytes (string ou Uint8Array) sobem como base64 — cópia fiel, sem re-interpretar */
  static encode(data) {
    if (typeof data === 'string') return Buffer.from(data, 'utf8').toString('base64');
    return Buffer.from(data).toString('base64');
  }

  static decode(b64) {
    return new Uint8Array(Buffer.from(String(b64 ?? ''), 'base64'));
  }

  async put(app, key, data) {
    const r = await this._send('/put', {
      method: 'POST',
      body: JSON.stringify({ app: String(app), key: String(key), encoding: 'base64', data: CloudStorageProvider.encode(data) }),
    });
    return { ok: r?.ok !== false, stored: `${app}/${key}` };
  }

  async get(app, key) {
    const r = await this._send(`/get?app=${encodeURIComponent(app)}&key=${encodeURIComponent(key)}`);
    if (r?.data == null) throw new CloudError('CLOUD_NOT_FOUND', `${app}/${key} não está na nuvem`);
    return CloudStorageProvider.decode(r.data);
  }

  async list(app) {
    const r = await this._send(`/list?app=${encodeURIComponent(app)}`);
    return Array.isArray(r?.keys) ? r.keys.map(String) : [];
  }
}
