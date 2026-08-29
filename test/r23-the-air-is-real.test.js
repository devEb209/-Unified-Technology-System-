// R23 — O AR É REAL + O TERRENO É LENTE: FUMAÇA COMO SOLUÇÃO (solver
// Euleriano 3D de verdade: advecção semi-Lagrangiana, EMPUXO TÉRMICO,
// PROJEÇÃO DE PRESSÃO por Gauss-Seidel; os incêndios do mundo injetam e o
// céu materializa as colunas da SOLUÇÃO), A LENTE DE CENA (GLSL de
// superfície gerado por composição: neve por altitude+declive, musgo por
// umidade, cinza de incêndio, floração determinística; o programa do
// TERRENO é recompilado com o shader forjado; espelho JS = GLSL).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createUTS } from '../src/index.js';
import { Fluid3D, FLUID3D_CONST } from '../src/world/phenomena/fluid3d.js';
import { composeSurfacePipeline, SURFACE_PRESETS, SURFACE_STAGES } from '../src/agent/shader-smith.js';
import { terrainFS, TERRAIN_FS } from '../src/render/shaders.js';

// ------------------------------------------------------------- fluido 3D
test('r23: O FLUIDO 3D É SOLVER REAL — a fumaça SOBE por empuxo, viaja com o vento e o campo é incompressível', () => {
  const f = new Fluid3D({ nx: 16, ny: 12, nz: 16, cell: 12, origin: [0, 0, 0] });
  for (let i = 0; i < 80; i++) { f.emit(96, 6, 96, { amount: 0.4, heat: 2 }); f.step(0.1, { wind: [0, 0, 0] }); }
  const col = f.columnAt(96, 96);
  assert.ok(col, 'a coluna de fumaça existe');
  assert.ok(col.pos[1] > 9, `o centro de massa SUBIU (${col.pos[1].toFixed(1)}m, injetado a 6m) — empuxo térmico é lei`);
  const div = f.divergence();
  assert.ok(Math.abs(div) < 0.005, `∇·v ≈ 0 pós-projeção (${div.toExponential(1)}) — o ar não comprime`);
  // vento leva a coluna: emite, PARA de emitir, e o campo viaja (momento
  // ambiente entra por arrasto — a nuvem desce o vento inteira)
  const g = new Fluid3D({ nx: 24, ny: 12, nz: 16, cell: 12, origin: [0, 0, 0] });
  for (let i = 0; i < 25; i++) { g.emit(96, 6, 96, { amount: 0.4, heat: 2 }); g.step(0.1, { wind: [3, 0, 0] }); }
  for (let i = 0; i < 130; i++) g.step(0.1, { wind: [3, 0, 0] });
  const moved = g.peakColumns(1)[0];
  assert.ok(moved.pos[0] > 96 + 24, `o vento LEVOU a fumaça para leste (${moved.pos[0].toFixed(0)}m de 96m)`);
  // determinismo (a realidade não é aleatória)
  const h = new Fluid3D({ nx: 16, ny: 12, nz: 16, cell: 12, origin: [0, 0, 0] });
  for (let i = 0; i < 80; i++) { h.emit(96, 6, 96, { amount: 0.4, heat: 2 }); h.step(0.1, { wind: [0, 0, 0] }); }
  assert.ok(Buffer.from(f.dens.buffer).equals(Buffer.from(h.dens.buffer)), 'mesma história = mesma fumaça (byte a byte)');
  // snapshot/restore ESPESSO e fiel (≤1e-3: a representação esparso+quantizada
  // carrega as células vivas — ar parado é zero e NÃO viaja)
  const w2 = new Fluid3D({ nx: 16, ny: 12, nz: 16, cell: 12, origin: [999, 0, 999] });
  w2.restore(f.snapshot());
  let maxErr = 0;
  for (let q = 0; q < f.n; q++) maxErr = Math.max(maxErr, Math.abs(w2.dens[q] - f.dens[q]), Math.abs(w2.temp[q] - f.temp[q]));
  assert.ok(maxErr <= 1e-3, `restore fiel dentro de 1e-3 (erro máx ${maxErr.toExponential(1)})`);
  const wire = JSON.stringify(f.snapshot());
  assert.ok(wire.length < 6000, `o wire esparso é pequeno (${wire.length}B)`);
});

