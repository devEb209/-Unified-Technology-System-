import { makeDFrame, type DFrame } from '../../dframe/src/dframe.ts';
import { materializeVisual } from '../../rrw-mat/src/materialize.ts';
import { ladderFor, costOf } from '../../d-system/src/ladders.ts';

/**
 * HARNESS DE CALIBRAÇÃO — rode no aparelho-alvo (itel A70 / Termux), não aqui.
 *
 * Nada neste arquivo mede GPU. Ele mede UMA coisa honesta: quantas unidades de
 * custo da escada o CPU deste aparelho executa por segundo materializando campo.
 * Isso calibra `unitsPerSecond` do plan.json. Usar o número como se fosse
 * capacidade de raster seria exatamente o tipo de falso atestado que
 * UTS l.2181 proíbe.
 */
export interface DeviceProfile {
  readonly kind: 'uts.genesis.device';
  readonly schemaVersion: 1;
  readonly unitsPerSecond: number;
  readonly iterations: number;
  readonly gridSize: number;
  readonly msPerIteration: number;
  readonly workloadUnits: number;
  readonly calibrationBand?: { low: string; high: string; msLow: number; msHigh: number };
  /** o que esta constante NÃO cobre — viaja junto, para nenhum leitor a tratar como universal */
  readonly limitation: string;
  readonly note: string;
  readonly measuredAt: string;
  readonly userAgent?: string;
}

export const CALIBRATION: { D: number; cells: { w: number; h: number; entities: number; lights: number; volumes: number } } = {
  // workload de referência: célula com mundo denso, o caso que a escada precisa separar
  D: 3,
  cells: { w: 1280, h: 720, entities: 60, lights: 2, volumes: 4000 },
};

export function calibrationFrame(D = CALIBRATION.D): DFrame {
  const R: Record<string, unknown> = { biome_code: 'calib', heightfield_ref: 'hf:calib', heightfield_sample_rate: D >= 1 ? 0.5 : 0 };
  if (D >= 2) Object.assign(R, { material_class: 'soil', spectral_band_code: 'nir', light_sample_rate: 0.5 });
  if (D >= 3) Object.assign(R, { shadow_atlas_index: 0, matter_state_code: 'wet' });
  if (D >= 4) Object.assign(R, { sky_model: 'turbid' });
  if (D >= 5) Object.assign(R, { volume_sample_rate: 1, detail_class: 'high' });
  return makeDFrame({
    regionId: 'r:calib',
    domain: 'visual',
    DCurrent: D,
    DTarget: D,
    Priority: 1,
    CostBudget: 1e9,
    Representation: R,
    QualityRequired: {
      QpMin: 0, QfMin: 0, QiMin: 0, minD: 0, maxD: 5,
      class: { Qp: 'PERCEPTUAL', Qf: 'FUNCTIONAL', Qi: 'INFORMATIONAL' },
      mode: 'MEASURE', overridden: false, reason: 'calibração',
    },
    OmittedFacts: [],
    RecoverySet: ['biome_code'],
    RecoveryRequired: [],
    Hysteresis: { h: 0.04, lastChangeTick: 0, lastQ: 1, lastD: D },
    entities: D >= 3 ? Array.from({ length: CALIBRATION.cells.entities }, (_, i) => ({ id: `c${i}`, delta: { matter_state_code: i % 2 ? 'wet' : 'dry' } })) : [],
  });
}

export interface MeasureOptions {
  iterations?: number;
  gridSize?: number;
  warmup?: number;
  /** degraus comparados na calibração por diferença (default 1 e 5) */
  Dlow?: number;
  Dhigh?: number;
}

function timeFrame(frame: DFrame, iterations: number, gridSize: number): number {
  for (let i = 0; i < Math.min(20, iterations); i++) materializeVisual(frame, { gridSize });
  const t0 = process.hrtime.bigint();
  for (let i = 0; i < iterations; i++) materializeVisual(frame, { gridSize });
  return Number(process.hrtime.bigint() - t0) / 1e6 / iterations;
}

