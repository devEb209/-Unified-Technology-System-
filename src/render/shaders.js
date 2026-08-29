// UTS :: render/shaders — UTS GLSL programs (OURS).
// Materials, Blinn-Phong sun, PCF shadow mapping from OUR depth pass,
// up to 4 point lights (fires) — all interpreting the Frame, inventing nothing.

export const SKY_VS = `#version 300 es
layout(location=0) in vec2 aPos;
out vec2 vUV;
void main(){ vUV = aPos*0.5+0.5; gl_Position = vec4(aPos, 0.999, 1.0); }`;

// SKY_FS: the sky IS the integral of sunlight scattered by the AIR along
// the view ray (Rayleigh+Mie, generated physics in SCATTER_GLSL). D-O15
// governs sample cost elsewhere; the phenomenon here is integrated whole.
import { SCATTER_GLSL } from './scattering.js';
import { CLOUD_GLSL } from './clouds.js';
import { OCEAN_GLSL } from './ocean.js';
import { SMOKE_GLSL } from './smoke.js';
export const SKY_FS = SCATTER_GLSL + CLOUD_GLSL + SMOKE_GLSL + `
in vec2 vUV;
uniform vec3 uCamFwd; uniform vec3 uCamRight; uniform vec3 uCamUp;
uniform float uTanF; uniform float uAspect;
uniform vec3 uSunDir; uniform float uAirMie; uniform float uAirI;
uniform float uTime0;
uniform float uFlash; uniform float uCloudCov; uniform float uCloudSeed;
uniform float uExposure;
uniform vec3 uEyeTint;
uniform vec4 uSmoke[4]; uniform int uSmokeN; uniform float uSmokeWind;
uniform vec2 uSmokeDir;
uniform vec3 uCamPos;
out vec4 fragColor;
void main(){
  vec2 ndc = vUV*2.0 - 1.0;
  vec3 dir = normalize(uCamFwd + uCamRight*(ndc.x*uAspect*uTanF) + uCamUp*(ndc.y*uTanF));
  vec3 col = skyColor(dir, uSunDir, uAirMie, uAirI, 8);
  // CLOUDS: the same air, condensed — integrated along the view ray
  float cT; vec3 cCol;
  marchClouds(uCamPos, dir, uSunDir, uCloudCov, uAirI*clamp(uSunDir.y*4.0+0.12,0.0,1.0), uCloudSeed, cCol, cT);
  col = col*cT + cCol;
  // SMOKE of far fires: volumetric plume, lit by the SAME sky (uSmoke =
  // [x,y,z,intensity]*N — causally fed from the combustion field)
  float smokeT;
  vec3 smokeCol = smokeMarch(uCamPos, dir, uSmoke, uSmokeN, uTime0, uSmokeWind, uSmokeDir, clamp(uAirI/22.0, 0.05, 1.2), smokeT);
  col = col*smokeT + smokeCol;
  col += vec3(uFlash*0.5); // lightning ADDS light to the air (physical)
  col = col * uEyeTint;
  col *= uExposure; // the observer's eye gain (adapts to real light)
  fragColor = vec4(col, 1.0);
}`;

export const SHADOW_VS = `#version 300 es
layout(location=0) in vec3 aPos;
layout(location=3) in vec4 aInst0; // xyz=pos, w=yaw
layout(location=4) in vec4 aInst1; // x=scale
uniform mat4 uLightVP;
void main(){
  float c = cos(aInst0.w), s = sin(aInst0.w);
  vec3 p = aPos * aInst1.x;
  vec3 rp = vec3(c*p.x - s*p.z, p.y, s*p.x + c*p.z);
  gl_Position = uLightVP * vec4(rp + aInst0.xyz, 1.0);
}`;

export const SHADOW_FS = `#version 300 es
precision highp float;
void main(){ /* depth only */ }`;

export const TERRAIN_VS = `#version 300 es
layout(location=0) in vec3 aPos;
layout(location=1) in vec3 aNorm;
layout(location=2) in float aBiome;
uniform mat4 uVP;
out vec3 vPos; out vec3 vNorm; out float vBiome;
void main(){
  vPos=aPos; vNorm=aNorm; vBiome=aBiome;
  gl_Position = uVP*vec4(aPos,1.0);
}`;

