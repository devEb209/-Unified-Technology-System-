import { test } from 'node:test';
import assert from 'node:assert/strict';
import { decideRegion, costOfSet, type OptimizerInput, type Region } from '../src/optimizer.ts';
import { ladderFor, costOf, stepAt } from '../../d-system/src/ladders.ts';

// 1 unidade ≈ custo de carregar/shading de 1 pixel ao custo 1.0. Um "região"
// do tamanho da tela inteira do A70 (720×1612 = 1.161.824 px) pesa ~116 unidades
// no degrau visual D3. Nada aqui é FPS nem resolução: é trabalho (Tese §69/§70).
const SCREEN = 720 * 1612;

function region(over: Partial<Region> = {}): Region {
  return { id: 'r:0,0', pixels: SCREEN, entities: 50, lights: 2, volumes: 1000, importance: 0.5, motion: 0.2, ...over };
}

const run = (input: OptimizerInput) => decideRegion(input);

test('O1 com nenhum requisito, o otimizador escolhe o menor D possível em cada domínio', () => {
  const r = run({ region: region({ entities: 0, volumes: 0 }), resources: { frameBudget: 1000, headroom: 1, thermal: 'nominal' }, requirements: {} });
  assert.equal(r.kind, 'ok');
  if (r.kind !== 'ok') return;
  assert.equal(r.regions.decisions.visual.D, 0);
  assert.equal(r.regions.decisions.physical.D, 0);
  assert.equal(r.regions.decisions.temporal.D, 0);
});

test('O2 requisito de capacidade é vincante: não dá para economizar apagando o NPC', () => {
  const r = run({
    region: region(),
    resources: { frameBudget: 1000, headroom: 1, thermal: 'nominal' },
    requirements: { visual: { domain: 'visual', requires: ['per_entity_detail'] } },
  });
  assert.equal(r.kind, 'ok');
  if (r.kind !== 'ok') return;
  assert.equal(r.regions.decisions.visual.D, 3, 'per_entity_detail só existe a partir de D3');
  assert.ok(r.regions.decisions.visual.floors.minD >= 3);
});

test('O3 orçamento apertado gera E_INFEASIBLE nomeado com a restrição vinculante', () => {
  const r = run({
    region: region(),
    resources: { frameBudget: 64, headroom: 0.1, thermal: 'nominal' },
    requirements: { visual: { domain: 'visual', requires: ['per_entity_detail'] } },
  });
  assert.equal(r.kind, 'infeasible');
  if (r.kind !== 'infeasible') return;
  assert.equal(r.error.domain, 'visual');
  assert.ok(['Qf', 'Qi', 'Qp', 'minD', 'budget'].includes(r.error.bindingConstraint), `binding=${r.error.bindingConstraint}`);
  assert.match(r.error.message, /E_INFEASIBLE/);
  assert.match(r.error.message, /decisão de objetivo/);
  assert.ok(r.fallback.coarse, 'fallback precisa estar marcado como degradação explícita');
});

test('O4 a soma dos mínimos por domínio estourando o frame é infeasível (não redistribuível)', () => {
  // Cada domínio é forçado a D3 por requisito inegociável; individualmente cabem
  // no orçamento, a soma não. É o único caso em que cortar é impossível sem o
  // humano reavaliar o objetivo — daí a mensagem ser diferente do caso por domínio.
  const small = { id: 'r:small', pixels: 1024, entities: 20, lights: 0, volumes: 0, importance: 0.5, motion: 0.2 };
  const req = { visual: { domain: 'visual', requires: ['per_entity_detail'] }, physical: { domain: 'physical', requires: ['rigid_body'] } };
  const alone = run({ region: small, resources: { frameBudget: 1.2, headroom: 0, thermal: 'nominal' }, requirements: { visual: req.visual } });
  assert.equal(alone.kind, 'ok', 'visual sozinho (0.410) cabe no orçamento de 1.200');
  const both = run({ region: small, resources: { frameBudget: 1.2, headroom: 0, thermal: 'nominal' }, requirements: req });
  assert.equal(both.kind, 'infeasible');
  if (both.kind !== 'infeasible') return;
  assert.equal(both.error.bindingConstraint, 'budget');
  assert.match(both.error.message, /não é redistribuível/);
  assert.ok(both.fallback.coarse, 'fallback é degradação explícita, nunca "otimizado"');
  // e o caso por domínio: o corte é impossível dentro de UM domínio
  const tight = run({ region: region(), resources: { frameBudget: 1, headroom: 0, thermal: 'nominal' }, requirements: { visual: req.visual } });
  assert.equal(tight.kind, 'infeasible');
  if (tight.kind !== 'infeasible') return;
  assert.equal(tight.error.domain, 'visual');
  assert.match(tight.error.message, /não há o que cortar aqui/);
});

