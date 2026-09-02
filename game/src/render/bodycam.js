import * as THREE from 'three';
import { EffectComposer } from 'three/examples/jsm/postprocessing/EffectComposer.js';
import { RenderPass } from 'three/examples/jsm/postprocessing/RenderPass.js';
import { ShaderPass } from 'three/examples/jsm/postprocessing/ShaderPass.js';
import { UnrealBloomPass } from 'three/examples/jsm/postprocessing/UnrealBloomPass.js';
import { SMAAPass } from 'three/examples/jsm/postprocessing/SMAAPass.js';

/*  Pipeline "AXON-K7": simula um sensor CMOS barato preso ao peito do operador.
    Nada aqui é estilização de filme — é degradação de sensor: rolling shutter,
    ganho ISO com ruído cromático, aberração cromática lateral, distorção de barril
    de lente grande-angular, respiração de foco, macroblocos de compressão H.264,
    gotas na lente, sujeira e clipping de highlight.                              */

const BodycamShader = {
  uniforms: {
    tDiffuse: { value: null },
    tHistory: { value: null },
    uTime: { value: 0 },
    uAspect: { value: 1.777 },
    uIso: { value: 0.35 },          // ganho do sensor -> ruído
    uExposure: { value: 1.0 },
    uBarrel: { value: 0.16 },
    uCA: { value: 1.0 },
    uShutter: { value: 0.0 },       // rolling shutter (skew) por velocidade angular
    uBlurAmt: { value: 0.0 },       // motion blur temporal
    uNV: { value: 0.0 },            // visão noturna
    uWet: { value: 0.0 },           // gotas na lente
    uDirt: { value: 0.35 },
    uBlood: { value: 0.0 },         // dano do operador
    uBreath: { value: 0.0 },
    uGlitch: { value: 0.0 },        // interferência de guerra eletrônica
    uFocus: { value: 0.0 },
    uDamage: { value: 0.0 }
  },
  vertexShader: /* glsl */`
    varying vec2 vUv;
    void main(){ vUv = uv; gl_Position = projectionMatrix * modelViewMatrix * vec4(position,1.0); }
  `,
  fragmentShader: /* glsl */`
    precision highp float;
    uniform sampler2D tDiffuse, tHistory;
    uniform float uTime,uAspect,uIso,uExposure,uBarrel,uCA,uShutter,uBlurAmt,uNV,uWet,uDirt,uBlood,uBreath,uGlitch,uFocus,uDamage;
    varying vec2 vUv;

    float hash(vec2 p){ p = fract(p*vec2(443.897,441.423)); p += dot(p,p+19.19); return fract(p.x*p.y); }
    float hash3(vec3 p){ return fract(sin(dot(p,vec3(12.9898,78.233,37.719)))*43758.5453); }
    float n2(vec2 p){ vec2 i=floor(p), f=fract(p); f=f*f*(3.-2.*f);
      return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y); }

    vec2 barrel(vec2 uv, float k){
      vec2 c = uv - 0.5; c.x *= uAspect;
      float r2 = dot(c,c);
      c *= 1.0 + k*r2 + k*0.42*r2*r2;
      c.x /= uAspect;
      return c + 0.5;
    }

    void main(){
      vec2 uv = vUv;

      // rolling shutter: linhas inferiores amostram o mundo alguns ms depois
      uv.x += uShutter * (uv.y - 0.5) * 0.06;
      uv.y += uShutter * 0.004 * sin(uv.y*90.0 + uTime*40.0);

      // respiração/estabilização mecânica residual da lente
      uv += vec2(sin(uTime*1.9)*0.0006, cos(uTime*1.4)*0.0009) * (0.4 + uBreath*3.0);

      // gotas de chuva na lente
      if(uWet > 0.001){
        vec2 gp = uv*vec2(uAspect,1.0)*8.0;
        vec2 gi = floor(gp); vec2 gf = fract(gp);
        float seed = hash(gi);
        float drift = fract(seed*7.3 + uTime*0.07*(0.4+seed));
        vec2 dc = vec2(0.5 + (seed-0.5)*0.6, drift);
        float d = length((gf-dc)*vec2(1.0,1.35));
        float rad = 0.10 + seed*0.16;
        float drop = smoothstep(rad, rad*0.35, d) * step(0.62, seed) * uWet;
        vec2 g = normalize(gf-dc+1e-5);
        uv -= g * drop * 0.028;
      }

      // distorção de barril + aberração cromática lateral (cresce com o raio)
      float k = uBarrel;
      vec2 uvR = barrel(uv, k*(1.0 + 0.010*uCA));
      vec2 uvG = barrel(uv, k);
      vec2 uvB = barrel(uv, k*(1.0 - 0.010*uCA));

      vec3 col;
      col.r = texture2D(tDiffuse, uvR).r;
      col.g = texture2D(tDiffuse, uvG).g;
      col.b = texture2D(tDiffuse, uvB).b;

      // motion blur temporal (acumulação de frames do sensor lento)
      vec3 hist = texture2D(tHistory, uvG).rgb;
      col = mix(col, max(col, hist*0.98), clamp(uBlurAmt,0.0,0.72));

      // desfoco por foco automático caçando (breathing) e por dano
      float defocus = uFocus*0.0035 + uDamage*0.004;
      if(defocus > 0.0002){
        vec3 acc = vec3(0.0);
        for(int i=0;i<6;i++){
          float a = float(i)*1.0472 + uTime;
          acc += texture2D(tDiffuse, uvG + vec2(cos(a),sin(a))*defocus).rgb;
        }
        col = mix(col, acc/6.0, 0.55);
      }

      col *= uExposure;

      // visão noturna Gen-3: ganho brutal, verde P43, halo e cintilação de fóton
      if(uNV > 0.01){
        float lum = dot(col, vec3(0.299,0.587,0.114));
        float g = pow(lum*7.5 + 0.02, 0.78);
        float scint = hash3(vec3(vUv*900.0, floor(uTime*40.0)))*0.30;
        vec3 nvc = vec3(g*0.30, g*1.10 + scint*0.5, g*0.42);
        nvc += vec3(0.0,1.0,0.35) * smoothstep(0.75,1.5,g) * 0.22; // blooming do tubo
        float r = length((vUv-0.5)*vec2(uAspect,1.0));
        nvc *= smoothstep(0.62,0.30,r);                             // vinheta do tubo
        nvc += (hash3(vec3(vUv*260.0, floor(uTime*30.0)))-0.5)*0.06;
        col = mix(col, nvc, uNV);
      }

      // ruído de sensor dependente de ISO e de luminância (mais grão na sombra)
      float lum = dot(col, vec3(0.2126,0.7152,0.0722));
      float grainAmt = uIso * (0.055 + 0.16*exp(-lum*7.0));
      vec3 gn = vec3(
        hash3(vec3(vUv*1180.0, floor(uTime*50.0))),
        hash3(vec3(vUv*1180.0+11.7, floor(uTime*50.0))),
        hash3(vec3(vUv*1180.0+23.4, floor(uTime*50.0)))) - 0.5;
      col += gn * grainAmt * vec3(1.0,0.85,1.25);

      // macroblocos de compressão em movimento forte / glitch de GE
      float gl = max(uGlitch, uBlurAmt*0.20);
      if(gl > 0.02){
        vec2 blk = floor(vUv*vec2(80.0,45.0));
        float bn = hash(blk + floor(uTime*11.0));
        if(bn > 1.0 - gl*0.45){
          vec2 off = (vec2(hash(blk+1.3), hash(blk+7.7))-0.5)*0.02*gl;
          col = mix(col, texture2D(tDiffuse, barrel(uv+off,k)).rgb, 0.85);
          col += (bn-0.5)*0.10;
        }
        if(hash(vec2(floor(uTime*7.0),0.0)) > 1.0-gl*0.3){
          float band = step(0.5, fract(vUv.y*3.0 + uTime*3.0));
          col = mix(col, col.brg*1.1, band*gl*0.5);
        }
      }

      // sujeira/óleo no protetor da lente + arranhões
      float dirt = n2(vUv*vec2(uAspect,1.0)*6.0)*0.6 + n2(vUv*22.0)*0.4;
      float smudge = smoothstep(0.55,1.0,dirt)*uDirt;
      col = mix(col, col*0.86 + vec3(0.04,0.042,0.045)*lum*3.0, smudge);
      float scratch = smoothstep(0.985,1.0, n2(vec2(vUv.x*230.0, vUv.y*3.0)));
      col += scratch*0.05*lum;

      // sangue/estilhaço sobre a lente quando o operador é atingido
      if(uBlood > 0.001){
        float b = smoothstep(0.62,1.0, n2(vUv*vec2(uAspect,1.0)*5.0 + 31.0));
        col = mix(col, vec3(0.22,0.02,0.02), b*uBlood*0.85);
        col *= 1.0 - uBlood*0.25*smoothstep(0.2,0.9,length(vUv-0.5));
      }

      // vinheta óptica + queda de nitidez nos cantos
      float r = length((vUv-0.5)*vec2(uAspect,1.0));
      col *= smoothstep(1.05, 0.28, r)*0.55 + 0.55;

      // clipping de highlight do sensor barato (canais estouram em ordem)
      col = min(col, vec3(1.35));
      col.b = min(col.b, 1.12);

      // curva de contraste tipo câmera corporal (log -> rec709 sujo)
      col = max(vec3(0.0), col);
      col = (col*(2.51*col+0.03))/(col*(2.43*col+0.59)+0.14);
      col = pow(col, vec3(0.92,0.95,1.02));
      col = mix(vec3(dot(col,vec3(0.299,0.587,0.114))), col, 1.06 - uNV*0.5);

      // interlace/linhas de leitura muito sutis
      col *= 1.0 - 0.018*step(0.5, fract(vUv.y*360.0));

      gl_FragColor = vec4(col, 1.0);
    }
  `
};

