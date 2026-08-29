// UTS :: render/vision — THE HUMAN EYE (beyond photorealism): the camera
// records photons; the EYE decides what you SEE. Scotopic Purkinje shift
// (night is BLUE), glare (the optics' point-spread halo around bright
// sources), and contrast sensitivity that falls with luminance (CSF).
import { SCATTER_CONST } from './scattering.js';

export const VISION_CONST = Object.freeze({
  MESOPIC_LO: 0.03,   // scotopic below this (rod vision)
  MESOPIC_HI: 3.0,    // photopic above (cone vision)
  GLARE_PSF: 0.06,    // halo energy fraction per bright source
  CSF_FLOOR: 0.55,    // min visible contrast fraction in the dark
});

/** rod/cone mix at a luminance (0 = all cones, 1 = all rods) */
export function rodMix(L) {
  const lo = Math.log10(Math.max(VISION_CONST.MESOPIC_LO, 1e-6));
  const hi = Math.log10(Math.max(VISION_CONST.MESOPIC_HI, 1e-3));
  const x = Math.log10(Math.max(L, 1e-6));
  const t = Math.max(0, Math.min(1, (x - lo) / (hi - lo)));
  return 1 - t * t * (3 - 2 * t); // 1 in the dark, 0 in daylight
}

/** Purkinje: the scene TINTS BLUE as rods take over (peak 507nm) */
export function purkinjeTint(L) {
  const r = rodMix(L);
  return [1 - 0.22 * r, 1 - 0.06 * r, 1 + 0.16 * r]; // red falls, blue rises
}

/** glare energy around a source of luminance L (the eye's PSF) */
export function glare(L) {
  return VISION_CONST.GLARE_PSF * Math.max(0, Math.log10(Math.max(L, 1) )) / 3;
}

/** contrast sensitivity: what fraction of contrast survives at luminance L */
export function contrastFrac(L) {
  return VISION_CONST.CSF_FLOOR + (1 - VISION_CONST.CSF_FLOOR) * (1 - rodMix(L));
}

/** everything the renderer needs, from the world's REAL light */
export function eyeState({ ambient = 1, flash = 0, exposure = 1 }) {
  const L = Math.max(0.01, ambient + flash * 2.5) * exposure;
  return { L, rod: rodMix(L), tint: purkinjeTint(L), glare: glare(L), contrast: contrastFrac(L) };
}
