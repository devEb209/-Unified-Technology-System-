// UTS :: singularity/genesis-machine-tools — AS FERRAMENTAS DE MÁQUINA.
// fs/exec/build tocam o SISTEMA OPERACIONAL (node:fs, node:child_process,
// node:crypto…): este módulo SÓ é carregado onde Node existe (import
// dinâmico a partir de genesis-tools) — os specifiers `node:` NUNCA entram
// no grafo do navegador (specifier node: em browser = grafo morto).
import { AgentFS } from '../agent/fs-agent.js';
import { ProcAgent } from '../agent/proc-agent.js';
import { build as buildApp, inspect as inspectApp, probeToolchains, TARGETS } from '../agent/build-system.js';

export function registerMachineTools({ core, ues = null, world = null, workspace = null, proc = null, agentFS = null }) {
  const tools = core.tools;
  const fs = agentFS ?? (workspace ? new AgentFS({ root: workspace }) : null);
  const agentProc = proc ?? new ProcAgent({ allow: (typeof process !== 'undefined' && process.env?.UTS_ALLOW_EXEC) === '1' });
  if (fs) for (const [name, def] of Object.entries(fs.tools())) {
    tools.register(name, { desc: def.desc, schema: def.schema, fn: def.fn });
  }
  for (const [name, def] of Object.entries(agentProc.tools())) {
    tools.register(name, { desc: def.desc, schema: def.schema, fn: def.fn });
  }
  tools.register('agent.inspect', {
    description: 'DECOMPILA um pacote (.zip/.apk/.aab): lista todo o conteúdo, tamanhos e manifestos (package.json, AndroidManifest). Binários são relatados como bytes — nunca fingidos.',
    input: '{ data: Uint8Array }',
    fn: async (p) => inspectApp(p.data),
  });
  tools.register('agent.build', {
    desc: `gera e compila um app: alvos ${Object.keys(TARGETS).join(', ')} (web builda AGORA; apk/exe geram projeto real e relatam toolchain com honestidade)`,
    schema: { name: { type: 'string' }, target: { type: 'string' }, title: { type: 'string' } },
    fn: async (p) => buildApp({ name: p.name ?? 'GenesisApp', target: p.target ?? 'web', manifest: { title: p.title ?? p.name }, fs: fs ?? undefined }),
  });
  tools.register('agent.toolchains', { desc: 'sonda honesta das toolchains desta máquina', schema: {}, fn: async () => probeToolchains() });
  // estado PUBLICADO para o genesis.status (a plataforma se vê honesta)
  tools.maquina = { fsJournal: fs?.journal?.length ?? 0, execAllowed: agentProc?.allow === true };
  tools.alvos = Object.keys(TARGETS);
  return { fs, agentProc };
}
