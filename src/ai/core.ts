/**
 * UTS · Singularity Core — núcleo de orquestração.
 *
 * Fluxo (Prompt 4/8):
 *   OBJETIVO → INTERPRETAÇÃO → PLANEJAMENTO → MODELO → AGENTE →
 *   FERRAMENTA → EXECUÇÃO → VERIFICAÇÃO → CORREÇÃO (fallback).
 *
 * Independente de modelo/provedor: o Core seleciona provider/modelo/
 * agente/ferramenta por tarefa. Correção é limitada (bounded) e registra
 * tudo na memória (conversação + decisões + fatos longos).
 */

import { Logger, Rng, newId } from '../core/index.ts';
import type { WorldAdapter } from '../contracts.ts';
import { MemorySystem } from './memory.ts';
import { AgentRegistry, ModelRegistry, ProviderRegistry, ToolRegistry } from './registries.ts';
import type { AgentTask } from './registries.ts';

/* ------------------------------------------------------------------ */
/* Tipos                                                               */
/* ------------------------------------------------------------------ */

export interface Goal {
  raw: string;
  /** Tipo interpretado (build-world, build-scene, optimize, inspect, generic). */
  type?: string;
  params?: Record<string, unknown>;
}

export interface StepReport {
  id: string;
  agent: string;
  action: string;
  modelId: string;
  ok: boolean;
  attempts: number;
  data: Record<string, unknown>;
  issues: string[];
}

export interface ExecutionReport {
  goalId: string;
  goal: string;
  goalType: string;
  status: 'success' | 'partial' | 'failed';
  steps: StepReport[];
  corrections: number;
  modelsUsed: string[];
  durationMs: number;
  summary: string;
}

export interface CoreContext {
  world: WorldAdapter;
  rng: Rng;
  now: number;
}

export interface CoreOptions {
  models: ModelRegistry;
  providers: ProviderRegistry;
  tools: ToolRegistry;
  agents: AgentRegistry;
  memory: MemorySystem;
  log?: Logger;
  /** Máximo de tentativas por etapa (correção limitada). */
  maxAttempts?: number;
}

/* ------------------------------------------------------------------ */
/* Interpretação de objetivos                                          */
/* ------------------------------------------------------------------ */

const BIOME_ALIASES: Record<string, string> = {
  desert: 'desert',
  deserto: 'desert',
  plains: 'plains',
  planicie: 'plains',
  planícies: 'plains',
  forest: 'forest',
  floresta: 'forest',
  mountain: 'mountain',
  montanha: 'mountain',
  mountains: 'mountain',
  coastal: 'coastal',
  praia: 'coastal',
  costa: 'coastal',
  snow: 'snow',
  neve: 'snow',
  tundra: 'snow',
};

const STRUCTURE_ALIASES: Record<string, string> = {
  market: 'market',
  mercado: 'market',
  house: 'house',
  houses: 'house',
  casa: 'house',
  casas: 'house',
  temple: 'temple',
  templo: 'temple',
  workshop: 'workshop',
  oficina: 'workshop',
  barracks: 'barracks',
  caserna: 'barracks',
  wall: 'wall',
  muralha: 'wall',
};

/**
 * Interpretação real (heurística local do S++): texto → objetivo estruturado.
 * Regras transparentes e testáveis — sem caixa-preta.
 */