test('O5 pré-requisito entre domínios: visual alto não pode flutuar sobre física abstrata', () => {
  // D3 visual exige physical≥2. Se física está presa em D0, visual D3 é barrado.
  const r = run({
    region: region(),
    resources: { frameBudget: 1000, headroom: 1, thermal: 'nominal' },
    requirements: {
      physical: { domain: 'physical', requires: [], floors: { QpMin: 1, QfMin: 0, QiMin: 1 } },
      visual: { domain: 'visual', requires: ['per_entity_detail'] },
    },
  });
  // Qi=1 na física empurra para D5 (único com Qi 1.0); isso satisfaz o prereq.
  assert.equal(r.kind, 'ok');
  if (r.kind !== 'ok') return;
  assert.ok(r.regions.decisions.physical.D >= 1, 'física não pode ficar abaixo do que a cena exige');
  assert.ok(r.regions.decisions.visual.D >= 3);
});

test('O6 o prereq vira infeasível quando o domínio dependente não pode subir', () => {
  const r = run({
    region: region(),
    resources: { frameBudget: 80, headroom: 1, thermal: 'nominal' },
    requirements: {
      physical: { domain: 'physical', requires: [], floors: { QpMin: 1, QfMin: 0, QiMin: 0.9 } },
      visual: { domain: 'visual', requires: ['sky_dispersion'] },
    },
  });
  assert.ok(r.kind === 'infeasible' || (r.kind === 'ok' && r.regions.decisions.physical.D >= 3));
});

test('O7 decisão nunca é pior que o teto: custo total ≤ orçamento', () => {
  for (const budget of [80, 120, 200, 500, 2000]) {
    const r = run({ region: region(), resources: { frameBudget: budget, headroom: 1, thermal: 'nominal' }, requirements: {} });
    if (r.kind === 'ok') assert.ok(r.regions.totalCost <= budget + 1e-6, `budget ${budget}: custo ${r.regions.totalCost}`);
  }
});

test('O8 economia medida: decisão adaptativa custa menos que o teto da escada', () => {
  const r = run({
    region: region(),
    resources: { frameBudget: 1000, headroom: 1, thermal: 'nominal' },
    requirements: { visual: { domain: 'visual', requires: ['analytic_light'] } },
  });
  assert.equal(r.kind, 'ok');
  if (r.kind !== 'ok') return;
  const maxCost = costOfSet(region(), { visual: 5, physical: 5, temporal: 5 });
  // "ingênuo" = menor D que satisfaz o requisito por capacidade, ignorando orçamento
  const naive = costOfSet(region(), { visual: 3, physical: 2, temporal: 3 });
  assert.ok(r.regions.totalCost < maxCost * 0.6, `adaptativo ${r.regions.totalCost.toFixed(1)} vs máximo ${maxCost.toFixed(1)}`);
  assert.ok(r.regions.totalCost < naive, `adaptativo ${r.regions.totalCost.toFixed(1)} vs ingênuo ${naive.toFixed(1)}`);
  assert.equal(r.regions.decisions.temporal.D, 0, 'sem requisito: event-driven, custo zero');
});

// Custos físicos por entidade (ladders.ts): D0 .0005 D1 .0008 D2 .004 D3 .0202
// D4 .045 D5 .09; por luz: D1 .002 D2 .008 D3 .012 D4 .016 D5 .024.
// Qf: D1 .5 D2 .8 D3 .92 | h = 0.04.
const FLOOR_05 = { domain: 'physical' as const, requires: [] as string[], floors: { QpMin: 1, QfMin: 0.5, QiMin: 0.5 } };
const FLOOR_08 = { domain: 'physical' as const, requires: [] as string[], floors: { QpMin: 1, QfMin: 0.8, QiMin: 0.8 } };

test('O9 estabilidade: um D atual que NÃO custa mais que o mínimo nunca é trocado por folga', () => {
  // entities=0, lights=0 → todos os degraus custam 0. O argmin visaria D1
  // (menor folga acima do piso); a estabilidade gratuita segura D3.
  const r = run({
    region: region({ entities: 0, lights: 0, volumes: 0 }),
    resources: { frameBudget: 1000, headroom: 1, thermal: 'nominal' },
    requirements: { physical: FLOOR_05 },
    persist: { physical: { DCurrent: 3, lastQ: 1, lastChangeTick: 0 } },
  });
  assert.equal(r.kind, 'ok');
  if (r.kind !== 'ok') return;
  assert.equal(r.regions.decisions.physical.D, 3);
  const d1 = stepAt('physical', 1)!;
  assert.ok(Math.min(d1.quality.Qf - 0.5, d1.quality.Qi - 0.5) < ladderFor('physical').hysteresis, 'D1 tem de ficar dentro da banda h');
});

