/**
 * UTS · Singularity AI — Memory System.
 *
 * Tipos de memória estabelecidos (versão mais recente):
 *   message · conversation · short-term · long-term · user · project ·
 *   preferences · decisions
 *
 * Decisões implementam a regra "sempre a versão mais recente":
 *   setDecision(topic, value, supersedes) cria um histórico encadeado e
 *   decision(topic) sempre retorna a MAIS RECENTE.
 */

import { newId } from '../core/index.ts';

export type Role = 'user' | 'assistant' | 'system' | 'tool';

export interface MemMessage {
  id: string;
  convId: string;
  role: Role;
  content: string;
  at: number; // sim-time
}

export interface MemFact {
  key: string;
  value: unknown;
  importance: number; // 0..1
  at: number;
  lastAccess: number;
  accessCount: number;
}

export interface MemShortEntry {
  id: string;
  content: string;
  at: number;
  ttl: number; // segundos de sim
}

export interface MemDecision {
  id: string;
  topic: string;
  value: unknown;
  at: number;
  supersedes: string | null;
  note?: string;
}

const SHORT_RING = 256;
const LONG_CAP = 2000;
const DECISION_CAP = 64;

export class MemorySystem {
  user: Record<string, unknown> = {};
  project: Record<string, unknown> = {};
  preferences: Record<string, unknown> = {};

  private convs = new Map<string, MemMessage[]>();
  private shortTerm: MemShortEntry[] = [];
  private longTerm = new Map<string, MemFact>();
  private decisions = new Map<string, MemDecision[]>();

  /* ---------------- message / conversation ---------------- */

  message(convId: string, role: Role, content: string, at: number): MemMessage {
    const m: MemMessage = { id: newId('msg'), convId, role, content, at };
    let l = this.convs.get(convId);
    if (!l) this.convs.set(convId, (l = []));
    l.push(m);
    return m;
  }

  conversation(convId: string): MemMessage[] {
    return [...(this.convs.get(convId) ?? [])];
  }

  /* ---------------- short-term (ring com TTL) ---------------- */

  setShort(content: string, ttl: number, at: number): void {
    this.shortTerm.push({ id: newId('st'), content, at, ttl });
    if (this.shortTerm.length > SHORT_RING) this.shortTerm.splice(0, this.shortTerm.length - SHORT_RING);
  }

  /** Entradas ainda vivas no tempo `at`. */
  shortSince(at: number): MemShortEntry[] {
    return this.shortTerm.filter((e) => at - e.at <= e.ttl);
  }

  /* ---------------- long-term (chave + importância + decaimento) ---------------- */

  remember(key: string, value: unknown, importance = 0.5, at = 0): void {
    const prev = this.longTerm.get(key);
    this.longTerm.set(key, {
      key,
      value,
      importance: Math.max(prev?.importance ?? 0, importance),
      at: prev?.at ?? at,
      lastAccess: at,
      accessCount: (prev?.accessCount ?? 0) + 1,
    });
    if (this.longTerm.size > LONG_CAP) {
      // descarta a menos importante
      let worstKey: string | null = null;
      let worstImp = Infinity;
      for (const f of this.longTerm.values()) {
        if (f.importance < worstImp) {
          worstImp = f.importance;
          worstKey = f.key;
        }
      }
      if (worstKey) this.longTerm.delete(worstKey);
    }
  }

  recallFact(key: string, at = 0): MemFact | undefined {
    const f = this.longTerm.get(key);
    if (f) {
      f.lastAccess = at;
      f.accessCount += 1;
    }
    return f;
  }

  recallFacts(pred: (f: MemFact) => boolean): MemFact[] {
    return [...this.longTerm.values()].filter(pred);
  }

  forget(key: string): void {
    this.longTerm.delete(key);
  }

  /** Decaimento de importância por idade + acesso (memória viva). */
  decay(at: number, halfLife = 3600): void {
    for (const f of this.longTerm.values()) {
      const age = Math.max(0, at - f.lastAccess);
      f.importance *= Math.pow(0.5, age / halfLife);
    }
    for (const [k, f] of [...this.longTerm]) {
      if (f.importance < 0.02) this.longTerm.delete(k);
    }
  }

  /* ---------------- decisions (latest version wins) ---------------- */

  setDecision(topic: string, value: unknown, at: number, note?: string): MemDecision {
    const hist = this.decisions.get(topic) ?? [];
    const d: MemDecision = { id: newId('dec'), topic, value, at, supersedes: hist.length ? hist[hist.length - 1].id : null, note };
    hist.push(d);
    if (hist.length > DECISION_CAP) hist.splice(0, hist.length - DECISION_CAP);
    this.decisions.set(topic, hist);
    return d;
  }

  /** A versão MAIS RECENTE da decisão (regra central do projeto). */
  decision(topic: string): MemDecision | undefined {
    const h = this.decisions.get(topic);
    return h?.length ? h[h.length - 1] : undefined;
  }

  decisionHistory(topic: string): MemDecision[] {
    return [...(this.decisions.get(topic) ?? [])];
  }

  /* ---------------- introspecção ---------------- */

  stats(): { conversations: number; messages: number; shortTerm: number; longTerm: number; decisionTopics: number } {
    let messages = 0;
    for (const l of this.convs.values()) messages += l.length;
    return {
      conversations: this.convs.size,
      messages,
      shortTerm: this.shortTerm.length,
      longTerm: this.longTerm.size,
      decisionTopics: this.decisions.size,
    };
  }

  serialize(): unknown {
    return {
      user: this.user,
      project: this.project,
      preferences: this.preferences,
      conversations: [...this.convs.entries()],
      shortTerm: this.shortTerm,
      longTerm: [...this.longTerm.values()],
      decisions: [...this.decisions.entries()],
    };
  }

  /** Restaura um estado criado por `serialize()` (persistência). */
  load(data: {
    user?: Record<string, unknown>;
    project?: Record<string, unknown>;
    preferences?: Record<string, unknown>;
    conversations?: Array<[string, MemMessage[]]>;
    shortTerm?: MemShortEntry[];
    longTerm?: MemFact[];
    decisions?: Array<[string, MemDecision[]]>;
  }): void {
    this.user = { ...(data.user ?? {}) };
    this.project = { ...(data.project ?? {}) };
    this.preferences = { ...(data.preferences ?? {}) };
    this.convs.clear();
    for (const [id, list] of data.conversations ?? []) this.convs.set(id, [...list]);
    this.shortTerm = [...(data.shortTerm ?? [])];
    this.longTerm.clear();
    for (const f of data.longTerm ?? []) this.longTerm.set(f.key, { ...f });
    this.decisions.clear();
    for (const [topic, list] of data.decisions ?? []) this.decisions.set(topic, [...list]);
  }
}
