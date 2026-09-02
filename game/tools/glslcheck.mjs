import { parser } from '@shaderfrog/glsl-parser';
import fs from 'fs';
const files = ['src/render/bodycam.js','src/main.js'];
const re = /\/\*\s*glsl\s*\*\/\s*`([\s\S]*?)`|fragmentShader:\s*`([\s\S]*?)`|vertexShader:\s*`([\s\S]*?)`/g;
let n=0, bad=0;
for (const f of files){
  const src = fs.readFileSync(f,'utf8');
  let m;
  while((m = re.exec(src))){
    const code = m[1]||m[2]||m[3];
    if(!code || !/void\s+main/.test(code)) continue;
    n++;
    const pre = `precision highp float;
uniform mat4 projectionMatrix, modelViewMatrix; attribute vec3 position; attribute vec2 uv;
`;
    try { parser.parse(/attribute|gl_Position\s*=\s*projectionMatrix/.test(code)? pre+code : pre+code); }
    catch(e){ bad++; console.log(`ERRO GLSL em ${f} bloco #${n}: ${e.message.split('\n')[0]}`); }
  }
}
console.log(`${n} shaders analisados, ${bad} com erro de sintaxe`);
