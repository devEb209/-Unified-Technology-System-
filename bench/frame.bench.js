#!/usr/bin/env node
// UTS :: bench/frame — frame extraction + renderer-backend cost at scale.
// Measures REAL ms for extractFrame and Null/Text manifests across world sizes.

import { createUTS, NullRenderer, TextRenderer } from '../src/index.js';

const CONFIGS = [
  { label: 'small (150 npcs, no settlement)' },
  { label: 'medium (600 npcs + village)', village: true },
  { label: 'large (2000 npcs + village)', village: true, npcs: 2000 },
];

console.log('\n=== UTS :: frame extraction benchmark ===\n');
console.log('scene'.padEnd(30), 'extract ms'.padStart(12), 'null ms'.padStart(9), 'text ms'.padStart(9), 'patches'.padStart(9), 'entities'.padStart(9));

for (const cfg of CONFIGS) {
  const uts = createUTS({ seed: 'frame-bench', log: { level: 'error' } });
  const n = cfg.npcs ?? (cfg.village ? 600 : 150);
  if (cfg.village) {
    uts.core.tools.execute('ues.create_settlement', { name: 'Bench Vila', pop: 40, nearRiver: false });
  }
  const side = Math.ceil(Math.sqrt(n)) * 14;
  for (let i = 0; i < n; i++) {
    const gx = (i % 45) * 14, gz = Math.floor(i / 45) * 14;
    uts.world.spawnNPC({ pos: [300 + gx, 0, 300 + gz] });
  }
  uts.ues.moveCamera([300 + side / 2, 40, 300 + side / 2]);
  uts.world.updateMaterialization(uts.ues.camera.pos);

  const WARM = 3, SAMPLES = 15;
  let tEx = 0, tNull = 0, tText = 0;
  let lastFrame = null;
  const nullR = new NullRenderer();
  const textR = new TextRenderer({ cols: 48, rows: 18 });
  for (let i = 0; i < WARM + SAMPLES; i++) {
    let t0 = performance.now();
    lastFrame = uts.ues.renderFrame();
    tEx += performance.now() - t0;
    t0 = performance.now();
    nullR.render(lastFrame);
    tNull += performance.now() - t0;
    if (i >= WARM) { t0 = performance.now(); textR.render(lastFrame); tText += performance.now() - t0; }
  }
  console.log(
    cfg.label.padEnd(30),
    (tEx / (WARM + SAMPLES)).toFixed(2).padStart(12),
    (tNull / (WARM + SAMPLES)).toFixed(2).padStart(9),
    (tText / SAMPLES).toFixed(2).padStart(9),
    String(lastFrame.terrain.patches.length).padStart(9),
    String(lastFrame.entities.length).padStart(9),
  );
}
console.log('');
