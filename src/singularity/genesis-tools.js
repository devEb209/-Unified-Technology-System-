// UTS :: singularity/genesis-tools — a IA opera a PLATAFORMA INTEIRA por
// chat: arquivos na pasta conectada, comandos na máquina (com guarda),
// builds apk/exe/web, geração de modelos em todos os Ds, texturas,
// animações, cutscenes, dublagem, escalas da realidade, perfis de aparelho.
import { AgentFS } from '../agent/fs-agent.js';
import { ProcAgent } from '../agent/proc-agent.js';
import { build as buildApp, inspect as inspectApp, probeToolchains, TARGETS } from '../agent/build-system.js';
import { generate as generateModel, DIMS } from '../media/models.js';
import { generateTexture } from '../media/textures.js';
import { walkClip, Clip, Track, blendPoses } from '../media/animation.js';
import { Cutscene } from '../media/cutscene.js';
import { dubScript, LANGS } from '../media/dub.js';
import { SCALES, scaleFor, ladder } from '../world/scales.js';
import { PROFILES, applyProfile, detectProfile } from '../ues/devices.js';

export function registerGenesisTools({ core, ues, world, workspace = null, proc = null }) {
  const tools = core.tools;
  const agentFS = workspace ? new AgentFS({ root: workspace }) : null;
  const agentProc = proc ?? new ProcAgent({ allow: process.env.UTS_ALLOW_EXEC === '1' });

  if (agentFS) for (const [name, def] of Object.entries(agentFS.tools())) {
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
    fn: async (p) => build({ name: p.name ?? 'GenesisApp', target: p.target ?? 'web', manifest: { title: p.title ?? p.name }, fs: agentFS ?? undefined }),
  });
  tools.register('agent.toolchains', { desc: 'sonda honesta das toolchains desta máquina', schema: {}, fn: async () => probeToolchains() });

  tools.register('media.model', {
    desc: `gera modelo 3D/2D/2.5D/3.5D(voxel)/4D(animado) — dimensões: ${DIMS.join(', ')}`,
    schema: { dim: { type: 'string' }, shape: { type: 'string' }, size: { type: 'number' } },
    fn: async (p) => ({ model: generateModel({ dim: p.dim ?? '3d', ...p }) }),
  });
  tools.register('media.texture', {
    desc: 'pinta textura procedural (wood/brick/marble) — RGBA determinística',
    schema: { kind: { type: 'string' }, size: { type: 'number' } },
    fn: async (p) => ({ texture: generateTexture(p.kind ?? 'wood', p) }),
  });
  tools.register('media.animation', {
    desc: 'gera animação por keyframes (estilo: normal/cansado/marcial)',
    schema: { style: { type: 'string' }, cadence: { type: 'number' } },
    fn: async (p) => { const clip = walkClip(p); return { name: clip.name, duration: clip.duration, pose: clip.pose(0.25) }; },
  });
  tools.register('media.cutscene', {
    desc: 'monta cutscene (timeline de planos de câmera) a partir de beats',
    schema: { beats: { type: 'array' } },
    fn: async (p) => {
      const cs = Cutscene.fromBrief({ beats: p.beats ?? [], name: p.name });
      return { name: cs.name, duration: cs.duration, shots: cs.shots.length };
    },
  });
  tools.register('media.dub', {
    desc: `dublagem automática em ${Object.keys(LANGS).join(', ')} (timings reais por idioma)`,
    schema: { script: { type: 'array' } },
    fn: async (p) => dubScript(p.script ?? [], p.langs),
  });

  tools.register('scales.report', {
    desc: 'a ESCADA DA REALIDADE: do átomo ao universo (níveis causais)',
    schema: {},
    fn: async () => ({ ladder: ladder(), count: SCALES.length }),
  });
  tools.register('scales.locate', {
    desc: 'em que escala da realidade está um fenômeno de tamanho X (metros)',
    schema: { size: { type: 'number' } },
    fn: async (p) => scaleFor(Number(p.size)),
  });
  tools.register('device.profile', {
    desc: `perfil D-O15 do aparelho: ${Object.keys(PROFILES).join(', ')} — mesma realidade, orçamentos menores`,
    schema: { profile: { type: 'string' } },
    fn: async (p) => ({ applied: applyProfile(world.do15 ?? ues.do15, p.profile ?? 'mid') }),
  });
  tools.register('device.detect', { desc: 'detecta o perfil pelo aparelho', schema: { deviceMemory: { type: 'number' }, cores: { type: 'number' }, mobile: { type: 'boolean' } },
    fn: async (p) => ({ profile: detectProfile(p) }) });

  tools.register('world.style', {
    desc: 'define o ESTILO do mundo (o usuário pede no chat, a IA aplica)',
    schema: { style: { type: 'string' } },
    fn: async (p) => {
      world.style = { name: String(p.style ?? 'realista'), at: world.clock.tick };
      world.rrw.emitEvent({ type: 'world.style.changed', subject: 'world', data: { style: world.style.name }, tick: world.clock.tick });
      return { ok: true, style: world.style };
    },
  });

  return { agentFS, agentProc };
}
