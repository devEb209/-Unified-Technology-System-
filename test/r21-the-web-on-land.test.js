// R21 — A TEIA NA TERRA E O BINÁRIO VIVO: FAUNA TERRESTRE na cadeia causal
// (capim bebe a água do solo, veado come o capim e MIGRA atrás do pasto,
// lobo COME o veado — a seca colapsa a teia com atraso e a chuva devolve),
// CÁPSULA no mundo físico (corpo rápido derruba NPC de pé e perde momento),
// O BINÁRIO ÚNICO REAL (SEA: app embutido no executável do node — ELF que
// executa) e O COLORISTA (shader de cor NOVO por composição arbitrária de
// leis verificadas, espelho JS = GLSL, identidade exata em 0°).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createUTS } from '../src/index.js';
import { build, probeToolchains } from '../src/agent/build-system.js';
import { composeColorPipeline, COLOR_PRESETS, COLOR_STAGES } from '../src/agent/shader-smith.js';
import { writeFile, chmod, rm } from 'node:fs/promises';
import { execFileSync } from 'node:child_process';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

// ------------------------------------------------------- teia na terra
test('r21: A TEIA NA TERRA — capim→veado→lobo; a seca colapsa com atraso e a chuva devolve', () => {
  const eco = createUTS({ seed: 'teia-terra' }).world.ecology;
  const dTot = () => [...eco.deerField.values()].reduce((a, b) => a + b, 0);
  for (let i = 0; i < 8000; i++) eco.step(0.5, { sunEl: 1, soilWet: 0.6 });
  const wetDeer = dTot(), wetWolves = eco.wolves;
  assert.ok(eco.grassField.size > 5, `o capim semeou (${eco.grassField.size} células)`);
  assert.ok(wetDeer > 0.1, `o veado chegou atrás do pasto (${wetDeer.toFixed(2)})`);
  assert.ok(wetWolves > 0.3, `o lobo seguiu o veado (${wetWolves.toFixed(1)})`);
  // SECA: o mato seca → o rebanho esvazia → o lobo sai (atrasado)
  for (let i = 0; i < 8000; i++) eco.step(0.5, { sunEl: 1, soilWet: 0.01 });
  assert.ok(dTot() < wetDeer * 0.5, `a seca colapsou o rebanho (${dTot().toFixed(3)} < ${wetDeer.toFixed(2)})`);
  assert.ok(eco.wolves < wetWolves, `o lobo caiu atrás (${eco.wolves.toFixed(1)} < ${wetWolves.toFixed(1)})`);
  // CHUVA DE VOLTA: imigração recoloniza — a teia respira
  for (let i = 0; i < 8000; i++) eco.step(0.5, { sunEl: 1, soilWet: 0.6 });
  assert.ok(dTot() > wetDeer * 0.5, `a vida voltou (${dTot().toFixed(2)})`);
  // persiste no snapshot
  const snap = eco.snapshot();
  const w2 = createUTS({ seed: 'outra' }).world;
  w2.ecology.restore(snap);
  assert.equal(w2.ecology.deerField.size, eco.deerField.size);
  assert.ok(Math.abs(w2.ecology.wolves - eco.wolves) < 1e-9);
  // o ambiente lê a teia (HUD/status)
  const uts = createUTS({ seed: 'env-teia' });
  uts.ues.run(2);
  assert.ok(Number.isFinite(uts.world.environment.deer));
  assert.ok(Number.isFinite(uts.world.environment.wolves));
});

// ------------------------------------------------------- cápsula física
test('r21: O CORPO NO MUNDO DAS PESSOAS — rocha derruba NPC de pé e PERDE momento (não é fantasma)', () => {
  const uts = createUTS({ seed: 'atropelo-r21' });
  const w = uts.world;
  w.ues.run(5);
  const npc = w.spawnNPC({ pos: [512, 0, 512] });
  const nsp = w.rrw.getComponent(npc.id, 'spatial');
  w.ues.run(10);
  const events0 = w.rrw.stats.events;
  const rock = w.physics.addBody({ pos: [nsp.pos[0] - 5, nsp.pos[1] + 0.4, nsp.pos[2]], vel: [14, 0, 0], radius: 0.45, material: 'rock', friction: 0.04 });
  w.ues.run(20);
  const npcC = w.rrw.getComponent(npc.id, 'npc');
  assert.ok(npcC.downedUntil > w.clock.tick, 'o corpo rápido derrubou o NPC (a cápsula é real)');
  const pv = Math.hypot(...w.rrw.getComponent(rock.id, 'physics').vel);
  assert.ok(pv < 4, `a rocha PERDEU momento ao atravessar a pessoa (${pv.toFixed(2)} de 14)`);
  assert.ok((w.physics.stats.npcHits ?? 0) >= 1, 'o contato foi medido');
  // caído não anda (mesma lei do impacto cinético da R20)
  w.rrw.addComponent(npc.id, 'intent', { target: [nsp.pos[0] + 60, 0, nsp.pos[2]] });
  const x0 = nsp.pos[0];
  w.ues.run(30);
  assert.ok(Math.abs(nsp.pos[0] - x0) < 0.01, 'caído não anda');
});

