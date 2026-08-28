// UTS :: platform/apps — AppHost: APPLICATIONS are first-class citizens of
// the PLATFORM. Not everything is a world: tools, dashboards, utilities and
// any computationally viable app run here, on platform infrastructure
// (storage + events + AI), independent of the UES engine.
//
// App kinds are an OPEN registry. An app kind defines:
//   setup(ctx)                 -> initial plain-data state
//   reduce(state, action, p)   -> { state, event? }  (pure, deterministic)
//   view(state)                -> renderable view model
// State persists through the platform StorageBackend (survives restarts).

export class AppError extends Error {}

export function builtinAppKinds() {
  return new Map([
    ['tasks', {
      desc: 'task list app',
      setup: () => ({ items: [], nextId: 1 }),
      reduce: (state, action, payload = {}) => {
        switch (action) {
          case 'add': {
            const text = String(payload.text ?? '').slice(0, 140);
            if (!text) throw new AppError('task text required');
            const s = structuredClone(state);
            s.items.push({ id: s.nextId++, text, done: false });
            return { state: s, event: 'app.task.added' };
          }
          case 'toggle': {
            const s = structuredClone(state);
            const it = s.items.find(i => i.id === payload.id);
            if (!it) throw new AppError(`task ${payload.id} not found`);
            it.done = !it.done;
            return { state: s, event: 'app.task.toggled' };
          }
          case 'remove': {
            const s = structuredClone(state);
            const before = s.items.length;
            s.items = s.items.filter(i => i.id !== payload.id);
            if (s.items.length === before) throw new AppError(`task ${payload.id} not found`);
            return { state: s, event: 'app.task.removed' };
          }
          default:
            throw new AppError(`unknown action '${action}' for tasks`);
        }
      },
      view: (state) => ({
        kind: 'tasks',
        total: state.items.length,
        done: state.items.filter(i => i.done).length,
        items: state.items.map(i => ({ id: i.id, text: i.text, done: i.done })),
      }),
    }],
    ['counter', {
      desc: 'minimal counter app (canonical example)',
      setup: () => ({ value: 0 }),
      reduce: (state, action, payload = {}) => {
        switch (action) {
          case 'increment': return { state: { ...state, value: state.value + 1 }, event: 'app.counter.incremented' };
          case 'decrement': return { state: { ...state, value: state.value - 1 }, event: 'app.counter.decremented' };
          case 'set': return { state: { ...state, value: Math.trunc(Number(payload.value ?? 0)) }, event: 'app.counter.set' };
          default: throw new AppError(`unknown action '${action}' for counter`);
        }
      },
      view: (state) => ({ kind: 'counter', value: state.value }),
    }],
  ]);
}

export class AppHost {
  constructor({ storage, bus = null, kinds = null } = {}) {
    this.name = 'apps';
    this.storage = storage;
    this.bus = bus;
    this.kinds = kinds ?? builtinAppKinds();
    this.apps = new Map(); // id -> {id, name, kind, state}
    this.nextId = 1;
  }

  registerKind(name, def) {
    if (typeof def.setup !== 'function' || typeof def.reduce !== 'function' || typeof def.view !== 'function') {
      throw new AppError(`app kind '${name}' needs setup/reduce/view`);
    }
    this.kinds.set(name, def);
  }

  async install({ kind, name }) {
    const def = this.kinds.get(kind);
    if (!def) throw new AppError(`unknown app kind '${kind}' (available: ${[...this.kinds.keys()].join(', ')})`);
    const id = 'app' + this.nextId++;
    const app = { id, name: String(name ?? kind).slice(0, 40), kind, state: structuredClone(def.setup()) };
    this.apps.set(id, app);
    await this._persist(app);
    this.bus?.emit('platform.app.installed', { id, kind, name: app.name });
    return { id, kind, name: app.name };
  }

  async act(appId, action, payload) {
    const app = this.apps.get(appId);
    if (!app) throw new AppError(`app ${appId} not installed`);
    const def = this.kinds.get(app.kind);
    const { state, event } = def.reduce(app.state, action, payload);
    app.state = state;
    await this._persist(app);
    if (event) this.bus?.emit(event, { appId });
    return this.view(appId);
  }

  view(appId) {
    const app = this.apps.get(appId);
    if (!app) throw new AppError(`app ${appId} not installed`);
    return this.kinds.get(app.kind).view(app.state);
  }

  list() {
    return [...this.apps.values()].map(a => ({ id: a.id, name: a.name, kind: a.kind }));
  }

  status() {
    return { apps: this.apps.size, kinds: [...this.kinds.keys()] };
  }

  async _persist(app) {
    await this.storage.set(`app:${app.id}`, JSON.stringify({ id: app.id, name: app.name, kind: app.kind, state: app.state, nextId: this.nextId }));
  }

  /** reload every persisted app (platform restart) — state survives */
  async boot() {
    const keys = (await this.storage.keys()).filter(k => k.startsWith('app:'));
    let maxId = 0;
    for (const key of keys) {
      const raw = await this.storage.get(key);
      let rec;
      try {
        rec = JSON.parse(raw);
      } catch {
        throw new AppError(`corrupted app state at ${key}`);
      }
      if (!this.kinds.has(rec.kind)) throw new AppError(`app kind '${rec.kind}' has no registered implementation`);
      this.apps.set(rec.id, { id: rec.id, name: rec.name, kind: rec.kind, state: rec.state });
      const n = parseInt(String(rec.id).replace(/\D/g, ''), 10) || 0;
      if (n > maxId) maxId = n;
    }
    this.nextId = Math.max(this.nextId, maxId + 1);
    return this.apps.size;
  }
}