test('r23: A FUMAÇA DO MUNDO É A SOLUÇÃO — o incêndio injeta, a grade segue o foco, o frame carrega as colunas', () => {
  const uts = createUTS({ seed: 'fumaca-r23' });
  const w = uts.world;
  w.ues.run(5);
  const comb = w.combustion;
  // acha mato DENTRO da cobertura ATUAL do solver que ACENDA de verdade
  const o = w.fluid3d.origin, half = w.fluid3d.nx * w.fluid3d.cell;
  const inGrid = (x, z) => x > o[0] + 12 && x < o[0] + half - 12 && z > o[2] + 12 && z < o[2] + half - 12;
  let ev = null;
  for (let x = Math.ceil(o[0]); x < o[0] + half && !ev; x += 12) for (let z = Math.ceil(o[2]); z < o[2] + half; z += 12) {
    const c = comb._cell(x, z);
    if (c && c.fuel > 0.25 && !c.burning) { ev = comb.ignite(x, z); if (ev) break; }
  }
  if (!ev) {
    // sem mato acendível no foco: acende onde houver e ANDA até lá (a
    // grade segue o observador — é o caminhar até o incêndio)
    for (let x = 200; x < 840 && !ev; x += 16) for (let z = 200; z < 840 && !ev; z += 16) {
      const c = comb._cell(x, z);
      if (c && c.fuel > 0.25) { ev = comb.ignite(x, z); if (ev) { w.ues.moveCamera([x + 24, 30, z + 24]); } }
    }
  }
  assert.ok(ev, 'o incêndio acende (combustível seco existe)');
  // o fogo queima ENQUANTO tem combustível (a vida dele é medida no meio)
  let sawBurning = 0;
  for (let i = 0; i < 200; i++) { w.ues.tick(0.05); sawBurning = Math.max(sawBurning, [...comb.cells.values()].filter((c) => c.burning).length); }
  assert.ok(sawBurning > 0, `o fogo queima enquanto há combustível (pico ${sawBurning} células)`);
  const cols = w.fluid3d.peakColumns(4);
  assert.ok(cols.length >= 1, `o solver tem fumaça (${cols.length} colunas)`);
  const f = w.ues.renderFrame();
  assert.ok((f.smoke3d ?? []).length >= 1, 'o FRAME carrega as colunas da solução');
  // a grade segue o FOCO (D-O15): camera mudou => origem mudou
  const before = [...w.fluid3d.origin];
  w.ues.moveCamera([w.fluid3d.origin[0] + 500, 30, w.fluid3d.origin[2] + 500]);
  w.ues.run(5);
  assert.ok(w.fluid3d.origin[0] !== before[0], 'a grade do solver SEGUE o foco (recêntrise honesto)');
  // persiste no snapshot do mundo
  const snap = w.phenomenaSnapshot();
  const w2 = createUTS({ seed: 'x' }).world;
  w2.phenomenaRestore(snap);
  assert.ok(w2.fluid3d, 'o solver existe no mundo restaurado');
});

// ------------------------------------------------------ smith de cena
test('r23: A LENTE DE CENA — GLSL de superfície gerado, espelho provado, o TERRENO recompila', async () => {
  // lei da neve: alto e plano NEVA; baixo e penhasco não
  const inverno = composeSurfacePipeline(SURFACE_PRESETS.inverno);
  const altoPlano = inverno.js([0.5, 0.5, 0.5], { y: 40, ny: 1, wet: 0, x: 0, z: 0 });
  const baixo = inverno.js([0.5, 0.5, 0.5], { y: 6, ny: 1, wet: 0, x: 0, z: 0 });
  const íngreme = inverno.js([0.5, 0.5, 0.5], { y: 40, ny: 0.3, wet: 0, x: 0, z: 0 });
  assert.ok(altoPlano[0] > 0.85, `alto e plano acumula neve (${altoPlano[0].toFixed(2)})`);
  assert.ok(baixo[0] < 0.51 && íngreme[0] < 0.51, 'baixo e penhasco ficam sem neve (a física da camada fria)');
  // composição arbitrária + GLSL montado
  const mata = composeSurfacePipeline([...SURFACE_PRESETS['mata-viva'], { type: 'cinza', params: { amount: 0.2 } }]);
  assert.equal(mata.stages, 3);
  assert.equal(mata.selfTest.finite, true);
  assert.match(mata.glsl, /utsSurface/);
  assert.match(mata.glsl, /127\.1, 311\.7/, 'o hash determinístico da floração está no shader');
  // o terreno compila o GLSL forjado: terrainFS injeta definição E chamada
  const forged = terrainFS(mata.glsl);
  assert.ok(forged.includes(mata.glsl), 'o GLSL forjado está no shader do terreno');
  assert.match(forged, /col = utsSurface\(col, vPos, n, uWetness\);/, 'a chamada está no ponto certo (pós-luz, pré-aérea)');
  assert.ok(!TERRAIN_FS.includes('utsSurface'), 'o padrão continua limpo (sem lente)');
  // erros honestos
  assert.throws(() => composeSurfacePipeline([{ type: 'lava' }]), /desconhecido/);
  assert.throws(() => composeSurfacePipeline([{ type: 'neve', params: { alt: 900 } }]), /fora de/);
  // ponta a ponta pelo chat: tool → frame → renderer recompila o TERRENO
  const uts = createUTS({ seed: 'cena-r23' });
  uts.ues.run(1);
  const r = await uts.core.tools.execute('agent.surface', { preset: 'inverno' });
  assert.equal(r.applied, true);
  const f = uts.ues.renderFrame();
  assert.equal(f.style.surface?.hash, r.hash, 'o frame carrega a lente de cena');
  await uts.core.tools.execute('agent.surface', { remover: true });
  const f2 = uts.ues.renderFrame();
  assert.ok(!f2.style?.surface, 'remover devolve o terreno padrão');
});
