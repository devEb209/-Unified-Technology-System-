import * as THREE from 'three';
const G=9.80665;
function sim(mv,bc,dist){
  let p=new THREE.Vector3(0,0,0), v=new THREE.Vector3(0,0,-mv), t=0, h=1/2000;
  while(-p.z<dist && t<5){
    const rel=v.clone(); const s=rel.length();
    const k=0.000302/Math.max(0.05,bc);
    v.addScaledVector(rel.normalize().multiplyScalar(-k*s*s),h);
    v.y-=G*h; p.addScaledVector(v,h); t+=h;
  }
  return {drop:-p.y,t,vel:v.length()};
}
for(const [n,mv,bc,d] of [['M110 7.62 @400m',838,0.500,400],['M110 @800m',838,0.500,800],['MK18 5.56 @300m',780,0.304,300],['Glock 9mm @50m',365,0.165,50]]){
  const r=sim(mv,bc,d);
  console.log(`${n}: queda ${r.drop.toFixed(2)} m | tempo ${r.t.toFixed(3)} s | vel restante ${r.vel.toFixed(0)} m/s`);
}