export const TERRAIN_FS = `#version 300 es
precision highp float;
in vec3 vPos; in vec3 vNorm; in float vBiome;
uniform vec3 uSunDir; uniform vec3 uSunColor; uniform float uAmbient;
uniform vec3 uSkyBottom; uniform float uFog; uniform float uWetness;
uniform float uAirMie; uniform float uAirI;
uniform float uCloudCov; uniform float uCloudSeed; uniform float uExposure;
uniform vec3 uEyeTint;
uniform float uAirFog;
uniform vec3 uCamPos;
uniform sampler2D uShadowMap; uniform mat4 uLightVP; uniform float uShadowOn;
uniform vec3 uPointPos[4]; uniform vec3 uPointColor[4]; uniform int uPointCount;
uniform float uAlpha;
out vec4 fragColor;
float shadowSample(vec3 wp, float ndl){
  if (uShadowOn < 0.5) return 1.0;
  vec4 lp = uLightVP * vec4(wp,1.0);
  vec3 proj = lp.xyz/lp.w * 0.5 + 0.5;
  if (proj.z > 1.0) return 1.0;
  float bias = max(0.0012, 0.0035*(1.0-ndl));
  float sum = 0.0;
  vec2 texel = vec2(1.0/1024.0);
  for (int x=-1;x<=1;x++){ for(int y=-1;y<=1;y++){
    float d = texture(uShadowMap, proj.xy + vec2(x,y)*texel).r;
    sum += (proj.z - bias > d) ? 0.45 : 1.0;
  }}
  return sum/9.0;
}
` + CLOUD_GLSL + `
void main(){
  vec3 cs[6];
  cs[0]=vec3(0.10,0.32,0.55); cs[1]=vec3(0.78,0.71,0.50); cs[2]=vec3(0.32,0.55,0.25);
  cs[3]=vec3(0.15,0.36,0.17); cs[4]=vec3(0.46,0.44,0.41); cs[5]=vec3(0.93,0.95,0.97);
  int b = int(vBiome+0.5);
  vec3 base = b==0?cs[0]: b==1?cs[1]: b==2?cs[2]: b==3?cs[3]: b==4?cs[4]: cs[5];
  vec3 n = normalize(vNorm);
  float ndl = max(dot(n,uSunDir),0.0);
  float sh = shadowSample(vPos, ndl);
  // CLOUD SHADOW: the SAME integrated slab, sampled from the ground toward
  // the sun — the storm you SEE above is the storm that darkens you
  vec3 cSh; float cloudT = 1.0;
  if (uCloudCov > 0.02) marchClouds(vPos + uSunDir*0.5, uSunDir, uSunDir, uCloudCov, 1.0, uCloudSeed, cSh, cloudT);
  vec3 col = base * (uAmbient*0.55*mix(0.6,1.0,cloudT) + ndl*0.75*sh*cloudT) * uSunColor;
  for (int i=0;i<4;i++){
    if (i>=uPointCount) break;
    vec3 L = uPointPos[i]-vPos;
    float d = length(L);
    float att = max(0.0, 1.0-d/26.0);
    col += base * uPointColor[i] * att * att * max(dot(n, L/max(d,0.01)),0.0) * 2.2;
  }
  col = mix(col, col*vec3(0.55,0.58,0.7), uWetness*0.65);
  // AERIAL PERSPECTIVE: the air between camera and terrain IS the atmosphere
  col = aerial(col, normalize(vPos-uCamPos), length(vPos-uCamPos), uSunDir, uAirMie, uAirI, uAirFog, max(vPos.y, 0.0));
  col = col * uEyeTint;
  col *= uExposure;
  fragColor = vec4(col, uAlpha);
}`;

export const ENTITY_INST_VS = `#version 300 es
layout(location=0) in vec3 aPos;
layout(location=1) in vec3 aNorm;
layout(location=3) in vec4 aInst0; // xyz pos, w yaw
layout(location=4) in vec4 aInst1; // x scale, yzw albedo
layout(location=5) in vec4 aInst2; // x emissive, y roughness
uniform mat4 uVP;
out vec3 vNorm; out vec3 vWorld; out vec4 vA1; out vec4 vA2;
void main(){
  float c = cos(aInst0.w), s = sin(aInst0.w);
  vec3 p = aPos * aInst1.x;
  vec3 rp = vec3(c*p.x - s*p.z, p.y, s*p.x + c*p.z);
  vec3 rn = vec3(c*aNorm.x - s*aNorm.z, aNorm.y, s*aNorm.x + c*aNorm.z);
  vWorld = rp + aInst0.xyz;
  vNorm = rn;
  vA1 = aInst1; vA2 = aInst2;
  gl_Position = uVP * vec4(vWorld,1.0);
}`;

