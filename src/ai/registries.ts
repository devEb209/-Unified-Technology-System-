/**
 * UTS · Singularity AI — Registros (Model / Provider / Tool / Agent).
 *
 * A arquitetura é desacoplada de qualquer fornecedor:
 *  - Provider = camada de acesso (Puter, OpenAI-like, local, ...);
 *  - Model = unidade concreta com tier + capacidades;
 *  - Tool = função nomeada com schema;
 *  - Agent = especialista que o Singularity Core roteia.
 *
 * Puter.js é APENAS um provider opcional — nunca a inteligência em si.
 * O HeuristicProvider é local e determinístico: permite testar o fluxo
 * completo (OBJETIVO → PLANO → EXECUÇÃO → VERIFICAÇÃO) sem rede.
 */

import { Logger, Rng, newId } from '../core/index.ts';

/* ------------------------------------------------------------------ */
/* Tiers                                                               */
/* ------------------------------------------------------------------ */

export type ModelTier = 'S++' | 'S+' | 'S' | 'A+' | 'A' | 'B' | 'C';

export const TIER_ORDER: ModelTier[] = ['S++', 'S+', 'S', 'A+', 'A', 'B', 'C'];
export const TIER_RANK: Record<ModelTier, number> = {
  'S++': 0,
  'S+': 1,
  S: 2,
  'A+': 3,
  A: 4,
  B: 5,
  C: 6,
};

/* ------------------------------------------------------------------ */
/* Models                                                              */
/* ------------------------------------------------------------------ */

export interface ModelSpec {
  id: string;
  providerId: string;
  tier: ModelTier;
  /** Capacidades que o modelo atende (ex.: 'planning','code','vision'). */
  capabilities: string[];
  /** Custo relativo 0..1 (alimenta seleção por orçamento). */
  cost: number;
  contextWindow?: number;
}

export interface ModelSelection {
  model: ModelSpec;
  reason: string;
}

export class ModelRegistry {
  private models = new Map<string, ModelSpec>();
  /** Main Model: o de melhor tier (S++ quando existir). */
  mainModelId: string | null = null;

  define(spec: ModelSpec): void {
    if (this.models.has(spec.id)) throw new Error(`ModelRegistry: modelo duplicado: ${spec.id}`);
    this.models.set(spec.id, spec);
    if (!this.mainModelId || TIER_RANK[spec.tier] < TIER_RANK[this.get(this.mainModelId).tier]) {
      this.mainModelId = spec.id;
    }
  }

  get(id: string): ModelSpec {
    const m = this.models.get(id);
    if (!m) throw new Error(`ModelRegistry: modelo inexistente: ${id}`);
    return m;
  }

  all(): ModelSpec[] {
    return [...this.models.values()];
  }

  main(): ModelSpec {
    if (!this.mainModelId) throw new Error('ModelRegistry: nenhum modelo definido');
    return this.get(this.mainModelId);
  }

  /**
   * Seleção por tarefa (não por "o melhor sempre"):
   *  - complexidade baixa → tier mínimo suficiente (barato);
   *  - complexidade alta  → sobe de tier até satisfazer;
   *  - capacidades exigidas são filtro duro;
   *  - orçamento (custo máx) é filtro duro quando presente.
   */
  select(opts: { capabilities?: string[]; complexity?: number; maxCost?: number; preferId?: string }): ModelSelection {
    const caps = opts.capabilities ?? [];
    const cx = opts.complexity ?? 0.3;
    // complexidade 0..1 → força mínima necessária (índice na ordem forte→fraca):
    //   cx=1 → índice 0 (só S++) · cx=0 → índice 6 (C basta).
    const minRequiredIndex = TIER_ORDER.length - 1 - Math.round(cx * (TIER_ORDER.length - 1));
    const satisfiesCaps = (m: ModelSpec) => (caps.length ? caps.every((c) => m.capabilities.includes(c)) : true);
    let candidates = this.all().filter((m) => {
      if (!satisfiesCaps(m)) return false;
      if (TIER_RANK[m.tier] < minRequiredIndex) return false; // menos forte que o necessário
      if (opts.maxCost !== undefined && m.cost > opts.maxCost + 1e-9) return false;
      return true;
    });
    if (candidates.length === 0) {
      // relaxa força (mantém capacidades) — melhor esforço
      candidates = this.all().filter(satisfiesCaps);
    }
    if (candidates.length === 0) throw new Error(`ModelRegistry: nenhum modelo para capacidades [${caps.join(',')}]`);
    // roteamento econômico: o MAIS FRACO suficiente (menor custo), depois id
    candidates.sort((a, b) => TIER_RANK[b.tier] - TIER_RANK[a.tier] || a.cost - b.cost || a.id.localeCompare(b.id));
    const chosen = opts.preferId && candidates.some((m) => m.id === opts.preferId) ? this.get(opts.preferId) : candidates[0];
    return { model: chosen, reason: `complexidade=${cx.toFixed(2)} caps=[${caps.join(',')}] → tier ${chosen.tier} via ${chosen.providerId}` };
  }
}