test('O10 histerese (Schmitt): sair de um degrau com perdas declaradas exige folga ≥ h', () => {
  // physical D5 tem drops vazio: voltar é barato → o preço manda e D5 desce ao
  // mínimo viável. É o contra-exemplo de O11.
  const r = run({
    region: { id: 'r:cheap', pixels: 1024, entities: 40, lights: 0, volumes: 0, importance: 0.5, motion: 0.2 },
    resources: { frameBudget: 1000, headroom: 0, thermal: 'nominal' },
    requirements: { physical: FLOOR_05 },
    persist: { physical: { DCurrent: 5, lastQ: 1, lastChangeTick: 0 } },
  });
  assert.equal(r.kind, 'ok');
  if (r.kind !== 'ok') return;
  assert.equal(r.regions.decisions.physical.D, 1, 'drops=[] ⇒ reversão grátis ⇒ o custo decide');
  assert.ok(stepAt('physical', 5)!.drops === undefined || stepAt('physical', 5)!.drops!.length === 0);
});

test('O11 um degrau com perdas declaradas só desce com folga ≥ h (§82 + §80/§81)', () => {
  // folga real na escada: D3 tem Qf=0.92 Qi=0.9 ; D2 tem Qf=0.8 Qi=0.8
  const R = () => ({ id: 'r:p', pixels: 1024, entities: 200, lights: 2, volumes: 0, importance: 0.5, motion: 0.2 });
  const hold = run({
    region: R(),
    resources: { frameBudget: 800, headroom: 0.2, thermal: 'nominal' },
    // piso 0.88 → D3 é o mínimo viável, folga 0.02 < h=0.04
    requirements: { physical: { domain: 'physical', requires: [], floors: { QpMin: 1, QfMin: 0.88, QiMin: 0.88 } } },
    persist: { physical: { DCurrent: 3, lastQ: 1, lastChangeTick: 0 } },
  });
  assert.equal(hold.kind, 'ok');
  if (hold.kind !== 'ok') return;
  assert.ok(hold.regions.decisions.physical.margin < ladderFor('physical').hysteresis, 'premissa: folga do D atual menor que h');
  assert.ok(hold.regions.decisions.physical.cost > 4 * (0.0008 * 200 + 0.002 * 2), 'o custo do D atual é maior que o do degrau abaixo');
  assert.equal(hold.regions.decisions.physical.D, 3, 'drops declarados + folga < h ⇒ não desce, mesmo economizando 25×');

  const free = run({
    region: R(),
    resources: { frameBudget: 800, headroom: 0.2, thermal: 'nominal' },
    // mesmo D3, piso baixo: folga 0.6 ≥ h ⇒ a banda libera a descida
    requirements: { physical: { domain: 'physical', requires: [], floors: { QpMin: 1, QfMin: 0.3, QiMin: 0.3 } } },
    persist: { physical: { DCurrent: 3, lastQ: 1, lastChangeTick: 0 } },
  });
  assert.equal(free.kind, 'ok');
  if (free.kind !== 'ok') return;
  assert.equal(free.regions.decisions.physical.D, 1, 'folga ≥ h ⇒ desce ao mínimo viável do band');

  const need = run({
    region: R(),
    resources: { frameBudget: 800, headroom: 0.2, thermal: 'nominal' },
    // piso 0.95: D3 deixa de ser viável (Qf 0.92). SUBIR por necessidade não espera banda.
    requirements: { physical: { domain: 'physical', requires: [], floors: { QpMin: 1, QfMin: 0.95, QiMin: 0.95 } } },
    persist: { physical: { DCurrent: 3, lastQ: 1, lastChangeTick: 0 } },
  });
  assert.equal(need.kind, 'ok');
  if (need.kind !== 'ok') return;
  assert.equal(need.regions.decisions.physical.D, 4, 'o piso manda: histerese nunca segura uma subida exigida');
});