export const ENTITY_FS = `#version 300 es
precision highp float;
in vec3 vNorm; in vec3 vWorld; in vec4 vA1; in vec4 vA2;
uniform vec3 uSunDir; uniform vec3 uSunColor; uniform float uAmbient;
uniform vec3 uSkyBottom; uniform float uFog; uniform vec3 uCamPos;
uniform float uAirMie; uniform float uAirI; uniform float uExposure;
uniform vec3 uEyeTint; uniform float uAirFog;
uniform sampler2D uShadowMap; uniform mat4 uLightVP; uniform float uShadowOn;
uniform vec3 uPointPos[4]; uniform vec3 uPointColor[4]; uniform int uPointCount;
uniform float uAlpha;
out vec4 fragColor;
float shadowSample(vec3 wp, float ndl){
  if (uShadowOn < 0.5) return 1.0;
  vec4 lp = uLightVP * vec4(wp,1.0);
  vec3 proj = lp.xyz/lp.w * 0.5 + 0.5;
  if (proj.z > 1.0) return 1.0;
  float bias = max(0.0015, 0.004*(1.0-ndl));
  float sum = 0.0;
  vec2 texel = vec2(1.0/1024.0);
  for (int x=-1;x<=1;x++){ for(int y=-1;y<=1;y++){
    float d = texture(uShadowMap, proj.xy + vec2(x,y)*texel).r;
    sum += (proj.z - bias > d) ? 0.4 : 1.0;
  }}
  return sum/9.0;
}
void main(){
  vec3 albedo = vA1.yzw;
  float emissive = vA2.x;
  float roughness = vA2.y;
  vec3 n = normalize(vNorm);
  float ndl = max(dot(n,uSunDir),0.0);
  float sh = emissive > 0.5 ? 1.0 : shadowSample(vWorld, ndl);
  vec3 col = albedo * (uAmbient*0.5 + ndl*0.8*sh) * uSunColor;
  // blinn-phong specular from OUR material roughness
  vec3 V = normalize(uCamPos - vWorld);
  vec3 H = normalize(uCamPos + uSunDir);
  float spec = pow(max(dot(n,H),0.0), mix(8.0, 96.0, 1.0-roughness)) * (1.0-roughness) * sh;
  col += uSunColor * spec * 0.35;
  for (int i=0;i<4;i++){
    if (i>=uPointCount) break;
    vec3 L = uPointPos[i]-vWorld;
    float d = length(L);
    float att = max(0.0, 1.0-d/26.0);
    col += albedo * uPointColor[i] * att * att * max(dot(n,L/max(d,0.01)),0.0) * 2.4;
  }
  col += albedo * emissive * 1.5;
  col = aerial(col, normalize(vWorld-uCamPos), length(vWorld-uCamPos), uSunDir, uAirMie, uAirI, uAirFog, max(vWorld.y, 0.0));
  col = col * uEyeTint;
  col *= uExposure;
  fragColor = vec4(col, uAlpha);
  fragColor = vec4(col,1.0);
}`;

export const POINTS_VS = `#version 300 es
layout(location=0) in float aSeed;
uniform mat4 uVP; uniform vec3 uCamPos; uniform float uTime; uniform float uWind; uniform float uCount;
uniform float uSize; uniform float uFall;
out float vAlpha;
void main(){
  float x = (fract(aSeed*0.738)*2.0-1.0)*60.0;
  float z = (fract(aSeed*0.417)*2.0-1.0)*60.0;
  float fall = fract(aSeed*0.913 + uTime*(0.35+uWind*0.3)*uFall);
  float y = 36.0*(1.0-fall);
  vec3 wp = vec3(uCamPos.x + x + uWind*12.0*fall, y, uCamPos.z + z);
  gl_Position = uVP*vec4(wp,1.0);
  gl_PointSize = uSize;
  vAlpha = step(aSeed, uCount);
}`;

export const POINTS_FS = `#version 300 es
precision highp float;
in float vAlpha;
uniform vec3 uColor;
out vec4 fragColor;
void main(){ if (vAlpha<0.5) discard; fragColor = vec4(uColor,0.55); }`;

// WATER_VS: wind-driven waves with REAL deep-water dispersion (ω=√gk) —
// generated physics from OCEAN_GLSL; the sea of a storm is another sea.
export const WATER_VS = `#version 300 es
` + OCEAN_GLSL + `
layout(location=0) in vec3 aPos; // xz RELATIVE to uCenter, y ignored (rebuilt as waves)
uniform mat4 uVP; uniform float uTime; uniform float uSeaLevel; uniform float uWind;
uniform vec2 uWindDir;
uniform vec2 uCenter; // the sea FOLLOWS the camera (scale!); waves stay fixed IN THE WORLD
out vec3 vPos; out float vWave; out float vFoam;
void main(){
  vec2 xz = aPos.xz + uCenter;
  float foam;
  vec3 fld = waveField(xz, uTime, uWind, uWindDir, foam);
  float y = uSeaLevel + fld.y;
  vPos = vec3(xz.x, y, xz.y);
  vWave = fld.y;
  vFoam = foam;
  gl_Position = uVP*vec4(vPos,1.0);
}`;

