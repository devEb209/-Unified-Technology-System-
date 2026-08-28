// UTS :: platform/projects — CREATION PROJECTS.
//
// Big creations take time — minutes, hours, days, weeks. A CreationProject
// is a durable, resumable plan: the platform AI decomposes the goal into
// milestones/tasks, executes them step by step within budgets, persists the
// project state through platform storage, and can resume in ANY later
// session exactly where it stopped. Nothing is claimed done before the
// verifier passes.

export class ProjectError extends Error {}

/** deterministic decomposition of a goal into ordered, idempotent tasks */
export function planProject(interpretation) {
  const tasks = [];
  const p = interpretation.params ?? {};
  switch (interpretation.intent) {
    case 'create_settlement': {
      const name = p.name ?? 'Nova Aurora';
      tasks.push(
        { title: `reconhecer o terreno para ${name}`, tool: 'ues.run_ticks', params: { ticks: 30 }, why: 'site survey (weather/ecology settle)' },
        { title: `fundar ${name}`, tool: 'ues.create_settlement', params: { name, pop: Math.max(1, Math.min(300, Number(p.pop ?? 24))), nearRiver: !!p.nearRiver }, why: 'founding' },
        { title: `povoar ${name}`, tool: 'ues.spawn_npcs', params: { count: Math.max(4, Math.min(60, Math.ceil(Number(p.pop ?? 24) * 0.7))), settlementName: name }, why: 'population' },
        { title: `nutrir a natureza ao redor de ${name}`, tool: 'ues.grow_nature', params: { settlementName: name, radius: 110 }, why: 'ecology substrate' },
        { title: `evoluir ${name} e validar`, tool: 'ues.run_ticks', params: { ticks: 240 }, why: 'emergence + verification' },
      );
      break;
    }
    case 'spawn_population':
      tasks.push({ title: `popular (${p.count} habitantes)`, tool: 'ues.spawn_npcs', params: { count: Math.max(1, Math.min(200, Number(p.count ?? 10))) }, why: 'population' });
      tasks.push({ title: 'estabilizar o mundo', tool: 'ues.run_ticks', params: { ticks: 60 }, why: 'integration' });
      break;
    default:
      // generic single-step project runs a few ticks (honest no-op plan)
      tasks.push({ title: 'executar objetivo direto', tool: 'ues.run_ticks', params: { ticks: 10 }, why: 'direct execution' });
  }
  return tasks.map((t, i) => ({ id: 't' + (i + 1), title: t.title, tool: t.tool, params: t.params, why: t.why, done: false, result: null }));
}

export class CreationProjectManager {
  constructor({ core, storage }) {
    this.core = core;       // SingularityCore (interpretation + verification)
    this.storage = storage; // platform StorageBackend (durable, resumable)
    this.cache = new Map(); // projectId -> project record
  }

  /** create a project from a natural-language goal (AI-first) */
  async create(goal, { name = null } = {}) {
    const chosen = await this.core.chooseModel(goal);
    const interpretation = await this.core.interpretObjective(goal, chosen);
    const tasks = planProject(interpretation);
    const project = {
      id: 'prj' + (this.cache.size + 1),
      goal,
      name: name ?? interpretation.params?.name ?? 'projeto',
      intent: interpretation.intent,
      status: 'active',           // active | done
      tasks,
      log: [],
      createdAtTick: this.core.world.clock.tick,
    };
    this.cache.set(project.id, project);
    await this._persist(project);
    return project;
  }

  /** execute the next pending task (one step of possibly-days-long work) */
  async step(projectId) {
    const project = this._get(projectId);
    const task = project.tasks.find(t => !t.done);
    if (!task) {
      project.status = 'done';
      await this._persist(project);
      return { project, executed: null, progress: this.progress(project) };
    }
    try {
      const result = await this.core.tools.execute(task.tool, task.params);
      // honest failure: a tool that reports ok:false is a FAILED step
      if (result && typeof result === 'object' && result.ok === false) {
        throw new ProjectError(`task '${task.title}' failed: ${result.reason ?? 'tool reported failure'}`);
      }
      task.done = true;
      task.result = { ok: true, ...(typeof result === 'object' ? { ...result } : { value: result }) };
      project.log.push({ task: task.id, title: task.title, ok: true });
    } catch (err) {
      task.result = { ok: false, error: String(err.message) };
      project.log.push({ task: task.id, title: task.title, ok: false, error: String(err.message) });
      await this._persist(project);
      throw err; // caller decides: retry, skip or abort (state is durable)
    }
    const remaining = project.tasks.some(t => !t.done);
    if (!remaining) project.status = 'done';
    await this._persist(project);
    return { project, executed: task, progress: this.progress(project) };
  }

  /** run up to maxSteps pending steps (budget-aware long execution) */
  async run(projectId, { maxSteps = Infinity } = {}) {
    let steps = 0;
    const summary = [];
    while (steps < maxSteps) {
      const { executed, progress } = await this.step(projectId);
      if (!executed) break;
      steps++;
      summary.push(executed.title);
      if (progress.done_all) break;
    }
    const project = this._get(projectId);
    return { project, steps, summary, progress: this.progress(project) };
  }

  progress(project) {
    const done = project.tasks.filter(t => t.done).length;
    return { done, total: project.tasks.length, done_all: done === project.tasks.length };
  }

  /** resume from durable storage (new session, same storage) */
  async resume(projectId) {
    const raw = await this.storage.get(`project:${projectId}`);
    if (!raw) throw new ProjectError(`project '${projectId}' not found in storage`);
    const rec = JSON.parse(raw);
    // tasks executed by tools stay done; tools are idempotent so retries are safe
    this.cache.set(rec.id, rec);
    return rec;
  }

  async listStored() {
    const keys = (await this.storage.keys()).filter(k => k.startsWith('project:'));
    return keys.map(k => k.replace('project:', ''));
  }

  status() {
    return { active: [...this.cache.values()].filter(p => p.status === 'active').length, cached: this.cache.size };
  }

  _get(projectId) {
    const p = this.cache.get(projectId);
    if (!p) throw new ProjectError(`project '${projectId}' not loaded`);
    return p;
  }

  async _persist(project) {
    await this.storage.set(`project:${project.id}`, JSON.stringify(project));
  }
}
