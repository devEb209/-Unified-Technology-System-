// UTS :: singularity/core — SingularityCore.
//
// The orchestration nucleus of Singularity AI:
//   objective -> interpretation -> decomposition (Tese dos D) ->
//   agent/model/tool selection -> execution -> verification ->
//   correction -> memory.
//
// The Core NEVER depends on one vendor. Model selection is capability+cost
// driven with real availability checks and fallback chains. The LLM is a
// capability the system USES — not the architecture itself.

import { ModelRegistry } from './models.js';
import { AgentRegistry, builtinAgents } from './agents.js';
import { ToolRegistry, builtinTools, ToolValidationError } from './tools.js';
import { parseCreation } from './grammar.js';
import { MemorySystem } from './memory.js';
import { registerPlatformTools } from './platform-tools.js';

const INTENTS = ['create_settlement', 'set_weather', 'spawn_population', 'start_fire', 'focus_camera', 'unknown'];

export class SingularityCore {
  constructor({ ues, world, rrw, providers, models = null, memory = null, log = null, platform = null }) {
    this.ues = ues;
    this.world = world;
    this.rrw = rrw;
    this.log = log;
    this.platform = platform;        // UTS platform (services, apps, projects) — optional until attached
    this.providers = providers;      // ProviderRegistry
    this.models = models ?? new ModelRegistry();
    this.agents = new AgentRegistry();
    for (const a of builtinAgents({ core: this })) this.agents.register(a);
    this.memory = memory ?? new MemorySystem();
    this.tools = builtinTools({ ues, world, rrw, core: this });
    if (platform) registerPlatformTools(this);
    this.lastReport = null;
  }

  // ------------------------------------------------------------ interpretation

  _interpretationMessages(objective, errorHint = null) {
    const sys = {
      role: 'system',
      content:
        'You are the interpreter of the UTS Singularity Core. ' +
        'Convert the user objective into STRICT JSON: ' +
        '{"intent":"create_settlement|set_weather|spawn_population|start_fire|focus_camera|unknown",' +
        '"params":{...}}. Intents: create_settlement{name,pop,nearRiver}, set_weather{weather:clear|cloudy|rain|storm|windy|dust}, ' +
        'spawn_population{count}, start_fire{}, focus_camera{settlementName?}. JSON only.',
    };
    const msgs = [sys, { role: 'user', content: objective }];
    if (errorHint) msgs.push({ role: 'user', content: `Your previous answer was invalid (${errorHint}). Answer with the STRICT JSON schema again.` });
    return msgs;
  }

  _validInterpretation(json) {
    if (!json || typeof json !== 'object') return null;
    if (!INTENTS.includes(json.intent)) return null;
    if (!json.params || typeof json.params !== 'object') return null;
    return { intent: json.intent, params: json.params };
  }

  async interpretObjective(objective, chosen, { maxCorrections = 2 } = {}) {
    let errorHint = null;
    for (let attempt = 0; attempt <= maxCorrections; attempt++) {
      let res;
      try {
        res = await chosen.provider.generate({
          messages: this._interpretationMessages(objective, errorHint),
          model: chosen.model?.id,
          json: true,
        });
      } catch (err) {
        // provider failed -> the Core stays in control: fallback chain
        return this._fallbackInterpretation(objective, `${chosen.provider.name} failed: ${err.message}`);
      }
      const valid = this._validInterpretation(res.json);
      if (valid) return { ...valid, provider: chosen.provider.name, model: chosen.model?.id ?? null, corrections: attempt };
      errorHint = res.json ? 'schema mismatch' : 'not JSON';
    }
    return this._fallbackInterpretation(objective, 'invalid answers exhausted');
  }

  _fallbackInterpretation(objective, reason) {
    const heuristic = this.providers.get('heuristic');
    if (heuristic) {
      return heuristic.generate({ messages: [{ role: 'user', content: objective }] }).then(res => ({
        intent: res.json.intent, params: res.json.params, provider: 'heuristic', model: 'heuristic-core', corrections: -1, fallbackReason: reason,
      }));
    }
    return Promise.resolve({ intent: 'unknown', params: {}, provider: null, model: null, fallbackReason: reason });
  }

