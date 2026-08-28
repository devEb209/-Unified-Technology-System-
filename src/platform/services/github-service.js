// UTS :: platform/services/github — CONNECTED SERVICE: GitHub.
//
// The platform AI can use connected services (GitHub and whatever else is
// plugged in) as tools: read/write files, inspect repos. Tokens come ONLY
// from secure configuration (env/param), are masked everywhere and are never
// persisted in memory, snapshots, logs or docs.

const API = 'https://api.github.com';

export class GitHubService {
  constructor({ token = null, owner = null, repo = null, apiBase = API, fetchImpl = null } = {}) {
    if (token == null && typeof process !== 'undefined' && process.env?.GITHUB_TOKEN) {
      token = process.env.GITHUB_TOKEN;
    }
    this.name = 'github';
    this._token = token;
    this.owner = owner;
    this.repo = repo;
    this.apiBase = apiBase.replace(/\/$/, '');
    this.fetchImpl = fetchImpl ?? (typeof fetch !== 'undefined' ? fetch : null);
    this.calls = 0;
  }

  capabilities() { return ['repos', 'files', 'commits']; }

  availability() {
    return !!(this._token && this.fetchImpl);
  }

  _headers() {
    return {
      'accept': 'application/vnd.github+json',
      'user-agent': 'UTS-Platform',
      ...(this._token ? { authorization: `Bearer ${this._token}` } : {}),
    };
  }

  async _request(path, init = {}) {
    if (!this.fetchImpl) throw new Error('github: no fetch available');
    if (!this._token) throw new Error('github: no token configured (set GITHUB_TOKEN env)');
    this.calls++;
    const res = await this.fetchImpl(`${this.apiBase}${path}`, {
      ...init,
      headers: { ...this._headers(), ...(init.headers ?? {}) },
    });
    const body = await res.json().catch(() => ({}));
    if (!res.ok) {
      throw new Error(`github: HTTP ${res.status} ${body?.message ?? ''}`.trim());
    }
    return body;
  }

  async repoInfo({ owner = this.owner, repo = this.repo } = {}) {
    return this._request(`/repos/${owner}/${repo}`);
  }

  async getFile(path, { owner = this.owner, repo = this.repo, ref = null } = {}) {
    const q = ref ? `?ref=${encodeURIComponent(ref)}` : '';
    const data = await this._request(`/repos/${owner}/${repo}/contents/${encodePath(path)}${q}`);
    if (Array.isArray(data)) return { type: 'dir', entries: data.map(e => ({ name: e.name, path: e.path, type: e.type })) };
    return {
      type: 'file',
      path: data.path,
      content: data.encoding === 'base64' ? Buffer.from(data.content, 'base64').toString('utf8') : data.content,
      sha: data.sha,
    };
  }

  async putFile(path, content, message, { owner = this.owner, repo = this.repo, branch = null } = {}) {
    let sha = null;
    try {
      const existing = await this.getFile(path, { owner, repo });
      if (existing.type === 'file') sha = existing.sha;
    } catch { /* new file */ }
    const body = {
      message: String(message ?? `UTS: update ${path}`).slice(0, 200),
      content: Buffer.from(String(content), 'utf8').toString('base64'),
      ...(sha ? { sha } : {}),
      ...(branch ? { branch } : {}),
    };
    const data = await this._request(`/repos/${owner}/${repo}/contents/${encodePath(path)}`, {
      method: 'PUT',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify(body),
    });
    return { path, commit: data?.commit?.sha ?? null, updated: !!sha };
  }

  status() {
    return {
      configured: !!this._token,
      repo: this.owner && this.repo ? `${this.owner}/${this.repo}` : null,
      calls: this.calls,
    };
  }

  async health() {
    return this.availability() ? 'ok' : 'not-configured';
  }

  /** secrets never leak */
  toString() {
    return `GitHubService(${this.owner ?? '?'}/${this.repo ?? '?'}, token=${this._token ? '***masked***' : 'none'})`;
  }

  toJSON() {
    return { name: this.name, repo: this.repo, owner: this.owner, token: this._token ? '***masked***' : null };
  }
}

function encodePath(path) {
  return String(path).split('/').map(encodeURIComponent).join('/');
}
