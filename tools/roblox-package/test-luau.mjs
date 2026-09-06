import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { LuauState } from 'luau-web';
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const modules = {
  Scheduler: 'roblox/UTS/BudgetScheduler.luau', Archive: 'roblox/UTS/SourceArchive.luau',
  Organizer: 'roblox/AutoOrganizer/Organizer.luau', Profile: 'roblox/Arkhe/VisualProfile.luau',
  Audit: 'roblox/Arkhe/SceneAudit.luau',
};
const passed = [];
const state = await LuauState.createAsync({ recordPass: name => { passed.push(name); console.log('PASS', name); } });
try {
  let bundled = '';
  for (const [name, relative] of Object.entries(modules)) {
    const source = fs.readFileSync(path.join(root, relative), 'utf8');
    state.loadstring(source, relative, true); // compile each independently as well
    bundled += `local ${name} = (function()\n${source}\nend)()\n`;
  }
  state.loadstring(fs.readFileSync(path.join(root, 'roblox/AutoOrganizer/Studio.luau'), 'utf8'), 'Studio', true);
  bundled += fs.readFileSync(path.join(root, 'tests/roblox/core.luau'), 'utf8');
  const test = state.loadstring(bundled, 'recovery-unit-tests', true);
  await test();
  if (passed.length < 25) throw new Error('Incomplete test execution');
  const report = { passed: passed.length, failed: 0, names: passed, environment: 'Luau WASM with mocked Roblox instances; NOT Studio' };
  if (process.argv[2]) fs.writeFileSync(process.argv[2], JSON.stringify(report, null, 2) + '\n');
  console.log(`Passed ${passed.length} Luau logic tests (Roblox API integration still needs Studio).`);
} finally { state.destroy(); }