/* ------------------------------------------------------------------ */
/* Providers                                                           */
/* ------------------------------------------------------------------ */

export interface ChatMessage {
  role: 'system' | 'user' | 'assistant';
  content: string;
}

export interface ProviderRequest {
  model: ModelSpec;
  messages: ChatMessage[];
  /** Payload estruturado para providers determinísticos (ex.: o planner). */
  payload?: Record<string, unknown>;
  rng?: Rng;
  signal?: { cancelled: boolean };
}

export interface ProviderResult {
  ok: boolean;
  content: string;
  /** Saída estruturada (quando o provider/modelo produz JSON). */
  structured?: unknown;
  error?: string;
  usage?: { tokens?: number; ms?: number };
}

export interface Provider {
  readonly id: string;
  readonly label: string;
  isAvailable(): boolean;
  call(req: ProviderRequest): ProviderResult;
}

export class ProviderRegistry {
  private providers = new Map<string, Provider>();
  log: Logger;
  constructor(log?: Logger) {
    this.log = (log ?? new Logger('ai')).child('providers');
  }
  define(p: Provider): void {
    this.providers.set(p.id, p);
  }
  get(id: string): Provider {
    const p = this.providers.get(id);
    if (!p) throw new Error(`ProviderRegistry: provider inexistente: ${id}`);
    return p;
  }
  available(): string[] {
    return [...this.providers.values()].filter((p) => p.isAvailable()).map((p) => p.id);
  }
  all(): string[] {
    return [...this.providers.keys()];
  }
}

/* ------------------------------------------------------------------ */
/* HeuristicProvider — local, determinístico, testável sem rede        */
/* ------------------------------------------------------------------ */

/**
 * "Modelos" locais que realmente computam (não são eco):
 *  - uts-architect (S++) : interpreta objetivos e produz planos estruturados;
 *  - uts-coder    (S)    : produz specs de código/entidades;
 *  - uts-critic   (A)    : verifica resultados contra critérios;
 *  - uts-scribe   (B)    : resume/rotula.
 */
export class HeuristicProvider implements Provider {
  readonly id = 'heuristic';
  readonly label = 'Local determinístico (offline)';

  private models: ModelSpec[] = [
    { id: 'uts-architect', providerId: this.id, tier: 'S++', capabilities: ['planning', 'decomposition', 'architecture'], cost: 1.0 },
    { id: 'uts-coder', providerId: this.id, tier: 'S', capabilities: ['code', 'specification', 'generation'], cost: 0.6 },
    { id: 'uts-critic', providerId: this.id, tier: 'A', capabilities: ['verification', 'critique', 'testing'], cost: 0.3 },
    { id: 'uts-scribe', providerId: this.id, tier: 'B', capabilities: ['summarization', 'naming', 'labels'], cost: 0.1 },
  ];

  isAvailable(): boolean {
    return true; // sempre disponível localmente
  }

  call(req: ProviderRequest): ProviderResult {
    const t0 = Date.now();
    try {
      const last = req.messages[req.messages.length - 1]?.content ?? '';
      const p = req.payload ?? {};
      let structured: unknown;
      let content: string;
      const kind = (p.kind as string) ?? inferKind(last);
      switch (kind) {
        case 'plan':
          structured = buildPlan(p);
          content = `Plano com ${(structured as { steps?: unknown[] }).steps?.length ?? 0} etapas.`;
          break;
        case 'verify':
          structured = runVerify(p);
          content = (structured as { ok: boolean }).ok ? 'Verificação passou.' : 'Verificação falhou.';
          break;
        case 'name':
          structured = makeNames(p, req.rng);
          content = `Nomes: ${(structured as string[]).join(', ')}`;
          break;
        case 'summarize':
          structured = { summary: summarize(p, last) };
          content = String(structured);
          break;
        default:
          structured = { echo: last };
          content = last;
      }
      return { ok: true, content, structured, usage: { ms: Date.now() - t0 } };
    } catch (e) {
      return { ok: false, content: '', error: e instanceof Error ? e.message : String(e), usage: { ms: Date.now() - t0 } };
    }
  }
}