export const WATER_FS = `#version 300 es
precision highp float;
` + OCEAN_GLSL + `
in vec3 vPos; in float vWave; in float vFoam;
uniform vec3 uSunDir; uniform vec3 uSunColor; uniform float uAmbient;
uniform vec3 uSkyBottom; uniform float uFog; uniform vec3 uCamPos;
uniform float uTime; uniform float uWind;
uniform float uWetness; uniform float uAlpha; uniform float uAirMie; uniform float uAirI;
uniform float uExposure;
uniform vec3 uEyeTint; uniform float uAirFog;
uniform vec2 uWindDir;
out vec4 fragColor;
void main(){
  vec3 view = normalize(uCamPos - vPos);
  // normal from the SAME dispersive field the vertex shader displaced
  float foam;
  vec3 fld = waveField(vPos.xz, uTime, uWind, uWindDir, foam);
  vec3 n = normalize(vec3(-fld.x, 1.0, -fld.z));
  float fres = pow(1.0 - clamp(dot(view, n), 0.0, 1.0), 3.0);
  vec3 deep = vec3(0.05, 0.14, 0.22) * (0.7 + uAmbient);
  vec3 shallow = vec3(0.12, 0.32, 0.42) * (0.7 + uAmbient);
  vec3 col = mix(deep, shallow, clamp(vWave*0.9 + 0.5, 0.0, 1.0));
  col = mix(col, skyColor(vec3(0.0,1.0,0.0), uSunDir, uAirMie, uAirI, 2)*0.9, vFoam); // whitecaps scatter the sky
  float spec = pow(max(dot(reflect(-uSunDir, n), view), 0.0), 90.0);
  col += uSunColor * spec * 0.9;
  vec3 skyRef = skyColor(reflect(-view, n), uSunDir, uAirMie, uAirI, 4); // the water mirrors the REAL sky
  col = mix(col, skyRef, fres*0.65);
  col = mix(col, col*vec3(0.6,0.62,0.72), uWetness*0.5); // rain darkens water
  col = aerial(col, normalize(vPos-uCamPos), length(vPos-uCamPos), uSunDir, uAirMie, uAirI, uAirFog, max(vPos.y, 0.0));
  col = col * uEyeTint;
  col *= uExposure;
  fragColor = vec4(col, uAlpha);
}
`;

// ---- VEGETATION: trees are REAL population (ecology) materialized as
// point-sprites. Health colors them (green → dry brown); height = maturity.
// D-O15 governs HOW MANY are materialized, never that they exist.
export const VEGETATION_VS = `#version 300 es
layout(location=0) in vec3 aPos;
layout(location=1) in vec2 aHH; // height (m), health (0..1)
uniform mat4 uVP; uniform float uPointScale;
out float vHealth;
void main(){
  vec3 wp = aPos + vec3(0.0, aHH.x * 0.5, 0.0);
  gl_Position = uVP * vec4(wp, 1.0);
  float w = max(gl_Position.w, 0.1);
  gl_PointSize = clamp(uPointScale * aHH.x / w, 1.5, 42.0);
  vHealth = aHH.y;
}`;
export const VEGETATION_FS = `#version 300 es
precision highp float;
in float vHealth;
uniform float uFog; uniform vec3 uSkyBottom; uniform vec3 uCamPos;
out vec4 fragColor;
void main(){
  vec3 healthy = vec3(0.16, 0.42, 0.14);
  vec3 dry = vec3(0.45, 0.36, 0.18);
  vec3 col = mix(dry, healthy, clamp(vHealth, 0.0, 1.0));
  fragColor = vec4(col, 0.92);
}`;

