/**
 * UTS · Tese dos D — estrutura funcional de níveis de representação.
 *
 * IMPORTANTE (versão mais recente das decisões):
 *  - "D" NÃO significa dimensão física, nem matemática abstrata.
 *  - Os D são CAMADAS / CONCEITOS FUNCIONAIS para atingir objetivos da arquitetura.
 *  - Valores podem ser fracionários (D.x, D.x.25, D.x.5, D.x.75).
 *  - Cada D possui função operacional verificável (não são nomes vazios).
 *
 * D-MAXIMO:
 *  - Não há documento anterior no repositório (PromptTeseDosD.TXT não localizado).
 *  - Decisão registrada em docs/decisions.md: D-MÁXIMO é o nível mais avançado da
 *    estrutura ATUALMENTE DEFINIDA — implementado como valor dinâmico (máximo dos
 *    camadas registradas), para que a definição nunca fique presa a um número antigo.
 */

export interface DLayerDef {
  id: string;
  /** Coordenada de ordenação — pode ser fracionária. */
  value: number;
  name: string;
  /** 1. objetivo */
  purpose: string;
  /** 2. problema resolvido */
  solves: string;
  /** 3. representação */
  representation: string;
  /** 4. dados utilizados */
  data: string;
  /** 5. sistemas afetados */
  affected: string[];
  /** 6. integração */
  integration: string[];
  /** 7. custo */
  cost: string;
  /** 8. otimização */
  optimization: string;
  /** 9. resultado observável (como verificar em teste) */
  observable: string;
  /** Capacidades fornecidas (tags) — usadas na resolução. */
  provides: string[];
  /** Camada inferior que aproxima esta (fallback para o D-O15). */
  fallbackId?: string;
}

export interface DResolveResult {
  /** Camadas ativas, em ordem crescente de valor. */
  layers: DLayerDef[];
  /** Valor efetivo (após clamp em D-MAXIMO e floor). */
  value: number;
  /** Camada de fallback usada, se houve downgrade. */
  downgradedFrom: DLayerDef | null;
}

export class TeseDosD {
  static readonly MAX_ID = 'D-MAX';
  private layers = new Map<string, DLayerDef>();

  define(def: DLayerDef): void {
    if (this.layers.has(def.id)) throw new Error(`Tese dos D: camada já definida: ${def.id}`);
    if (!Number.isFinite(def.value)) throw new Error(`Tese dos D: valor inválido para ${def.id}`);
    this.layers.set(def.id, def);
  }

  get(id: string): DLayerDef | undefined {
    return this.layers.get(id);
  }

  layerIds(): string[] {
    return [...this.layers.keys()];
  }

  /** Camadas ordenadas por valor (menor → maior). */
  ordered(): DLayerDef[] {
    return [...this.layers.values()].sort((a, b) => a.value - b.value);
  }

  /** D-MAXIMO: o nível mais avançado da estrutura atualmente definida (dinâmico). */
  max(): DLayerDef {
    const all = this.ordered();
    if (all.length === 0) throw new Error('Tese dos D: nenhum D definido');
    return all[all.length - 1];
  }

  bottom(): DLayerDef {
    const all = this.ordered();
    if (all.length === 0) throw new Error('Tese dos D: nenhum D definido');
    return all[0];
  }

  /** Camadas que fornecem uma capacidade. */
  byCapability(tag: string): DLayerDef[] {
    return this.ordered().filter((l) => l.provides.includes(tag));
  }

  /** Fallback de uma camada (aproximação inferior) — null no fundo. */
  fallback(id: string): DLayerDef | null {
    const l = this.layers.get(id);
    if (!l?.fallbackId) return null;
    return this.layers.get(l.fallbackId) ?? null;
  }

