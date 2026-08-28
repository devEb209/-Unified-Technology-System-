// UTS :: render/shaders — GLSL ES 3.0 programs for the WebGL2 backend.
// The renderer MANIFESTS the Frame; shaders interpret materials, light,
// atmosphere and phenomena — they do not invent reality.

export const TERRAIN_VS = `#version 300 es
layout(location=0) in vec3 aPos;
layout(location=1) in vec3 aNorm;
layout(location=2) in float aBiome;
uniform mat4 uVP;
out vec3 vPos;
out vec3 vNorm;
out float vBiome;
void main(){
  vPos = aPos;
  vNorm = aNorm;
  vBiome = aBiome;
  gl_Position = uVP * vec4(aPos, 1.0);
}`;

export const TERRAIN_FS = `#version 300 es
precision highp float;
in vec3 vPos;
in vec3 vNorm;
in float vBiome;
uniform vec3 uSunDir;
uniform vec3 uSunColor;
uniform float uAmbient;
uniform vec3 uSkyBottom;
uniform float uFog;
uniform float uWetness;
uniform vec3 uCamPos;
out vec4 fragColor;
void main(){
  vec3 cWater = vec3(0.10,0.32,0.55);
  vec3 cSand  = vec3(0.78,0.71,0.50);
  vec3 cGrass = vec3(0.32,0.55,0.25);
  vec3 cForest= vec3(0.15,0.36,0.17);
  vec3 cRock  = vec3(0.46,0.44,0.41);
  vec3 cSnow  = vec3(0.93,0.95,0.97);
  int b = int(vBiome + 0.5);
  vec3 base = b==0?cWater : b==1?cSand : b==2?cGrass : b==3?cForest : b==4?cRock : cSnow;
  float diff = max(dot(normalize(vNorm), uSunDir), 0.0);
  vec3 col = base * (uAmbient * 0.55 + diff * 0.75) * uSunColor;
  col = mix(col, col * vec3(0.55,0.58,0.7), uWetness * 0.65);  // rain wetness darkens
  float d = length(vPos - uCamPos);
  float fog = 1.0 - exp(-d * uFog * 0.008);
  col = mix(col, uSkyBottom, clamp(fog, 0.0, 0.9));
  fragColor = vec4(col, 1.0);
}`;

export const ENTITY_VS = `#version 300 es
layout(location=0) in vec3 aPos;
layout(location=1) in vec3 aNorm;
uniform mat4 uModel;
uniform mat4 uVP;
out vec3 vNorm;
out vec3 vWorld;
void main(){
  vWorld = (uModel * vec4(aPos, 1.0)).xyz;
  vNorm = normalize(mat3(uModel) * aNorm);
  gl_Position = uVP * vec4(vWorld, 1.0);
}`;

export const ENTITY_FS = `#version 300 es
precision highp float;
in vec3 vNorm;
in vec3 vWorld;
uniform vec3 uColor;
uniform vec3 uSunDir;
uniform vec3 uSunColor;
uniform float uAmbient;
uniform float uEmissive;
uniform vec3 uSkyBottom;
uniform float uFog;
uniform vec3 uCamPos;
out vec4 fragColor;
void main(){
  float diff = max(dot(normalize(vNorm), uSunDir), 0.0);
  vec3 col = uColor * (uAmbient * 0.5 + diff * 0.8) * uSunColor + uColor * uEmissive * 1.5;
  float d = length(vWorld - uCamPos);
  float fog = 1.0 - exp(-d * uFog * 0.008);
  col = mix(col, uSkyBottom, clamp(fog, 0.0, 0.9));
  fragColor = vec4(col, 1.0);
}`;

export const SKY_VS = `#version 300 es
layout(location=0) in vec2 aPos;
out vec2 vUV;
void main(){
  vUV = aPos * 0.5 + 0.5;
  gl_Position = vec4(aPos, 0.999, 1.0);
}`;

export const SKY_FS = `#version 300 es
precision highp float;
in vec2 vUV;
uniform vec3 uSkyTop;
uniform vec3 uSkyBottom;
uniform float uFlash;
out vec4 fragColor;
void main(){
  vec3 col = mix(uSkyBottom, uSkyTop, pow(clamp(vUV.y, 0.0, 1.0), 0.75));
  col += vec3(uFlash * 0.5);
  fragColor = vec4(col, 1.0);
}`;

export const POINTS_VS = `#version 300 es
layout(location=0) in float aSeed;
uniform mat4 uVP;
uniform vec3 uCamPos;
uniform float uTime;
uniform float uWind;
uniform float uCount;
out float vAlpha;
void main(){
  float x = (fract(aSeed * 0.738) * 2.0 - 1.0) * 60.0;
  float z = (fract(aSeed * 0.417) * 2.0 - 1.0) * 60.0;
  float fall = fract(aSeed * 0.913 + uTime * (0.35 + uWind * 0.3));
  float y = 36.0 * (1.0 - fall);
  vec3 wp = vec3(uCamPos.x + x + uWind * 12.0 * fall, y, uCamPos.z + z);
  gl_Position = uVP * vec4(wp, 1.0);
  gl_PointSize = 2.2;
  vAlpha = step(aSeed, uCount);
}`;

export const POINTS_FS = `#version 300 es
precision highp float;
in float vAlpha;
uniform vec3 uColor;
out vec4 fragColor;
void main(){
  if (vAlpha < 0.5) discard;
  fragColor = vec4(uColor, 0.55);
}`;
