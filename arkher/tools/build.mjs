import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import { fileURLToPath, pathToFileURL } from 'node:url';
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const deps = createRequire(path.join(root,'tools/roblox-package/package.json'));
const { createDom, readBinary } = deps('rbx-dom');
const { parseBuffer } = deps('rbx-reader');
const { LuauState } = await import(pathToFileURL(deps.resolve('luau-web')).href);
const output = path.join(root,'arkher/releases/g1-development');
const version = JSON.parse(fs.readFileSync(path.join(root,'arkher/package.json'),'utf8')).version;
fs.mkdirSync(output,{recursive:true});
const sha = data => crypto.createHash('sha256').update(data).digest('hex');
const node = (className,name,children=[],properties={}) => ({className,name,children,properties});
const folder = (name,children) => node('Folder',name,children);
const text = (name,value) => node('StringValue',name,[],{Value:{String:value}});
const sources=[];
function scriptNode(relative,className,name,disabled=false) {
  const source=fs.readFileSync(path.join(root,'arkher/src',relative),'utf8');
  sources.push({file:relative,sha256:sha(source)});
  return node(className,name,[],{Source:{String:source},...(className==='ModuleScript'?{}:{Disabled:{Bool:disabled}})});
}
function moduleFolder(relative) {
  return folder(relative,fs.readdirSync(path.join(root,'arkher/src',relative)).filter(file => file.endsWith('.luau') && !file.includes('.server.') && !file.includes('.client.')).sort().map(file => scriptNode(relative+'/'+file,'ModuleScript',file.replace('.luau',''))));
}
const library=folder('ARKHER',[
  moduleFolder('Core'),moduleFolder('Client'),
  folder('Remotes',[node('RemoteFunction','Request'),node('RemoteEvent','Event')]),
  text('Version',`ARKHER G1 · ${version} · full V1 not certified`),
]);
const server=folder('ARKHER_SERVER',[
  scriptNode('Server/Config.luau','ModuleScript','Config'),
  scriptNode('Server/DataStoreStore.luau','ModuleScript','DataStoreStore'),
  scriptNode('Server/Provider.luau','ModuleScript','Provider'),
  scriptNode('Server/Bootstrap.server.luau','Script','ARKHER_SERVER_BOOT'),
]);
const client=scriptNode('Client/Bootstrap.client.luau','LocalScript','ARKHER_CLIENT');
const installer=scriptNode('Install.luau','ModuleScript','Install');
const place=node('DataModel','ARKHER_STUDIOS',[
  node('Workspace','Workspace'),
  node('Lighting','Lighting',[],{ClockTime:{Float32:14},Brightness:{Float32:2.5},GlobalShadows:{Bool:true}}),
  node('ReplicatedStorage','ReplicatedStorage',[library]),
  node('ServerScriptService','ServerScriptService',[server],{LoadStringEnabled:{Bool:false}}),
  node('StarterPlayer','StarterPlayer',[node('StarterPlayerScripts','StarterPlayerScripts',[client])]),
]);
const transported=structuredClone({library,server,client});
function disable(item) {
  if (['Script','LocalScript'].includes(item.className)) item.properties.Disabled={Bool:true};
  for (const child of item.children) disable(child);
}
Object.values(transported).forEach(disable);
const model=node('DataModel','ROOT',[node('Model','ARKHER_G1_PACKAGE',[
  installer,
  text('LEIA_ME','ARKHER G1 em desenvolvimento. Não é plugin. Instale em um place vazio com require(workspace.ARKHER_G1_PACKAGE.Install).Install(true), no Command Bar de edição. Depois Play. O .rbxl já está instalado. Configuração de editores, DataStore e IA externa fica somente em ServerScriptService.ARKHER_SERVER.Config. Importação/runtime Studio ainda exigem validação real.'),
  folder('Payload',[
    folder('ReplicatedStorage',[transported.library]),folder('ServerScriptService',[transported.server]),folder('StarterPlayerScripts',[transported.client]),
  ]),
])]);
const vm=await LuauState.createAsync();
let compiled=0;
for (const entry of new Map(sources.map(s => [s.file,s])).values()) {
  vm.loadstring(fs.readFileSync(path.join(root,'arkher/src',entry.file),'utf8'),entry.file,true);compiled++;
}
vm.destroy();
function utf8(value) { return Buffer.from(value,'latin1').toString('utf8'); }
const artifacts=[];
for (const [name,spec] of [['ARKHER_STUDIOS_G1_DEV.rbxl',place],['ARKHER_STUDIOS_G1_DEV.rbxm',model]]) {
  const binary=createDom(spec).toBinary({compression:'lz4'});
  assert(binary.equals(createDom(spec).toBinary({compression:'lz4'})),'Non-deterministic binary');
  const native=readBinary(binary);
  const independent=parseBuffer(binary);
  let instances=0;
  function compare(expected,reference,foreign) {
    instances++;
    const actual=native.instance(reference);
    assert.equal(actual.name,expected.name);assert.equal(actual.className,expected.className);
    assert.equal(utf8(foreign.Name),expected.name);assert.equal(foreign.ClassName,expected.className);
    for (const [key,value] of Object.entries(expected.properties)) {
      assert.deepEqual(native.getProperty(reference,key),value,`${expected.name}.${key}`);
      if (value.String!==undefined) assert.equal(utf8(foreign[key]),value.String);
      else if (value.Bool!==undefined) assert.equal(foreign[key],value.Bool);
      else if (value.Float32!==undefined) assert(Math.abs(foreign[key]-value.Float32)<=Math.max(1,Math.abs(value.Float32))*2e-6, `${key}: independent Float32 outside tolerance`);
    }
    const children=native.children(reference);
    assert.equal(children.length,expected.children.length);assert.equal(foreign.Children.length,children.length);
    for (const child of expected.children) {
      const nativeChild=children.find(ref => native.instance(ref).name===child.name);
      const foreignChild=foreign.Children.find(c => utf8(c.Name)===child.name);
      assert(nativeChild && foreignChild,'Missing child '+child.name);compare(child,nativeChild,foreignChild);
    }
  }
  const nativeRoots=native.children(native.rootRef);
  assert.equal(nativeRoots.length,spec.children.length);assert.equal(independent.result.length,spec.children.length);
  for (const child of spec.children) compare(child,nativeRoots.find(r => native.instance(r).name===child.name),independent.result.find(c => utf8(c.Name)===child.name));
  assert.equal(native.instanceCount,instances+1);assert.equal(independent.instances.length,instances);
  fs.writeFileSync(path.join(output,name),binary);
  artifacts.push({file:name,bytes:binary.length,sha256:sha(binary),instances,nativeRoundTrip:'passed',independentRead:'passed',independentFloat32RelativeTolerance:2e-6,deterministicBytes:'passed'});
  console.log(name,binary.length,'bytes;',instances,'instances; both parsers agree.');
}
const report={product:'ARKHER STUDIOS',generation:1,version,releaseStatus:'DEVELOPMENT_NOT_FINAL_V1',
  brief:{commit:'c849100aec49e344cf915cbbe5b31bcc707963ee',blob:'9f628f98e103d1fedea1a7c418ecb50ecdf21fcf'},
  compiledLuauSources:compiled,sources:[...new Map(sources.map(s => [s.file,s])).values()],artifacts,
  robloxStudioImport:'NOT_TESTED',clientServerRuntime:'NOT_TESTED',mobileConsoleVR:'NOT_TESTED',formal10000Systems:'NOT_CERTIFIED',formal100000Features:'NOT_CERTIFIED'};
fs.writeFileSync(path.join(output,'VALIDACAO.json'),JSON.stringify(report,null,2)+'\n');