  // -------------------------------------------------------------- model chain

  async chooseModel(objective, { preferredProvider = null } = {}) {
    const needs = { structured: true, reasoning: /por que|why|analy|estrateg|plan|proj/.test(objective.toLowerCase()) };
    let candidates = this.models.select(needs);
    if (preferredProvider) {
      const hit = candidates.find(c => c.provider === preferredProvider);
      if (hit) candidates = [hit, ...candidates];
    }
    for (const model of candidates) {
      const provider = this.providers.get(model.provider);
      if (!provider) continue;
      try {
        if (await provider.availability()) return { model, provider };
      } catch { /* try next */ }
    }
    const heuristicProvider = this.providers.get('heuristic');
    const heuristicModel = this.models.get('heuristic-core');
    if (!heuristicProvider || !heuristicModel) throw new Error('no provider available (heuristic fallback missing)');
    return { model: heuristicModel, provider: heuristicProvider };
  }

  // -------------------------------------------------------------------- plan

  /** deterministic decomposition — the Tese dos D applied to objectives.
   *  R5: the CREATION GRAMMAR may yield a LIST of commands; each becomes a
   *  task in causal order (anchors before neighbors, world before camera). */
  planFromInterpretation(interpretation) {
    if (Array.isArray(interpretation.commands) && interpretation.commands.length > 0) {
      const tasks = [];
      let settlementIdx = 0;
      let ecologyBefore = null;
      for (const cmd of interpretation.commands) {
        switch (cmd.intent) {
          case 'create_settlement': {
            settlementIdx++;
            tasks.push({
              tool: 'ues.create_settlement',
              params: {
                name: cmd.params.name ?? `Nova Aurora ${settlementIdx}`,
                pop: Math.max(1, Math.min(300, Number(cmd.params.pop ?? 24))),
                nearRiver: !!cmd.params.nearRiver,
                ...(cmd.params.pos ? { pos: cmd.params.pos } : {}),
                ...(cmd.params.nearName ? { nearName: cmd.params.nearName } : {}),
                ...(cmd.params.dir ? { dir: cmd.params.dir } : {}),
                ...(cmd.params.of ? { of: cmd.params.of } : {}),
              },
              capability: 'world',
              reason: `grammar command from: "${cmd.source}"`,
            });
            break;
          }
          case 'plant_forest': {
            if (ecologyBefore == null) ecologyBefore = this.world.ecology.aliveCount();
            tasks.push({
              tool: 'world.plant_forest',
              params: { count: Math.max(1, Math.min(200, Number(cmd.params.count ?? 40))) },
              capability: 'world',
              reason: `grammar command from: "${cmd.source}"`,
            });
            break;
          }
          case 'set_weather':
            tasks.push({ tool: 'world.set_weather', params: { weather: cmd.params.weather }, capability: 'world', reason: `grammar command from: "${cmd.source}"` });
            break;
          case 'spawn_population':
            tasks.push({ tool: 'ues.spawn_npcs', params: { count: Math.max(1, Math.min(200, Number(cmd.params.count ?? 10))), ...(cmd.params.settlementName ? { settlementName: cmd.params.settlementName } : {}) }, capability: 'world', reason: `grammar command from: "${cmd.source}"` });
            break;
          case 'start_fire':
            tasks.push({ tool: 'world.start_fire', params: cmd.params ?? {}, capability: 'world', reason: `grammar command from: "${cmd.source}"` });
            break;
          case 'focus_camera':
            tasks.push({ tool: 'ues.focus_camera', params: cmd.params ?? {}, capability: 'world', reason: `grammar command from: "${cmd.source}"` });
            break;
          default:
            break; // unknown commands NEVER become tasks (no unsafe state)
        }
      }
      const plan = { intent: interpretation.commands[0].intent, tasks, grammar: true, commands: interpretation.commands.length };
      if (ecologyBefore != null) plan.ecologyBefore = ecologyBefore;
      return plan;
    }
    const tasks = [];
    switch (interpretation.intent) {
      case 'create_settlement': {
        tasks.push({
          tool: 'ues.create_settlement',
          params: {
            name: interpretation.params.name ?? 'Nova Aurora',
            pop: Math.max(1, Math.min(300, Number(interpretation.params.pop ?? 24))),
            nearRiver: !!interpretation.params.nearRiver,
          },
          capability: 'world',
          reason: 'found the settlement requested by the objective',
        });
        tasks.push({
          tool: 'ues.focus_camera',
          params: { settlementName: interpretation.params.name ?? '' },
          capability: 'world',
          reason: 'focus the new reality (camera/focus feeds materialization)',
        });
        break;
      }
      case 'set_weather':
        tasks.push({
          tool: 'world.set_weather',
          params: { weather: interpretation.params.weather },
          capability: 'world',
          reason: 'change the represented weather through the causal chain',
        });
        break;
      case 'spawn_population':
        tasks.push({
          tool: 'ues.spawn_npcs',
          params: { count: Math.max(1, Math.min(200, Number(interpretation.params.count ?? 10))) },
          capability: 'world',
          reason: 'populate the reality',
        });
        break;
      case 'start_fire':
        tasks.push({ tool: 'world.start_fire', params: {}, capability: 'world', reason: 'ignite a hazard to observe emergence' });
        break;
      case 'focus_camera':
        tasks.push({ tool: 'ues.focus_camera', params: interpretation.params, capability: 'world', reason: 'point focus' });
        break;
      default:
        break; // unknown -> no unsafe tasks (free text never mutates state)
    }
    return { intent: interpretation.intent, tasks };
  }

