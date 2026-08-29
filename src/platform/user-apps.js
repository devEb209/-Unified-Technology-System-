// UTS :: platform/user-apps — REAL USER APPS on the platform: the GENESIS
// creates a game, the user INSTALLS it, the platform serves it and gives
// it its OWN sandboxed storage (per-app, on the connected folder). An
// app can never read another app's storage (the fs guard is the wall).
import { zipRead } from '../util/zip.js';

export class UserApps {
  constructor({ fs }) {
    this.fs = fs; // AgentFS rooted at the workspace
    this.apps = new Map(); // name → { installedAt, entry, files, bytes }
  }

  _dir(name) {
    const n = String(name ?? '').toLowerCase().replace(/[^a-z0-9-]+/g, '-').replace(/^-+|-+$/g, '');
    if (!n) throw new Error('apps: nome inválido');
    return `apps/${n}`;
  }

  /**
   * Install a created app FROM ITS VERIFIED ZIP: real files into the
   * workspace, registry updated. The zip is the one artifact whose bytes
   * were self-verified at creation — a single truth.
   */
  async install({ name, zip }) {
    const entries = zipRead(zip instanceof Uint8Array ? zip : new Uint8Array(zip));
    const dir = this._dir(name);
    let bytes = 0;
    const names = [];
    for (const [fname, data] of entries) {
      await this.fs.write(`${dir}/${fname}`, data);
      bytes += data.length;
      names.push(fname);
    }
    const meta = { name: this._nameOf(name), dir, entry: `${dir}/index.html`, files: names, bytes, installedAt: Date.now() };
    await this.fs.write(`${dir}/app.json`, JSON.stringify(meta, null, 2));
    this.apps.set(meta.name, meta);
    return { ok: true, ...meta, url: `/apps/${meta.name}/index.html` };
  }

  _nameOf(name) { return this._dir(name).split('/')[1]; }

  /** re-attach after restart: apps already on disk come back */
  async rescan() {
    try {
      const entries = await this.fs.list('apps');
      for (const e of entries) {
        if (!e.dir) continue;
        try {
          const meta = JSON.parse((await this.fs.read(`apps/${e.name}/app.json`)).toString());
          this.apps.set(meta.name, meta);
        } catch { /* app sem manifesto: ignorado (honesto) */ }
      }
    } catch { /* sem pasta apps ainda */ }
    return this.list();
  }

  list() { return [...this.apps.values()].map((a) => ({ name: a.name, entry: a.entry, bytes: a.bytes, files: a.files.length, installedAt: a.installedAt })); }

  /** per-app sandboxed storage (apps/<name>/data/<path>) */
  async storageWrite(name, path, data) {
    const app = this.apps.get(this._nameOf(name));
    if (!app) throw new Error(`apps: "${name}" não está instalado`);
    const p = String(path ?? '');
    if (p.includes('..') || p.startsWith('/')) throw new Error('apps: caminho de storage inválido');
    return this.fs.write(`${app.dir}/data/${p}`, data);
  }

  async storageRead(name, path) {
    const app = this.apps.get(this._nameOf(name));
    if (!app) throw new Error(`apps: "${name}" não está instalado`);
    const p = String(path ?? '');
    if (p.includes('..') || p.startsWith('/')) throw new Error('apps: caminho de storage inválido');
    return this.fs.read(`${app.dir}/data/${p}`);
  }
}
