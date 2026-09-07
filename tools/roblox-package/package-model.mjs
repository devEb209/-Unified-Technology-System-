import fs from 'node:fs';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
import { createDom, readBinary, metadata } from 'rbx-dom';
import { parseBuffer } from 'rbx-reader';
import { LuauState } from 'luau-web';

// No custom binary serializer: upstream rbx_binary writes native RBXM with LZ4.
const [input, output, reportPath] = process.argv.slice(2);
if (!input || !output || !reportPath) throw new Error('Usage: node package-model.mjs spec.json model.rbxm report.json');
const spec = JSON.parse(fs.readFileSync(input, 'utf8'));
assert.equal(spec.className, 'DataModel');
assert.equal(spec.children.length, 1);
assert.equal(spec.children[0].className, 'Model');
const allowed = new Set(['Model', 'Folder', 'StringValue', 'ModuleScript']);
let instances = 0, compiledModules = 0, stringValues = 0;
const state = await LuauState.createAsync();
function checkSpec(item) {
  if (item.className !== 'DataModel') {
    assert(allowed.has(item.className), `Unexpected/active class: ${item.className}`);
    instances++;
  }
  if (item.className === 'StringValue') {
    assert(Buffer.byteLength(item.properties.Value.String, 'utf8') <= 180000, `Oversized value: ${item.name}`);
    stringValues++;
  }
  if (item.className === 'ModuleScript') {
    state.loadstring(item.properties.Source.String, item.name, true);
    compiledModules++;
  }
  const names = new Set();
  for (const child of item.children ?? []) {
    assert(!names.has(child.name), `Duplicate child: ${child.name}`);
    names.add(child.name);
    checkSpec(child);
  }
}
checkSpec(spec);
state.destroy();
console.log('Serializing', spec.children[0].name);
let dom = createDom(spec);
const binary = dom.toBinary({ compression: 'lz4' });
dom = null;
global.gc?.();
assert(binary.subarray(0, 14).equals(Buffer.from([60,114,111,98,108,111,120,33,137,255,13,10,26,10])));
// Rebuilding from the same spec must produce exactly the same native bytes.
assert(binary.equals(createDom(spec).toBinary({ compression: 'lz4' })), 'Non-deterministic RBXM');
global.gc?.();
console.log('Validating native round trip:', binary.length, 'bytes');
let reread = readBinary(binary);
assert.equal(reread.instanceCount, instances + 1); // implicit DataModel
function compareNative(expected, ref) {
  const actual = reread.instance(ref);
  assert.equal(actual.name, expected.name);
  assert.equal(actual.className, expected.className);
  for (const [name, tagged] of Object.entries(expected.properties ?? {})) {
    assert.deepEqual(reread.getProperty(ref, name), tagged, `${expected.name}.${name}`);
  }
  const children = reread.children(ref);
  assert.equal(children.length, (expected.children ?? []).length);
  const byName = new Map(children.map(r => [reread.instance(r).name, r]));
  for (const child of expected.children ?? []) compareNative(child, byName.get(child.name));
}
compareNative(spec.children[0], reread.children(reread.rootRef)[0]);
reread = null;
global.gc?.();

// An independent TypeScript parser, not the library that serialized the model.
// rbx-reader 1.5.10 exposes serialized strings as byte strings (Latin-1); decode UTF-8 explicitly.
console.log('Validating independent parser');
const independent = parseBuffer(binary);
assert(independent, 'Independent parser rejected RBXM');
assert.equal(independent.result.length, 1);
assert.equal(independent.instances.length, instances);
function utf8(raw) { return Buffer.from(raw, 'latin1').toString('utf8'); }
function compareIndependent(expected, actual) {
  assert(actual, `Missing ${expected.name}`);
  assert.equal(utf8(actual.Name), expected.name);
  assert.equal(actual.ClassName, expected.className);
  for (const [name, tagged] of Object.entries(expected.properties ?? {})) {
    assert.equal(utf8(actual[name]), tagged.String, `${expected.name}.${name}: independent read`);
  }
  const children = actual.Children;
  assert.equal(children.length, (expected.children ?? []).length);
  const byName = new Map(children.map(c => [utf8(c.Name), c]));
  assert.equal(byName.size, children.length);
  for (const child of expected.children ?? []) compareIndependent(child, byName.get(child.name));
}
compareIndependent(spec.children[0], independent.result[0]);
fs.writeFileSync(output, binary);
const report = {
  file: output.split('/').pop(), format: 'RBXM binary (LZ4)', bytes: binary.length,
  sha256: crypto.createHash('sha256').update(binary).digest('hex'),
  instances, stringValues, moduleScripts: compiledModules, autoExecutingScripts: 0,
  nativeRoundTrip: 'passed', independentParser: 'passed',
  fullHierarchyAndPropertyComparison: 'passed', luauCompilation: 'passed',
  deterministicBinary: 'passed', robloxStudioImport: 'NOT_TESTED',
  runtimeInRoblox: 'NOT_TESTED', tools: { rbxDom: '0.3.0', rbxReader: '1.5.10', luauWeb: '1.4.0', upstream: metadata() }
};
fs.writeFileSync(reportPath, JSON.stringify(report, null, 2) + '\n');
console.log(`${report.file}: ${report.bytes} bytes, ${instances} instances, ${compiledModules} modules; binary and independent read OK (Studio not tested)`);
