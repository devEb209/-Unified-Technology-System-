// UTS :: net/sync — AUTHORITATIVE state sync on top of the raw transport:
// the server's world is the ONE truth; deltas cross the wire with a
// sequence number. Gaps and replays are HONEST errors (never silent
// divergence): seq must be exactly lastSeq+1 (or a replay, ignored).
// Byte-equality test proves two sides converge to the SAME state.

/** encode one authoritative delta {seq, state} as wire bytes */
export function encodeDelta(seq, state) {
  return JSON.stringify({ v: 1, seq, state });
}

/**
 * Apply a delta to the client state. Rules (all honest):
 *  - exact next seq → merge (shallow) and advance;
 *  - seq ≤ lastSeq  → replay/old, IGNORED (idempotent), reports {applied:false};
 *  - gap            → THROW (the client asks for a full snapshot, never guesses).
 */
export function applyDelta(client, wire, lastSeq) {
  const d = typeof wire === 'string' ? JSON.parse(wire) : wire;
  if (d.v !== 1) throw new Error(`sync: versão desconhecida v=${d.v}`);
  if (d.seq <= lastSeq) return { applied: false, lastSeq, reason: 'replay/antigo (ignorado — idempotente)' };
  if (d.seq > lastSeq + 1) throw new Error(`sync: GAP — recebi seq ${d.seq}, esperava ${lastSeq + 1} (peça snapshot completo)`);
  Object.assign(client, d.state);
  return { applied: true, lastSeq: d.seq };
}

/**
 * DeltaStream: the server-side sequence authority. Every broadcast gets
 * the next seq; history keeps the last deltas (a reconnecting client can
 * request a full snapshot by seq).
 */
export class DeltaStream {
  constructor({ history = 50 } = {}) {
    this.lastSeq = 0;
    this.history = [];
    this.historyCap = history;
  }

  /** next authoritative delta for the given state slice */
  encode(state) {
    this.lastSeq += 1;
    const wire = encodeDelta(this.lastSeq, state);
    this.history.push({ seq: this.lastSeq, bytes: wire.length });
    if (this.history.length > this.historyCap) this.history.shift();
    return wire;
  }

  /** feed one client's mirror; returns its lastSeq (per-client bookkeeping outside) */
  static feed(client, wire, lastSeq) {
    return applyDelta(client, wire, lastSeq);
  }
}