function inferKind(text: string): string {
  const t = text.toLowerCase();
  if (t.includes('plano') || t.includes('plan') || t.includes('decomp')) return 'plan';
  if (t.includes('verif') || t.includes('valid') || t.includes('check')) return 'verify';
  if (t.includes('nome') || t.includes('name')) return 'name';
  if (t.includes('resum') || t.includes('summar')) return 'summarize';
  return 'echo';
}

/**
 * Planner heurístico REAL: decompõe objetivos em etapas de agentes.
 * Não é eco — produz estrutura usada pelo Core para executar de fato.
 */
function buildPlan(p: Record<string, unknown>): { objective: string; steps: Array<{ id: string; agent: string; action: string; args: Record<string, unknown>; verify: Record<string, unknown> | null }> } {
  const objective = String(p.objective ?? 'generic');
  const goalType = (p.goalType as string) ?? 'generic';
  const steps: Array<{ id: string; agent: string; action: string; args: Record<string, unknown>; verify: Record<string, unknown> | null }> = [];
  const step = (agent: string, action: string, args: Record<string, unknown>, verify: Record<string, unknown> | null = null) => {
    steps.push({ id: newId('step'), agent, action, args, verify });
  };
  switch (goalType) {
    case 'build-world':
      step('world-builder', 'create-world', { size: p.size, biomes: p.biomes, seed: p.seed }, { worldExists: true });
      step('world-builder', 'populate', { count: p.count, spread: p.spread }, { entityCount: { min: Number(p.count ?? 0) } });
      step('optimizer', 'profile', {}, { report: true });
      break;
    case 'build-scene':
      step('world-builder', 'create-biome', { biome: p.biome, x: p.x, y: p.y }, { biome: p.biome });
      if (Array.isArray(p.structures)) step('world-builder', 'build-structures', { structures: p.structures, x: p.x, y: p.y }, { structures: p.structures.length });
      if (Number(p.npcs) > 0) step('npc-designer', 'spawn-npcs', { count: Number(p.npcs), x: p.x, y: p.y }, { npcs: Number(p.npcs) });
      step('verifier', 'check-invariants', {}, { invariants: true });
      break;
    case 'optimize':
      step('optimizer', 'analyze', {}, { report: true });
      step('optimizer', 'apply-strategy', {}, { applied: true });
      break;
    case 'inspect':
      step('inspector', 'describe', {}, { description: true });
      break;
    default:
      step('orchestrator', 'noop', {}, null);
  }
  return { objective, steps };
}

function runVerify(p: Record<string, unknown>): { ok: boolean; issues: string[] } {
  const issues: string[] = [];
  const expected = p.expected as Record<string, unknown> | undefined;
  const actual = p.actual as Record<string, unknown> | undefined;
  if (expected && actual) {
    for (const [k, v] of Object.entries(expected)) {
      const a = actual[k];
      if (v && typeof v === 'object' && 'min' in (v as Record<string, unknown>)) {
        if (typeof a !== 'number' || a < Number((v as Record<string, unknown>).min)) issues.push(`${k}: esperado ≥ ${v.min}, obtido ${a}`);
      } else if (v !== a) {
        issues.push(`${k}: esperado ${String(v)}, obtido ${String(a)}`);
      }
    }
  }
  return { ok: issues.length === 0, issues };
}

const NAME_POOL = ['Ana', 'Bruno', 'Carla', 'Diego', 'Elisa', 'Fábio', 'Greta', 'Heitor', 'Inês', 'João', 'Kátia', 'Lucas', 'Marta', 'Nuno', 'Olívia', 'Pedro', 'Quésia', 'Rafael', 'Sofia', 'Tiago', 'Úrsula', 'Vitor', 'Wanda', 'Xavier', 'Yara', 'Zeca'];

function makeNames(p: Record<string, unknown>, rng?: Rng): string[] {
  const n = Math.max(0, Math.min(64, Number(p.count ?? 3)));
  const r = rng ?? new Rng(Date.now() % 2147483647);
  const pool = [...NAME_POOL];
  r.shuffle(pool);
  const out: string[] = [];
  for (let i = 0; i < n; i++) out.push(pool[i % pool.length]);
  return out;
}

function summarize(p: Record<string, unknown>, last: string): string {
  const k = p.key as string | undefined;
  return k ? `${k}: ${last.slice(0, 120)}` : last.slice(0, 120);
}

/* ------------------------------------------------------------------ */
/* PuterProvider — adapter opcional (NUNCA a inteligência)             */
/* ------------------------------------------------------------------ */