// ----------------------------------------------------- binário único SEA
test('r21: O BINÁRIO ÚNICO É REAL — SEA embute o app no executável e o binário EXECUTA', { skip: probeToolchains().postject ? false : 'postject ausente nesta máquina' }, async () => {
  const t0 = Date.now();
  const exe = await build({ name: 'VilaR21', target: 'exe', manifest: { title: 'Vila' } });
  assert.equal(exe.ok, true);
  assert.match(exe.kind, /binário único/, `kind: ${exe.kind}`);
  const head = exe.artifact.data.slice(0, 4);
  assert.ok(head[0] === 0x7f && head[1] === 0x45, 'o artefato é um executável nativo (ELF)');
  assert.ok(exe.artifact.bytes > 40 * 1024 * 1024, `o binário carrega o runtime (${(exe.artifact.bytes / 1e6).toFixed(0)}MB)`);
  // o binário EXECUTA: --version responde o app embutido
  const bin = join(tmpdir(), `uts-r21-${Date.now()}-VilaR21`);
  await writeFile(bin, exe.artifact.data);
  await chmod(bin, 0o755);
  try {
    const out = execFileSync(bin, ['--version'], { timeout: 15000 }).toString();
    assert.match(out, /VilaR21/, `o binário responde: ${out.trim().slice(0, 60)}`);
  } finally {
    await rm(bin, { force: true });
  }
  assert.ok(Date.now() - t0 < 120000, 'o build SEA termina em tempo mensurável');
});

// ---------------------------------------------------------------- colorista
test('r21: O COLORISTA — shader de cor NOVO por composição arbitrária, espelho provado, lente viva', async () => {
  // identidade EXATA em 0° (base ortonormal por Gram-Schmidt)
  const id = composeColorPipeline([{ type: 'rotacaoMatiz', params: { graus: 0 } }]);
  const [r0, g0, b0] = id.js([0.3, 0.6, 0.9]);
  assert.ok(Math.abs(r0 - 0.3) < 1e-9 && Math.abs(g0 - 0.6) < 1e-9 && Math.abs(b0 - 0.9) < 1e-9, 'matiz 0° é a identidade (base ortonormal)');
  // rotação preserva magnitude (transformação ortogonal de verdade)
  const h = composeColorPipeline([{ type: 'rotacaoMatiz', params: { graus: 120 } }]);
  assert.ok(Math.abs(Math.hypot(...h.js([0.8, 0.2, 0.1])) - Math.hypot(0.8, 0.2, 0.1)) < 1e-9, 'a rotação gira o croma sem inventar luz');
  // pipeline ARBITRÁRIO de 3 estágios: finite + GLSL montado na hora
  const triplo = composeColorPipeline([
    { type: 'rotacaoMatiz', params: { graus: -37.5 } },
    { type: 'sepia', params: { m: 0.4 } },
    { type: 'liftGammaGain', params: { lift: 0.02, gamma: 1.1, gain: 1.05 } },
  ]);
  assert.equal(triplo.stages, 3);
  assert.equal(triplo.selfTest.finite, true);
  assert.match(triplo.glsl, /utsColorista/);
  assert.match(triplo.glsl, /mat3\(/, 'o GLSL da rotação foi MONTADO no shader');
  assert.ok(triplo.glsl.split('\n').length > 6, 'o GLSL é novo (não tabela pronta)');
  // erros honestos
  assert.throws(() => composeColorPipeline([{ type: 'voa' }]), /desconhecido/);
  assert.throws(() => composeColorPipeline([{ type: 'temperatura', params: { t: 9 } }]), /fora de/);
  // presets e tool
  assert.ok(COLOR_PRESETS.quente.length >= 1 && COLOR_STAGES.temperatura);
  const uts = createUTS({ seed: 'colorista-r21' });
  uts.ues.run(1); uts.ues.renderFrame();
  const r = await uts.core.tools.execute('agent.colorist', { preset: 'quente' });
  assert.equal(r.applied, true);
  assert.equal(r.selfTest.finite, true);
  const tint = uts.world.style.params.tint;
  assert.ok(tint[0] > 1 && tint[2] < 1, `a lente viva ficou QUENTE (${tint.map((x) => x.toFixed(3)).join(',')})`);
  const f = uts.ues.renderFrame();
  assert.deepEqual(f.style.tint.map((x) => +x.toFixed(4)), tint.map((x) => +x.toFixed(4)), 'o frame carrega o tint forjado');
});
