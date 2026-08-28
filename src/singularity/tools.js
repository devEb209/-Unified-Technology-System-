// UTS :: singularity/tools — ToolRegistry.
// The ONLY way external intelligence (LLM text) changes reality:
// structured, validated calls into the UES/RRW. Free text NEVER mutates state.

export class ToolValidationError extends Error {}

function validate(schema, params) {
  const out = {};
  for (const [key, rule] of Object.entries(schema)) {
    let v = params?.[key];
    if (v === undefined) {
      if (rule.required) throw new ToolValidationError(`missing param '${key}'`);
      v = rule.default;
    }
    if (v === undefined || v === null) { out[key] = v; continue; }
    switch (rule.type) {
      case 'string':
        v = String(v);
        if (rule.maxLength && v.length > rule.maxLength) throw new ToolValidationError(`param '${key}' too long`);
        break;
      case 'number': {
        const n = Number(v);
        if (Number.isNaN(n)) throw new ToolValidationError(`param '${key}' must be a number`);
        if (rule.min != null && n < rule.min) throw new ToolValidationError(`param '${key}' < min ${rule.min}`);
        if (rule.max != null && n > rule.max) throw new ToolValidationError(`param '${key}' > max ${rule.max}`);
        v = n;
        break;
      }
      case 'boolean':
        v = v === true || v === 'true' || v === 1;
        break;
      case 'array':
        if (!Array.isArray(v)) throw new ToolValidationError(`param '${key}' must be an array`);
        break;
      case 'enum':
        if (!rule.values.includes(v)) throw new ToolValidationError(`param '${key}' must be one of ${rule.values.join('|')}`);
        break;
      default:
        throw new ToolValidationError(`unknown rule type ${rule.type}`);
    }
    out[key] = v;
  }
  return out;
}

export class ToolRegistry {
  constructor() {
    this.tools = new Map();
  }

  register(name, { desc, schema = {}, fn }) {
    if (typeof fn !== 'function') throw new Error(`tool ${name} needs fn`);
    this.tools.set(name, { name, desc, schema, fn });
    return this.tools.get(name);
  }

  get(name) { return this.tools.get(name) ?? null; }
  list() { return [...this.tools.values()]; }

  async execute(name, params) {
    const tool = this.tools.get(name);
    if (!tool) throw new ToolValidationError(`unknown tool: ${name}`);
    const clean = validate(tool.schema, params ?? {});
    return tool.fn(clean);
  }
}

/** build the standard UES toolset over a live system */
export function builtinTools({ ues, world, rrw, core }) {
  const tools = new ToolRegistry();

  tools.register('ues.create_settlement', {
    desc: 'Found a settlement, optionally near a river',
    schema: {
      name: { type: 'string', required: true, maxLength: 40 },
      pop: { type: 'number', min: 1, max: 300, default: 24 },
      nearRiver: { type: 'boolean', default: false },
    },
    fn: (p) => {
      // idempotent by name — corrective retries never duplicate reality
      const existing = rrw.query({ kind: 'settlement', predicate: e => e.name === p.name })[0];
      if (existing) {
        return { ok: true, settlementId: existing, name: p.name, existed: true };
      }
      const t = world.terrain;
      let pos;
      if (p.nearRiver) {
        const water = t.findWater(t.size / 2, t.size / 2, 500);
        pos = water ? t.findLand(water[0] + 14, water[2] + 8, 260) : t.findLand(t.size / 2, t.size / 2, 260);
      } else {
        pos = t.findLand(t.size / 2, t.size / 2, 260);
      }
      const ent = world.createSettlement({ name: p.name, pos, pop: p.pop });
      // initial population + surrounding ecology (real emergence substrate)
      for (let i = 0; i < Math.min(p.pop, 16); i++) {
        const a = (i / Math.min(p.pop, 16)) * Math.PI * 2;
        const r = 6 + (i % 5) * 3;
        world.spawnNPC({ pos: [pos[0] + Math.cos(a) * r, 0, pos[2] + Math.sin(a) * r], settlementId: ent.id });
      }
      world.spawnResourceNodes(pos, { radius: 90, bushes: 20, trees: 30 });
      ues.moveCamera([pos[0], 34, pos[2] + 70]);
      return { ok: true, settlementId: ent.id, name: p.name, pos, pop: p.pop };
    },
  });

  tools.register('ues.spawn_npcs', {
    desc: 'Spawn NPCs near a settlement or the camera',
    schema: {
      count: { type: 'number', required: true, min: 1, max: 200 },
      settlementName: { type: 'string', maxLength: 40 },
    },
    fn: (p) => {
      let anchor = ues.camera.pos;
      if (p.settlementName) {
        const id = rrw.query({ kind: 'settlement', predicate: e => e.name?.toLowerCase() === p.settlementName.toLowerCase() })[0];
        if (id) anchor = rrw.getComponent(id, 'spatial').pos;
      }
      const created = [];
      for (let i = 0; i < p.count; i++) {
        const a = world.rng.next() * Math.PI * 2, r = 5 + world.rng.next() * 25; // deterministic scatter
        const pos = world.terrain.findLand(anchor[0] + Math.cos(a) * r, anchor[2] + Math.sin(a) * r, 40);
        created.push(world.spawnNPC({ pos }).id);
      }
      return { ok: true, created: created.length };
    },
  });

  tools.register('world.set_weather', {
    desc: 'Change the weather via the causal RealLife chain',
    schema: {
      weather: { type: 'enum', required: true, values: ['clear', 'cloudy', 'rain', 'storm', 'windy', 'dust'] },
    },
    fn: (p) => {
      const eventId = world.setWeather(p.weather);
      return { ok: true, weather: p.weather, eventId };
    },
  });

  tools.register('world.start_fire', {
    desc: 'Ignite a fire (hazard) near the camera or at a position',
    schema: { pos: { type: 'array' } },
    fn: (p) => {
      const strikeId = world.rrw.emitEvent({ type: 'reallife.lightning.strike', subject: 'world', cause: world.environment.lastWeatherEventId, data: { induced: true }, tick: world.clock.tick });
      const fireId = world.reallife.igniteFire(p.pos ?? ues.camera.pos, strikeId);
      return { ok: true, fireId, strikeId };
    },
  });

  tools.register('ues.focus_camera', {
    desc: 'Point the camera at a settlement or position',
    schema: {
      settlementName: { type: 'string', maxLength: 40 },
      pos: { type: 'array' },
    },
    fn: (p) => {
      if (p.settlementName) {
        const id = rrw.query({ kind: 'settlement', predicate: e => e.name?.toLowerCase().includes(p.settlementName.toLowerCase()) })[0];
        if (!id) return { ok: false, reason: `settlement '${p.settlementName}' not found` };
        const sp = rrw.getComponent(id, 'spatial');
        ues.moveCamera([sp.pos[0], 34, sp.pos[2] + 70]);
        return { ok: true, focus: id };
      }
      if (p.pos) { ues.moveCamera([p.pos[0], 34, p.pos[2] + 70]); return { ok: true, focus: p.pos }; }
      return { ok: false, reason: 'no target given' };
    },
  });

  tools.register('ues.run_ticks', {
    desc: 'Advance the simulation by N ticks',
    schema: { ticks: { type: 'number', min: 1, max: 2000, default: 10 } },
    fn: (p) => { const ran = ues.run(p.ticks); return { ok: true, uesTick: ran }; },
  });

  return tools;
}
