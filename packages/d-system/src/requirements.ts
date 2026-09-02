import type { Domain, Ladder } from './types.ts';
import { ladderFor } from './ladders.ts';

/**
 * Requisitos → pisos de Q, derivados por capacidade (não por número chutado).
 *
 * Este é o mecanismo que impede a engine de "economizar" apagando o que o autor
 * pediu: se a cena exige `per_entity_detail`, todo D abaixo de 3 é infeasível
 * para aquela região, e o D-O15 é obrigado a gastar ou a reportar
 * `E_INFEASIBLE` — nunca a degradar em silêncio.
 *
 * `minD` é vincante e separado dos pisos: o otimizador não pode satisfazer os
 * pisos escolhendo um D mais barato que não tem a capacidade exigida.
 */
export interface DomainRequirements {
  domain: Domain;
  /** Capacidades que PRECISAM existir na representação materializada. */
  requires?: readonly string[];
  /** Capacidades que PRECISAM continuar reconstruíveis após abstrair (Tese §80/§81). */
  mustRecover?: readonly string[];
  /** Pisos numéricos explícitos. Sobrescrevem os derivados e ficam marcados como override. */
  floors?: { QpMin?: number; QfMin?: number; QiMin?: number };
}

export interface ResolvedFloors {
  domain: Domain;
  QpMin: number;
  QfMin: number;
  QiMin: number;
  /** Menor D que satisfaz capacidades + reconstrução. Vincante. */
  minD: number;
  /** Maior D disponível naquele domínio. */
  maxD: number;
  /** true se algum piso veio de override humano em vez de derivação. */
  overridden: boolean;
  reason: string;
}

/** Menor D cuja capacidade declarada cobre `requires`. */
export function deriveMinD(ladder: Ladder, requires: readonly string[], viaRecoverable = false): number {
  if (requires.length === 0) return 0;
  for (const s of ladder.steps) {
    const have = new Set(viaRecoverable ? s.recoverable : s.caps);
    if (requires.every((r) => have.has(r))) return s.D;
  }
  return Number.POSITIVE_INFINITY;
}

export function resolveRequirements(domain: Domain, req: DomainRequirements): ResolvedFloors {
  const ladder = ladderFor(domain);
  const requires = req.requires ?? [];
  const mustRecover = req.mustRecover ?? [];

  if (ladder.steps.length === 0) {
    throw new Error(
      `LADDER_NOT_DEFINED: domínio "${domain}" não tem escada nesta geração; ` +
        'existe como slot do contrato e não entra no espaço de otimização (§98.1).',
    );
  }

  const byCap = deriveMinD(ladder, requires, false);
  const byRecovery = deriveMinD(ladder, mustRecover, true);
  const minD = Math.max(byCap, byRecovery);

  if (!Number.isFinite(minD)) {
    const missing = !Number.isFinite(byCap) ? requires : mustRecover;
    const kind = !Number.isFinite(byCap) ? 'capacidade' : 'reconstrução';
    throw new Error(
      `REQUIREMENT_UNSATISFIABLE: nenhum D do domínio "${domain}" cobre (${kind}) ${JSON.stringify(missing)}. ` +
        'Isso é decisão de objetivo, não de otimização — criar um D exige os 10 requisitos da Tese §40.',
    );
  }

  const step = ladder.steps.find((s) => s.D === minD)!;
  const over = req.floors ?? {};
  const floors = {
    QpMin: over.QpMin ?? step.quality.Qp,
    QfMin: over.QfMin ?? step.quality.Qf,
    QiMin: over.QiMin ?? step.quality.Qi,
  };
  const overridden = over.QpMin !== undefined || over.QfMin !== undefined || over.QiMin !== undefined;

  const reason =
    requires.length + mustRecover.length === 0
      ? 'sem requisito: mínimo absoluto (D0)'
      : `menor D cobrindo ${requires.length} capacidade(s) + ${mustRecover.length} reconstrução(ões)`;

  return { domain, ...floors, minD, maxD: ladder.steps[ladder.steps.length - 1].D, overridden, reason };
}