export function interpretGoal(raw: string): Goal {
  const t = raw.toLowerCase();
  const goal: Goal = { raw };

  if (/(construir|build|criar|create|gerar|generate).*(mundo|world)/.test(t)) {
    goal.type = 'build-world';
    const size = /(\d+)\s*(?:chunks?|células?|quads?|de tamanho)?/.exec(t);
    goal.params = {
      size: size ? Number(size[1]) : 4,
      biomes: extractList(t, BIOME_ALIASES) ?? ['plains', 'forest'],
      seed: pickNumber(t, 'seed') ?? 42,
      count: pickNumber(t, 'npc') ?? 8,
      spread: 0.5,
    };
    return goal;
  }
  if (/(construir|build|criar|create|adicionar|add|gerar|generate).*(bioma|biome|cena|scene|vila|village)/.test(t)) {
    goal.type = 'build-scene';
    const biome = extractList(t, BIOME_ALIASES)?.[0] ?? 'plains';
    const npcs = pickNumber(t, 'npc') ?? pickNumber(t, 'habitantes') ?? 0;
    const structures = extractList(t, STRUCTURE_ALIASES) ?? [];
    goal.params = { biome, npcs, structures, x: pickNumber(t, 'x') ?? 0, y: pickNumber(t, 'y') ?? 0 };
    return goal;
  }
  if (/(otimizar|optimize|otimizaç)/.test(t)) {
    goal.type = 'optimize';
    goal.params = {};
    return goal;
  }
  if (/(analisar|inspect|descrever|describe|auditar|audit)/.test(t)) {
    goal.type = 'inspect';
    goal.params = {};
    return goal;
  }
  goal.type = 'generic';
  goal.params = {};
  return goal;
}

function extractList(t: string, aliases: Record<string, string>): string[] | null {
  const found: string[] = [];
  for (const [alias, canonical] of Object.entries(aliases)) {
    if (t.includes(alias) && !found.includes(canonical)) found.push(canonical);
  }
  return found.length ? found : null;
}

function pickNumber(t: string, word: string): number | null {
  // "12 npcs" (número antes) ou "seed 99" (palavra antes)
  const re = new RegExp(`(\\d+)\\s*${word}s?|${word}s?\\s*(\\d+)`);
  const m = re.exec(t);
  return m ? Number(m[1] ?? m[2]) : null;
}

/* ------------------------------------------------------------------ */
/* Verificação de etapas                                               */
/* ------------------------------------------------------------------ */

function checkStepVerify(expected: Record<string, unknown> | null | undefined, data: Record<string, unknown>): string[] {
  const issues: string[] = [];
  if (!expected) return issues;
  for (const [k, v] of Object.entries(expected)) {
    const a = data[k];
    if (v && typeof v === 'object' && 'min' in (v as Record<string, unknown>)) {
      if (typeof a !== 'number' || a < Number((v as Record<string, unknown>).min)) {
        issues.push(`${k}: esperado ≥ ${(v as Record<string, unknown>).min}, obtido ${String(a)}`);
      }
    } else if (v && typeof v === 'object' && 'eq' in (v as Record<string, unknown>)) {
      if (a !== (v as Record<string, unknown>).eq) issues.push(`${k}: esperado ${(v as Record<string, unknown>).eq}, obtido ${String(a)}`);
    } else if (v === true) {
      if (a !== true) issues.push(`${k}: esperado true, obtido ${String(a)}`);
    } else if (typeof v === 'number' || typeof v === 'string') {
      if (a !== v) issues.push(`${k}: esperado ${String(v)}, obtido ${String(a)}`);
    }
  }
  return issues;
}

/* ------------------------------------------------------------------ */
/* Singularity Core                                                    */
/* ------------------------------------------------------------------ */

export class SingularityCore {
  private models: ModelRegistry;
  private providers: ProviderRegistry;
  private tools: ToolRegistry;
  private agents: AgentRegistry;
  private memory: MemorySystem;
  private log: Logger;
  private maxAttempts: number;

  constructor(opts: CoreOptions) {
    this.models = opts.models;
    this.providers = opts.providers;
    this.tools = opts.tools;
    this.agents = opts.agents;
    this.memory = opts.memory;
    this.log = (opts.log ?? new Logger('ai')).child('core');
    this.maxAttempts = opts.maxAttempts ?? 2;
  }

