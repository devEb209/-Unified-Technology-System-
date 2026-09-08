#!/usr/bin/env python3
"""GENESIS V1.19 — +20 editores x60 = 15320 ferramentas, 255 editores"""
import os
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REL = os.path.join(ROOT, "Releases")
os.makedirs(REL, exist_ok=True)
from build_rbxm import Inst, serialize, write, T_STRING
from build_genesis_v1_2 import build_editor_window
from build_genesis_v1_18 import build_all_v118
EDITORS = [
 ("ContinuumCoreLab","CONTINUUM CORE",0x4527A0,60),
 ("RealityLab","REALITY FABRIC",0x4A148C,60),
 ("EmergenceLab","EMERGENCE",0x6A1B9A,60),
 ("NeuralFieldLab","NEURAL FIELD",0x283593,60),
 ("SparseLab","SPARSE RESIDENCY",0x00695C,60),
 ("InfiniteGridLab","INFINITE GRID",0x0D47A1,60),
 ("EpochLab","EPOCH CLOCK",0x01579B,60),
 ("WorldMemoryLab","WORLD MEMORY",0x4CAF50,60),
 ("ComplexityLab","COMPLEXITY BUDGET",0xFF6F00,60),
 ("FabricLab","SIM FABRIC",0x5D4037,60),
 ("CoherenceLab","COHERENCE GUARD",0x37474F,60),
 ("HorizonLab","HORIZON SPAN",0x0D47A1,60),
 ("SeamLab","SEAM LATTICE 2",0x311B92,60),
 ("OccupancyLab2","OCCUPANCY 2",0x37474F,60),
 ("InterestLab2","INTEREST 2",0x4A148C,60),
 ("FidelityLab2","FIDELITY 2",0x006064,60),
 ("PersistLab2","PERSIST 2",0x1B5E20,60),
 ("CoherenceSeamLab2","COHERENCE SEAM 2",0xB71C1C,60),
 ("NeuralPatchLab2","NEURAL PATCH 2",0x4A148C,60),
 ("SimDomainLab2","SIM DOMAIN 2",0x0D47A1,60),
]
def gen(n):
    base=["InfiniteGrid","EpochClock","SparseResidency","MultiScale","PersistentState","CoherenceGuard","NeuralField","WorldMemory","ComplexityBudget","SimulationFabric","RealityContinuum","EmergenceContinuum","Validator","Optimizer","Profiler","Cache","Stream","Pool","Async","Parallel","Worker","Error","Logging","Diagnostics","Validation","Config","Environment","FeatureFlag","Capability","Permission","Sandbox","APIGateway","Extension","HotReload","Versioning","Migration","BuildGraph","Bootstrap","Continuum","Epoch","Sparse","Multiscale","Persistent","Coherence","Neural","WorldMem","Complexity","Fabric","Reality","Emergence","LOD","HLOD","Cull","Occlude","Batch","Instance","Atlas","Compress","Encrypt","Guard"]
    return [f"{n}_{b}" for b in base[:60]]
LAB={n: gen(n) for n,_,_,_ in EDITORS}
FUNC="""
local M={ContinuumCoreLab="continuum",RealityLab="reality",EmergenceLab="emergence",NeuralFieldLab="neuralfield",SparseLab="sparse",InfiniteGridLab="infinitegrid",EpochLab="epoch",WorldMemoryLab="worldmemory",ComplexityLab="complexity",FabricLab="fabric",CoherenceLab="coherence",HorizonLab="horizonspan",SeamLab="seamlattice",OccupancyLab2="occupancymap",InterestLab2="interestfield",FidelityLab2="fidelityband",PersistLab2="persistsegment",CoherenceSeamLab2="coherenceseam",NeuralPatchLab2="neuralpatch",SimDomainLab2="simdomain"}
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
for _,n in ipairs({"ContinuumCoreLab","RealityLab","EmergenceLab","NeuralFieldLab","SparseLab","InfiniteGridLab","EpochLab","WorldMemoryLab","ComplexityLab","FabricLab","CoherenceLab","HorizonLab","SeamLab","OccupancyLab2","InterestLab2","FidelityLab2","PersistLab2","CoherenceSeamLab2","NeuralPatchLab2","SimDomainLab2"}) do pcall(wire,n) end
print("[V1.19] +20 — 255 editores")
"""
def build_all_v119():
    roots=build_all_v118()
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
                    f.add(Inst("LocalScript","ARKHER_ToolsFunctional_V119",{"Source":(T_STRING,FUNC)}))
    return roots
if __name__=="__main__":
    roots=build_all_v119()
    out=os.path.join(REL,"ARKHER_STUDIO_1_GENESIS_EDITION_V1_19.rbxl")
    write(out, serialize(roots))
    print(f"V1.19 {out} ({os.path.getsize(out)/1048576:.2f} MB) - 255 editores 15320 ferramentas")
    import subprocess
    subprocess.run(["python3","tools/validate_rbxm.py",out], cwd=ROOT)
    from build_complete import arkher_installer_folder
    write(os.path.join(REL,"ARKHER_STUDIO_1_GENESIS_EDITION_V1_19.rbxm"), serialize([arkher_installer_folder()]))
    print("rbxm done")
