#!/usr/bin/env python3
"""GENESIS V1.20 — +20 editores x60 = 16520 ferramentas, 275 editores"""
import os
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REL = os.path.join(ROOT, "Releases")
os.makedirs(REL, exist_ok=True)
from build_rbxm import Inst, serialize, write, T_STRING
from build_genesis_v1_2 import build_editor_window
from build_genesis_v1_19 import build_all_v119
EDITORS = [
 ("ArchitectLab2","ARCHITECT 2",0x3E2723,60),
 ("BiomeLab3","BIOME 3",0x33691E,60),
 ("CitySimLab3","CITY SIM 3",0x212121,60),
 ("VegSimLab3","VEG SIM 3",0x2E7D32,60),
 ("RoadSimLab3","ROAD SIM 3",0x424242,60),
 ("BridgeSimLab3","BRIDGE SIM 3",0x5D4037,60),
 ("WaterSimLab3","WATER SIM 3",0x0277BD,60),
 ("ClimateSimLab3","CLIMATE SIM 3",0x00695C,60),
 ("WeatherSimLab4","WEATHER SIM 4",0x0288D1,60),
 ("EcologySimLab3","ECOLOGY SIM 3",0x33691E,60),
 ("EconomySimLab3","ECONOMY SIM 3",0xF57F17,60),
 ("SocietySimLab3","SOCIETY SIM 3",0x4A148C,60),
 ("NarrativeSimLab3","NARRATIVE SIM 3",0xBF360C,60),
 ("QuestSimLab3","QUEST SIM 3",0x01579B,60),
 ("DialogueSimLab3","DIALOGUE SIM 3",0x6A1B9A,60),
 ("MemorySimLab3","MEMORY SIM 3",0x4527A0,60),
 ("PerceptionSimLab3","PERCEPTION SIM 3",0x283593,60),
 ("BehaviourSimLab3","BEHAVIOUR SIM 3",0x1565C0,60),
 ("NavSimLab3","NAV SIM 3",0x006064,60),
 ("PhysicsSimLab3","PHYSICS SIM 3",0xBF360C,60),
]
def gen(n):
    base=["InfiniteGrid","EpochClock","SparseResidency","MultiScale","PersistentState","CoherenceGuard","NeuralField","WorldMemory","ComplexityBudget","SimulationFabric","RealityContinuum","EmergenceContinuum","Validator","Optimizer","Profiler","Cache","Stream","Pool","Async","Parallel","Worker","Error","Logging","Diagnostics","Validation","Config","Environment","FeatureFlag","Capability","Permission","Sandbox","APIGateway","Extension","HotReload","Versioning","Migration","BuildGraph","Bootstrap","Continuum","Epoch","Sparse","Multiscale","Persistent","Coherence","Neural","WorldMem","Complexity","Fabric","Reality","Emergence","LOD","HLOD","Cull","Occlude","Batch","Instance","Atlas","Compress","Encrypt","Guard"]
    return [f"{n}_{b}" for b in base[:60]]
LAB={n: gen(n) for n,_,_,_ in EDITORS}
FUNC="""
local M={ArchitectLab2="architectdistrict",BiomeLab3="biomecont",CitySimLab3="citycont",VegSimLab3="vegfield",RoadSimLab3="roadcont",BridgeSimLab3="bridgecont",WaterSimLab3="watercont",ClimateSimLab3="climatecont",WeatherSimLab4="weathercont",EcologySimLab3="ecologycont",EconomySimLab3="economycont",SocietySimLab3="societycont",NarrativeSimLab3="narrativecont",QuestSimLab3="questcont",DialogueSimLab3="dialoguecont",MemorySimLab3="memorycont",PerceptionSimLab3="perceptioncont",BehaviourSimLab3="behaviourcont",NavSimLab3="navcont",PhysicsSimLab3="physicscont"}
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
for _,n in ipairs({"ArchitectLab2","BiomeLab3","CitySimLab3","VegSimLab3","RoadSimLab3","BridgeSimLab3","WaterSimLab3","ClimateSimLab3","WeatherSimLab4","EcologySimLab3","EconomySimLab3","SocietySimLab3","NarrativeSimLab3","QuestSimLab3","DialogueSimLab3","MemorySimLab3","PerceptionSimLab3","BehaviourSimLab3","NavSimLab3","PhysicsSimLab3"}) do pcall(wire,n) end
print("[V1.20] +20 — 275 editores")
"""
def build_all_v120():
    roots=build_all_v119()
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
                    f.add(Inst("LocalScript","ARKHER_ToolsFunctional_V120",{"Source":(T_STRING,FUNC)}))
    return roots
if __name__=="__main__":
    roots=build_all_v120()
    out=os.path.join(REL,"ARKHER_STUDIO_1_GENESIS_EDITION_V1_20.rbxl")
    write(out, serialize(roots))
    print(f"V1.20 {out} ({os.path.getsize(out)/1048576:.2f} MB) - 275 editores 16520 ferramentas")
    import subprocess
    subprocess.run(["python3","tools/validate_rbxm.py",out], cwd=ROOT)
    from build_complete import arkher_installer_folder
    write(os.path.join(REL,"ARKHER_STUDIO_1_GENESIS_EDITION_V1_20.rbxm"), serialize([arkher_installer_folder()]))
    print("rbxm done")
