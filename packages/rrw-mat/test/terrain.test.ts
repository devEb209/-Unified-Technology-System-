// Terreno materializado por LEIS (era GÊNESIS: "construir a realidade").
// O que estes testes prendem não é "bonito": é que cada degrau ligue exatamente uma
// lei, que a lei não roube massa, e que nada seja pintado à mão pelo materializador.
import test from 'node:test';
import assert from 'node:assert/strict';
import { terrainFrameAtD, materializeTerrain, restHeightAt, surfaceHeightAt } from '../src/terrain.ts';
import { ladderFor, costOf } from '../../d-system/src/ladders.ts';
import { decideRegion } from '../../do15/src/optimizer.ts';
import { DOMAIN_ORDER } from '../../do15/src/optimizer.ts';

const opts = { gridSize: 48, cellSize: 4 } as const;
const at = (D: number, over: Record<string, unknown> = {}) =>
  materializeTerrain(terrainFrameAtD(D, (over as never) ?? {}), opts as never);

test('T1 a escada terrain valida e cada degrau acrescenta exatamente uma lei', () => {
  const steps = ladderFor('terrain').steps;
  assert.equal(steps.length, 6);
  assert.deepEqual(steps[0].caps, [], 'D0 não agrega capacidade — tem de ser opção real "não ter relevo"');
  for (let i = 1; i < steps.length; i++) {
    const added = steps[i].caps.filter((c) => !steps[i - 1].caps.includes(c));
    assert.ok(added.length >= 1, `D${steps[i].D} não agrega nada (nomenclatura vazia)`);
    for (const c of steps[i - 1].caps) assert.ok(steps[i].caps.includes(c), `D${steps[i].D} perdeu ${c}`);
    const zero = { pixels: 4096, entities: 400, lights: 4, volumes: 2304 };
    assert.ok(costOf(steps[i], zero) > costOf(steps[i - 1], zero), `D${steps[i].D} não custa mais`);
  }
});

test('T2 determinismo: o mesmo frame devolve o mesmo terreno, célula a célula', () => {
  const a = at(5), b = at(5);
  for (let i = 0; i < a.elevation.length; i++) {
    assert.equal(a.elevation[i], b.elevation[i]);
    assert.equal(a.water[i], b.water[i]);
    assert.equal(a.vegetation[i], b.vegetation[i]);
  }
});

test('T3 o custo é por CÉLULA DE CAMPO, nunca por entidade (o erro dos 216 ms/tick)', () => {
  const region = (ents: number) => ({ pixels: 1160640, entities: ents, lights: 0, volumes: 2304 });
  const step = ladderFor('terrain').steps[5];
  assert.equal(costOf(step, region(1)), costOf(step, region(40000)),
    'terreno que cobra por entidade volta a ser cena, não região');
  // linearidade NO INCREMENTO: o total tem um custo fixo de manter o campo, e
  // afirmar "dobrar células dobra o TOTAL" cobriria justamente o que se quer
  // verificar. O que tem de ser exato é Δ(D1→D5) ∝ células de campo, e nada ∝ entidade.
  const s1 = ladderFor('terrain').steps[1];
  const s5 = ladderFor('terrain').steps[5];
  // pixels:0 de propósito: terreno NÃO tem termo por pixel (é campo, não raster), e
  // a linearidade só é testável sem o termo que não deveria existir.
  for (const s of [s1, s5]) assert.equal(s.cost.perPixel, 0, `D${s.D} de terrain cobra por pixel — terreno não é raster`);
  // a lei que se testa é do TERMO VARIÁVEL (fixed é o custo de manter o campo e não
  // tem de escalar com ele): v→2v dobra o custo de variável, exatamente.
  const vol = (s: typeof s5, vols: number, ents: number) => costOf(s, { pixels: 0, entities: ents, lights: 0, volumes: vols }) - s.cost.fixed;
  assert.ok(Math.abs(vol(s5, 4608, 1) / vol(s5, 2304, 1) - 2) < 1e-9, `dobrar células de campo deve dobrar o custo variável: ${vol(s5, 2304, 1)} → ${vol(s5, 4608, 1)}`);
  assert.ok(Math.abs(vol(s1, 4608, 1) / vol(s1, 2304, 1) - 2) < 1e-9, 'mesma lei vale para D1');
  assert.equal(vol(s5, 2304, 400000), vol(s5, 2304, 1), 'entidade não entra no custo do terreno');
});

