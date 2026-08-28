// UTS :: persistence/storage — decoupled storage backends.
// Persistence -> StorageBackend (Memory today, File on Node, Database/Cloud later).

export class MemoryStorage {
  constructor() {
    this.map = new Map();
  }

  async get(key) {
    return this.map.get(key) ?? null;
  }

  async set(key, value) {
    this.map.set(String(key), String(value));
  }

  async delete(key) {
    this.map.delete(String(key));
  }

  async keys() {
    return [...this.map.keys()];
  }
}

/** Node-only backend. Atomic writes (tmp + rename). fs injected for tests. */
export class FileStorage {
  constructor(dir, fsp = null) {
    this.dir = dir;
    this._fsp = fsp;
  }

  async _fs() {
    if (!this._fsp) {
      this._fsp = await import('node:fs/promises');
    }
    return this._fsp;
  }

  _path(key) {
    const safe = String(key).replace(/[^a-zA-Z0-9._-]/g, '_');
    return `${this.dir}/${safe}.uts.json`;
  }

  async get(key) {
    const fsp = await this._fs();
    try {
      return await fsp.readFile(this._path(key), 'utf8');
    } catch (e) {
      if (e?.code === 'ENOENT') return null;
      throw e;
    }
  }

  async set(key, value) {
    const fsp = await this._fs();
    await fsp.mkdir(this.dir, { recursive: true });
    const path = this._path(key);
    const tmp = path + '.tmp';
    await fsp.writeFile(tmp, String(value), 'utf8');
    await fsp.rename(tmp, path);
  }

  async delete(key) {
    const fsp = await this._fs();
    try { await fsp.unlink(this._path(key)); } catch (e) { if (e?.code !== 'ENOENT') throw e; }
  }

  async keys() {
    const fsp = await this._fs();
    await fsp.mkdir(this.dir, { recursive: true });
    const files = await fsp.readdir(this.dir);
    return files.filter(f => f.endsWith('.uts.json')).map(f => f.replace('.uts.json', ''));
  }
}