  /**
   * Executa um objetivo de ponta a ponta. Sincrono para providers locais;
   * providers assíncronos (ex.: Puter em browser) envolvem `call` em um
   * wrapper — a interface do Core permanece idêntica.
   */
  run(goal: Goal | string, ctx: CoreContext): ExecutionReport {
    const t0 = Date.now();
    const goalId = newId('goal');
    const goalObj: Goal = typeof goal === 'string' ? interpretGoal(goal) : goal;
    const convId = `conv_${goalId}`;
    this.memory.message(convId, 'user', goalObj.raw, ctx.now);
    this.log.info(`objetivo recebido: "${goalObj.raw}" → ${goalObj.type}`, goalObj.params);

    // 1) INTERPRETAÇÃO + 2) PLANEJAMENTO — Main Model (S++): o planejamento
    // do objetivo é sempre a tarefa de maior responsabilidade.
    const planSel = { model: this.models.main(), reason: 'Main Model (S++) para interpretação + planejamento' };
    const provider = this.providers.get(planSel.model.providerId);
    const planRes = provider.call({
      model: planSel.model,
      messages: [{ role: 'system', content: 'Você planeja objetivos para a UTS.' }, { role: 'user', content: goalObj.raw }],
      payload: { kind: 'plan', objective: goalObj.raw, goalType: goalObj.type, ...goalObj.params },
      rng: ctx.rng,
    });
    if (!planRes.ok) {
      this.memory.message(convId, 'assistant', `Falha no planejamento: ${planRes.error}`, ctx.now);
      return this.finish(goalId, goalObj, 'failed', [], 0, [planSel.model.id], t0, `planejamento falhou: ${planRes.error}`);
    }
    const plan = planRes.structured as { objective: string; steps: Array<{ id: string; agent: string; action: string; args: Record<string, unknown>; verify: Record<string, unknown> | null }> };
    this.memory.setDecision(`strategy/${goalId}`, { model: planSel.model.id, goalType: goalObj.type, steps: plan.steps.length }, ctx.now, 'plano principal escolhido');
    this.memory.remember(`goal.${goalId}.type`, goalObj.type, 0.8, ctx.now);
    this.log.info(`plano: ${plan.steps.length} etapas (modelo ${planSel.model.id})`);

    // 3..8) EXECUÇÃO por etapa: agente → ferramentas → verificação → correção
    const stepReports: StepReport[] = [];
    let corrections = 0;
    const modelsUsed = new Set<string>([planSel.model.id]);

    for (const s of plan.steps) {
      const agent = this.agents.selectFor(s.action, s.agent);
      const stepReport: StepReport = { id: s.id, agent: agent?.id ?? s.agent, action: s.action, modelId: planSel.model.id, ok: false, attempts: 0, data: {}, issues: [] };
      if (!agent) {
        stepReport.issues.push(`nenhum agente atende a ação "${s.action}"`);
        stepReports.push(stepReport);
        continue;
      }
      // Seleção de MODELO por tarefa (não sempre o maior):
      const agentModel = this.models.select({
        capabilities: agent.id === 'verifier' ? ['verification'] : agent.id === 'optimizer' ? ['verification', 'critique'] : ['code', 'specification'],
        complexity: agent.complexity,
      });
      modelsUsed.add(agentModel.model.id);
      stepReport.modelId = agentModel.model.id;

      let lastIssues: string[] = [];
      for (let attempt = 1; attempt <= this.maxAttempts; attempt++) {
        stepReport.attempts = attempt;
        const task: AgentTask = { id: s.id, agent: agent.id, action: s.action, args: s.args, verify: s.verify };
        let res;
        try {
          res = agent.execute(task, { ...ctx, task, model: agentModel.model, tools: this.tools, memory: this.memory } as never);
        } catch (e) {
          res = { ok: false, data: {}, error: e instanceof Error ? e.message : String(e) };
        }
        lastIssues = res.ok ? checkStepVerify(s.verify, res.data) : [res.error ?? 'agente retornou falha', ...checkStepVerify(s.verify, res.data)];
        if (res.ok && lastIssues.length === 0) {
          stepReport.ok = true;
          stepReport.data = res.data;
          break;
        }
        // CORREÇÃO: registra na memória, tenta de novo com contexto de erro (bounded)
        if (attempt < this.maxAttempts) {
          corrections += 1;
          this.log.warn(`etapa ${s.action} falhou (tentativa ${attempt}): ${lastIssues.join('; ')} — corrigindo`);
          this.memory.setDecision(`correction/${goalId}/${s.id}`, { attempt, issues: lastIssues }, ctx.now, 'tentativa de correção');
          // reinjeta o erro nos args para o agente poder se adaptar
          s.args = { ...s.args, __lastError: lastIssues.join('; ') };
        }
      }
      if (!stepReport.ok) stepReport.issues = lastIssues;
      stepReports.push(stepReport);
      this.memory.message(convId, 'tool', `etapa ${s.action} ${stepReport.ok ? 'OK' : 'FALHOU'}: ${JSON.stringify(stepReport.data).slice(0, 200)}`, ctx.now);
    }

    const okCount = stepReports.filter((r) => r.ok).length;
    const status: ExecutionReport['status'] = okCount === stepReports.length ? 'success' : okCount > 0 ? 'partial' : 'failed';
    const summary = `${status}: ${okCount}/${stepReports.length} etapas (${planSel.model.id} planejou; correções=${corrections})`;
    this.memory.message(convId, 'assistant', summary, ctx.now);
    this.memory.setDecision(`result/${goalId}`, { status, okCount, total: stepReports.length }, ctx.now, 'resultado final');
    this.memory.remember(`goal.${goalId}.result`, status, 0.9, ctx.now);
    return this.finish(goalId, goalObj, status, stepReports, corrections, [...modelsUsed], t0, summary);
  }