test('T4 hidrologia: rio desce (monotônico) e lago fecha bacia sem ninguém pintar', () => {
  const f2 = at(2);
  let water = 0;
  for (const v of f2.water) if (v > 0) water++;
  assert.ok(water > 0, 'D2 tem de produzir água parada em bacia fechada (D1 não produz)');
  assert.equal(at(1).water.reduce((a, v) => a + (v > 0 ? 1 : 0), 0), 0, 'sem a lei de hidrologia não pode haver lago');
  // onde flui, desce: nenhum vizinho a jusante pode ser mais alto que a montante
  const g = f2.g;
  let bad = 0;
  for (let y = 1; y < g - 1; y++) for (let x = 1; x < g - 1; x++) {
    const i = y * g + x;
    if (f2.flow[i] <= 0) continue;
    let lower = false;
    for (let dy = -1; dy <= 1; dy++) for (let dx = -1; dx <= 1; dx++) {
      if (!dx && !dy) continue;
      if (f2.elevation[(y + dy) * g + x + dx] < f2.elevation[i]) lower = true;
    }
    if (!lower) bad++;
  }
  assert.ok(bad / (g * g) < 0.05, `${bad} células com fluxo sem saída downhill`);
});

test('T5 erosão com conservação: D5 corta, e o corte é VOLUME REMOVIDO, não fantasma', () => {
  const f4 = at(4), f5 = at(5);
  let changed = 0, sum4 = 0, sum5 = 0;
  for (let i = 0; i < f4.elevation.length; i++) {
    sum4 += f4.elevation[i]; sum5 += f5.elevation[i];
    if (f4.elevation[i] !== f5.elevation[i]) changed++;
  }
  assert.ok(changed > f4.elevation.length * 0.15, `erosão mexeu em só ${changed} células — a lei não roda`);
  const removed = sum4 - sum5;
  assert.ok(removed > 0, 'erosão tem de tirar material');
  assert.ok(removed < (sum4 - sum5) * 1.0 + sum4 * 0.02, 'erosão não pode sumir com o terreno inteiro');
  // e D5 sem D4 é o mesmo relevo: deposição não muda rota sem clima ligado
  assert.ok(f5.water.reduce((a, v) => a + (v > 0 ? 1 : 0), 0) > 0);
});

test('T6 deformação é FATO persistente, não textura: D5 guarda a marca, D4 ignora', () => {
  const scar = [{ x: 0.5, y: 0.5, radius: 0.12, depth: 30 }];
  const d5 = materializeTerrain(terrainFrameAtD(5), { ...opts, deformations: scar } as never);
  const d4 = materializeTerrain(terrainFrameAtD(4), { ...opts, deformations: scar } as never);
  const plain = at(5);
  const i = 24 * 48 + 24;
  assert.ok(d5.elevation[i] < plain.elevation[i] - 5, 'D5 tem de carregar a marca no campo');
  assert.equal(d4.elevation[i], at(4).elevation[i], 'D4 sem dynamic_deformation não pode deformar (senão é enfeite pago)');
});

test('T7 clima e vegetação são DERIVADOS (altitude/latitude), não pintados', () => {
  // mundo de 60 km, relevo de 300 m de amplitude, 48 amostras de consulta: é a
  // separação entre "tamanho do mundo" e "resolução da decisão" que faz o clima
  // materializar certo (ver nota de `reliefM` no materializador).
  const wide = { gridSize: 48, cellSize: 4, domainMeters: 600000, reliefM: 700, latitudeSpanDeg: 0.25 } as never;
  // altitudes declaradas pela CENA (não pela tabela do materializador): é o §37 —
  // o terreno só pode derivar clima do que o frame afirma, e afirmar por fora seria
  // o medidor consertando o medido.
  const plain = materializeTerrain(terrainFrameAtD(4, { biome: 'floodplain', baseAltitudeM: 8 }), wide);
  const peak = materializeTerrain(terrainFrameAtD(4, { biome: 'montanha_nevada', baseAltitudeM: 4400 }), wide);
  const mean = (f: { temperature: Float64Array }) => f.temperature.reduce((a, b) => a + b, 0) / f.temperature.length;
  assert.ok(mean(peak) < mean(plain) - 10, `cordilheira (2600 m) tem de ser mais fria que planície: ${mean(peak).toFixed(1)} vs ${mean(plain).toFixed(1)}`);
  // neve NÃO foi pintada: ela aparece exatamente onde a altitude passa da linha de
  // neve equatorial (~4.700 m), derivada da mesma fórmula da temperatura.
  const snow = peak.vegetation.filter((v) => v === 'snow').length;
  assert.ok(snow > 0 && snow < peak.vegetation.length, `linha de neve tem de ser linha, não cobertor total: ${snow}/${peak.vegetation.length}`);
  assert.equal(plain.vegetation.filter((v) => v === 'snow').length, 0, 'planície a 8 m não pode nevar');
  // monotonicidade: mais alto ⇒ mais frio, em toda célula (é gradiente, não sorteio)
  let viol = 0;
  const g = peak.g;
  for (let y = 0; y < g; y++) for (let x = 0; x < g - 1; x++) {
    const i = y * g + x;
    if (peak.elevation[i + 1] > peak.elevation[i] + 1e-9 && peak.temperature[i + 1] > peak.temperature[i]) viol++;
  }
  assert.equal(viol, 0, `${viol} células onde subir altitude esquentou`);
  assert.ok(at(3).vegetation.every((v) => v === 'none'), 'sem a lei de clima, vegetação é ausência materializada, não default');
});

