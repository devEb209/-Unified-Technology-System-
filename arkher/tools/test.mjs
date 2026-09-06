import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';
import { fileURLToPath, pathToFileURL } from 'node:url';
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const deps = createRequire(path.join(root, 'tools/roblox-package/package.json'));
const { LuauState } = await import(pathToFileURL(deps.resolve('luau-web')).href);
const names = ['Util','Transform','Schema','Procedural','Graph','Project','Budget','Runtime','Planner','Session'];
const passed = [];
const state = await LuauState.createAsync({ recordPass: name => { passed.push(name); console.log('PASS', name); } });
let compiled = 0;
function walk(folder) {
  return fs.readdirSync(folder, { withFileTypes: true }).flatMap(entry => entry.isDirectory()
    ? walk(path.join(folder, entry.name)) : [path.join(folder, entry.name)]);
}
try {
  for (const file of walk(path.join(root, 'arkher/src')).filter(p => p.endsWith('.luau'))) {
    state.loadstring(fs.readFileSync(file,'utf8'), path.relative(root,file), true);
    compiled++;
  }
  let bundle = '';
  for (const name of names) {
    const source = fs.readFileSync(path.join(root, `arkher/src/Core/${name}.luau`), 'utf8')
      .replace(/require\(script\.Parent\.(\w+)\)/g, (_, dependency) => 'Core_' + dependency)
      .replace(/require\(script\.Parent:WaitForChild\("(\w+)"\)\)/g, (_, dependency) => 'Core_' + dependency);
    bundle += `local Core_${name} = (function()\n${source}\nend)()\nlocal ${name} = Core_${name}\n`;
  }
  bundle += 'local PlatformStore = (function()\n' + fs.readFileSync(path.join(root,'arkher/src/Server/DataStoreStore.luau'),'utf8') + '\nend)()\n';
  bundle += fs.readFileSync(path.join(root,'arkher/tests/core.luau'),'utf8');
  bundle += '\n' + fs.readFileSync(path.join(root,'arkher/tests/session.luau'),'utf8');
  await state.loadstring(bundle,'arkher-core-tests',true)();
  if (passed.length < 30) throw new Error('Test suite did not finish');
  const report = { product:'ARKHER',generation:1,status:'development',passed:passed.length,failed:0,
    compiledLuauFiles:compiled,tests:passed,environment:'Luau WASM, platform-neutral core only',
    robloxStudio:'NOT_TESTED',deviceValidation:'NOT_TESTED',formal10000Systems:'NOT_CERTIFIED' };
  fs.mkdirSync(path.join(root,'build/arkher'),{recursive:true});
  fs.writeFileSync(path.join(root,'build/arkher/tests.json'),JSON.stringify(report,null,2)+'\n');
  console.log(`Passed ${passed.length} ARKHER core tests; compiled ${compiled} Luau sources. Studio not tested.`);
} finally { state.destroy(); }
