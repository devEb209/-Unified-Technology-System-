import { DOMAINS, type Domain, type DStep } from '../../d-system/src/types.ts';
import { GEN1_DOMAINS } from '../../d-system/src/types.ts';
import { ladderFor, stepAt, costOf, capsAt } from '../../d-system/src/ladders.ts';
import { resolveRequirements, type DomainRequirements } from '../../d-system/src/requirements.ts';

/**
 * D-O15 — o otimizador da Tese, implementado como o contrato manda:
 *
 *   D* = argmin_D  C(D)   sujeito a  Qp/Qf/Qi ≥ pisos, ΔInfo, Stability, Function
 *
 * Não é `argmax(Q − C)`: sem compensação entre componentes, e com falha
 * nomeada quando nada satisfaz. `minD` derivado por capacidade é vincante,
 * então "economizar apagando o que o autor pediu" é impossível por construção.
 */

export interface Region {
  id: string;
  pixels: number;
  entities: number;
  lights?: number;
  volumes?: number;
  /** Importância (Tese §49): escala pisos e prioridade. Não é distância. */
  importance: number;
  /** Velocidade relativa percebida — alimenta Qp temporal e a margem prevista. */
  motion: number;
  /** Fatos que podem deixar de existir se abstraídos demais (Tese §10). */
  atRisk?: readonly string[];
}

export interface PersistState {
  DCurrent: number;
  lastQ: number;
  lastChangeTick: number;
}

export interface OptimizerInput {
  region: Region;
  resources: { frameBudget: number; headroom: number; thermal: 'nominal' | 'throttling' | 'critical' };
  requirements: Partial<Record<Domain, DomainRequirements>>;
  /** estado por (região,domínio) para histerese; ausente = sem histórico */
  persist?: Partial<Record<Domain, PersistState>>;
  /** Horizonte de previsão (Tese §83/§84). 0 desliga margem preditiva. */
  horizon?: number;
  /** teto de folga que a previsão justifica (contrato §1.4). */
  marginCeiling?: number;
  /** I9: o otimizador também obedece ao §33. 0 = sem corte (auditoria). */
  candidateCap?: number;
  tick?: number;
}

export interface DomainDecision {
  domain: Domain;
  D: number;
  step: DStep;
  cost: number;
  quality: { Qp: number; Qf: number; Qi: number };
  floors: { QpMin: number; QfMin: number; QiMin: number; minD: number; maxD: number; overridden: boolean; reason: string };
  /** folga sobre o piso, usada no tie-break e no ResultFrame. */
  margin: number;
  /** porque este D e não o anterior/mais barato. */
  why: string;
}

export interface Infeasible {
  domain: Domain;
  bindingConstraint: 'Qp' | 'Qf' | 'Qi' | 'minD' | 'prereq' | 'budget' | 'thermal';
  required: number;
  bestAchieved: number;
  atD: number;
  message: string;
}

export type Decision =
  | { kind: 'ok'; regions: DecisionSet }
  | { kind: 'infeasible'; error: Infeasible; fallback: DecisionSet };

export interface DecisionSet {
  regionId: string;
  decisions: Record<string, DomainDecision>;
  totalCost: number;
  /** quantos candidatos o otimizador avaliou — entra em C (I9) */
  candidatesEvaluated: number;
  coarse: boolean;
}

const EPS = 1e-9;
/** Empate de custo: 1 unidade de custo ≈ 5.000 pixels — abaixo disso é ruído de escala. */
const COST_EPS = 1e-6;

interface Candidate {
  step: DStep;
  cost: number;
  Qp: number;
  Qf: number;
  Qi: number;
  feasible: boolean;
  binding?: Infeasible['bindingConstraint'];
}