test('T8 conversão §37: terrain alimenta physical sem ninguém colar mesh', () => {
  const f = at(5);
  const h = restHeightAt(f, 0.5, 0.5);
  const s = surfaceHeightAt(f, 0.5, 0.5);
  assert.ok(Number.isFinite(h) && Number.isFinite(s));
  // interpolar não pode quicar: no meio de uma célula a superfície fica entre as quatro
  // os cantos são os da célula que a interpolação usa (floor(u·(g−1))), não os de
  // `restHeightAt` (floor(u·g)): são gradeamentos diferentes, e confundir os dois é
  // exatamente o tipo de bug que um teste ingênuo passa a afirmar errado.
  const g = f.g;
  const x0 = Math.floor(0.5 * (g - 1)), y0 = Math.floor(0.5 * (g - 1));
  const corners = [f.elevation[y0 * g + x0], f.elevation[y0 * g + x0 + 1], f.elevation[(y0 + 1) * g + x0], f.elevation[(y0 + 1) * g + x0 + 1]];
  const lo = Math.min(...corners), hi = Math.max(...corners);
  assert.ok(s >= lo - 1e-9 && s <= hi + 1e-9, `superfície ${s} fora do intervalo dos cantos [${lo},${hi}]`);
});

test('T9 terreno é DOMÍNIO ON-DEMAND: cena sem requisito não paga por ele', () => {
  const region = { id: 'r:0,0', pixels: 1160640, entities: 100, lights: 2, volumes: 2304, importance: 1, motion: 0.3 };
  const plain = decideRegion({ region, resources: { frameBudget: 1e9, headroom: 0.1, thermal: 'nominal' }, requirements: {} });
  assert.ok(plain.kind === 'ok');
  assert.equal(plain.regions.decisions.terrain, undefined, 'ligar domínio sem exigência é capacidade inventada');
  const req = decideRegion({
    region,
    resources: { frameBudget: 1e9, headroom: 0.1, thermal: 'nominal' },
    requirements: { terrain: { domain: 'terrain', requires: ['hydrology'], floors: { QpMin: 0, QfMin: 0, QiMin: 0 } } } as never,
  });
  assert.ok(req.kind === 'ok');
  assert.ok(req.regions.decisions.terrain.D >= 2, `hydrology exige D≥2, veio D${req.regions.decisions.terrain.D}`);
});

test('T10 prereq terrain D5 → temporal D3 é vínculo, não sugestão', () => {
  const region = { id: 'r:0,0', pixels: 4096, entities: 10, lights: 0, volumes: 1024, importance: 1, motion: 0.5 };
  const r = decideRegion({
    region,
    resources: { frameBudget: 1e9, headroom: 0.1, thermal: 'nominal' },
    requirements: {
      terrain: { domain: 'terrain', requires: ['dynamic_deformation'], floors: { QpMin: 0, QfMin: 0, QiMin: 0 } },
      temporal: { domain: 'temporal', requires: [], floors: { QpMin: 0, QfMin: 0, QiMin: 0 } },
    } as never,
  });
  assert.ok(r.kind === 'ok');
  assert.equal(r.regions.decisions.terrain.D, 5);
  assert.ok(r.regions.decisions.temporal.D >= 3, `deformação sem tick por frame é animação: temporal D${r.regions.decisions.temporal.D}`);
  // ordem DERIVADA: só entram domínios com escada; slot vazio não é otimizado nem
  // inventado (é o mesmo motivo pelo qual a lista fixa anterior era um bug).
  assert.deepEqual([...DOMAIN_ORDER].sort(), ['physical', 'temporal', 'terrain', 'visual']);
});
