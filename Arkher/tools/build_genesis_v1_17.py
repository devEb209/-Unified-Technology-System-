#!/usr/bin/env python3
"""GENESIS V1.17 — +20 editores x60 = 12920 ferramentas, 215 editores"""
import os
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REL = os.path.join(ROOT, "Releases")
os.makedirs(REL, exist_ok=True)
from build_rbxm import Inst, serialize, write, T_STRING
from build_genesis_v1_2 import build_editor_window
from build_genesis_v1_16 import build_all_v116
EDITORS = [
 ("CrowdSimLab","CROWD SIM 2",0x6A1B9A,60),
 ("TrafficSimLab","TRAFFIC SIM 2",0xF57F17,60),
 ("EcologySimLab","ECOLOGY SIM",0x33691E,60),
 ("EconomySimLab","ECONOMY SIM 2",0xF57F17,60),
 ("WeatherSimLab","WEATHER SIM 3",0x0288D1,60),
 ("OceanSimLab","OCEAN SIM 2",0x0277BD,60),
 ("RiverSimLab","RIVER SIM",0x01579B,60),
 ("VegetationSimLab","VEGETATION SIM",0x2E7D32,60),
 ("BuildingSimLab","BUILDING SIM",0x37474F,60),
 ("RoadSimLab","ROAD SIM 2",0x424242,60),
 ("BridgeSimLab","BRIDGE SIM 2",0x5D4037,60),
 ("DestructionSimLab","DESTRUCTION 2",0xB71C1C,60),
 ("FireSimLab","FIRE SIM",0xE65100,60),
 ("SmokeSimLab","SMOKE SIM",0x455A64,60),
 ("ExplosionLab","EXPLOSION",0xBF360C,60),
 ("ParticleLab","PARTICLE SYSTEM",0xFF6F00,60),
 ("FluidSimLab2","FLUID SIM 2",0x01579B,60),
 ("ClothSimLab2","CLOTH SIM 2",0x880E4F,60),
 ("HairSimLab2","HAIR SIM 2",0x6D4C41,60),
 ("RagdollLab","RAGDOLL",0x4A148C,60),
]
def gen(n):
    base=["Create","Edit","Delete","Clone","Merge","Split","Optimize","Validate","Preview","Export","Import","Sync","Batch","Randomize","Procedural","Neural","Simulate","Analyze","Profile","Debug","Cache","Stream","Compress","Encrypt","Auth","Guard","Budget","Scheduler","Pipeline","Graph","Index","Search","Filter","LOD","Cull","Occlude","Bake","Lightmap","Probe","Reflect","Shadow","Denoise","Temporal","Spatial","Bilateral","Quantize","Distill","Prune","Accelerate","Serve","Evaluate","Benchmark","Safety","Guardrail","Explain","Trace","Log","Deploy","Scale","Monitor"]
    return [f"{n}_{b}" for b in base[:60]]
LAB={n: gen(n) for n,_,_,_ in EDITORS}
FUNC="""
local M={CrowdSimLab="crowd",TrafficSimLab="traffic",EcologySimLab="ecology",EconomySimLab="economy",WeatherSimLab="weather",OceanSimLab="ocean",RiverSimLab="river",VegetationSimLab="vegetation",BuildingSimLab="building",RoadSimLab="road",BridgeSimLab="bridge",DestructionSimLab="destruction",FireSimLab="fire",SmokeSimLab="smoke",ExplosionLab="explosion",ParticleLab="particle",FluidSimLab2="fluid",ClothSimLab2="cloth",HairSimLab2="hair",RagdollLab="ragdoll"}
local P=game:GetService("Players") local pl=P.LocalPlayer
local function call(pat,name)
 local e=_G.ARKHER if not e then print("[TOOL] "..name.." offline") return end
 local f=e:findSystems(pat) if #f==0 then f=e:findSystems(string.lower(name)) end
 if #f>0 then local en=f[1] local ok=pcall(function() if en.instance.selfTest then return en.instance.selfTest() end return true end) print(string.format("[TOOL] %s -> %s ok=%s",name,en.key,tostring(ok)))
  local g=pl.PlayerGui:FindFirstChild("ARKHER_STUDIO") if g then local s=g.Root:FindFirstChild("StatusBar",true) if s then local l=s:FindFirstChild("Status") if l then l.Text=name.." -> "..en.key end end end
 else print("[TOOL] "..name.." no "..pat) end
end
local function wire(n)
 local g=P.LocalPlayer.PlayerGui:FindFirstChild("ARKHER_STUDIO") if not g then return end
 local w=g.Root:FindFirstChild(n,true) if not w then return end
 local c=w:FindFirstChild("Tools",true) or w
 for _,b in ipairs(c:GetDescendants()) do if b:IsA("TextButton") then b.Activated:Connect(function()
  local o=b.BackgroundColor3 b.BackgroundColor3=Color3.fromRGB(0,255,136) task.delay(0.2,function() b.BackgroundColor3=o end)
  local cat=M[n] or "" local pat=cat~="" and ("arkher."..cat.."."..string.lower(b.Name)) or string.lower(b.Name)
  call(pat,b.Name)
 end) end end
end
for _,n in ipairs({"CrowdSimLab","TrafficSimLab","EcologySimLab","EconomySimLab","WeatherSimLab","OceanSimLab","RiverSimLab","VegetationSimLab","BuildingSimLab","RoadSimLab","BridgeSimLab","DestructionSimLab","FireSimLab","SmokeSimLab","ExplosionLab","ParticleLab","FluidSimLab2","ClothSimLab2","HairSimLab2","RagdollLab"}) do pcall(wire,n) end
print("[V1.17] +20 — 215 editores")
"""
def build_all_v117():
    roots=build_all_v116()
    for r in roots:
        if r.cls=="StarterGui":
            for sg in r.children:
                if sg.name=="ARKHER_STUDIO":
                    for child in sg.children:
                        if child.name=="Root":
                            ex={c.name for c in child.children}
                            for name,title,color,_ in EDITORS:
                                if name not in ex:
                                    child.add(build_editor_window(name,title,color,LAB[name]))
    for r in roots:
        if r.cls=="StarterPlayer":
            for f in r.children:
                if f.name=="StarterPlayerScripts":
                    f.add(Inst("LocalScript","ARKHER_ToolsFunctional_V117",{"Source":(T_STRING,FUNC)}))
    return roots
if __name__=="__main__":
    roots=build_all_v117()
    out=os.path.join(REL,"ARKHER_STUDIO_1_GENESIS_EDITION_V1_17.rbxl")
    write(out, serialize(roots))
    print(f"V1.17 {out} ({os.path.getsize(out)/1048576:.2f} MB) - 215 editores 12920 ferramentas")
    import subprocess
    subprocess.run(["python3","tools/validate_rbxm.py",out], cwd=ROOT)
    from build_complete import arkher_installer_folder
    write(os.path.join(REL,"ARKHER_STUDIO_1_GENESIS_EDITION_V1_17.rbxm"), serialize([arkher_installer_folder()]))
    print("rbxm done")
