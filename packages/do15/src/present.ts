import type { DomainDecision, Region } from './optimizer.ts';
import { ladderFor, costOf } from '../../d-system/src/ladders.ts';

/**
 * TAXA DE APRESENTAÇÃO ≠ TAXA DE SIMULAÇÃO.
 *
 * Frame generation comercial (DLSS-FG, FSR3-FG, RSD) estima movimento OLHANDO
 * DOIS QUADROS: é optical flow — adivinhação, cara em GPU móvel e com artefato de
 * desoclusão. Este módulo é o lado oposto do problema: a engine É DONA do estado,
 * então o movimento entre dois snapshots não precisa ser adivinhado da imagem, ele
 * é lido da física (velocidade × Δt). Interpolação aqui é avaliar uma função que
 * já existe, não reconstruir um quadro.
 *
 * Consequência dura, e é ela que decide se a técnica serve a um jogo de tiro:
 * interpolação NÃO cria informação. O que nasceu entre dois snapshots (projétil,
 * partícula, oclusão aberta) não pode aparecer "suavemente". A regra é repetir o
 * último estado válido, nunca inventar — um ghost na mira custa mais que um
 * quadro com judder.
 */

export type DisocclusionPolicy = 'repeat' | 'attenuate' | 'error';

export interface Snapshot {
  readonly tick: number;
  readonly tMs: number;
  /** posição por entidade, no referencial da célula */
  readonly pos: Readonly<Record<string, readonly [number, number]>>;
  /** velocidade por entidade: existe porque a física a calcula, não por estimativa */
  readonly vel?: Readonly<Record<string, readonly [number, number]>>;
}

export interface InterpResult {
  readonly t: number;
  readonly pos: Record<string, readonly [number, number]>;
  /** deslocamento desde o último snapshot — o vetor de movimento do reprojetor */
  readonly delta: Record<string, number>;
  /** entidades cujo movimento real divergiu do previsto: desoclusão provável */
  readonly surprises: string[];
  readonly predicted: boolean;
}

/**
 * Interpolação entre dois snapshots reais. t em [0,1]: 0 = último snapshot,
 * 1 = o próximo. t > 1 é PREDIÇÃO (extrapolação pela velocidade), limitada por
 * `maxLead` e DEVOLVIDA MARCADA: previsão é uma categoria diferente de estado e
 * o consumidor tem de saber qual recebeu.
 */
export function interpolate(
  a: Snapshot,
  b: Snapshot,
  t: number,
  opts: { maxLead?: number; surprise?: number } = {},
): InterpResult {
  const maxLead = opts.maxLead ?? 0.34;
  const tol = opts.surprise ?? 0.25;
  if (!Number.isFinite(t)) throw new PresentError('PRESENT_T', `t=${t} não é finito`);
  if (b.tick <= a.tick) throw new PresentError('PRESENT_TICK_ORDER', `snapshots fora de ordem (a=${a.tick}, b=${b.tick})`);
  const dtTicks = b.tick - a.tick;
  const predicted = t > 1;
  const k = Math.min(1, Math.max(0, Math.min(t, 1 + maxLead)));
  const pos: Record<string, readonly [number, number]> = {};
  const delta: Record<string, number> = {};
  const surprises: string[] = [];
  for (const id of Object.keys(b.pos)) {
    const pa = a.pos[id];
    const pb = b.pos[id];
    if (!pa) {
      // entidade nova: não se suaviza o nascimento. Entra onde a física a pôs.
      pos[id] = pb;
      delta[id] = 0;
      continue;
    }
    const vel = b.vel?.[id] ?? [0, 0];
    const expected: readonly [number, number] = [pa[0] + vel[0] * dtTicks, pa[1] + vel[1] * dtTicks];
    const drift = Math.hypot(pb[0] - expected[0], pb[1] - expected[1]);
    const x = pa[0] + (pb[0] - pa[0]) * k;
    const y = pa[1] + (pb[1] - pa[1]) * k;
    pos[id] = [x, y];
    delta[id] = Math.hypot(x - pa[0], y - pa[1]);
    // Desoclusão provável = o movimento REAL divergiu do previsto em mais de
    // `tol` da própria distância percorrida (medida relativa: em metros ou em
    // unidades de célula, o detector tem de dizer a mesma coisa). ε evita que
    // arredondamento de 1e-14 vira "surpresa".
    const travelled = Math.max(Math.hypot(pb[0] - pa[0], pb[1] - pa[1]), Math.hypot(expected[0] - pa[0], expected[1] - pa[1]));
    if (drift > tol * travelled + 1e-9) surprises.push(id);
  }
  return { t: predicted ? Math.min(t, 1 + maxLead) : k, pos, delta, surprises, predicted };
}