function candidatesFor(
  domain: Domain,
  region: Region,
  floors: { QpMin: number; QfMin: number; QiMin: number; minD: number; maxD: number },
  budget: number,
  cap: number,
): { list: Candidate[]; evaluated: number } {
  const ladder = ladderFor(domain);
  const out: Candidate[] = [];
  let evaluated = 0;
  for (const s of ladder.steps) {
    if (s.D > floors.maxD) break;
    if (cap > 0 && evaluated >= cap) break;
    evaluated++;
    const cost = costOf(s, region);
    const q = s.quality;
    let feasible = s.D >= floors.minD && cost <= budget + EPS;
    let binding: Candidate['binding'] = cost > budget + EPS ? 'budget' : undefined;
    if (s.D < floors.minD) binding = 'minD';
    if (q.Qp + EPS < floors.QpMin) { feasible = false; binding = 'Qp'; }
    if (q.Qf + EPS < floors.QfMin) { feasible = false; binding = binding ?? 'Qf'; }
    if (q.Qi + EPS < floors.QiMin) { feasible = false; binding = binding ?? 'Qi'; }
    out.push({ step: s, cost, Qp: q.Qp, Qf: q.Qf, Qi: q.Qi, feasible, binding });
  }
  return { list: out, evaluated };
}

/** custo real do frame inteiro, dado um conjunto de decisões por domínio. */
export function costOfSet(region: Region, d: Partial<Record<Domain, number>>): number {
  let t = 0;
  for (const dom of GEN1_DOMAINS) {
    const v = d[dom];
    if (v === undefined) continue;
    const s = stepAt(dom, v);
    if (s) t += costOf(s, region);
  }
  return t;
}

function prereqFloor(domain: Domain, D: number, chosen: Partial<Record<Domain, number>>): { ok: boolean; need?: { dom: Domain; D: number } } {
  const s = stepAt(domain, D);
  if (!s?.prereq) return { ok: true };
  for (const [dep, need] of Object.entries(s.prereq) as [Domain, number][]) {
    if (!GEN1_DOMAINS.includes(dep)) continue;
    if ((chosen[dep] ?? 0) < need) return { ok: false, need: { dom: dep, D: need } };
  }
  return { ok: true };
}

function marginOf(c: { Qp: number; Qf: number; Qi: number }, f: { QpMin: number; QfMin: number; QiMin: number }): number {
  return Math.min(c.Qp - f.QpMin, c.Qf - f.QfMin, c.Qi - f.QiMin);
}

type Resolved = ReturnType<typeof resolveRequirements>;

/** Ordem em que domínios são resolvidos: quem é dependência vem antes. */
// A ordem é DERIVADA do registro de domínios, não escrita à mão: a versão anterior
// (lista fixa) significava que adicionar uma era nova exigia lembrar de um segundo
// lugar — e o domínio ficava silenciosamente fora do fixpoint, decidido como zero.
export const DOMAIN_ORDER: readonly Domain[] = DOMAINS.filter((d) => ladderFor(d).steps.length > 0);

function bestQuality(list: Candidate[]): Candidate | undefined {
  return list.reduce<Candidate | undefined>((a, b) => (!a || b.Qf + b.Qi > a.Qf + a.Qi ? b : a), undefined);
}

function infeasibleFor(
  domain: Domain,
  list: Candidate[],
  floors: Resolved,
  budget: number,
  cause: 'budget' | 'prereq' | 'quality' | 'minD',
  prereqNote?: string,
): Infeasible {
  const best = bestQuality(list) ?? list[0];
  let binding: Infeasible['bindingConstraint'] = cause;
  // "nenhum D satisfaz os pisos" e "nenhum D que satisfaz cabe no orçamento" são
  // diagnósticos diferentes: o primeiro manda o humano reavaliar o requisito, o
  // segundo manda-o reavaliar o orçamento. Classificar errado é mentir no erro.
  const floorsMet = list.filter((c) => c.step.D >= floors.minD && c.Qp + EPS >= floors.QpMin && c.Qf + EPS >= floors.QfMin && c.Qi + EPS >= floors.QiMin);
  if (cause === 'quality' && floorsMet.length > 0) cause = 'budget';
  if (cause === 'quality' && best) {
    binding = best.Qp + EPS < floors.QpMin ? 'Qp' : best.Qf + EPS < floors.QfMin ? 'Qf' : 'Qi';
  }
  const detail =
    cause === 'prereq'
      ? `todo D que satisfaz os pisos exige ${prereqNote ?? 'dependência não satisfeita'} e o domínio dependente não pôde subir`
      : cause === 'budget'
        ? `mesmo o degrau mais barato que satisfaz os pisos custa ${Math.min(...(floorsMet.length ? floorsMet : list).map((c) => c.cost)).toFixed(3)} acima do orçamento (${budget.toFixed(3)}) — não há o que cortar aqui`
        : `nenhum D satisfaz os pisos com C ≤ ${budget.toFixed(3)}`;
  return {
    domain,
    bindingConstraint: binding,
    required: binding === 'Qp' ? floors.QpMin : binding === 'Qi' ? floors.QiMin : binding === 'budget' ? budget : floors.QfMin,
    bestAchieved: best ? (binding === 'Qp' ? best.Qp : binding === 'Qi' ? best.Qi : binding === 'budget' ? best.cost : best.Qf) : 0,
    atD: best?.step.D ?? 0,
    message: `E_INFEASIBLE[${domain}] ${detail}. Reduzir o requisito é decisão de objetivo, não de otimização.`,
  };
}

