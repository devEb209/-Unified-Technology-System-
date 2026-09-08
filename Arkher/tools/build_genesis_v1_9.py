#!/usr/bin/env python3
"""GENESIS V1.9 — +10 editores x60 = 4220 ferramentas, 70 editores"""
import os
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REL = os.path.join(ROOT, "Releases")
os.makedirs(REL, exist_ok=True)
from build_rbxm import Inst, serialize, write, T_STRING
from build_genesis_v1_2 import build_editor_window
from build_genesis_v1_8 import build_all_v18
EDITORS = [
 ("OccupancyMap","OCCUPANCY MAP",0x37474F,60),
 ("InterestField","INTEREST FIELD",0x4A148C,60),
 ("FidelityBand","FIDELITY BAND",0x006064,60),
 ("PersistSegment","PERSIST SEGMENT",0x1B5E20,60),
 ("CoherenceSeam","COHERENCE SEAM",0xB71C1C,60),
 ("NeuralPatch","NEURAL PATCH",0x4A148C,60),
 ("SimDomain","SIM DOMAIN",0x0D47A1,60),
 ("ArchitectDistrict","ARCHITECT DISTRICT",0x3E2723,60),
 ("BiomeCont2","BIOME CONT 2",0x33691E,60),
 ("CityCont2","CITY CONT 2",0x212121,60),
]
def gen(n):
    base=["InfiniteGrid","EpochClock","SparseResidency","MultiScale","PersistentState","CoherenceGuard","NeuralField","WorldMemory","ComplexityBudget","SimulationFabric","RealityContinuum","EmergenceContinuum","Validator","Optimizer","Profiler","Cache","Stream","Pool","Async","Parallel","Worker","Error","Logging","Diagnostics","Validation","Config","Environment","FeatureFlag","Capability","Permission","Sandbox","APIGateway","Extension","HotReload","Versioning","Migration","BuildGraph","Bootstrap","Continuum","Epoch","Sparse","Multiscale","Persistent","Coherence","Neural","WorldMem","Complexity","Fabric","Reality","Emergence","LOD","HLOD","Cull","Occlude","Batch","Instance","Atlas","Compress","Encrypt","Guard"]
    return [f"{n}_{s}" for s in base[:60]]
LAB={n:gen(n) for n,_,_,_ in EDITORS}
FUNC="""
local M={OccupancyMap="occupancymap",InterestField="interestfield",FidelityBand="fidelityband",PersistSegment="persistsegment",CoherenceSeam="coherenceseam",NeuralPatch="neuralpatch",SimDomain="simdomain",ArchitectDistrict="architectdistrict",BiomeCont2="biomecont",CityCont2="citycont"}
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
  local cat=M[n] or "" local pat=cat~="" and ("arkher.contsim."..cat.."."..string.lower(b.Name)) or string.lower(b.Name)
  call(pat,b.Name)
 end) end end
end
for _,n in ipairs({"OccupancyMap","InterestField","FidelityBand","PersistSegment","CoherenceSeam","NeuralPatch","SimDomain","ArchitectDistrict","BiomeCont2","CityCont2"}) do pcall(wire,n) end
print("[V1.9] +10 — 70 editores")
"""
def build_all_v19():
    roots=build_all_v18()
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
                    f.add(Inst("LocalScript","ARKHER_ToolsFunctional_V19",{"Source":(T_STRING,FUNC)}))
    return roots
if __name__=="__main__":
    roots=build_all_v19()
    out=os.path.join(REL,"ARKHER_STUDIO_1_GENESIS_EDITION_V1_9.rbxl")
    write(out, serialize(roots))
    print(f"V1.9 {out} ({os.path.getsize(out)/1048576:.2f} MB) - 70 editores 4220 ferramentas")
    import subprocess
    subprocess.run(["python3","tools/validate_rbxm.py",out], cwd=ROOT)
    from build_complete import arkher_installer_folder
    write(os.path.join(REL,"ARKHER_STUDIO_1_GENESIS_EDITION_V1_9.rbxm"), serialize([arkher_installer_folder()]))
    print("rbxm done")