  /**
   * Resolução operacional: dado o valor solicitado (ex.: pela relevância) e o
   * valor concedido (ex.: pelo D-O15 sob pressão de hardware), quais camadas
   * ficam ativas. Nunca abaixo do floor (D-0/D-1: estado semântico preservado).
   */
  resolve(opts: { requestedValue: number; grantedValue: number }): DResolveResult {
    const mx = this.max();
    const floor = this.bottom();
    const requested = Math.min(mx.value, Math.max(floor.value, opts.requestedValue));
    const granted = Math.min(requested, Math.max(floor.value, opts.grantedValue));
    const layers = this.ordered().filter((l) => l.value <= granted + 1e-9);
    const downgradedFrom = granted < requested - 1e-9 ? this.near(requested) : null;
    return { layers, value: granted, downgradedFrom };
  }

  private near(value: number): DLayerDef | null {
    let best: DLayerDef | null = null;
    for (const l of this.ordered()) {
      if (l.value <= value + 1e-9) best = l;
    }
    return best;
  }

  /**
   * Mapeia o nível de materialização RRW (0..1) para o valor de D ativo:
   *  detail 0 → até D-1 (estado semântico, abstrato);
   *  detail 1 → D-MAXIMO;
   *  entre → interpolação linear (valores fracionários permitidos).
   */
  valueForDetail(detail: number): number {
    const mx = this.max();
    const d1 = this.get('D-1')?.value ?? this.bottom().value + 1;
    const d = Math.min(1, Math.max(0, detail));
    return d <= 0 ? d1 : d1 + d * (mx.value - d1);
  }

  /** Descrição legível (docs/debug). */
  describe(): string {
    const lines: string[] = ['TESE DOS D — camadas funcionais (versão mais recente)'];
    for (const l of this.ordered()) {
      lines.push(
        [
          `${l.id} (valor=${l.value}) — ${l.name}`,
          `   objetivo: ${l.purpose}`,
          `   resolve: ${l.solves}`,
          `   representação: ${l.representation}`,
          `   dados: ${l.data}`,
          `   afetados: ${l.affected.join(', ')}`,
          `   integração: ${l.integration.join(', ')}`,
          `   custo: ${l.cost}`,
          `   otimização: ${l.optimization}`,
          `   observável: ${l.observable}`,
          `   fornece: ${l.provides.join(', ')}`,
          `   fallback: ${l.fallbackId ?? '—'}`,
        ].join('\n'),
      );
    }
    const mx = this.max();
    lines.push(`${TeseDosD.MAX_ID} — nível mais avançado atualmente definido (dinâmico) = ${mx.id} (valor=${mx.value})`);
    return lines.join('\n');
  }
}

/**
 * Conjunto de camadas ATUALMENTE DEFINIDO no projeto (versão mais recente).
 * A lista é extensível em runtime via tese.define(...).
 */