  private finish(
    goalId: string,
    goalObj: Goal,
    status: ExecutionReport['status'],
    steps: StepReport[],
    corrections: number,
    modelsUsed: string[],
    t0: number,
    summary: string,
  ): ExecutionReport {
    return { goalId, goal: goalObj.raw, goalType: goalObj.type ?? 'generic', status, steps, corrections, modelsUsed, durationMs: Date.now() - t0, summary };
  }
}

/* ------------------------------------------------------------------ */
/* Fábrica de agentes padrão (implementam o fluxo real sobre WorldAdapter) */
/* ------------------------------------------------------------------ */

export function createDefaultAgents(): AgentRegistry {
  const reg = new AgentRegistry();
  const w = (ctx: { world: WorldAdapter }) => ctx.world;

  reg.define({
    id: 'world-builder',
    label: 'Construtor de mundos',
    handles: ['create-world', 'create-biome', 'populate', 'build-structures'],
    complexity: 0.7,
    execute(task, ctx) {
      const world = w(ctx as never);
      switch (task.action) {
        case 'create-world': {
          if (world.worldExists()) return { ok: true, data: { worldExists: true, already: true } };
          const r = world.createWorld({ size: Number(task.args.size ?? 4), biomes: (task.args.biomes as string[]) ?? ['plains'], seed: Number(task.args.seed ?? 42) });
          return { ok: r.ok, data: { worldExists: world.worldExists(), id: r.id } };
        }
        case 'create-biome': {
          const r = world.createBiome(String(task.args.biome ?? 'plains'), Number(task.args.x ?? 0), Number(task.args.y ?? 0));
          return { ok: r.ok, data: { biome: r.ok ? task.args.biome : null, id: r.id } };
        }
        case 'populate': {
          const before = world.entityCount();
          world.spawnNpcs(Number(task.args.count ?? 0), 0, 0, { spread: task.args.spread });
          return { ok: true, data: { entityCount: world.entityCount(), spawned: world.entityCount() - before } };
        }
        case 'build-structures': {
          const r = world.buildStructures((task.args.structures as string[]) ?? [], Number(task.args.x ?? 0), Number(task.args.y ?? 0));
          return { ok: r.ok, data: { structures: r.count } };
        }
        default:
          return { ok: false, data: {}, error: `ação não atendida: ${task.action}` };
      }
    },
  });

  reg.define({
    id: 'npc-designer',
    label: 'Designer de NPCs (NMN)',
    handles: ['spawn-npcs'],
    complexity: 0.5,
    execute(task, ctx) {
      const world = w(ctx as never);
      const r = world.spawnNpcs(Number(task.args.count ?? 0), Number(task.args.x ?? 0), Number(task.args.y ?? 0), task.args);
      return { ok: r.ok, data: { npcs: r.count, ids: r.ids.length } };
    },
  });

  reg.define({
    id: 'optimizer',
    label: 'Otimizador (D-O15)',
    handles: ['profile', 'analyze', 'apply-strategy'],
    complexity: 0.6,
    execute(task, ctx) {
      const world = w(ctx as never);
      switch (task.action) {
        case 'profile':
        case 'analyze': {
          const report = world.optimizationReport();
          return { ok: true, data: { report: true, pressure: (report as { pressure?: number }).pressure ?? 0 } };
        }
        case 'apply-strategy': {
          const r = world.applyOptimization();
          return { ok: r.ok, data: { applied: r.ok, before: r.before, after: r.after } };
        }
        default:
          return { ok: false, data: {}, error: `ação não atendida: ${task.action}` };
      }
    },
  });

  reg.define({
    id: 'inspector',
    label: 'Inspetor (análise de estado)',
    handles: ['describe'],
    complexity: 0.2,
    execute(_task, ctx) {
      const world = w(ctx as never);
      return { ok: true, data: { description: true, summary: world.describe() } };
    },
  });

  reg.define({
    id: 'verifier',
    label: 'Verificador de invariantes',
    handles: ['check-invariants'],
    complexity: 0.3,
    execute(_task, ctx) {
      const world = w(ctx as never);
      const r = world.checkInvariants();
      return { ok: r.ok, data: { invariants: r.ok, issues: r.issues } };
    },
  });

  reg.define({
    id: 'orchestrator',
    label: 'Orquestrador genérico',
    handles: ['noop'],
    complexity: 0.1,
    execute() {
      return { ok: true, data: { noop: true } };
    },
  });

  return reg;
}

