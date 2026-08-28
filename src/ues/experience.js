// UTS :: ues/experience — THE UES AS A GENERAL ENGINE.
//
// UES = Unified Engine System: an ENGINE inside the UTS platform, able to
// create, represent, simulate and execute EXPERIENCES of any kind — worlds,
// games, simulations and platform apps — never specialized in a single genre.
// Experiences are declared as MANIFESTS and booted on platform
// infrastructure; the engine consumes the platform, never the reverse.

import { ExperienceError } from './rules.js';

const SYSTEM_KEYS = ['weather', 'ecology', 'economy', 'trade', 'nmn', 'movement', 'physics', 'materializer', 'streaming', 'deferred'];

/** validate + default an experience manifest */
export function defineExperience(manifest) {
  if (!manifest || typeof manifest !== 'object') throw new ExperienceError('manifest required');
  if (!manifest.name || typeof manifest.name !== 'string') throw new ExperienceError('manifest.name required');
  const kind = manifest.kind ?? 'world-sim';
  if (!['world-sim', 'app'].includes(kind)) throw new ExperienceError(`unknown experience kind '${kind}'`);

  if (kind === 'app') {
    return {
      id: manifest.id ?? null,
      kind,
      name: manifest.name.slice(0, 40),
      app: {
        kindName: manifest.app?.kind ?? 'tasks',
        appName: manifest.app?.name ?? manifest.name,
        actions: manifest.app?.actions ?? [],
      },
    };
  }

  const world = manifest.world ?? {};
  const ruleset = manifest.ruleset ?? {};
  for (const k of Object.keys(ruleset)) {
    if (!SYSTEM_KEYS.includes(k)) throw new ExperienceError(`unknown ruleset key '${k}' (valid: ${SYSTEM_KEYS.join(', ')})`);
  }
  const settlements = (world.settlements ?? []).map((s, i) => ({
    name: String(s.name ?? `Povoado ${i + 1}`).slice(0, 40),
    pop: Math.max(1, Math.min(300, Number(s.pop ?? 24))),
    nearRiver: !!s.nearRiver,
  }));
  return {
    id: manifest.id ?? null,
    kind,
    name: manifest.name.slice(0, 40),
    world: {
      seed: world.seed ?? 'uts-experience',
      weather: world.weather ?? null,           // null = natural evolution
      population: Math.max(0, Math.min(2000, Number(world.population ?? 0))),
      settlements,
      camera: world.camera ?? null,             // [x, y, z]
    },
    ruleset: Object.fromEntries(SYSTEM_KEYS.map(k => [k, ruleset[k] !== false])),
  };
}

/**
 * Boot an experience on a live system (UTS platform infrastructure + UES).
 *  - world-sim: configures rules (system toggles), builds the declared world
 *    through the platform AI's validated tools, returns engine controls.
 *  - app: installs the app through the platform AppHost (platform infra).
 */
export async function bootExperience(uts, manifest, { platform = null } = {}) {
  const exp = defineExperience(manifest);

  if (exp.kind === 'app') {
    if (!platform) throw new ExperienceError('app experiences require the UTS platform');
    const installed = await platform.apps.install({ kind: exp.app.kindName, name: exp.app.appName });
    for (const { action, payload } of exp.app.actions) {
      await platform.apps.act(installed.id, action, payload);
    }
    return { experience: exp, app: installed, view: () => platform.apps.view(installed.id) };
  }

  const { ues, world, core } = uts;

  // 1) ruleset -> engine system toggles (genres are rule configurations)
  for (const [sys, enabled] of Object.entries(exp.ruleset)) ues.setSystemEnabled(sys, enabled);

  // 2) declared world content via validated tools (AI-first, no shortcuts)
  const created = [];
  for (const s of exp.world.settlements) {
    const r = await core.tools.execute('ues.create_settlement', { name: s.name, pop: s.pop, nearRiver: s.nearRiver });
    created.push(r.settlementId);
    if (s.pop > 16) {
      await core.tools.execute('ues.spawn_npcs', { count: Math.min(60, s.pop - 16), settlementName: s.name });
    }
    await core.tools.execute('ues.grow_nature', { settlementName: s.name, radius: 110 });
  }
  if (exp.world.population > 0) {
    await core.tools.execute('ues.spawn_npcs', { count: exp.world.population });
  }
  if (exp.world.weather) {
    await core.tools.execute('world.set_weather', { weather: exp.world.weather });
  }

  // 3) camera
  if (exp.world.camera) ues.moveCamera(exp.world.camera);

  return {
    experience: exp,
    ues,
    created,
    /** persist this experience through platform storage (or any backend) */
    async saveTo(storage, slot = 'experience') {
      const { save } = await import('../persistence/snapshot.js');
      return save(storage, slot, uts);
    },
  };
}