/**
 * Calibração por DIFERENÇA DE TRABALHO.
 *
 * Medir um único D e dividir o custo nominal dele pelo tempo mistura duas
 * despesas que não são comparáveis: o custo da escada conta termos por
 * luz/volume que este materializador GEN-1 não executa, e o tempo medido inclui
 * o custo fixo de alocar as grades. Subtraindo dois degraus, o fixo cancela e o
 * que sobra é trabalho marginal real por unidade de custo da escada — que é
 * exatamente a grandeza que `argmin C` precisa para converter ms em unidades.
 *
 * Ainda assim NÃO é medida de GPU: é o teto do lado CPU da pipeline.
 */
export function measureDevice(opts: MeasureOptions = {}, env: { userAgent?: string } = {}): DeviceProfile {
  const iterations = opts.iterations ?? 400;
  const gridSize = opts.gridSize ?? 48;
  const Dlow = opts.Dlow ?? 1;
  const Dhigh = opts.Dhigh ?? 5;
  const region = {
    pixels: CALIBRATION.cells.w * CALIBRATION.cells.h,
    entities: CALIBRATION.cells.entities,
    lights: CALIBRATION.cells.lights,
    volumes: CALIBRATION.cells.volumes,
  };
  const steps = ladderFor('visual').steps;
  // duas leituras: sob carga, uma única amostra pode inverter a ordem dos
  // degraus e o Δ virar ruído. Escolher a leitura com maior diferença é o que
  // torna o número estável — e não mascara falha: se NENHUMA das duas separa os
  // degraus, a calibração é declarada involta abaixo.
  const reads = [0, 1].map(() => {
    const a = timeFrame(calibrationFrame(Dlow), iterations, gridSize);
    const b = timeFrame(calibrationFrame(Dhigh), iterations, gridSize);
    return { msLow: a, msHigh: b };
  });
  reads.sort((x, y) => (y.msHigh - y.msLow) - (x.msHigh - x.msLow));
  const { msLow, msHigh } = reads[0];
  const unitsLow = costOf(steps[Dlow], region);
  const unitsHigh = costOf(steps[Dhigh], region);
  const dUnits = unitsHigh - unitsLow;
  const dMs = msHigh - msLow;
  const LIMITATION =
    'LIMITAÇÃO CONHECIDA: os termos perLight/perVolume da escada ainda não têm trabalho correspondente neste materializador, ' +
    'logo unitsPerSecond só é válido no regime dominado por pixels. Um plano que dependa de custo por volume está fora da validade da calibração.';
  const unitsPerSecond = dMs > 0 && dUnits > 0 ? dUnits / (dMs / 1000) : 0;
  return {
    kind: 'uts.genesis.device',
    schemaVersion: 1,
    unitsPerSecond: Math.round(unitsPerSecond),
    iterations,
    gridSize,
    msPerIteration: Math.round(msHigh * 1000) / 1000,
    workloadUnits: Math.round(dUnits * 1000) / 1000,
    calibrationBand: { low: `D${Dlow}`, high: `D${Dhigh}`, msLow: Math.round(msLow * 1000) / 1000, msHigh: Math.round(msHigh * 1000) / 1000 },
    note:
      dMs > 0
        ? `${LIMITATION} unitsPerSecond vem da diferença D${Dhigh}−D${Dlow} (${dUnits.toFixed(1)} unidades por ${dMs.toFixed(3)} ms) materializando ${gridSize}×${gridSize} em CPU. NÃO é raster, fill-rate nem GPU.`
        : `FALHOU: D${Dhigh} não custou mais que D${Dlow} (${msHigh.toFixed(3)} ms vs ${msLow.toFixed(3)} ms). Calibração sem diferença mensurável não produz constante — aumente --iterations ou o grid, ou o número seria inventado.`,
    limitation: LIMITATION,
    measuredAt: new Date().toISOString(),
    userAgent: env.userAgent,
  };
}