/**
 * Resolve a região com ponto fixo entre domínios.
 *
 * Invariantes do laço: (a) pré-requisito nunca é motivo para abandonar um
 * domínio — ele eleva o mínimo do vizinho e o laço continua; (b) infeasibilidade
 * só é declarada quando nenhum domínio pode mais subir; (c) o custo do próprio
 * laço é contabilizado (I9).
 */
export function decideRegion(input: OptimizerInput): Decision {
  const cap = input.candidateCap ?? 0;
  const chosen: Partial<Record<Domain, number>> = {};
  const raisedFloor: Partial<Record<Domain, number>> = {};
  const decided = new Set<Domain>();
  const decisions: Record<string, DomainDecision> = {};
  const deferred = new Map<Domain, string>();
  let evaluated = 0;
  let budget = input.resources.frameBudget;

  const active = DOMAIN_ORDER.filter((d) => ladderFor(d).steps.length > 0 && (input.requirements[d] !== undefined || GEN1_DOMAINS.includes(d)));
  const floors = new Map<Domain, Resolved>(active.map((d) => [d, resolveRequirements(d, { ...(input.requirements[d] ?? { domain: d }), domain: d })]));

  for (let pass = 0; pass <= active.length + 1; pass++) {
    const last = pass === active.length + 1;
    let changed = false;

    for (const dom of active) {
      if (decided.has(dom)) continue;
      const f0 = floors.get(dom)!;
      const minD = Math.max(f0.minD, raisedFloor[dom] ?? 0);
      const floorsNow = { ...f0, minD };
      const cand = candidatesFor(dom, input.region, floorsNow, budget, cap);
      evaluated += cand.evaluated;

      const usable = cand.list.filter((x) => x.feasible);
      const live = usable.filter((x) => prereqFloor(dom, x.step.D, chosen).ok);

      if (live.length === 0) {
        if (usable.length > 0) {
          // pré-requisito não atendido: eleva o vizinho e tenta de novo
          // o raise usa o pré-requisito do DEGRAU MAIS BARATO ainda viável, não o
          // pior entre todos: exigir D3 do vizinho quando D3 seria a escolha é
          // pagar 40% por uma dependência que a escolha mais barata não tem
          let worst: { dom: Domain; D: number } | undefined;
          const cheapest = usable.sort((a0, b0) => a0.cost - b0.cost || a0.step.D - b0.step.D)[0];
          for (const x of [cheapest, ...usable]) {
            const pr = prereqFloor(dom, x.step.D, chosen);
            if (!pr.ok && pr.need) { worst = pr.need; break; }
          }
          if (worst) {
            deferred.set(dom, `${worst.dom}≥${worst.D}`);
            if ((raisedFloor[worst.dom] ?? 0) < worst.D && worst.D <= (floors.get(worst.dom)?.maxD ?? 0)) {
              raisedFloor[worst.dom] = worst.D;
              decided.delete(worst.dom);
              changed = true;
              continue;
            }
            if (!last) continue;
          }
        }
        if (!last) continue; // outro domínio pode destravar isto no próximo passe
        const cause: 'budget' | 'prereq' | 'quality' = usable.length > 0 ? 'prereq' : cand.list.length > 0 && cand.list.every((x) => x.cost > budget + EPS) ? 'budget' : 'quality';
        const err = infeasibleFor(dom, cand.list, floorsNow, budget, cause, deferred.get(dom));
        const set: DecisionSet = { regionId: input.region.id, decisions, totalCost: costOfSet(input.region, chosen), candidatesEvaluated: evaluated, coarse: true };
        return { kind: 'infeasible', error: err, fallback: set };
      }

      // SELEÇÃO — uma regra só, derivada da §33 (Representação Mínima Suficiente):
      // 1. menor custo viável é o objetivo; empate de custo é decidido por
      //    estabilidade (§82), nunca por "mais qualidade de graça";
      // 2. entre custos iguais, o D mais próximo do atual — estabilidade é
      //    gratuita e popping não é;
      // 3. persistindo o empate, a menor folga acima dos pisos.
      live.sort((a, b) => a.cost - b.cost || Math.abs(marginOf(a, floorsNow)) - Math.abs(marginOf(b, floorsNow)) || a.step.D - b.step.D);
      const minCost = live[0].cost;
      const band = live.filter((x) => x.cost - minCost <= COST_EPS);
      let pick = band[0];
      const persist = input.persist?.[dom];
      const h = ladderFor(dom).hysteresis;
      if (persist) {
        const cur = live.find((c) => c.step.D === persist.DCurrent);
        if (cur) {
          const curIsFree = cur.cost - minCost <= COST_EPS;
          if (input.resources.thermal === 'critical' && curIsFree && cur.step.D < pick.step.D) {
            pick = cur; // sob térmico crítico não se expande
          } else if (curIsFree) {
            // Mesmo custo → manter é a decisão mínima. A qualidade a mais não é
            // pedida, mas também não é paga: trocar por nada é gastar a troca.
            pick = cur;
          } else if (cur.step.D > pick.step.D) {
            // DESCER gasta menos, então a economia manda — SALVO quando a volta não
            // é gratuita. Um degrau que DECLARA perdas (`drops`) não pode ser desfeito
            // no tick seguinte; aí a banda de folga de §82 é o que segura a decisão,
            // e ela é cumprida no estado que se DEIXA (gatilho de Schmitt: banda de
            // saída h, banda de entrada 0). É isto que "histerese" significa, e é a
            // regra que o §82 pedia sem formalizar.
            const revertIsFree = (cur.step.drops ?? []).length === 0;
            const qDrift = persist.lastQ === undefined ? 0 : Math.abs(cur.Qp - persist.lastQ);
            const mayLeave = revertIsFree || marginOf(cur, floorsNow) >= h || qDrift >= 0.5;
            if (!mayLeave) pick = cur;
          }
        }
      }
      const predicted = input.marginCeiling !== undefined && marginOf(pick, floorsNow) <= input.marginCeiling;
      const d: DomainDecision = {
        domain: dom,
        D: pick.step.D,
        step: pick.step,
        cost: pick.cost,
        quality: { Qp: pick.Qp, Qf: pick.Qf, Qi: pick.Qi },
        floors: floorsNow,
        margin: marginOf(pick, floorsNow),
        why: `${minD > 0 ? `D${minD} exigido (capacidade${raisedFloor[dom] ? '/pré-requisito' : ''}); ` : ''}menor custo viável = ${pick.cost.toFixed(3)}${predicted ? `; folga ${marginOf(pick, floorsNow).toFixed(2)} dentro do previsto (ΔCtx ≤ ${input.marginCeiling})` : ''}`,
      };
      decisions[dom] = d;
      decided.add(dom);
      if (chosen[dom] !== d.D) {
        chosen[dom] = d.D;
        changed = true;
      }
    }
    if (!changed) break;
  }
  // Nenhum domínio pode terminar pendente: decisão ausente materializaria o
  // nível antigo para sempre, que é a pior forma de falha silenciosa.
  for (const dom of active) {
    if (decided.has(dom)) continue;
    const floorsNow = floors.get(dom)!;
    const cand = candidatesFor(dom, input.region, floorsNow, budget, cap);
    const cause: 'budget' | 'prereq' | 'quality' =
      cand.list.some((x) => x.feasible) ? 'prereq' : cand.list.every((x) => x.cost > budget + EPS) ? 'budget' : 'quality';
    const partial: DecisionSet = { regionId: input.region.id, decisions, totalCost: costOfSet(input.region, chosen), candidatesEvaluated: evaluated, coarse: true };
    return { kind: 'infeasible', error: infeasibleFor(dom, cand.list, floorsNow, budget, cause, deferred.get(dom)), fallback: partial };
  }

  // ——— DESCIDA COUPLED (fixpoint mínimo, não máximo) ———
  // O laço acima eleva pisos quando um domínio dependente exige capacidade do
  // vizinho (`prereq`). Elevar é fácil; o que falta em qualquer fixpoint por
  // elevação é o outro lado: se o dependente pôde descer, a exigência sobre o
  // vizinho deixou de existir e a elevação viraria herança paga para sempre.
  // Por isso a descida percorre o grafo de dependências em ordem topológica
  // inversa — um domínio só é rebaixado DEPOIS dos que dependem dele.
  const Dof = (d: Domain) => decisions[d]?.D;
  const demandsOn = (target: Domain) => {
    let need = 0;
    for (const other of active) {
      if (other === target) continue;
      const D = Dof(other);
      if (D === undefined) continue;
      const pr = prereqFloor(other, D, { ...chosen, [target]: 0 });
      if (!pr.ok && pr.need && pr.need.dom === target) need = Math.max(need, pr.need.D);
    }
    return need;
  };
  const outdeg = new Map<Domain, number>(
    active.map((d) => [d, ladderFor(d).steps.reduce((n, s) => n + Object.keys(s.prereq ?? {}).length, 0)]),
  );
  const descentOrder = [...active].sort((a, b) => outdeg.get(b)! - outdeg.get(a)!);
  for (const dom of descentOrder) {
    const base = floors.get(dom)!;
    const cur = decisions[dom];
    if (!cur) continue;
    for (let eff = Math.max(base.minD, demandsOn(dom)); eff >= base.minD; eff--) {
      const floorsNow = { ...base, minD: eff };
      const live = candidatesFor(dom, input.region, floorsNow, budget, cap).list.filter(
        (x) => x.feasible && prereqFloor(dom, x.step.D, chosen).ok,
      );
      const pick = live
        .filter((x) => x.cost < cur.cost - COST_EPS)
        .sort((a, b) => a.cost - b.cost || Math.abs(marginOf(a, floorsNow)) - Math.abs(marginOf(b, floorsNow)) || a.step.D - b.step.D)[0];
      if (!pick) break;
      decisions[dom] = {
        ...cur,
        D: pick.step.D,
        step: pick.step,
        cost: pick.cost,
        quality: { Qp: pick.Qp, Qf: pick.Qf, Qi: pick.Qi },
        floors: floorsNow,
        margin: marginOf(pick, floorsNow),
        why: `descida: D${cur.step.D} só existia por exigência recíproca que deixou de valer (novo mínimo D${pick.step.D})`,
      };
      chosen[dom] = pick.step.D;
      break;
    }
  }

  const set: DecisionSet = {
    regionId: input.region.id,
    decisions,
    totalCost: costOfSet(input.region, chosen),
    candidatesEvaluated: evaluated,
    coarse: cap > 0 && evaluated > cap,
  };
  if (set.totalCost > budget + EPS) {
    return {
      kind: 'infeasible',
      error: {
        domain: 'visual',
        bindingConstraint: 'budget',
        required: budget,
        bestAchieved: set.totalCost,
        atD: 0,
        message: `E_INFEASIBLE[budget] a soma dos mínimos de cada domínio (${set.totalCost.toFixed(3)}) excede o orçamento do frame (${budget.toFixed(3)}). O corte não é redistribuível: cada domínio já está no menor D que satisfaz seu requisito.`,
      },
      fallback: { ...set, coarse: true },
    };
  }
  return { kind: 'ok', regions: set };
}