// ---- HORIZON MARKERS + WATER FILM: D-O15 re-representation of SCALE.
// Far fires = horizon glow (never dropped); far settlements = causal-state
// markers; hydrology film = the puddle/flow cells materialized as points.
export const HORIZON_VS = `#version 300 es
layout(location=0) in vec3 aPos;
layout(location=1) in vec4 aSC; // size(world), r, g, b
layout(location=2) in float aAlpha;
uniform mat4 uVP; uniform float uPointScale; uniform float uTime;
out float vAlpha; out vec3 vColor;
void main(){
  gl_Position = uVP * vec4(aPos, 1.0);
  float w = max(gl_Position.w, 0.1);
  gl_PointSize = clamp(uPointScale * aSC.x / w, 2.0, 90.0);
  float flicker = 1.0 + 0.18 * sin(uTime * 11.0 + aPos.x * 3.1 + aPos.z * 2.3);
  vColor = aSC.yzw * flicker;
  vAlpha = aAlpha;
}`;
export const HORIZON_FS = `#version 300 es
precision highp float;
in float vAlpha; in vec3 vColor;
out vec4 fragColor;
void main(){
  vec2 d = gl_PointCoord - 0.5;
  float r = length(d) * 2.0;
  float soft = clamp(1.0 - r, 0.0, 1.0);
  fragColor = vec4(vColor, vAlpha * soft);
}`;

// ---- TREE: the living population as REAL geometry (not billboards).
// Instance attrs: aT0 = (worldPos.xyz, height); aT1 = (health, wind, phase, pad).
export const TREE_VS = `#version 300 es
precision highp float;
layout(location=0) in vec3 aPos;
layout(location=1) in vec3 aNorm;
layout(location=2) in float aCanopy;
layout(location=3) in vec4 aT0;
layout(location=4) in vec4 aT1;
uniform mat4 uVP; uniform float uTime; uniform vec2 uWindDir;
out vec3 vPos; out vec3 vNorm; out float vCanopy; out float vHealth;
void main(){
  float h = max(aT0.w, 0.1);
  vec3 lp = aPos;
  // the cantilever bends DOWNWIND (the same wind of the sea, fire and clouds)
  float bend = aT1.y * 0.5 * aPos.y*aPos.y * (0.6 + 0.4*sin(uTime*1.4 + aT1.z));
  lp.x += bend*uWindDir.x; lp.z += bend*uWindDir.y;
  vec3 wp = aT0.xyz + lp*vec3(1.0, h, 1.0);
  vPos = wp; vNorm = aNorm; vCanopy = aCanopy; vHealth = aT1.x;
  gl_Position = uVP*vec4(wp, 1.0);
}`;

// TREE_FS reuses the GENERATED scattering physics (aerial perspective) — the
// tree breathes the SAME air as the terrain (no #version here: SCATTER_GLSL
// already opens the shader).
export const TREE_FS = SCATTER_GLSL + `
precision highp float;
in vec3 vPos; in vec3 vNorm; in float vCanopy; in float vHealth;
uniform vec3 uSunDir; uniform vec3 uSunColor; uniform float uAmbient;
uniform vec3 uCamPos; uniform float uAirMie; uniform float uAirI; uniform float uExposure;
uniform vec3 uEyeTint; uniform float uAirFog;
out vec4 fragColor;
void main(){
  vec3 bark = vec3(0.27, 0.19, 0.12);
  vec3 dry  = vec3(0.42, 0.35, 0.19);
  vec3 lush = vec3(0.13, 0.33, 0.12);
  vec3 col = vCanopy > 0.5 ? mix(dry, lush, clamp(vHealth, 0.0, 1.0)) : bark;
  float ndl = max(dot(normalize(vNorm), uSunDir), 0.0);
  col = col*(uSunColor*ndl + vec3(uAmbient*0.9));
  col = aerial(col, normalize(vPos-uCamPos), length(vPos-uCamPos), uSunDir, uAirMie, uAirI, uAirFog, max(vPos.y, 0.0));
  col = col * uEyeTint;
  col *= uExposure;
  fragColor = vec4(col, 1.0);
}`;

// ---- FIRE: hot gas EMITS blackbody light (Planck), cools, becomes smoke.
// Additive emission — the fire IS a light source; it never shades.
export const FIRE_VS = `#version 300 es
precision highp float;
layout(location=0) in vec3 aPos;
layout(location=1) in vec4 aSC;  // size, r, g, b
layout(location=2) in float aAlpha;
uniform mat4 uVP; uniform float uPointScale;
out vec3 vCol; out float vA;
void main(){
  vec4 clip = uVP*vec4(aPos, 1.0);
  float dist = max(clip.w, 0.1);
  gl_Position = clip;
  gl_PointSize = clamp(aSC.x*uPointScale/dist, 1.0, 220.0);
  vCol = aSC.yzw; vA = aAlpha;
}`;

export const FIRE_FS = `#version 300 es
precision highp float;
in vec3 vCol; in float vA;
out vec4 fragColor;
void main(){
  float d = length(gl_PointCoord - vec2(0.5));
  float fall = smoothstep(0.5, 0.10, d);
  float a = fall*vA;
  fragColor = vec4(vCol*a, a); // emissive: energy, not shading
}`;
