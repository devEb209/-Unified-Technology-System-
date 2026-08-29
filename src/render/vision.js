// UTS :: render/vision — THE HUMAN EYE, COMPLETE. The camera records
// photons; the EYE decides what you SEE — and everything it captures is
// modeled here, not painted: scotopic Purkinje shift (night is BLUE),
// glare PSF, CSF contrast, PUPIL dynamics (asymmetric constriction/
// dilation), ACCOMMODATION (depth of field from pupil aperture), FOVEAL
// ACUITY (the eye samples the center densely), SACCADIC MASKING (vision
// drops during fast gaze shifts), NEGATIVE AFTERIMAGES (persistência
// retiniana), VEILING GLARE (scattered light lifts the black), CRITICAL
// FLICKER FUSION (temporal resolution) and LATERAL CHROMATIC ABERRATION.
import { SCATTER_CONST } from './scattering.js';

export const VISION_CONST = Object.freeze({
  MESOPIC_LO: 0.03,   // scotopic below this (rod vision)
  MESOPIC_HI: 3.0,    // photopic above (cone vision)
  GLARE_PSF: 0.06,    // halo energy fraction per bright source
  CSF_FLOOR: 0.55,    // min visible contrast fraction in the dark
  PUPIL_MIN: 2.0,     // mm, full daylight
  PUPIL_MAX: 7.0,     // mm, near-total darkness
  PUPIL_TAU_FAST: 0.25, // s — constriction is FAST (protect the retina)
  PUPIL_TAU_SLOW: 1.5,  // s — dilation is SLOW (dark adaptation)
  SACCADE_VEL: 60,    // °/s — gaze faster than this is a saccade
  SACCADE_MAX: 0.85,  // deepest suppression fraction of the gain
  AFTERIMAGE_TAU: 1.2,  // s — negative afterimage decay
  VEIL_MAX: 0.045,    // veiling glare lift at full daylight
  CFF_FOVEA_DAY: 56,  // Hz — critical flicker fusion, foveal, photopic
  CFF_FOVEA_NIGHT: 36, // Hz — scotopic fusion is lower
  CFF_PERIPH_EXTRA: 24, // Hz — the periphery fuses higher (motion!)
  CA_PER_DEG: 0.00035, // lateral chromatic aberration per degree of eccentricity
  ACUITY_ECC: 2.2,    // deg — foveal acuity half-width
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
  return VISION_CONST.GLARE_PSF * Math.max(0, Math.log10(Math.max(L, 1))) / 3;
}

/** contrast sensitivity: what fraction of contrast survives at luminance L */
export function contrastFrac(L) {
  return VISION_CONST.CSF_FLOOR + (1 - VISION_CONST.CSF_FLOOR) * (1 - rodMix(L));
}

/** pupil TARGET diameter for a luminance (mm) — the iris motor plan */
export function pupilTarget(L) {
  const t = Math.max(0, Math.min(1, (Math.log10(Math.max(L, 1e-5)) + 2) / 5));
  return VISION_CONST.PUPIL_MIN + (VISION_CONST.PUPIL_MAX - VISION_CONST.PUPIL_MIN) * (1 - t);
}

/** foveal acuity fraction at an eccentricity (1 at the fovea, tiny at 20°) */
export function acuity(eccDeg) {
  const e = Math.abs(eccDeg) / VISION_CONST.ACUITY_ECC;
  return 1 / (1 + e * e);
}

/** circle of confusion of the eye's optics (accommodation): bigger pupil,
 *  shallower focus. depthM = distance being imaged, focusM = where the
 *  lens is accommodated. Returns a 0..∞ blur fraction. */
export function cocOf(pupilMM, depthM, focusM) {
  const d = Math.max(0.1, depthM), f = Math.max(0.1, focusM);
  const defocus = Math.abs(d - f) / ((d * f) / Math.max(d, f)); // relative defocus 0..1
  return (pupilMM / VISION_CONST.PUPIL_MAX) * defocus * 0.5;
}

/** critical flicker fusion (Hz): fovea vs periphery, day vs night */
export function cff(rod) {
  return {
    fovea: VISION_CONST.CFF_FOVEA_DAY + (VISION_CONST.CFF_FOVEA_NIGHT - VISION_CONST.CFF_FOVEA_DAY) * rod,
    periphery: VISION_CONST.CFF_FOVEA_DAY + VISION_CONST.CFF_PERIPH_EXTRA * (1 - rod) + 6 * rod,
  };
}

/** lateral chromatic aberration: color fringing grows with eccentricity
 *  (fraction of image radius separating red/blue focus) */
export function chromaticOffset(eccDeg) {
  return Math.abs(eccDeg) * VISION_CONST.CA_PER_DEG;
}

/** veiling glare: scattered light in the optics LIFTS the black point,
 *  proportional to how bright the scene is */
export function veilOf(L) {
  return VISION_CONST.VEIL_MAX * Math.min(1, Math.max(0, L) / 2);
}

/**
 * The EYE AS AN ORGAN: state that persists across frames and evolves —
 * pupil mid-motion, lingering afterimages, current suppression. Fully
 * deterministic (no random): the same light history gives the same eye.
 */
export class VisionDynamics {
  constructor() {
    this.pupilMM = VISION_CONST.PUPIL_MAX * 0.6; // born mid-range
    this.after = [0, 0, 0];       // negative afterimage (added to the image)
    this.suppress = 0;            // saccadic masking now
    this.lastYaw = 0; this.lastPitch = 0;
    this.L = 1;
  }

  update(dt, { ambient = 1, flash = 0, exposure = 1, yaw = 0, pitch = 0 } = {}) {
    const L = Math.max(0.01, ambient + flash * 2.5) * exposure;
    this.L = L;
    const st = { L, rod: rodMix(L), tint: purkinjeTint(L), glare: glare(L), contrast: contrastFrac(L) };

    // PUPIL: asymmetric dynamics toward the luminance target
    const target = pupilTarget(L);
    const tau = target < this.pupilMM ? VISION_CONST.PUPIL_TAU_FAST : VISION_CONST.PUPIL_TAU_SLOW;
    this.pupilMM += (target - this.pupilMM) * (1 - Math.exp(-Math.max(dt, 1e-4) / tau));

    // SACCADE: fast gaze shifts mask vision (the gain collapses)
    const vel = Math.hypot((yaw - this.lastYaw) * 57.3, (pitch - this.lastPitch) * 57.3) / Math.max(dt, 1e-3);
    this.lastYaw = yaw; this.lastPitch = pitch;
    this.suppress = Math.min(1, Math.max(0, (vel - VISION_CONST.SACCADE_VEL) / 240)) * VISION_CONST.SACCADE_MAX;

    // AFTERIMAGE: a flash burns a NEGATIVE image that decays (seconds)
    if (flash > 0.4) {
      const k = 0.32 * flash;
      this.after = [-st.tint[0] * k, -st.tint[1] * k, -st.tint[2] * k];
    }
    const decay = Math.exp(-Math.max(dt, 0) / VISION_CONST.AFTERIMAGE_TAU);
    this.after = [this.after[0] * decay, this.after[1] * decay, this.after[2] * decay];

    return {
      ...st,
      pupilMM: this.pupilMM,
      suppress: this.suppress,
      veil: veilOf(L),
      after: this.after,
      cff: cff(st.rod),
      acuityCenter: acuity(0),
      caFrac: VISION_CONST.CA_PER_DEG * 57.29578, // fração por radiano (o post usa)
    };
  }
}

/** everything the renderer needs, from the world's REAL light (stateless) */
export function eyeState({ ambient = 1, flash = 0, exposure = 1 }) {
  const L = Math.max(0.01, ambient + flash * 2.5) * exposure;
  return { L, rod: rodMix(L), tint: purkinjeTint(L), glare: glare(L), contrast: contrastFrac(L), caFrac: VISION_CONST.CA_PER_DEG * 57.29578 };
}