export function createDefaultTese(): TeseDosD {
  const t = new TeseDosD();
  t.define({
    id: 'D-0',
    value: 0,
    name: 'Presença',
    purpose: 'Garantir existência, identidade e tipagem de qualquer aspecto da realidade.',
    solves: 'Como uma coisa "existe" na representação sem nenhum custo de detalhe.',
    representation: 'Id, categoria aberta, estado bruto (alive/detail).',
    data: 'identidade, categoria, timestamps.',
    affected: ['rrw', 'ues/world', 'ai/memory'],
    integration: ['rrw.entities', 'memory.longTerm'],
    cost: 'Mínimo (tabela de ids).',
    optimization: 'Sempre ativo; nunca descarregável (é o estado mínimo).',
    observable: 'Entidade abstrata continua consultável por id/categoria.',
    provides: ['existence', 'identity'],
  });
  t.define({
    id: 'D-1',
    value: 1,
    name: 'Estado Semântico',
    purpose: 'Preservar o estado completo de significado: dados, relações, eventos, causas.',
    solves: 'O mundo continua "verdadeiro" mesmo quando nada está materializado.',
    representation: 'data aberta + relações + log de eventos + snapshots comprimidos.',
    data: 'propriedades, relações tipadas, eventos com causalidade, memórias.',
    affected: ['rrw', 'ues/society', 'ues/npc', 'ai'],
    integration: ['rrw.data', 'rrw.relations', 'rrw.events'],
    cost: 'Baixo (dados planos, sem geometria).',
    optimization: 'Preservado mesmo em abstração total (regra: nunca apagar estado).',
    observable: 'Abstrair e re-materializar mantém dados/relações idênticos (testado).',
    provides: ['state', 'relations', 'causality'],
    fallbackId: 'D-0',
  });
  t.define({
    id: 'D-2',
    value: 2,
    name: 'Processos Comportamentais',
    purpose: 'Fazer o comportamento evoluir (processos RRW com estados e tick).',
    solves: 'Mundo vivo: necessidades, clima, economia e sociedade evoluem sozinhos.',
    representation: 'Processos nomeados com tick materializado / tick abstrato.',
    data: 'estados de processo, parâmetros de comportamento.',
    affected: ['ues/npc', 'ues/society', 'ues/world (ambiente)'],
    integration: ['rrw.processes', 'd-o15.scheduler'],
    cost: 'Médio (lógica por tick).',
    optimization: 'Em abstração, processos rodam o tick abstrato (custo ~10x menor).',
    observable: 'Entidades fora do foco continuam evoluindo estado (testado em sociedade).',
    provides: ['behavior', 'processes'],
    fallbackId: 'D-1',
  });
  t.define({
    id: 'D-3',
    value: 3,
    name: 'Materialização Espacial',
    purpose: 'Materializar posição, forma e ocupação espacial quando relevante.',
    solves: 'Interação física/espacial exige detalhe que abstração não tem.',
    representation: 'Componentes de posição/geometria, terreno heightfield, colisões.',
    data: 'posições, heightfields, chunks, ocupação.',
    affected: ['ues/world', 'ues/graphics', 'ues/npc (movimento)'],
    integration: ['rrw.components', 'ues.world.chunks', 'd-o15 (streaming)'],
    cost: 'Alto (geometria + streaming).',
    optimization: 'Streaming por foco: materializa perto, abstrata longe (testado).',
    observable: 'Chunk descarregado vira estado; recarregado restaura entidades idênticas.',
    provides: ['spatial', 'geometry', 'terrain'],
    fallbackId: 'D-2',
  });
  t.define({
    id: 'D-4',
    value: 4,
    name: 'Detalhe Perceptual e Relacional Fino',
    purpose: 'Percepção de alta fidelidade, memória de curto prazo e relações finas.',
    solves: 'Agentes e observadores próximos precisam de detalhe rico e barato de obter.',
    representation: 'Percepção por raio, episódios de memória, confiança/debt finos, sombras por entidade.',
    data: 'percepções, episódios, confiança, eventos locais.',
    affected: ['ues/npc', 'ues/graphics', 'ai/memory'],
    integration: ['rrw.events', 'memory.shortTerm', 'graphics.frame'],
    cost: 'Alto (percepção por par, memória).',
    optimization: 'Só ativo no raio interno do foco; fora dele o estado vira lembrança agregada.',
    observable: 'NPC vê/ouve apenas o materializado no raio; distante lembra por agregado.',
    provides: ['perception', 'fine-relations', 'memory'],
    fallbackId: 'D-3',
  });
  t.define({
    id: 'D-O15',
    value: 15,
    name: 'Otimização',
    purpose: 'Escolher a MELHOR representação/processamento para o resultado necessário.',
    solves: 'Sistemas maiores que a simulação ingênua permitiria, sem destruir o resultado.',
    representation: 'Decisões de estratégia por sistema: detalhe, Hz, representação (full/coarse/aggregate/cached).',
    data: 'profiling (CPU/memória), hardware, relevância, custo estimado.',
    affected: ['todos'],
    integration: ['profiler', 'hardware', 'scheduler', 'tese.resolve'],
    cost: 'Baixo (metanível; roda a 2 Hz).',
    optimization: 'É a otimização: pressão → downgrade com floor de estado; folga → promoção.',
    observable: 'Sob carga, sistemas menos relevantes perdem Hz/detalhe; estado nunca se perde.',
    provides: ['optimization', 'adaptation'],
  });
  return t;
}
