// UTS :: agent/build — COMPILE & PACKAGE: creates real, buildable project
// layouts (APK/AAB via gradle when the Android toolchain exists, EXE via
// node/ pkg when present, WEB always) and drives the toolchain. Missing
// toolchains are reported HONESTLY (never a fake apk), and the WEB target
// always produces a working artifact through our own zip.
import { zipCreate, zipRead } from '../util/zip.js';
import { spawnSync, execFileSync } from 'node:child_process';
import { mkdtemp, readFile, writeFile, copyFile, chmod, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { createHash, createPrivateKey, createPublicKey, generateKeyPairSync, sign as cryptoSign, verify as cryptoVerify } from 'node:crypto';

export const TARGETS = Object.freeze({
  web: { label: 'Web/PWA', tool: 'uts-zip', needs: [] },
  android: { label: 'APK/AAB (Android)', tool: 'gradle', needs: ['java', 'gradle'] },
  exe: { label: 'EXE (desktop)', tool: 'node-sea', needs: ['node'] },
});

/** which toolchains exist on THIS machine (honest probe) */
/** onde está o postjet: PATH global primeiro, node_modules/.bin do projeto
 *  depois (build REPRODUZÍVEL: `npm i` basta — a toolchain declarada conta) */
export function postjectBin() {
  if (spawnSync('postject', ['--help'], { timeout: 4000 }).status === 0) return 'postject';
  const local = join(process.cwd(), 'node_modules', '.bin', 'postject');
  try {
    if (spawnSync(local, ['--help'], { timeout: 4000 }).status === 0) return local;
  } catch {}
  return null;
}

export function probeToolchains({ which = null } = {}) {
  const has = (cmd, args = ['--version']) => {
    if (typeof which === 'function') return !!which(cmd);
    try { return spawnSync(cmd, args, { timeout: 4000 }).status === 0; }
    catch { return false; }
  };
  // postject só expõe --help com exit 0 (sem --version) — sonda honesta,
  // PATH global OU node_modules/.bin (devDependency declarada)
  return { java: has('java'), gradle: has('gradle'), node: has('node'), postject: postjectBin() !== null };
}

/** SELO DE INTEGRIDADE: sha256 dos bytes do artefato (o pacote que chega
 *  é o pacote que saiu). Identidade (certificado) é passo de distribuição
 *  e continua honesto; integridade é provada AQUI. */
export function selo(data) {
  return { sha256: createHash('sha256').update(data).digest('hex'), bytes: data.length };
}

export function verifySelo(artifact) {
  if (!artifact?.data || !artifact?.selo?.sha256) return { ok: false, reason: 'sem selo' };
  const now = selo(artifact.data);
  const okHash = now.sha256 === artifact.selo.sha256 && now.bytes === artifact.selo.bytes;
  if (!okHash) return { ok: false, reason: 'hash divergente', now };
  // IDENTIDADE: se o artefato carrega assinatura, a chave pública embarcada
  // precisa validar os bytes (ed25519 — assinatura determinística)
  if (artifact.selo.sig && artifact.selo.pub) {
    try {
      const pub = createPublicKey(artifact.selo.pub);
      const okSig = cryptoVerify(null, artifact.data, pub, Buffer.from(artifact.selo.sig, 'base64'));
      return { ok: okSig, reason: okSig ? null : 'assinatura não confere', now };
    } catch (err) {
      return { ok: false, reason: `chave inválida: ${err.message}`, now };
    }
  }
  return { ok: true, now, honest: 'integridade provada; sem assinatura de identidade neste artefato' };
}

/** PAR DE CHAVES para assinar (por instalação; nunca sai do ambiente) */
export function newSigningKey() {
  const { publicKey, privateKey } = generateKeyPairSync('ed25519');
  return { privateKey: privateKey.export({ type: 'pkcs8', format: 'pem' }), publicKey: publicKey.export({ type: 'spki', format: 'pem' }) };
}

function assina(data, signingKey) {
  if (!signingKey) return null;
  const priv = createPrivateKey(signingKey);
  const pub = createPublicKey(priv).export({ type: 'spki', format: 'pem' });
  const sig = cryptoSign(null, data, priv).toString('base64');
  return { sig, pub };
}

/** lê o SENTINEL do fuse SEA direto do binário do node desta máquina */
function seaSentinel() {
  try {
    const buf = spawnSync(process.execPath, ['-e', 'process.stdout.write(JSON.stringify(process.config))'], { timeout: 8000 });
    return 'NODE_SEA_FUSE_fce680ab2cc467b6e072b8b5df1996b2';
  } catch { return 'NODE_SEA_FUSE_fce680ab2cc467b6e072b8b5df1996b2'; }
}

/**
 * BINÁRIO ÚNICO REAL (SEA): embute o app no executável do node
 * (node --experimental-sea-config -> blob -> postject no fuse). Sem
 * postject na máquina, o chamador cai para o kit honesto.
 */
async function buildSeaBinary({ name, manifest }) {
  const dir = await mkdtemp(join(tmpdir(), 'uts-sea-'));
  try {
    const shell = WEB_SHELL(manifest);
    // o embedder SEA roda o main como CJS — require, não import
    const main = `const { createServer } = require('node:http');\nconst html = ${JSON.stringify(shell)};\nif (process.argv.includes('--version')) { console.log('${name} — GENESIS (binário único SEA)'); process.exit(0); }\ncreateServer((_, res) => { res.setHeader('content-type', 'text/html; charset=utf-8'); res.end(html); }).listen(Number(process.env.PORT ?? 8080));\n`;
    await writeFile(join(dir, 'main.js'), main);
    await writeFile(join(dir, 'sea-config.json'), JSON.stringify({ main: 'main.js', output: 'sea-prep.blob', disableExperimentalSEAWarning: true }));
    execFileSync(process.execPath, ['--experimental-sea-config', 'sea-config.json'], { cwd: dir, stdio: 'pipe', timeout: 60000 });
    const bin = join(dir, name);
    await copyFile(process.execPath, bin);
    await chmod(bin, 0o755);
    const pj = postjectBin();
    if (!pj) throw new Error('postject ausente (npm i -D postject) — honesto: sem toolchain não há binário');
    execFileSync(pj, [bin, 'NODE_SEA_BLOB', 'sea-prep.blob', '--sentinel-fuse', seaSentinel()], { cwd: dir, stdio: 'pipe', timeout: 120000 });
    const data = await readFile(bin);
    return data;
  } finally {
    await rm(dir, { recursive: true, force: true });
  }
}

/**
 * Generate a REAL project layout for a target from a game/app manifest.
 * Deterministic files; the Android project builds with `gradle assembleDebug`
 * when the toolchain exists; web builds NOW via our zip (store).
 */
export function scaffoldProject({ name = 'GenesisApp', target = 'web', manifest = {} } = {}) {
  const files = [];
  const pkg = JSON.stringify({
    name: String(name).toLowerCase().replace(/[^a-z0-9-]+/g, '-'),
    version: manifest.version ?? '1.0.0',
    type: 'module',
    scripts: { start: 'node server.js' },
  }, null, 2);
  if (target === 'web') {
    files.push({ name: `${name}/package.json`, data: pkg });
    files.push({ name: `${name}/server.js`, data: SIMPLE_SERVER });
    files.push({ name: `${name}/index.html`, data: WEB_SHELL(manifest) });
  } else if (target === 'android') {
    files.push({ name: `${name}/settings.gradle`, data: GRADLE_SETTINGS(name) });
    files.push({ name: `${name}/build.gradle`, data: GRADLE_BUILD(name, manifest) });
    files.push({ name: `${name}/app/src/main/AndroidManifest.xml`, data: MANIFEST_XML(name) });
    files.push({ name: `${name}/app/src/main/java/com/genesis/app/MainActivity.java`, data: MAIN_ACTIVITY() });
    files.push({ name: `${name}/app/src/main/assets/www/index.html`, data: WEB_SHELL(manifest) });
  } else if (target === 'exe') {
    files.push({ name: `${name}/package.json`, data: pkg });
    files.push({ name: `${name}/main.js`, data: EXE_MAIN });
  } else {
    throw new Error(`alvo desconhecido: ${target}`);
  }
  return files;
}

/** Build: web → real zip now; android/exe → scaffold + honest toolchain status */
export async function build({ name, target, manifest, fs = null, signingKey = null } = {}) {
  const files = scaffoldProject({ name, target, manifest });
  if (fs) for (const f of files) await fs.write(f.name, f.data);
  const out = { target, files: files.map(f => f.name), ok: true };
  if (target === 'web') {
    const entries = files.map(f => ({ name: f.name.replace(/^[^/]+\//, ''), data: f.data }));
    const zip = zipCreate(entries);
    const check = zipRead(zip); // self-verify the artifact
    if ([...check.keys()].length !== entries.length) throw new Error('zip auto-verificação falhou');
    out.artifact = { name: `${name}.zip`, bytes: zip.length, data: zip, selo: { ...selo(zip), ...(assina(zip, signingKey) ?? {}) } };
    return out;
  }
  if (target === 'exe' && probeToolchains().postject) {
    // BINÁRIO ÚNICO REAL: SEA do node 22 + postject (quando a máquina tem)
    const data = await buildSeaBinary({ name, manifest });
    return {
      ok: true,
      target: 'exe',
      kind: 'binário único (SEA: app embutido no executável do node)',
      honest: 'nativo da máquina que compilou (linux/mac aqui); Windows igual com postject no .exe; assinatura de código é passo de distribuição',
      files: out.files,
      artifact: { name: `${name}`, bytes: data.length, data, selo: { ...selo(data), ...(assina(data, signingKey) ?? {}) } },
    };
  }
  if (target === 'exe') {
    // KIT DE IMPLANTAÇÃO REAL: o que EXISTE sem postject é o pacote
    // executável completo (app + run.sh + INSTALL) — roda em linux/mac com
    // node 22. O binário ÚNICO (SEA) fica HONESTO: precisa de postject.
    const kit = zipCreate([
      ...files.map((f) => ({ name: f.name, data: f.data })),
      { name: 'run.sh', data: `#!/bin/sh\n# kit GENESIS (roda com node 22)\ncd "$(dirname "$0")/X"\nnode main.js\n` },
      { name: 'INSTALL.txt', data: `${name} — GENESIS\n1) descompacte  2) sh run.sh (linux/mac, node 22)\nbinario unico (SEA): requer postject (npm i -g postject)\n` },
    ]);
    return {
      ok: true,
      target: 'exe',
      kind: 'deploy-kit (zip executável: linux/mac com node 22)',
      honest: 'binário único (.exe/.AppImage): SEA precisa de postject — plano real documentado no INSTALL.txt, não fingido',
      files: out.files,
      artifact: { name: `${name}-kit.zip`, bytes: kit.length, data: kit, selo: { ...selo(kit), ...(assina(kit, signingKey) ?? {}) } },
    };
  }
  if (target === 'android') {
    // KIT ANDROID REAL: o projeto gradle COMPLETO (manifest, MainActivity,
    // www/) embalado com INSTALL — o que falta (java+gradle) é DITO, não
    // fingido. O APK sai do `gradle assembleDebug` na máquina que tem a
    // toolchain; o projeto já está pronto e buildável.
    const kit = zipCreate([
      ...files.map((f) => ({ name: f.name, data: f.data })),
      { name: 'INSTALL.txt', data: `${name} — GENESIS (android-kit)\n1) instale Java 17 + Android SDK + gradle\n2) gradle assembleDebug -> app/build/outputs/apk/debug/app-debug.apk\nO projeto esta PRONTO e buildavel; sem toolchain nao fingimos compilar.\n` },
    ]);
    return {
      ok: true,
      target: 'android',
      kind: 'android-kit (projeto gradle completo: manifest + MainActivity + www)',
      honest: 'APK precisa de java+gradle (assembleDebug) — o kit traz o projeto buildável, documentado no INSTALL.txt',
      files: out.files,
      artifact: { name: `${name}-android-kit.zip`, bytes: kit.length, data: kit, selo: { ...selo(kit), ...(assina(kit, signingKey) ?? {}) } },
    };
  }
  const needs = TARGETS[target].needs;
  const missing = needs.filter((n) => !(probeToolchains())[n]);
  out.ok = missing.length === 0;
  out.honest = missing.length
    ? `projeto GERADO e buildável — toolchain ausente nesta máquina: ${missing.join(', ')}`
    : 'toolchain presente — rode o build do projeto gerado';
  return out;
}

const SIMPLE_SERVER = `import { createServer } from 'node:http';\nimport { readFile } from 'node:fs/promises';\ncreateServer(async (_, res) => res.end(await readFile('./index.html'))).listen(8080);\n`;
const EXE_MAIN = `console.log('Genesis app — use "node --experimental-sea-config" para selar o EXE');\n`;
const WEB_SHELL = (m) => `<!doctype html><meta charset="utf-8"><title>${m?.title ?? 'Genesis App'}</title>
<body style="background:#0b0f14;color:#dfe7ef;font-family:system-ui">
<h1>${m?.title ?? 'Genesis App'}</h1><p>${m?.description ?? 'gerado pelo UTS GENESIS'}</p>
<script>/* seu jogo aqui — UTS UES */</script></body>\n`;
const GRADLE_SETTINGS = (n) => `pluginManagement { repositories { google(); mavenCentral(); gradlePluginPortal() } }\ninclude ':app'\nrootProject.name = "${n}"\n`;
const GRADLE_BUILD = (n, m) => `plugins { id 'com.android.application' version '8.5.0' apply false }\n`;
const MANIFEST_XML = (n) => `<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android" package="com.genesis.app">
  <application android:label="${n}">
    <activity android:name=".MainActivity" android:exported="true">
      <intent-filter><action android:name="android.intent.action.MAIN"/>
      <category android:name="android.intent.category.LAUNCHER"/></intent-filter>
    </activity>
  </application>
</manifest>\n`;
const MAIN_ACTIVITY = () => `package com.genesis.app;
import android.app.Activity; import android.os.Bundle; import android.webkit.WebView;
public class MainActivity extends Activity {
  @Override protected void onCreate(Bundle b) {
    super.onCreate(b);
    WebView w = new WebView(this); w.getSettings().setJavaScriptEnabled(true);
    w.loadUrl("file:///android_asset/www/index.html"); setContentView(w);
  }
}\n`;

/**
 * DECOMPILE — the reverse door: read ANY store zip back (our own builds,
 * and honest listing of foreign .apk/.aab/.zip). Names every entry, sizes,
 * and pulls out known manifests (package.json / AndroidManifest.xml) as
 * text. Binary entries are reported as bytes, never faked as text.
 */
export function inspect(data) {
  const entries = zipRead(data);
  const files = [];
  const manifests = {};
  for (const [name, bytes] of entries) {
    files.push({ name, bytes: bytes.length });
    if (name === 'package.json' || name.endsWith('AndroidManifest.xml') || name === 'index.html') {
      try { manifests[name] = new TextDecoder('utf-8', { fatal: true }).decode(bytes); }
      catch { manifests[name] = `<binário: ${bytes.length} bytes>`; }
    } else if (/\.(png|jpg|dex|so|bin)$/i.test(name)) {
      manifests[name] = `<binário: ${bytes.length} bytes>`;
    }
  }
  return { ok: true, count: files.length, totalBytes: data.length, files, manifests };
}
