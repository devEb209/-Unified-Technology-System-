// UTS :: singularity/genesis-tools — a IA opera a PLATAFORMA INTEIRA por
// chat: arquivos na pasta conectada, comandos na máquina (com guarda),
// builds apk/exe/web, geração de modelos em todos os Ds, texturas,
// animações, cutscenes, dublagem, escalas da realidade, perfis de aparelho.
import { generate as generateModel, DIMS } from '../media/models.js';
import { generateTexture } from '../media/textures.js';
import { walkClip, Clip, Track, blendPoses } from '../media/animation.js';
import { Cutscene } from '../media/cutscene.js';
import { dubScript, LANGS } from '../media/dub.js';
import { StyleEngine } from '../render/style.js';
import { veilOf } from '../render/vision.js';
import { createGame, GENRES } from '../agent/creator.js';
import { composeOptics, forgeLook, composeColorPipeline, COLOR_STAGES, COLOR_PRESETS, composeSurfacePipeline, SURFACE_STAGES, SURFACE_PRESETS, EFFECTS } from '../agent/shader-smith.js';
import { composeGeometry, GEOMETRY_KINDS } from '../agent/geometry-smith.js';
import { forgeLight, LIGHT_KINDS, selfTests as lightSelfTests } from '../agent/light-smith.js';
import { DeltaStream } from '../net/sync.js';
import { UserApps } from '../platform/user-apps.js';
import { PARAMETRIC_TABLE, loadMeasuredTable, applyHRTF } from '../audio/hrtf.js';
import { SCALES, scaleFor, ladder } from '../world/scales.js';
import { PROFILES, applyProfile, detectProfile } from '../ues/devices.js';

