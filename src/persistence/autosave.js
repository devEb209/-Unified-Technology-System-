// UTS :: persistence/autosave — OUR checkpoint journaling system.
//
//   simulation → autosave.shouldSave(tick) → host awaits save()
//   → serializeState (checksum) → gzip (OS layer) → UTS-DB tx → journal
//
// The UTS-DB journal IS the event sourcing of saves: every checkpoint is an
// atomic, replayable, crash-safe record. Recovery walks newest → oldest: a
// corrupt checkpoint is stepped over LOUDLY (recorded in `skipped`, reason
// logged) — silence about lost state is a bug. Zero valid checkpoints is a
// loud SnapshotError. Retention keeps the newest `keep` checkpoints plus
// every `stride`-th generation anchor, so history is never all-or-nothing.
//
// Honest scope: checkpoints are full compressed states (RRW is the single
// source of truth; gzip + retention make the cost incremental). Per-entity
// delta streams (RRW event tail) are the next frontier, not silently claimed.
// gzip/zlib is the OS layer (ADR-018: inevitable, behind OUR api).
//
// Scheduling (rule 9): the SIMULATION only polls `shouldSave` (sync, free);
// the actual save runs in the host between ticks — persistence never blocks
// or degrades a tick, and world determinism is untouched (checkpoints are
// presentation-of-state, like frames).

import { gzipSync, gunzipSync } from 'node:zlib';
import { fnv1a } from '../core/math.js';
import { serializeState, load, SnapshotError } from './snapshot.js';
import { MemoryStorage } from './storage.js';

export class AutosaveError extends Error {}

const genOf = (tick) => `cp:${tick}`;

export class AutosaveManager {
  constructor(uts, db, { col = 'checkpoints', everyTicks = 300, keep = 5, stride = 3 } = {}) {
    this.uts = uts;
    this.db = db;
    this.col = col;
    this.everyTicks = everyTicks;
    this.keep = keep;
    this.stride = stride;
    this.lastSavedTick = null;
    this.pending = false;
    this.stats = { saves: 0, recovers: 0, skippedCorrupt: 0, bytesRaw: 0, bytesGz: 0, lastMs: 0, lastRatio: 0 };
  }

  /** sync, free, tick-side: did we cross the next checkpoint boundary? */
  shouldSave(tick = this.uts.world.clock.tick) {
    if (this.lastSavedTick == null) return tick >= this.everyTicks;
    return tick - this.lastSavedTick >= this.everyTicks;
  }

  /** host-side (between ticks): write ONE atomic compressed checkpoint */
  async save() {
    const tick = this.uts.world.clock.tick;
    const t0 = (typeof performance !== 'undefined' && performance.now) ? performance.now() : Date.now();
    // same envelope contract as snapshot.save() — createdAt stays null so the
    // checksum is deterministic (wall time is never part of reality)
    const state = serializeState(this.uts);
    const body = JSON.stringify({
      schemaVersion: state.schemaVersion,
      engineVersion: state.engineVersion,
      checksum: fnv1a(JSON.stringify(state)),
      state,
    });
    const gz = gzipSync(Buffer.from(body, 'utf8'));
    const data = gz.toString('base64');
    await this.db.put(this.col, genOf(tick), {
      tick, algo: 'gzip', data, sum: fnv1a(data), schemaVersion: state.schemaVersion,
    });
    this.lastSavedTick = tick;
    this.stats.saves++;
    this.stats.bytesRaw += Buffer.byteLength(body);
    this.stats.bytesGz += gz.byteLength;
    this.stats.lastMs = (typeof performance !== 'undefined' && performance.now) ? performance.now() - t0 : 0;
    this.stats.lastRatio = gz.byteLength > 0 ? Buffer.byteLength(body) / gz.byteLength : 1;
    await this._retain();
    return { tick, bytes: gz.byteLength, ratio: this.stats.lastRatio, ms: this.stats.lastMs };
  }

  /** newest → oldest; the FIRST checkpoint that verifies wins; corruption is loud */
  async recover() {
    const ticks = (await this.db.keys(this.col))
      .map(k => Number(k.slice(3)))
      .sort((a, b) => b - a);
    if (ticks.length === 0) throw new AutosaveError('no checkpoints in the journal');
    const skipped = [];
    for (const tick of ticks) {
      const rec = await this.db.get(this.col, genOf(tick));
      try {
        if (!rec || rec.algo !== 'gzip' || typeof rec.data !== 'string') throw new Error('malformed record');
        if (fnv1a(rec.data) !== rec.sum) throw new Error('checksum mismatch');
        const json = gunzipSync(Buffer.from(rec.data, 'base64')).toString('utf8');
        // full pipeline: integrity + migration + RRW validation (loud on purpose)
        const shim = new MemoryStorage();
        await shim.set('cp', json);
        const uts = await load(shim, 'cp');
        this.stats.recovers++;
        this.lastSavedTick = tick;
        return { uts, restoredTick: tick, skipped };
      } catch (err) {
        skipped.push({ tick, reason: String(err.message ?? err) });
        this.stats.skippedCorrupt++;
      }
    }
    throw new SnapshotError(`all ${ticks.length} checkpoint(s) are corrupt — nothing to recover`);
  }

  /** keep newest `keep` + every `stride`-th generation (history anchors) */
  async _retain() {
    const ticks = (await this.db.keys(this.col)).map(k => Number(k.slice(3))).sort((a, b) => a - b);
    const gens = ticks.map((t, i) => ({ t, i }));
    const doomed = gens.filter(({ i }) => i < gens.length - this.keep && i % this.stride !== 0);
    for (const { t } of doomed) await this.db.del(this.col, genOf(t));
    return { kept: gens.length - doomed.length, dropped: doomed.length };
  }
}

/** convenience: manager + a one-call host helper (poll in the loop, never inside a tick) */
export function createAutosave(uts, db, opts = {}) {
  const mgr = new AutosaveManager(uts, db, opts);
  mgr.maybeSave = async (tick = uts.world.clock.tick) => {
    if (mgr.shouldSave(tick)) return mgr.save();
    return null;
  };
  return mgr;
}