/* ------------------------------------------------------------------ */
/* Fábrica de ferramentas padrão (a IA também opera via ferramentas)   */
/* ------------------------------------------------------------------ */

export function createDefaultTools(ctxProvider: () => { world: WorldAdapter }): ToolRegistry {
  const reg = new ToolRegistry();
  const world = () => ctxProvider().world;
  reg.define({
    name: 'world.describe',
    description: 'Descreve o estado atual do mundo (RRW + UES).',
    args: {},
    run: () => world().describe(),
  });
  reg.define({
    name: 'world.invariants',
    description: 'Verifica invariantes do mundo (estado coerente).',
    args: {},
    run: () => world().checkInvariants(),
  });
  reg.define({
    name: 'world.spawn-npcs',
    description: 'Gera NPCs com mentalidade natural (NMN).',
    args: { count: 'number', x: 'number', y: 'number' },
    run: (args) => world().spawnNpcs(Number(args.count ?? 0), Number(args.x ?? 0), Number(args.y ?? 0)),
  });
  reg.define({
    name: 'd-o15.report',
    description: 'Relatório de otimização (D-O15): pressão, gargalos, decisões.',
    args: {},
    run: () => world().optimizationReport(),
  });
  reg.define({
    name: 'd-o15.apply',
    description: 'Aplica estratégia de otimização ao hardware/pressão atual.',
    args: {},
    run: () => world().applyOptimization(),
  });
  return reg;
}
