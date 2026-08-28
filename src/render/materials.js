// UTS :: render/materials — OUR material system.
// Materials are UTS data (RRW-kind-driven), not engine magic: albedo,
// emissive, roughness and flags that the UTS shaders interpret.
// The Frame carries resolved materials; the renderer only uploads them.

export class MaterialLibrary {
  constructor() {
    this.materials = new Map();
    this.registerDefaults();
  }

  register(id, def) {
    const mat = {
      id,
      albedo: def.albedo ?? [0.7, 0.7, 0.7],
      emissive: def.emissive ?? 0,
      roughness: Math.min(1, Math.max(0.04, def.roughness ?? 0.8)),
      emissiveColor: def.emissiveColor ?? [1, 0.6, 0.2],
      castShadows: def.castShadows ?? true,
    };
    this.materials.set(id, mat);
    return mat;
  }

  registerDefaults() {
    this.register('npc', { albedo: [0.85, 0.65, 0.45], roughness: 0.85 });
    this.register('tree', { albedo: [0.16, 0.42, 0.2], roughness: 0.95 });
    this.register('bush', { albedo: [0.35, 0.6, 0.25], roughness: 0.95 });
    this.register('settlement', { albedo: [0.62, 0.55, 0.48], roughness: 0.9 });
    this.register('aggregate', { albedo: [0.5, 0.52, 0.55], roughness: 1, castShadows: false });
    this.register('prop', { albedo: [0.45, 0.44, 0.42], roughness: 0.6 });
    this.register('hazard', {
      albedo: [1.0, 0.35, 0.08], emissive: 1, roughness: 0.4,
      emissiveColor: [1.0, 0.45, 0.1],
    });
  }

  /** resolve by kind with dynamic params (e.g. fire intensity drives emissive) */
  resolve(kind, params = {}) {
    const base = this.materials.get(kind) ?? this.materials.get('prop');
    const mat = { ...base, albedo: [...base.albedo] };
    if (params.emissive != null) mat.emissive = params.emissive;
    if (params.albedoTint) {
      mat.albedo = [
        base.albedo[0] * params.albedoTint[0],
        base.albedo[1] * params.albedoTint[1],
        base.albedo[2] * params.albedoTint[2],
      ];
    }
    return mat;
  }

  list() { return [...this.materials.keys()]; }
}
