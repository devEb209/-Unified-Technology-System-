// UTS :: persistence/utsdb — UTS-DB: OUR embedded database (no external DB).
//
//   append-only journal (WAL) + replay recovery + transactions + compaction
//   + collections + secondary indexes + StorageBackend adapter
//
// The journal is OUR format (JSONL ops). The filesystem is the inevitable
// OS layer, injected behind a Journal interface (Memory/File) — the database
// itself, its semantics and its recovery are UTS-native. Crash safety:
// a torn tail (partial line) is ignored on replay, never trusted.

export class UTSDBError extends Error {}

/** Journal interface impls — append(bytes), readAll() -> lines[] */
export class MemoryJournal {
  constructor() { this.lines = []; }
  async append(line) { this.lines.push(line); }
  async readAll() { return [...this.lines]; }
  async replaceAll(lines) { this.lines = [...lines]; }
}

export class FileJournal {
  constructor(path, fsp = null) {
    this.path = path;
    this._fsp = fsp;
  }
  async _fs() {
    this._fsp ??= await import('node:fs/promises');
    return this._fsp;
  }
  async append(line) {
    const fs = await this._fs();
    await fs.appendFile(this.path, line + '\n', 'utf8');
  }
  async readAll() {
    const fs = await this._fs();
    let data = '';
    try { data = await fs.readFile(this.path, 'utf8'); } catch (e) { if (e?.code !== 'ENOENT') throw e; }
    return data.length ? data.split('\n').slice(0, -1) : [];
  }
  async replaceAll(lines) {
    const fs = await this._fs();
    const tmp = this.path + '.compact';
    await fs.writeFile(tmp, lines.length ? lines.join('\n') + '\n' : '', 'utf8');
    await fs.rename(tmp, this.path);
  }
}

export class UTSDB {
  constructor({ journal = null, name = 'uts' } = {}) {
    this.name = name;
    this.journal = journal ?? new MemoryJournal();
    /** col -> Map(key -> value) */
    this.collections = new Map();
    /** col -> Map(field -> Map(value -> Set(key))) */
    this.indexes = new Map();
    this.staged = null; // transaction staging: Map(opKey -> {op})
    this.stats = { ops: 0, replays: 0, tornTails: 0, compactions: 0, txCommits: 0, txRollbacks: 0 };
  }

  _col(col) {
    if (!this.collections.has(col)) this.collections.set(col, new Map());
    return this.collections.get(col);
  }

  /** open/recover: replay the journal; ignore a torn (incomplete) tail */
  async open() {
    const lines = await this.journal.readAll();
    this.collections.clear();
    let replayed = 0;
    for (let i = 0; i < lines.length; i++) {
      let op;
      try {
        op = JSON.parse(lines[i]);
      } catch {
        // only the LAST line may be torn (crash during append)
        if (i === lines.length - 1) { this.stats.tornTails++; continue; }
        throw new UTSDBError(`corrupted journal line ${i + 1}`);
      }
      this._apply(op);
      replayed++;
    }
    this.stats.replays++;
    return { replayed, tornTails: this.stats.tornTails };
  }

  _apply(op) {
    if (op.op === 'put') {
      this._col(op.col).set(op.key, op.val);
      this._indexPut(op.col, op.key, op.val);
      this.stats.ops++;
    } else if (op.op === 'del') {
      this._col(op.col).delete(op.key);
      this._indexDel(op.col, op.key);
      this.stats.ops++;
    }
  }

  // ------------------------------------------------------------- transactions

  async begin() {
    if (this.staged) throw new UTSDBError('transaction already open');
    this.staged = new Map();
    return this;
  }

  stagePut(col, key, val) { this._requireTx(); this.staged.set(`${col}|${key}`, { op: 'put', col, key, val }); }
  stageDelete(col, key) { this._requireTx(); this.staged.set(`${col}|${key}`, { op: 'del', col, key }); }

  _requireTx() { if (!this.staged) throw new UTSDBError('no transaction open'); }

  async commit() {
    this._requireTx();
    const ops = [...this.staged.values()];
    for (const op of ops) await this.journal.append(JSON.stringify(op));
    for (const op of ops) this._apply(op);
    this.staged = null;
    this.stats.txCommits++;
    return ops.length;
  }

  async rollback() {
    this._requireTx();
    this.staged = null;
    this.stats.txRollbacks++;
  }

  // ----------------------------------------------------------------- CRUD

  get(col, key) {
    if (this.staged?.has(`${col}|${key}`)) {
      const op = this.staged.get(`${col}|${key}`);
      return op.op === 'put' ? op.val : undefined;
    }
    return this._col(col).get(key);
  }

  async put(col, key, val) {
    await this.begin();
    this.stagePut(col, key, val);
    return this.commit();
  }

  async del(col, key) {
    await this.begin();
    this.stageDelete(col, key);
    return this.commit();
  }

  keys(col) {
    const base = [...this._col(col).keys()];
    if (!this.staged) return base.sort();
    for (const [opKey, op] of this.staged) {
      const [c, k] = opKey.split('|');
      if (c !== col) continue;
      if (op.op === 'put' && !base.includes(k)) base.push(k);
      if (op.op === 'del') { const i = base.indexOf(k); if (i >= 0) base.splice(i, 1); }
    }
    return base.sort();
  }

  // ---------------------------------------------------------------- indexes

  createIndex(col, field) {
    if (!this.indexes.has(col)) this.indexes.set(col, new Map());
    const idx = this.indexes.get(col).set(field, new Map()).get(field);
    for (const [key, val] of this._col(col)) {
      const fv = val?.[field];
      if (fv == null) continue;
      if (!idx.has(fv)) idx.set(fv, new Set());
      idx.get(fv).add(key);
    }
    return idx;
  }

  _indexPut(col, key, val) {
    const idxs = this.indexes.get(col);
    if (!idxs) return;
    for (const [field, idx] of idxs) {
      const fv = val?.[field];
      if (fv == null) continue;
      if (!idx.has(fv)) idx.set(fv, new Set());
      idx.get(fv).add(key);
    }
  }

  _indexDel(col, key) {
    const idxs = this.indexes.get(col);
    if (!idxs) return;
    for (const idx of idxs.values()) {
      for (const set of idx.values()) set.delete(key);
    }
  }

  findBy(col, field, value) {
    const idx = this.indexes.get(col)?.get(field);
    if (!idx) throw new UTSDBError(`no index on ${col}.${field} (createIndex first)`);
    return [...(idx.get(value) ?? [])];
  }

  // -------------------------------------------------------------- compaction

  /** rewrite the journal as a minimal snapshot; safe against torn tails */
  async compact() {
    const lines = [];
    for (const [col, map] of this.collections) {
      for (const [key, val] of map) lines.push(JSON.stringify({ op: 'put', col, key, val }));
    }
    await this.journal.replaceAll(lines);
    this.stats.compactions++;
    return { snapshotOps: lines.length };
  }

  // ----------------------------------------------------- StorageBackend adapter

  /** adapter so the whole platform (apps, projects, snapshots) runs on UTS-DB */
  asStorage(col = 'kv') {
    const db = this;
    return {
      async get(key) {
        const raw = db.get(col, key);
        return raw === undefined || raw === null ? null : raw;
      },
      async set(key, value) { await db.put(col, key, String(value)); },
      async delete(key) { await db.del(col, key); },
      async keys() { return db.keys(col); },
      db,
    };
  }

  report() {
    return {
      ...this.stats,
      collections: [...this.collections.entries()].map(([c, m]) => ({ col: c, keys: m.size })),
    };
  }
}
