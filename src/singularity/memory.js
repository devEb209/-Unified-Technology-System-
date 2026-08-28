// UTS :: singularity/memory — MemorySystem.
// message / conversation / short-term / long-term / user preferences /
// project / decisions — continuity and understanding of project state.
// Snapshots NEVER contain provider secrets (providers mask; core stores names).

export class MemorySystem {
  constructor() {
    this.messages = [];
    this.conversations = new Map();
    this.shortTerm = [];
    this.longTerm = new Map();
    this.decisions = [];
    this.preferences = new Map();
    this.project = new Map();
    this.nextMessageId = 1;
    this.nextConversationId = 1;
  }

  addMessage(role, content, meta = {}) {
    const msg = { id: 'm' + this.nextMessageId++, role, content, meta, at: null };
    this.messages.push(msg);
    if (this.messages.length > 500) this.messages.shift();
    return msg;
  }

  newConversation(title) {
    const id = 'c' + this.nextConversationId++;
    this.conversations.set(id, { id, title, messages: [] });
    return id;
  }

  addMessageToConversation(convId, role, content) {
    const conv = this.conversations.get(convId);
    if (!conv) throw new Error(`unknown conversation ${convId}`);
    const msg = this.addMessage(role, content);
    conv.messages.push(msg.id);
    return msg;
  }

  rememberShort(item) {
    this.shortTerm.push({ ...item });
    if (this.shortTerm.length > 32) this.shortTerm.shift();
  }

  rememberLong(key, value) { this.longTerm.set(key, value); }
  recallLong(key) { return this.longTerm.get(key) ?? null; }

  setPreference(key, value) { this.preferences.set(key, value); }
  getPreference(key) { return this.preferences.get(key) ?? null; }

  setProject(key, value) { this.project.set(key, value); }
  getProject(key) { return this.project.get(key) ?? null; }

  decide(record) {
    this.decisions.push({ ...record });
    if (this.decisions.length > 128) this.decisions.shift();
  }

  recall({ role = null, contains = null, limit = 20 } = {}) {
    let out = this.messages;
    if (role) out = out.filter(m => m.role === role);
    if (contains) out = out.filter(m => String(m.content).toLowerCase().includes(String(contains).toLowerCase()));
    return out.slice(-limit);
  }

  snapshot() {
    return {
      messages: this.messages,
      conversations: [...this.conversations.entries()],
      shortTerm: this.shortTerm,
      longTerm: [...this.longTerm.entries()],
      decisions: this.decisions,
      preferences: [...this.preferences.entries()],
      project: [...this.project.entries()],
      counters: { message: this.nextMessageId, conversation: this.nextConversationId },
    };
  }

  restore(s) {
    this.messages = s.messages ?? [];
    this.conversations = new Map(s.conversations ?? []);
    this.shortTerm = s.shortTerm ?? [];
    this.longTerm = new Map(s.longTerm ?? []);
    this.decisions = s.decisions ?? [];
    this.preferences = new Map(s.preferences ?? []);
    this.project = new Map(s.project ?? []);
    this.nextMessageId = s.counters?.message ?? this.messages.length + 1;
    this.nextConversationId = s.counters?.conversation ?? this.conversations.size + 1;
  }
}