const CopyShader = {
  uniforms: { tDiffuse: { value: null } },
  vertexShader: `varying vec2 vUv; void main(){vUv=uv;gl_Position=projectionMatrix*modelViewMatrix*vec4(position,1.0);}`,
  fragmentShader: `uniform sampler2D tDiffuse; varying vec2 vUv; void main(){ gl_FragColor = texture2D(tDiffuse,vUv); }`
};

export class BodycamPipeline {
  constructor(renderer, scene, camera) {
    this.renderer = renderer; this.scene = scene; this.camera = camera;
    const size = renderer.getSize(new THREE.Vector2());
    const dpr = renderer.getPixelRatio();

    this.composer = new EffectComposer(renderer);
    this.composer.addPass(new RenderPass(scene, camera));

    this.bloom = new UnrealBloomPass(new THREE.Vector2(size.x, size.y), 0.42, 0.72, 0.86);
    this.composer.addPass(this.bloom);

    this.bodycam = new ShaderPass(BodycamShader);
    this.composer.addPass(this.bodycam);

    this.smaa = new SMAAPass(size.x * dpr, size.y * dpr);
    this.composer.addPass(this.smaa);

    this.history = new THREE.WebGLRenderTarget(size.x * dpr, size.y * dpr, { depthBuffer: false });
    this.copy = new ShaderPass(CopyShader);
    this.copy.renderToScreen = false;

    this.u = this.bodycam.uniforms;
    this.u.uAspect.value = size.x / size.y;
    this._exposureTarget = 1;
  }

