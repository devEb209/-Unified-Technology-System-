// UTS :: ues/devices — D-O15 DEVICE PROFILES: an A01 runs the SAME reality
// with lower materialization budgets (the strategy defers, never discards).
// The game the A01 PLAYS is the same game the desktop plays — less detail,
// zero lies.
export const PROFILES = Object.freeze({
  a01:     { frameMs: 33, simMs: 4,  veg: 40,  shadows: false, async: false, npcFull: 8,   skySteps: 6, cloudSteps: 8 },
  low:     { frameMs: 22, simMs: 6,  veg: 90,  shadows: false, async: true,  npcFull: 20,  skySteps: 6, cloudSteps: 10 },
  mid:     { frameMs: 16, simMs: 8,  veg: 180, shadows: true,  async: true,  npcFull: 60,  skySteps: 8, cloudSteps: 12 },
  high:    { frameMs: 14, simMs: 8,  veg: 320, shadows: true,  async: true,  npcFull: 120, skySteps: 8, cloudSteps: 12 },
  desktop: { frameMs: 11, simMs: 10, veg: 500, shadows: true,  async: true,  npcFull: 300, skySteps: 10, cloudSteps: 14 },
});

export function applyProfile(do15, profile = 'mid') {
  const p = PROFILES[profile];
  if (!p) throw new Error(`perfil desconhecido: ${profile} (use ${Object.keys(PROFILES).join(', ')})`);
  do15.budget.frameMs = p.frameMs;
  do15.budget.simMs = p.simMs;
  do15.profile = { name: profile, ...p };
  do15.recomputeStrategy({});
  return do15.profile;
}

/** auto-detect from the device's own signals (honest defaults) */
export function detectProfile({ deviceMemory = 4, cores = 4, mobile = false } = {}) {
  if (mobile || deviceMemory <= 2) return 'a01';
  if (deviceMemory <= 4 || cores <= 4) return 'low';
  if (deviceMemory <= 8) return 'mid';
  if (cores >= 12 && deviceMemory >= 16) return 'desktop';
  return 'high';
}
