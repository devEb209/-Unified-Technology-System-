// UTS :: render/shaders — UTS GLSL programs (OURS).
// Materials, Blinn-Phong sun, PCF shadow mapping from OUR depth pass,
// up to 4 point lights (fires) — all interpreting the Frame, inventing nothing.

export const SKY_VS = `#version 300 es
layout(location=0) in vec2 aPos;
out vec2 vUV;
void main(){ vUV = aPos*0.5+0.5; gl_Position = vec4(aPos, 0.999, 1.0); }`;

export const SKY_FS = `#version 300 es
precision highp float;
in vec2 vUV;
uniform vec3 uSkyTop; uniform vec3 uSkyBottom; uniform float uFlash;
out vec4 fragColor;
void main(){
  vec3 col = mix(uSkyBottom, uSkyTop, pow(clamp(vUV.y,0.,1.),0.75));
  col += vec3(uFlash*0.5);
  fragColor = vec4(col,1.0);
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
void main(){
  vec3 cs[6];
  cs[0]=vec3(0.10,0.32,0.55); cs[1]=vec3(0.78,0.71,0.50); cs[2]=vec3(0.32,0.55,0.25);
  cs[3]=vec3(0.15,0.36,0.17); cs[4]=vec3(0.46,0.44,0.41); cs[5]=vec3(0.93,0.95,0.97);
  int b = int(vBiome+0.5);
  vec3 base = b==0?cs[0]: b==1?cs[1]: b==2?cs[2]: b==3?cs[3]: b==4?cs[4]: cs[5];
  vec3 n = normalize(vNorm);
  float ndl = max(dot(n,uSunDir),0.0);
  float sh = shadowSample(vPos, ndl);
  vec3 col = base * (uAmbient*0.55 + ndl*0.75*sh) * uSunColor;
  for (int i=0;i<4;i++){
    if (i>=uPointCount) break;
    vec3 L = uPointPos[i]-vPos;
    float d = length(L);
    float att = max(0.0, 1.0-d/26.0);
    col += base * uPointColor[i] * att * att * max(dot(n, L/max(d,0.01)),0.0) * 2.2;
  }
  col = mix(col, col*vec3(0.55,0.58,0.7), uWetness*0.65);
  float dcam = length(vPos-uCamPos);
  col = mix(col, uSkyBottom, clamp(1.0-exp(-dcam*uFog*0.008),0.0,0.9));
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
  float dcam = length(vWorld-uCamPos);
  col = mix(col, uSkyBottom, clamp(1.0-exp(-dcam*uFog*0.008),0.0,0.9));
  fragColor = vec4(col, uAlpha);
  fragColor = vec4(col,1.0);
}`;

export const POINTS_VS = `#version 300 es
layout(location=0) in float aSeed;
uniform mat4 uVP; uniform vec3 uCamPos; uniform float uTime; uniform float uWind; uniform float uCount;
out float vAlpha;
void main(){
  float x = (fract(aSeed*0.738)*2.0-1.0)*60.0;
  float z = (fract(aSeed*0.417)*2.0-1.0)*60.0;
  float fall = fract(aSeed*0.913 + uTime*(0.35+uWind*0.3));
  float y = 36.0*(1.0-fall);
  vec3 wp = vec3(uCamPos.x + x + uWind*12.0*fall, y, uCamPos.z + z);
  gl_Position = uVP*vec4(wp,1.0);
  gl_PointSize = 2.2;
  vAlpha = step(aSeed, uCount);
}`;

export const POINTS_FS = `#version 300 es
precision highp float;
in float vAlpha;
uniform vec3 uColor;
out vec4 fragColor;
void main(){ if (vAlpha<0.5) discard; fragColor = vec4(uColor,0.55); }`;

export const WATER_VS = `#version 300 es
layout(location=0) in vec3 aPos; // xz world, y ignored (rebuilt as waves)
uniform mat4 uVP; uniform float uTime; uniform float uSeaLevel; uniform float uWind;
out vec3 vPos; out float vWave;
void main(){
  float w = sin(aPos.x*0.11 + uTime*1.9)*0.5 + cos(aPos.z*0.13 - uTime*1.3)*0.35
          + sin((aPos.x+aPos.z)*0.05 + uTime*0.7)*0.4;
  float amp = 0.22 + uWind*0.5;
  float y = uSeaLevel + w*amp;
  vPos = vec3(aPos.x, y, aPos.z);
  vWave = w;
  gl_Position = uVP*vec4(vPos,1.0);
}`;

export const WATER_FS = `#version 300 es
precision highp float;
in vec3 vPos; in float vWave;
uniform vec3 uSunDir; uniform vec3 uSunColor; uniform float uAmbient;
uniform vec3 uSkyBottom; uniform float uFog; uniform vec3 uCamPos;
uniform float uWetness; uniform float uAlpha;
out vec4 fragColor;
void main(){
  vec3 view = normalize(uCamPos - vPos);
  // wave normal from the same field the vertex shader used (cheap derivative)
  vec3 n = normalize(vec3(-cos(vPos.x*0.11)*0.06, 1.0, cos(vPos.z*0.13)*0.05));
  float fres = pow(1.0 - clamp(dot(view, n), 0.0, 1.0), 3.0);
  vec3 deep = vec3(0.05, 0.14, 0.22) * (0.7 + uAmbient);
  vec3 shallow = vec3(0.12, 0.32, 0.42) * (0.7 + uAmbient);
  vec3 col = mix(deep, shallow, clamp(vWave*0.5 + 0.5, 0.0, 1.0));
  float spec = pow(max(dot(reflect(-uSunDir, n), view), 0.0), 90.0);
  col += uSunColor * spec * 0.9;
  col = mix(col, uSkyBottom, fres*0.65);
  col = mix(col, col*vec3(0.6,0.62,0.72), uWetness*0.5); // rain darkens water
  float dc = length(uCamPos - vPos);
  col = mix(col, uSkyBottom, clamp(1.0-exp(-dc*uFog*0.008),0.0,0.9));
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
