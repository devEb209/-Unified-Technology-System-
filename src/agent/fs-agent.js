// UTS :: agent/fs — the AI's FILE SYSTEM on whatever the user connects
// (workspace folder, phone storage via the server). HARD SANDBOX: every op
// resolves INSIDE the root; `..`, absolute escapes and symlink tricks are
// rejected. Every op is journaled (the RRW of files — auditable).

import { promises as fs } from 'node:fs';
import { dirname, join, resolve, sep, relative } from 'node:path';

export class AgentFS {
  constructor({ root } = {}) {
    if (!root) throw new Error('AgentFS precisa de um root (pasta conectada)');
    this.root = resolve(root);
    this.journal = [];
  }

  /** resolve a virtual path INSIDE the sandbox (the single guard) */
  _safe(vpath) {
    const raw = String(vpath ?? '');
    if (raw.startsWith('/') || raw.startsWith('\\') || /^[a-zA-Z]:/.test(raw)) {
      throw new Error(`fs: caminho absoluto não é permitido (use caminhos do workspace): ${vpath}`);
    }
    if (raw.split(/[\\/]+/).includes('..')) {
      throw new Error(`fs: caminho escapa do sandbox: ${vpath}`);
    }
    const abs = resolve(this.root, '.' + sep + raw.replace(/^[/\\]+/, ''));
    const rel = relative(this.root, abs);
    if (rel.startsWith('..')) throw new Error(`fs: caminho escapa do sandbox: ${vpath}`);
    return abs;
  }

  async _log(op, path, extra = {}) {
    this.journal.push({ op, path, at: Date.now(), ...extra });
    if (this.journal.length > 500) this.journal.shift();
  }

  async read(vpath) {
    const abs = this._safe(vpath);
    const data = await fs.readFile(abs);
    await this._log('read', vpath, { bytes: data.length });
    return data;
  }

  async write(vpath, data) {
    const abs = this._safe(vpath);
    await fs.mkdir(dirname(abs), { recursive: true });
    await fs.writeFile(abs, data);
    await this._log('write', vpath, { bytes: data.length ?? String(data).length });
    return { ok: true, path: vpath, bytes: data.length ?? String(data).length };
  }

  async mkdir(vpath) {
    await fs.mkdir(this._safe(vpath), { recursive: true });
    await this._log('mkdir', vpath);
    return { ok: true, path: vpath };
  }

  async list(vpath = '.') {
    const abs = this._safe(vpath);
    const names = await fs.readdir(abs, { withFileTypes: true });
    await this._log('list', vpath);
    return names.map(d => ({ name: d.name, dir: d.isDirectory() }));
  }

  async remove(vpath, { recursive = true } = {}) {
    await fs.rm(this._safe(vpath), { recursive });
    await this._log('remove', vpath);
    return { ok: true };
  }

  async move(from, to) {
    const a = this._safe(from);
    const b = this._safe(to);
    await fs.mkdir(dirname(b), { recursive: true });
    await fs.rename(a, b);
    await this._log('move', from, { to });
    return { ok: true };
  }

  /** the tool surface the Singularity AI calls (validated, journaled) */
  tools() {
    const t = this;
    return {
      'fs.write': { desc: 'escreve arquivo no workspace conectado', schema: { path: { type: 'string' }, content: { type: 'string' } },
        fn: async (p) => t.write(p.path, p.content) },
      'fs.read': { desc: 'lê arquivo do workspace', schema: { path: { type: 'string' } },
        fn: async (p) => ({ content: (await t.read(p.path)).toString() }) },
      'fs.mkdir': { desc: 'cria pasta', schema: { path: { type: 'string' } }, fn: async (p) => t.mkdir(p.path) },
      'fs.list': { desc: 'lista pasta', schema: { path: { type: 'string' } }, fn: async (p) => ({ entries: await t.list(p.path) }) },
      'fs.remove': { desc: 'remove arquivo/pasta', schema: { path: { type: 'string' } }, fn: async (p) => t.remove(p.path) },
      'fs.move': { desc: 'move/renomeia', schema: { from: { type: 'string' }, to: { type: 'string' } }, fn: async (p) => t.move(p.from, p.to) },
    };
  }
}