export function registerGenesisTools({ core, ues, world, workspace = null, proc = null }) {
  const tools = core.tools;

  // FERRAMENTAS DE MÁQUINA (fs/exec/build): carregadas por import DINÂMICO
  // só onde Node existe — os specifiers node: ficam FORA do grafo do
  // navegador (specifier node: em browser = grafo inteiro morto).
  if (typeof process !== 'undefined' && process.versions?.node) {
    tools.machineReady = import('./genesis-machine-tools.js')
      .then((m) => m.registerMachineTools({ core, ues, world, workspace, proc }))
      .catch(() => {});
  } else tools.machineReady = null;




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
    desc: 'monta cutscene (timeline de planos de câmera) a partir de beats; play:true ROLA na câmera viva (com letterbox e devolução do enquadramento no fim)',
    schema: { beats: { type: 'array' }, name: { type: 'string' }, play: { type: 'boolean' } },
    fn: async (p) => {
      const cs = Cutscene.fromBrief({ beats: p.beats ?? [], name: p.name });
      if (p.play) return { name: cs.name, duration: cs.duration, shots: cs.shots.length, playback: ues.playCutscene(cs) };
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

  tools.register('eye.readout', {
    desc: 'o que o OLHO humano está capturando agora: pupila (mm), supressão sacádica, pós-imagem, véu, CFF, tinta de Purkinje',
    schema: {},
    fn: async () => {
      const eye = world._eye;
      if (!eye) return { ok: false, honest: 'nenhum frame renderizado ainda (o olho ainda não viu nada)' };
      return { ok: true, pupilMM: +eye.pupilMM.toFixed(2), suppress: +eye.suppress.toFixed(3), afterimage: eye.after.map((v) => +v.toFixed(3)), veil: +veilOf(eye.L).toFixed(4), L: +eye.L.toFixed(3) };
    },
  });
  tools.register('genesis.create', {
    desc: 'CRIA UM JOGO COMPLETO E JOGÁVEL de uma frase: gênero (corrida/plataforma/rpg/torre/sobrevivencia) + nome; nível, missões, assets e casca reais, determinístico, zip verificado',
    schema: { genre: { type: 'string' }, name: { type: 'string' } },
    fn: async (p) => {
      const r = createGame({ genre: p.genre, name: p.name ?? 'JogoGenesis', brief: p.brief ?? {} });
      return { ok: true, genre: r.genre, seed: r.seed, files: r.files, zip: r.artifact };
    },
  });
  tools.register('genesis.status', {
    desc: 'a plataforma se VÊ: estado honesto de TODOS os subsistemas (mundo, olho, estilo, escalas, erosão, agentes, rede, build)',
    schema: {},
    fn: async () => {
      if (tools.machineReady) await tools.machineReady; // o estado da máquina vem dela
      const eye = world._eye;
      return {
        ok: true,
        world: { tick: world.clock.tick, weather: world.environment.weather ?? null, wetness: +(world.environment.wetness ?? 0).toFixed(3) },
        eye: eye ? { pupilMM: +eye.pupilMM.toFixed(2), L: +eye.L.toFixed(3), suppress: +eye.suppress.toFixed(3) } : { honest: 'nenhum frame ainda' },
        style: world.style?.name ?? 'realista',
        scales: world.scales ? { levels: 15, tagged: world.scales.tags?.size ?? 0 } : null,
        erosion: world.erosion ? { moved: +world.erosion.stats.eroded.toFixed(4), events: world.erosion.events.length, siltCells: world.erosion.silt.size } : null,
        agents: { fsJournal: tools.maquina?.fsJournal ?? 0, execAllowed: tools.maquina?.execAllowed === true },
        perf: world.perf ? Object.fromEntries(Object.entries(world.perf).map(([k, v]) => [k, +v.toFixed(3)])) : { honest: 'nenhum passo ainda' },
        build: tools.alvos ?? null,
        media: { models: '2d/2.5d/3d/3.5d/4d', textures: 3, dubLangs: Object.keys(LANGS).length },
      };
    },
  });
  tools.register('agent.colorist', {
    desc: `o COLORISTA gera um SHADER DE COR NOVO por composição arbitrária de leis verificadas (${Object.keys(COLOR_STAGES).join(', ')}; presets: ${Object.keys(COLOR_PRESETS).join(', ')}) — espelho JS = GLSL, autoteste; a lente viva recebe o resumo escalar (D-O15)`,
    schema: { pipeline: { type: 'array' }, preset: { type: 'string' } },
    fn: async (p) => {
      const pipeline = p.pipeline ?? COLOR_PRESETS[p.preset ?? 'quente'];
      const r = composeColorPipeline(pipeline);
      // RESUMO ESCALAR (D-O15): o que a lente viva carrega hoje é o que o
      // pipeline faz com o cinza médio — o GLSL completo viaja no build
      const mid = r.js([0.5, 0.5, 0.5]);
      if (!world.style?.params) new StyleEngine(world).apply('realista', {}); // a lente nasce se não existe
      world.style.params = {
        ...world.style.params,
        tint: mid.map((x) => Math.max(0, Math.min(2, x / 0.5))),
      };
      return { ...r, applied: true, lensSummary: 'tint = pipeline(cincza médio); GLSL completo no artefato do build' };
    },
  });
  tools.register('agent.surface', {
    desc: `o SMITH DE CENA gera um SHADER DE SUPERFÍCIE NOVO por composição (${Object.keys(SURFACE_STAGES).join(', ')}; presets: ${Object.keys(SURFACE_PRESETS).join(', ')}) — o programa do TERRENO é recompilado com o GLSL forjado; espelho JS = GLSL`,
    schema: { stages: { type: 'array' }, preset: { type: 'string' }, remover: { type: 'boolean' } },
    fn: async (p) => {
      if (p.remover) {
        if (world.style?.params) delete world.style.params.surface;
        return { ok: true, removed: true, honest: 'o terreno voltou ao programa padrão' };
      }
      const pipeline = p.stages ?? SURFACE_PRESETS[p.preset ?? 'inverno'];
      const r = composeSurfacePipeline(pipeline);
      if (!world.style?.params) new StyleEngine(world).apply('realista', {});
      world.style.params = { ...world.style.params, surface: { glsl: r.glsl, hash: r.hash, stages: r.stages } };
      return { ok: true, hash: r.hash, stages: r.stages, selfTest: r.selfTest, honest: r.honest, applied: true };
    },
  });
  tools.register('agent.geometry', {
    desc: `a FORJA DE GEOMETRIA gera malhas NOVAS por regras determinísticas (${Object.keys(GEOMETRY_KINDS).join(', ')}) com autoteste — contagens pela fórmula, mesma semente = mesma malha`,
    // params ACHATADOS (a validação da registry é por campo tipado)
    schema: { kind: { type: 'string' }, seed: { type: 'string' }, 'níveis': { type: 'number' }, comprimento: { type: 'number' }, galhos: { type: 'number' }, faces: { type: 'number' }, altura: { type: 'number' }, raio: { type: 'number' }, subdiv: { type: 'number' }, rugosidade: { type: 'number' } },
    fn: async (p) => {
      const params = {};
      for (const k of ['níveis', 'comprimento', 'galhos', 'faces', 'altura', 'raio', 'subdiv', 'rugosidade']) if (p[k] !== undefined) params[k] = p[k];
      const r = composeGeometry({ kind: p.kind ?? 'arvore', params, seed: p.seed ?? 'genesis' });
      return { kind: r.kind, stats: r.stats, selfTest: r.selfTest, honest: r.honest, ok: r.selfTest.ok };
    },
  });
  tools.register('agent.light', {
    desc: `a FORJA DE LUZ: temperatura Planck (Kelvin→cromatura nas âncoras CIE), candela→lux com INVERSO DO QUADRADO exato, spot pela lei do cosseno, luz de ÁREA amostrada (suave de perto), rig 3 pontos (key/fill/rim) — determinística, kinds: ${Object.keys(LIGHT_KINDS).join(', ')}`,
    schema: { kind: { type: 'string' }, kelvin: { type: 'number' }, candela: { type: 'number' }, x: { type: 'number' }, y: { type: 'number' }, z: { type: 'number' }, spotDeg: { type: 'number' }, exponent: { type: 'number' }, areaW: { type: 'number' }, areaH: { type: 'number' }, samples: { type: 'number' }, seed: { type: 'number' }, keyCd: { type: 'number' }, fillCd: { type: 'number' }, rimCd: { type: 'number' }, rigDist: { type: 'number' } },
    fn: async (p) => {
      const l = forgeLight(p);
      const provas = lightSelfTests();
      return { kind: l.kind, kelvin: l.kelvin, rgb: l.rgb, chroma: l.chroma ?? null, cutMeters: l.cutMeters ?? null, panel: l.panel ?? null, lights: l.lights ? l.lights.map((L) => ({ nome: L.nome, cd: L.cd })) : undefined, sample: l.evaluate ? l.evaluate([l.pos?.[0] ?? 0, 0, l.pos?.[2] ?? 0]) : undefined, selfTest: { ok: provas.every((t) => t.ok), provas: provas.length }, ok: provas.every((t) => t.ok) };
    },
  });
  tools.register('genesis.critique', {
    desc: 'o OLHO DO DIRETOR: a IA lê o próprio mundo e devolve crítica honesta + sugestões derivadas do estado',
    schema: {},
    fn: async () => core.critique(),
  });
  tools.register('agent.shader', {
    desc: 'o AGENTE GRÁFICO forja óptica real da biblioteca verificada (vinheta cos⁴, grão de sensor): devolve params + GLSL + autoteste do espelho e aplica na lente viva',
    schema: { effects: { type: 'array' }, look: { type: 'string' }, grain: { type: 'number' }, vignette: { type: 'number' }, bloom: { type: 'number' }, tone: { type: 'number' }, ca: { type: 'number' }, sharp: { type: 'number' } },
    fn: async (p) => {
      if (p.look) {
        // FORJA POR DESCRIÇÃO: o chat descreve o olhar, o smith compõe a
        // óptica do léxico verificado e aplica na lente viva (que ele
        // PRÓPRIO cria se ainda não existir — nunca no-op silencioso)
        const forged = forgeLook(p.look);
        if (!world.style?.params) new StyleEngine(world).apply('realista', {});
        world.style.params = { ...world.style.params, ...forged.params };
        return { ...forged, applied: true };
      }
      const amount = {};
      if (p.vignette !== undefined) amount.vinheta = p.vignette;
      if (p.grain !== undefined) amount.grao = p.grain;
      if (p.bloom !== undefined) amount.bloom = p.bloom;
      if (p.tone !== undefined) amount.tonemap = p.tone;
      if (p.ca !== undefined) amount.aberracao = p.ca;
      if (p.sharp !== undefined) amount.nitidez = p.sharp;
      const r = composeOptics({ effects: p.effects, amount });
      if (world.style?.params) {
        // aplica na LENTE viva (o estilo atual herda a óptica forjada)
        world.style.params = { ...world.style.params, ...r.params };
      }
      return r;
    },
  });
  tools.register('net.sync', {
    desc: 'delta AUTORITATIVO do estado do mundo (seq + estado) para o transporte — gap/replay são erros honestos, nunca divergência silenciosa',
    schema: {},
    fn: async () => {
      const stream = (world._sync ??= new DeltaStream());
      return { wire: stream.encode({ tick: world.clock.tick, weather: world.environment.weather ?? null, style: world.style?.name ?? 'realista', erosionMoved: +(world.erosion?.stats.eroded ?? 0).toFixed(4) }), lastSeq: stream.lastSeq };
    },
  });
  // AgentFS lazy NO PONTO DE CHAMADA: o navegador nunca resolve node:fs
  // (recebe o honesto 'sem workspace'); no Node é durável e real.
  const userAppsLento = async () => {
    if (typeof process === 'undefined' || !process.versions?.node || !workspace) return null;
    const { AgentFS } = await import('../agent/fs-agent.js');
    return new UserApps({ fs: new AgentFS({ root: workspace }) });
  };
  tools.register('platform.install', {
    desc: 'INSTALA um app criado na plataforma (workspace/apps/<nome>/) com storage próprio; devolve a URL para jogar',
    schema: { name: { type: 'string' }, genre: { type: 'string' } },
    fn: async (p) => {
      const userApps = await userAppsLento();
      if (!userApps) return { ok: false, honest: 'sem workspace (UTS_WORKSPACE) não há onde instalar' };
      const game = createGame({ genre: p.genre, name: p.name ?? 'AppGenesis' });
      return userApps.install({ name: `${game.genre}-${String(p.name ?? 'app').toLowerCase().replace(/[^a-z0-9-]+/g, '-')}`, zip: game.artifact.data });
    },
  });
  tools.register('platform.apps', {
    desc: 'lista os apps INSTALADOS na plataforma (com seus storages)',
    schema: {},
    fn: async () => {
      const userApps = await userAppsLento();
      if (!userApps) return { ok: false, honest: 'sem workspace' };
      await userApps.rescan();
      return { ok: true, apps: userApps.list() };
    },
  });
  tools.register('platform.storage', {
    desc: 'storage do APP (sandbox por app): write/read no workspace/apps/<nome>/data/',
    schema: { app: { type: 'string' }, op: { type: 'string', values: ['write', 'read'] }, path: { type: 'string' }, data: { type: 'string' } },
    fn: async (p) => {
      const userApps = await userAppsLento();
      if (!userApps) return { ok: false, honest: 'sem workspace' };
      if (p.op === 'write') return { ok: true, ...(await userApps.storageWrite(p.app, p.path, p.data ?? '')) };
      const content = (await userApps.storageRead(p.app, p.path)).toString();
      return { ok: true, content };
    },
  });
  tools.register('audio.hrtf', {
    desc: 'a ORELHA DIRECIONAL: aplica a tabela HRTF (paramétrica publicada hoje; o dono anexa banco MEDIDO pelo mesmo schema) e devolve L/R',
    schema: { az: { type: 'number' }, elev: { type: 'number' } },
    fn: async (p) => {
      const n = 220;
      const tone = new Float32Array(n);
      for (let i = 0; i < n; i++) tone[i] = Math.sin((2 * Math.PI * 440 * i) / PARAMETRIC_TABLE.sr) * 0.5;
      const r = applyHRTF(tone, p.az ?? 0, p.elev ?? 0);
      return { ok: true, table: r.table, leftPeak: +Math.max(...r.left).toFixed(3), rightPeak: +Math.max(...r.right).toFixed(3) };
    },
  });
  tools.register('world.style', {
    desc: 'define o ESTILO do mundo (o usuário pede no chat, a IA aplica): nome + parâmetros opcionais achatados (sat, contrast, rim, bloom, tone, grain, vignette)',
    schema: { style: { type: 'string' }, sat: { type: 'number' }, contrast: { type: 'number' }, rim: { type: 'number' }, bloom: { type: 'number' }, tone: { type: 'number' }, grain: { type: 'number' }, vignette: { type: 'number' }, ca: { type: 'number' }, sharp: { type: 'number' } },
    fn: async (p) => {
      const engine = new StyleEngine(world);
      const overrides = {};
      for (const k of ['sat', 'contrast', 'rim', 'bloom', 'tone', 'grain', 'vignette', 'ca', 'sharp']) {
        if (p[k] !== undefined) overrides[k] = p[k];
      }
      const r = engine.apply(p.style ?? 'realista', overrides);
      return { ok: true, style: world.style, history: engine.history.length };
    },
  });

  return {};
}