  // ----------------------------------------------------------------- verify

  verifyPlan(plan) {
    const checks = [];
    (plan.tasks ?? []).forEach((task, taskIndex) => {
      const add = (check, ok, detail) => checks.push({ taskIndex, check, ok, detail });
      if (task.tool === 'ues.create_settlement') {
        const id = this.rrw.query({ kind: 'settlement', predicate: e => e.name === task.params.name })[0];
        const s = id ? this.rrw.getComponent(id, 'settlement') : null;
        add('settlement.exists', !!id, id ?? task.params.name);
        add('settlement.populated', !!s && s.pop > 0, s?.pop ?? 0);
        add(
          'settlement.onLand',
          !!id && this.world.terrain.height(this.rrw.getComponent(id, 'spatial').pos[0], this.rrw.getComponent(id, 'spatial').pos[2]) >= this.world.terrain.seaLevel,
          id,
        );
      }
      if (task.tool === 'world.set_weather') {
        add('weather.applied', this.world.environment.weather === task.params.weather, this.world.environment.weather);
        add(
          'weather.causalChain',
          (() => { const ev = this.world.environment.lastWeatherEventId; return ev ? this.rrw.verifyCausalChain(ev).valid : false; })(),
          this.world.environment.lastWeatherEventId,
        );
      }
      if (task.tool === 'ues.spawn_npcs') {
        add('npcs.spawned', this.rrw.count('npc') >= (task.params.count ?? 1), this.rrw.count('npc'));
      }
      if (task.tool === 'world.start_fire') {
        add('fire.exists', this.rrw.count('hazard') > 0, this.rrw.count('hazard'));
      }
      if (task.tool === 'world.plant_forest') {
        // REAL verification: the population GREW (trees exist as individuals)
        const baseline = plan.ecologyBefore ?? 0;
        add('forest.grew', this.world.ecology.aliveCount() > baseline,
          `${baseline} -> ${this.world.ecology.aliveCount()}`);
      }
    });
    return checks;
  }

  // -------------------------------------------------------------- main flow

  /** R5: attachments are VALIDATED context — kinds text/csv/image, size-capped.
   *  Images are honestly recorded as NOT seen (offline providers are vision:false). */
  validateAttachments(attachments = []) {
    const out = [];
    for (const att of attachments) {
      const kind = att.kind ?? 'text';
      if (!['text', 'csv', 'image'].includes(kind)) throw new Error(`attachment kind '${kind}' not supported`);
      const name = String(att.name ?? 'anexo').slice(0, 80);
      const content = att.content != null ? String(att.content) : '';
      if (content.length > 65536) throw new Error(`attachment '${name}' exceeds 64KB`);
      out.push({ name, kind, content, seen: kind !== 'image' });
    }
    return out;
  }