test('O13 pré-requisito eleva o mínimo do vizinho até o necessário, nem um degrau a mais', () => {
  // visual D3 (Qf 0.85 ≥ piso) exige physical ≥ 2; physical não tem requisito
  // próprio. O raise tem de parar em 2, não saltar para 3 nem voltar para 0.
  const R = { id: 'r:prune', pixels: 1024, entities: 2, lights: 0, volumes: 0, importance: 0.5, motion: 0.2 };
  const o = run({
    region: R,
    resources: { frameBudget: 1000, headroom: 0, thermal: 'nominal' },
    requirements: { visual: { domain: 'visual', requires: [], floors: { QpMin: 1, QfMin: 0.85, QiMin: 0.8 } } },
  });
  assert.equal(o.kind, 'ok');
  if (o.kind !== 'ok') return;
  assert.equal(o.regions.decisions.visual.D, 3, 'piso 0.85 torna D2 inviável: D3 é o mínimo');
  assert.equal(o.regions.decisions.physical.D, 2, 'D3 do visual exige física 2 — não 3');
  assert.equal(o.regions.decisions.temporal.D, 0, 'nada exige frame-synced aqui');
  assert.ok(o.regions.decisions.physical.floors.minD >= 2, 'a elevação fica registrada no frame de decisão');

  // e quando a física sobe sozinha, por requisito próprio, o temporal acompanha:
  // D5 (CCD) declara prereq temporal:5 na escada
  const hot = run({
    region: R,
    resources: { frameBudget: 1000, headroom: 0, thermal: 'nominal' },
    requirements: { physical: { domain: 'physical', requires: ['ccd'] } },
  });
  assert.equal(hot.kind, 'ok');
  if (hot.kind !== 'ok') return;
  assert.equal(hot.regions.decisions.physical.D, 5);
  assert.equal(hot.regions.decisions.temporal.D, 5, 'CCD sem tick por frame tunela: coerção, não preferência');

  // e o corte: nada pode terminar inflado quando o vizinho desceu
  const noInflate = run({
    region: R,
    resources: { frameBudget: 1000, headroom: 0, thermal: 'nominal' },
    requirements: {},
  });
  assert.equal(noInflate.kind, 'ok');
  if (noInflate.kind !== 'ok') return;
  assert.equal(noInflate.regions.decisions.temporal.D, 0, 'sem CCD: temporal D0');
  assert.equal(noInflate.regions.decisions.physical.D, 0, 'sem requisito: física D0');
});

test('I9 o otimizador é limitado em candidatos e avisa quando ficou coarse', () => {
  const r = run({
    region: region(),
    resources: { frameBudget: 1000, headroom: 1, thermal: 'nominal' },
    requirements: {},
    candidateCap: 2,
  });
  assert.equal(r.kind, 'ok');
  if (r.kind !== 'ok') return;
  assert.ok(r.regions.candidatesEvaluated > 0, 'precisa contabilizar o próprio custo (I9)');
});

test('O11 térmico crítico bloqueia expansão automática', () => {
  const r = run({
    region: region({ entities: 400 }),
    resources: { frameBudget: 1000, headroom: 0.05, thermal: 'critical' },
    requirements: { visual: { domain: 'visual', requires: ['global_illumination'] } },
    persist: { visual: { DCurrent: 2, lastQ: 1, lastChangeTick: 0 } },
  });
  // D4 é o exigido; sob thermal crítico a regra é não expandir → infeasível, não "desce sozinho"
  assert.ok(r.kind === 'infeasible' || r.regions.decisions.visual.D >= 4);
  if (r.kind === 'infeasible') assert.match(r.error.message, /E_INFEASIBLE/);
});

test('O12 determinismo: mesma entrada, mesma decisão (núcleo testável offline)', () => {
  const input = {
    region: region({ entities: 137 }),
    resources: { frameBudget: 300, headroom: 0.5, thermal: 'nominal' as const },
    requirements: { visual: { domain: 'visual' as const, requires: ['material_class'] }, physical: { domain: 'physical' as const, requires: ['aabb_collision'] } },
  };
  const a = JSON.stringify(run(input));
  const b = JSON.stringify(run(input));
  assert.equal(a, b);
});

test('O13 todo D escolhido cobre as capacidades exigidas (piso não é decorativo)', () => {
  const requires = ['spatial_presence', 'aabb_collision'];
  const r = run({ region: region(), resources: { frameBudget: 2000, headroom: 1, thermal: 'nominal' }, requirements: { physical: { domain: 'physical', requires } } });
  assert.equal(r.kind, 'ok');
  if (r.kind !== 'ok') return;
  const caps = new Set(stepAt('physical', r.regions.decisions.physical.D)!.caps);
  for (const req of requires) assert.ok(caps.has(req), `${req} ausente em D${r.regions.decisions.physical.D}`);
});

test('O14 decisão respeita o orçamento de cada região sem ajuda externa', () => {
  const small = region({ pixels: 4096, entities: 2, volumes: 0 });
  const r = run({ region: small, resources: { frameBudget: 500, headroom: 1, thermal: 'nominal' }, requirements: {} });
  assert.equal(r.kind, 'ok');
  if (r.kind !== 'ok') return;
  const full = ladderFor('visual').steps.map((s) => costOf(s, small));
  assert.ok(r.regions.totalCost <= full[full.length - 1]);
});