type PuterGlobal = { ai?: { chat?: (m: string | ChatMessage[], o?: Record<string, unknown>) => Promise<unknown> } };

declare const window: unknown;

function readWindowPuter(): PuterGlobal | undefined {
  if (typeof window === 'undefined') return undefined;
  const w = window as { puter?: PuterGlobal } | undefined;
  return w?.puter;
}

/**
 * Adapter para Puter.js (camada de acesso a modelos via navegador).
 * Disponível apenas quando `window.puter` existe (ambiente browser).
 * Em Node/CLI, isAvailable() === false e call() falha com erro claro.
 */
export class PuterProvider implements Provider {
  readonly id = 'puter';
  readonly label = 'Puter.js (browser)';

  private get globalPuter(): PuterGlobal | undefined {
    return readWindowPuter();
  }

  isAvailable(): boolean {
    return !!this.globalPuter?.ai?.chat;
  }

  private models: ModelSpec[] = [
    { id: 'puter:auto', providerId: this.id, tier: 'S', capabilities: ['planning', 'code', 'verification', 'summarization'], cost: 0.5 },
  ];

  call(req: ProviderRequest): ProviderResult {
    const puter = this.globalPuter;
    if (!puter?.ai?.chat) {
      return { ok: false, content: '', error: 'Puter indisponível neste ambiente (window.puter ausente). Use outro provider.' };
    }
    // Puter é async; este provider é sincrono na interface, então dispara e avisa.
    const text = req.messages.map((m) => m.content).join('\n');
    const promise = puter.ai.chat(text, {});
    // Nota de design: a integração browser real assina este promise em um
    // loop assíncrono; aqui registramos a delegação para não bloquear.
    void promise;
    return { ok: true, content: 'Delegado ao Puter (async em ambiente browser).', structured: { delegated: true, model: req.model.id } };
  }
}

/* ------------------------------------------------------------------ */
/* Tools                                                               */
/* ------------------------------------------------------------------ */

export interface ToolSchema {
  name: string;
  description: string;
  /** Schema simples de argumentos (tipo por chave). */
  args: Record<string, string>;
  run: (args: Record<string, unknown>, ctx: Record<string, unknown>) => unknown;
}

export class ToolRegistry {
  private tools = new Map<string, ToolSchema>();
  define(t: ToolSchema): void {
    if (this.tools.has(t.name)) throw new Error(`ToolRegistry: ferramenta duplicada: ${t.name}`);
    this.tools.set(t.name, t);
  }
  get(name: string): ToolSchema {
    const t = this.tools.get(name);
    if (!t) throw new Error(`ToolRegistry: ferramenta inexistente: ${name}`);
    return t;
  }
  all(): ToolSchema[] {
    return [...this.tools.values()];
  }
  run(name: string, args: Record<string, unknown>, ctx: Record<string, unknown> = {}): unknown {
    return this.get(name).run(args, ctx);
  }
}

/* ------------------------------------------------------------------ */
/* Agents                                                              */
/* ------------------------------------------------------------------ */

export interface AgentTask {
  id: string;
  agent: string;
  action: string;
  args: Record<string, unknown>;
  verify?: Record<string, unknown> | null;
}

export interface AgentContext {
  [key: string]: unknown;
}

export interface AgentResult {
  ok: boolean;
  data: Record<string, unknown>;
  error?: string;
}

export interface AgentSpec {
  id: string;
  label: string;
  /** Tipos de ação que este agente atende. */
  handles: string[];
  /** Típica complexidade que atende (0..1) — usada no roteamento. */
  complexity: number;
  execute(task: AgentTask, ctx: AgentContext): AgentResult;
}

export class AgentRegistry {
  private agents = new Map<string, AgentSpec>();
  define(a: AgentSpec): void {
    if (this.agents.has(a.id)) throw new Error(`AgentRegistry: agente duplicado: ${a.id}`);
    this.agents.set(a.id, a);
  }
  get(id: string): AgentSpec {
    const a = this.agents.get(id);
    if (!a) throw new Error(`AgentRegistry: agente inexistente: ${id}`);
    return a;
  }
  all(): AgentSpec[] {
    return [...this.agents.values()];
  }
  /** Seleciona o melhor agente para uma ação (determinístico). */
  selectFor(action: string, preferId?: string): AgentSpec | null {
    if (preferId && this.agents.has(preferId)) return this.get(preferId);
    const byAction = this.all().filter((a) => a.handles.includes(action));
    if (byAction.length === 0) return null;
    byAction.sort((a, b) => a.id.localeCompare(b.id));
    return byAction[0];
  }
}
