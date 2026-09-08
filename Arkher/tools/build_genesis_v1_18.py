#!/usr/bin/env python3
"""GENESIS V1.18 — +20 editores x60 = 14120 ferramentas, 235 editores"""
import os
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REL = os.path.join(ROOT, "Releases")
os.makedirs(REL, exist_ok=True)
from build_rbxm import Inst, serialize, write, T_STRING
from build_genesis_v1_2 import build_editor_window
from build_genesis_v1_17 import build_all_v117
EDITORS = [
 ("VehicleSimLab2","VEHICLE SIM 2",0x01579B,60),
 ("CharacterSimLab2","CHARACTER SIM 2",0x4A148C,60),
 ("AnimationSimLab2","ANIMATION SIM 2",0x6A1B9A,60),
 ("PhysicsSimLab2","PHYSICS SIM 2",0xBF360C,60),
 ("AudioSimLab2","AUDIO SIM 2",0x880E4F,60),
 ("VFXSimLab2","VFX SIM 2",0xE65100,60),
 ("LightSimLab2","LIGHT SIM 2",0xF9A825,60),
 ("RenderSimLab2","RENDER SIM 2",0x0288D1,60),
 ("MaterialSimLab2","MATERIAL SIM 2",0x6D4C41,60),
 ("TerrainSimLab3","TERRAIN SIM 3",0x2E7D32,60),
 ("ProceduralSimLab2","PROCEDURAL 2",0x4527A0,60),
 ("NeuralSimLab2","NEURAL SIM 2",0x00ACC1,60),
 ("WorldSimLab3","WORLD SIM 3",0x2E7D32,60),
 ("CollabSimLab2","COLLAB SIM 2",0xFF8F00,60),
 ("SecuritySimLab2","SECURITY SIM 2",0xB71C1C,60),
 ("OptimizationSimLab2","OPTIMIZATION 2",0x00695C,60),
 ("AssetSimLab2","ASSET SIM 2",0x5D4037,60),
 ("GameplaySimLab2","GAMEPLAY SIM 2",0xFF6F00,60),
 ("NetworkSimLab2","NETWORK SIM 2",0x0D47A1,60),
 ("CoreSimLab2","CORE SIM 2",0x37474F,60),
]
def gen(n):
    base=["Create","Edit","Delete","Clone","Merge","Split","Optimize","Validate","Preview","Export","Import","Sync","Batch","Randomize","Procedural","Neural","Simulate","Analyze","Profile","Debug","Cache","Stream","Compress","Encrypt","Auth","Guard","Budget","Scheduler","Pipeline","Graph","Index","Search","Filter","LOD","Cull","Occlude","Bake","Lightmap","Probe","Reflect","Shadow","Denoise","Temporal","Spatial","Bilateral","Quantize","Distill","Prune","Accelerate","Serve","Evaluate","Benchmark","Safety","Guardrail","Explain","Trace","Log","Deploy","Scale","Monitor"]
    return [f"{n}_{b}" for b in base[:60]]
LAB={n: gen(n) for n,_,_,_ in EDITORS}
FUNC="""
local M={VehicleSimLab2="vehicle",CharacterSimLab2="character",AnimationSimLab2="animation",PhysicsSimLab2="physics",AudioSimLab2="audio",VFXSimLab2="vfx",LightSimLab2="light",RenderSimLab2="render",MaterialSimLab2="material",TerrainSimLab3="terrain",ProceduralSimLab2="procedural",NeuralSimLab2="neural",WorldSimLab3="world",CollabSimLab2="collab",SecuritySimLab2="security",OptimizationSimLab2="optimization",AssetSimLab2="asset",GameplaySimLab2="gameplay",NetworkSimLab2="network",CoreSimLab2="core"}
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
for _,n in ipairs({"VehicleSimLab2","CharacterSimLab2","AnimationSimLab2","PhysicsSimLab2","AudioSimLab2","VFXSimLab2","LightSimLab2","RenderSimLab2","MaterialSimLab2","TerrainSimLab3","ProceduralSimLab2","NeuralSimLab2","WorldSimLab3","CollabSimLab2","SecuritySimLab2","OptimizationSimLab2","AssetSimLab2","GameplaySimLab2","NetworkSimLab2","CoreSimLab2"}) do pcall(wire,n) end
print("[V1.18] +20 — 235 editores")
"""
def build_all_v118():
    roots=build_all_v117()
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
                    f.add(Inst("LocalScript","ARKHER_ToolsFunctional_V118",{"Source":(T_STRING,FUNC)}))
    return roots
if __name__=="__main__":
    roots=build_all_v118()
    out=os.path.join(REL,"ARKHER_STUDIO_1_GENESIS_EDITION_V1_18.rbxl")
    write(out, serialize(roots))
    print(f"V1.18 {out} ({os.path.getsize(out)/1048576:.2f} MB) - 235 editores 14120 ferramentas")
    import subprocess
    subprocess.run(["python3","tools/validate_rbxm.py",out], cwd=ROOT)
    from build_complete import arkher_installer_folder
    write(os.path.join(REL,"ARKHER_STUDIO_1_GENESIS_EDITION_V1_18.rbxm"), serialize([arkher_installer_folder()]))
    print("rbxm done")