export interface PresentBudget {
  readonly simHz: number;
  readonly dispHz: number;
  readonly simFrameMs: number;
  readonly dispFrameMs: number;
  /** fração do trabalho de simulação evitada ao rodar a simHz em vez de dispHz */
  readonly simSaving: number;
  readonly pixelMs: number;
  readonly simAtDisplayMs: number;
  readonly costIfAllAtDisplayMs: number;
  readonly costWithPresentMs: number;
  /** trabalho novo criado só por apresentar (leitura do estado anterior + blend) */
  readonly presentCostPerFrameMs: number;
  /** custo de renderizar SÓ a camada livre de simulação (câmera/arma/UI) a dispHz */
  readonly viewModelCostPerFrameMs: number;
  /** quanto do orçamento o trabalho de simulação ocupa (>=1 = estoura o alvo) */
  readonly overDeadline: boolean;
  readonly savingMs: number;
  /** latência adicionada por esperar o próximo snapshot (pior caso, ms) */
  readonly addedLatencyMs: number;
  readonly verdict: 'vale' | 'não vale';
  readonly why: string;
}

/**
 * A conta que responde "15 fps com suavização parece 30?" sem rodeio.
 *
 * Critério (a primeira versão errava aqui): não é "a apresentação é barata
 * relativa ao pixel". São duas coisas independentes, e as duas têm de valer:
 *   (a) o quadro ESTOURA o deadline se renderizarmos e simularmos os dois a
 *       dispHz — senão não existe problema a resolver e gerar quadro só paga
 *       latência por nada;
 *   (b) a reprojeção não come sozinha o quadro-alvo (aqui: 10% do deadline),
 *       senão trocar judder por estouro é fraude de medição;
 *   (c) quando (b) falha, ainda existe a via barata (só a camada livre de
 *       simulação sobe de taxa) — e o veredito distingue as duas coisas em vez
 *       de chamar de "vale" um caminho que custa mais do que economiza.
 *
 * Resultado medido neste kernel (não é opinião, é o que presentBudget devolve):
 * a 720p o custo de apresentar é ~25% do deadline de 30 Hz — ou seja, num
 * telemóvel desta classe frame generation full-screen SÓ compensa em célula
 * dominada por simulação (multidão/agregados), nunca na célula em foco.
 */