  setSize(w, h) {
    const dpr = this.renderer.getPixelRatio();
    this.composer.setSize(w, h);
    this.history.setSize(w * dpr, h * dpr);
    this.u.uAspect.value = w / h;
    this.bloom.setSize(w, h);
  }

  render(dt, state) {
    const u = this.u;
    u.uTime.value += dt;
    // adaptação automática de exposição (o sensor caça a luz, com atraso)
    const t = state.targetExposure ?? 1;
    u.uExposure.value += (t - u.uExposure.value) * Math.min(1, dt * (t > u.uExposure.value ? 1.1 : 2.4));
    u.uIso.value = state.iso;
    u.uShutter.value = state.shutter;
    u.uBlurAmt.value = state.motion;
    u.uNV.value = state.nv;
    u.uWet.value = state.wet;
    u.uBlood.value = state.blood;
    u.uBreath.value = state.breath;
    u.uGlitch.value = state.glitch;
    u.uFocus.value = state.focus;
    u.uDamage.value = state.damage;
    u.uBarrel.value = state.barrel ?? 0.16;
    this.bloom.strength = state.nv > 0.5 ? 0.9 : 0.42;
    u.tHistory.value = this.history.texture;

    this.composer.render(dt);

    // guarda o frame final para o borrão temporal do próximo
    this.copy.uniforms.tDiffuse.value = this.composer.readBuffer.texture;
    this.copy.render(this.renderer, this.history, this.composer.readBuffer, dt, false);
  }
}
