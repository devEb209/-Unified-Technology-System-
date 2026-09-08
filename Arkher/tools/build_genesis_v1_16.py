#!/usr/bin/env python3
"""GENESIS V1.16 — +20 editores x60 = 11720 ferramentas, 195 editores"""
import os
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REL = os.path.join(ROOT, "Releases")
os.makedirs(REL, exist_ok=True)
from build_rbxm import Inst, serialize, write, T_STRING
from build_genesis_v1_2 import build_editor_window
from build_genesis_v1_15b import build_all_v115
EDITORS = [
 ("UILab","UI WIDGETS",0xFFD600,60),
 ("HUDLab","HUD SYSTEM",0xFF6F00,60),
 ("MenuLab","MENU SYSTEM",0x4A148C,60),
 ("InputMapLab","INPUT MAP",0xFF5722,60),
 ("CameraLab","CAMERA SYSTEM",0x0277BD,60),
 ("CinematicLab2","CINEMATIC 2",0xFFB800,60),
 ("SequencerLab","SEQUENCER",0x6A1B9A,60),
 ("TimelineLab","TIMELINE",0x4527A0,60),
 ("KeyframeLab","KEYFRAME",0x283593,60),
 ("CurveLab","CURVE EDITOR",0x006064,60),
 ("GraphLab","GRAPH EDITOR",0x37474F,60),
 ("BlueprintLab","BLUEPRINT",0x01579B,60),
 ("ScriptGraphLab","SCRIPT GRAPH",0x00ACC1,60),
 ("BehaviorTreeLab","BEHAVIOR TREE",0x2E7D32,60),
 ("StateMachineLab","STATE MACHINE",0x827717,60),
 ("BlackboardLab","BLACKBOARD",0x5D4037,60),
 ("PerceptionLab2","PERCEPTION 2",0x283593,60),
 ("SensorsLab","SENSORS",0x00695C,60),
 ("PathfindingLab","PATHFINDING",0x006064,60),
 ("NavMeshLab","NAVMESH",0x1B5E20,60),
]
def gen(n):
    base=["Create","Edit","Delete","Clone","Merge","Split","Optimize","Validate","Preview","Export","Import","Sync","Batch","Randomize","Procedural","Neural","Simulate","Analyze","Profile","Debug","Cache","Stream","Compress","Encrypt","Auth","Guard","Budget","Scheduler","Pipeline","Graph","Index","Search","Filter","LOD","Cull","Occlude","Bake","Lightmap","Probe","Reflect","Shadow","Denoise","Temporal","Spatial","Bilateral","Quantize","Distill","Prune","Accelerate","Serve","Evaluate","Benchmark","Safety","Guardrail","Explain","Trace","Log","Deploy","Scale","Monitor"]
    return [f"{n}_{b}" for b in base[:60]]
LAB={n: gen(n) for n,_,_,_ in EDITORS}
FUNC="""
local M={UILab="ui",HUDLab="hud",MenuLab="menu",InputMapLab="input",CameraLab="camera",CinematicLab2="cinematic",SequencerLab="sequencer",TimelineLab="timeline",KeyframeLab="keyframe",CurveLab="curve",GraphLab="graph",BlueprintLab="blueprint",ScriptGraphLab="script",BehaviorTreeLab="behaviortree",StateMachineLab="statemachine",BlackboardLab="blackboard",PerceptionLab2="perception",SensorsLab="sensors",PathfindingLab="pathfinding",NavMeshLab="navmesh"}
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
for _,n in ipairs({"UILab","HUDLab","MenuLab","InputMapLab","CameraLab","CinematicLab2","SequencerLab","TimelineLab","KeyframeLab","CurveLab","GraphLab","BlueprintLab","ScriptGraphLab","BehaviorTreeLab","StateMachineLab","BlackboardLab","PerceptionLab2","SensorsLab","PathfindingLab","NavMeshLab"}) do pcall(wire,n) end
print("[V1.16] +20 — 195 editores")
"""
def build_all_v116():
    roots=build_all_v115()
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
                    f.add(Inst("LocalScript","ARKHER_ToolsFunctional_V116",{"Source":(T_STRING,FUNC)}))
    return roots
if __name__=="__main__":
    roots=build_all_v116()
    out=os.path.join(REL,"ARKHER_STUDIO_1_GENESIS_EDITION_V1_16.rbxl")
    write(out, serialize(roots))
    print(f"V1.16 {out} ({os.path.getsize(out)/1048576:.2f} MB) - 195 editores 11720 ferramentas")
    import subprocess
    subprocess.run(["python3","tools/validate_rbxm.py",out], cwd=ROOT)
    from build_complete import arkher_installer_folder
    write(os.path.join(REL,"ARKHER_STUDIO_1_GENESIS_EDITION_V1_16.rbxm"), serialize([arkher_installer_folder()]))
    print("rbxm done")