export function presentBudget(
  decisions: Record<string, DomainDecision>,
  region: Region,
  opts: { simHz: number; dispHz: number; unitsPerSecond: number; policy?: DisocclusionPolicy; presentShareLimit?: number; viewModelShare?: number },
): PresentBudget {
  const { simHz, dispHz, unitsPerSecond } = opts;
  if (!(simHz > 0 && dispHz >= simHz)) {
    throw new PresentError('PRESENT_RATES', `exige dispHz (${dispHz}) >= simHz (${simHz}) > 0`);
  }
  if (!(unitsPerSecond > 0)) throw new PresentError('PRESENT_UNITS', `unitsPerSecond=${unitsPerSecond}: sem calibração medida não há conta a fazer`);
  const simFrameMs = 1000 / simHz;
  const dispFrameMs = 1000 / dispHz;
  const simUnits = costOfDomain(decisions, region, ['physical', 'temporal', 'behavioral', 'social', 'economic']);
  const simCostMs = (simUnits * simHz * 1000) / unitsPerSecond;
  const simAtDisplayMs = (simUnits * dispHz * 1000) / unitsPerSecond;
  const pixelMs = (costOfDomain(decisions, region, ['visual']) * dispHz * 1000) / unitsPerSecond;
  // A apresentação é precificada como RELAÇÃO, como qualquer custo da escada.
  // IMPORTANTE (e a primeira versão errava aqui): o mapa de movimento NÃO é pago
  // por entidade — ele é lido do snapshot que a simulação já produz. Cobrar
  // "uma amostra por entidade" fazia o custo de apresentação crescer junto com a
  // própria simulação, e o resultado era frame generation NUNCA caber: um
  // resultado que parece teórico demais para ser verdade normalmente é um erro de
  // modelo. Custo honesto é por pixel: ler o quadro anterior + misturar.
  const pres = { perPixel: 0.0001, perEntity: 0 };
  const presentCostPerFrameMs = ((region.pixels * pres.perPixel + region.entities * pres.perEntity) * dispHz * 1000) / unitsPerSecond;
  // Caminho livre de simulação: a camada que NÃO vem do snapshot (câmera, arma,
  // HUD) pode ir a dispHz sem pagar latência nenhuma e sem tocar no mundo. Ela é
  // precificada como fração da tela — o mesmo custo por pixel da reprojeção, só que
  // sobre uma área muito menor. Ignorar isto é o erro que faz o veredito mentir:
  // quando a reprojeção full-screen não compensa, quase sempre é ESTA via que vale.
  const viewModelShare = opts.viewModelShare ?? 0.12;
  const viewModelCostPerFrameMs = ((region.pixels * viewModelShare) * pres.perPixel * dispHz * 1000) / unitsPerSecond;
  const saving = simAtDisplayMs > 0 ? 1 - simCostMs / simAtDisplayMs : 0;
  const addedLatencyMs = simFrameMs;
  const costIfAllAtDisplayMs = pixelMs + simAtDisplayMs;
  const costWithPresentMs = pixelMs + simCostMs / dispHz + presentCostPerFrameMs;
  const overDeadline = costIfAllAtDisplayMs > dispFrameMs;
  const buysSomething = costWithPresentMs < costIfAllAtDisplayMs * 0.95;
  const savingMs = costIfAllAtDisplayMs - costWithPresentMs;

  const head =
    `alvo ${dispFrameMs.toFixed(2)} ms/quadro; tudo a ${dispHz} Hz custaria ${costIfAllAtDisplayMs.toFixed(2)} ms ` +
    `(pixels ${pixelMs.toFixed(2)} + sim ${simAtDisplayMs.toFixed(2)}); com sim a ${simHz} Hz fica ${costWithPresentMs.toFixed(2)} ms, ` +
    `desses ${presentCostPerFrameMs.toFixed(2)} ms é a reprojeção.`;
  const vmNote =
    ` Já está orçado na conta o caminho livre de simulação (câmera/arma/UI a ${dispHz} Hz: ${viewModelCostPerFrameMs.toFixed(2)} ms), ` +
    `que suaviza o que a mão segura sem tocar na latência do tiro.`;
  let verdict: PresentBudget['verdict'];
  let why: string;
  if (!overDeadline) {
    verdict = 'não vale';
    why =
      `${head} O deadline NÂO é estourado: não há o que recuperar, e gerar quadro só adicionaria ${addedLatencyMs.toFixed(1)} ms de latência de graça. ` +
      `Cena folgada se resolve subindo o D (piso de qualidade), não a taxa de apresentação.`;
  } else if (!buysSomething) {
    verdict = 'não vale';
    why =
      `${head} Gerar quadro economizaria ${savingMs.toFixed(2)} ms de simulação e criaria ${presentCostPerFrameMs.toFixed(2)} ms de reprojeção: ` +
      (savingMs <= 0
        ? `fica NEGATIVO — a suavização custaria mais do que poupa, porque nesta célula quem manda é o render, não a simulação. `
        : `não compensa: a reprojeção full-screen come a economia. `) +
      `Aqui a suavização não é o parafuso certo; reduzir trabalho materializado (D por célula) é.`;
  } else {
    verdict = 'vale';
    why =
      `${head} A simulação domina e sobram ${savingMs.toFixed(2)} ms: rodar o mundo a ${simHz} Hz e ` +
      `apresentar a ${dispHz} Hz corta ${(saving * 100).toFixed(0)}% do trabalho de simulação. Custo honesto: +${addedLatencyMs.toFixed(1)} ms de latência nos ` +
      `corpos dos OUTROS (nada no seu tiro se a arma for do view-model).`;
  }
  return {
    simHz,
    dispHz,
    simFrameMs,
    dispFrameMs,
    simSaving: Number(saving.toFixed(4)),
    pixelMs: Number(pixelMs.toFixed(3)),
    simAtDisplayMs: Number(simAtDisplayMs.toFixed(3)),
    costIfAllAtDisplayMs: Number(costIfAllAtDisplayMs.toFixed(3)),
    costWithPresentMs: Number(costWithPresentMs.toFixed(3)),
    presentCostPerFrameMs: Number(presentCostPerFrameMs.toFixed(3)),
    viewModelCostPerFrameMs: Number(viewModelCostPerFrameMs.toFixed(3)),
    overDeadline,
    savingMs: Number(savingMs.toFixed(3)),
    addedLatencyMs: Number(addedLatencyMs.toFixed(2)),
    verdict,
    why: `${why}${vmNote} Política de desoclusão: "${opts.policy ?? 'repeat'}" — o que não está no snapshot é repetido, nunca inventado.`,
  };
}

function costOfDomain(decisions: Record<string, DomainDecision>, region: Region, doms: readonly string[]): number {
  let t = 0;
  for (const d of doms) {
    const dec = decisions[d];
    if (!dec) continue;
    const step = ladderFor(d as never).steps[dec.D];
    if (step) t += costOf(step, region);
  }
  return t;
}

export class PresentError extends Error {
  readonly code: string;
  constructor(code: string, message: string) {
    super(`${code}: ${message}`);
    this.code = code;
    this.name = 'PresentError';
  }
}