  async processObjective(objective, { preferredProvider = null, attachments = [] } = {}) {
    const memory = this.memory;
    const validated = this.validateAttachments(attachments);
    const attNote = validated.length
      ? ` [anexos: ${validated.map(a => `${a.name}(${a.kind}${a.seen ? '' : ', não visto'})`).join(', ')}]`
      : '';
    memory.addMessage('user', objective + attNote);
    const startedProviders = this.providers.names();

    // 1) model + provider (capability/cost driven, with availability checks)
    const chosen = await this.chooseModel(objective, { preferredProvider });

    // 2) interpretation (correction loop + heuristic fallback), then the
    //    CREATION GRAMMAR augments/overrides when it captures MORE of the
    //    objective (multi-command) or the provider guessed 'unknown'.
    let interpretation = await this.interpretObjective(objective, chosen);
    const parsed = parseCreation(objective, { attachments: validated });
    if (parsed.commands.length > 0 && (interpretation.intent === 'unknown' || parsed.commands.length > 1)) {
      interpretation = {
        intent: parsed.commands[0].intent,
        params: parsed.commands[0].params,
        commands: parsed.commands,
        unknown: parsed.unknown,
        grammar: true,
        provider: interpretation.provider,
      };
    }

    // 3) decomposition (planning through the agent specialized in architecture)
    const architect = this.agents.select(['architecture']);
    const plan = architect
      ? await architect.execute({ interpretation }, { core: this, tools: this.tools, ues: this.ues })
      : this.planFromInterpretation(interpretation);

    // 4) execution via specialized agents + validated tools
    const executed = [];
    for (const task of plan.tasks) {
      const agent = this.agents.select([task.capability ?? 'world']);
      try {
        const result = await agent.execute(task, { core: this, tools: this.tools, ues: this.ues, world: this.world });
        executed.push({ task, agent: agent.name, result });
      } catch (err) {
        executed.push({ task, agent: agent?.name ?? 'none', error: err.message });
      }
    }

    // 5) verification — targeted corrective pass (only tasks with failed checks)
    let verifications = await this.verifyPlan(plan);
    let corrections = 0;
    if (plan.tasks.length > 0 && verifications.some(v => !v.ok) && corrections < 1) {
      corrections++;
      const failedIdx = new Set(verifications.filter(v => !v.ok).map(v => v.taskIndex));
      for (const [i, task] of plan.tasks.entries()) {
        if (!failedIdx.has(i)) continue;
        const agent = this.agents.select([task.capability ?? 'world']);
        try {
          const result = await agent.execute(task, { core: this, tools: this.tools, ues: this.ues });
          executed.push({ task, agent: agent.name, result, corrective: true });
        } catch (err) {
          executed.push({ task, agent: agent?.name ?? 'none', error: err.message, corrective: true });
        }
        verifications = await this.verifyPlan(plan);
      }
    }

    const ok = plan.intent !== 'unknown' && verifications.every(v => v.ok);
    const report = {
      ok,
      objective,
      providersConsidered: startedProviders,
      chosen: { provider: chosen.provider.name, model: chosen.model.id },
      interpretation,
      plan,
      executed,
      verifications,
      corrections,
      toolErrors: executed.filter(e => e.error).length,
      attachments: validated.map(a => ({ name: a.name, kind: a.kind, seen: a.seen })),
    };

    // 6) memory — decisions and project state persist (never secrets: only names)
    memory.decide({
      at: this.world.clock.tick,
      objective,
      intent: interpretation.intent,
      ok,
      provider: chosen.provider.name,
      model: chosen.model.id,
      corrections,
    });
    memory.rememberShort({ kind: 'objective', objective, ok });
    if (interpretation.intent === 'create_settlement' && ok) {
      memory.rememberLong('settlements', [...(memory.recallLong('settlements') ?? []), interpretation.params?.name]);
      memory.setProject('lastSettlement', interpretation.params?.name);
    }
    memory.addMessage('assistant', JSON.stringify({ ok, intent: interpretation.intent }));
    this.lastReport = report;
    this.log?.info(`objective '${objective}' -> ${interpretation.intent} ok=${ok}`, { provider: chosen.provider.name });
    return report;
  }
}

export { ToolValidationError };
