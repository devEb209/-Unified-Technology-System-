#!/usr/bin/env python3
"""GENESIS V1.14 — +20 editores x60 = 9320 ferramentas, 155 editores"""
import os
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REL = os.path.join(ROOT, "Releases")
os.makedirs(REL, exist_ok=True)
from build_rbxm import Inst, serialize, write, T_STRING
from build_genesis_v1_2 import build_editor_window
from build_genesis_v1_13 import build_all_v113
EDITORS = [
 ("ValidationLab","VALIDATION",0x827717,60),
 ("ConfigLab","CONFIG",0x5D4037,60),
 ("EnvLab","ENVIRONMENT",0x00695C,60),
 ("FeatureFlagLab","FEATURE FLAG",0x4527A0,60),
 ("CapabilityLab","CAPABILITY",0x4A148C,60),
 ("PermissionLab","PERMISSION",0xB71C1C,60),
 ("SandboxLab","SANDBOX",0x37474F,60),
 ("APIGatewayLab","API GATEWAY",0x0D47A1,60),
 ("ExtensionLab","EXTENSION",0x01579B,60),
 ("HotReloadLab","HOT RELOAD",0xFF6F00,60),
 ("VersioningLab","VERSIONING",0x5D4037,60),
 ("MigrationLab","MIGRATION",0x827717,60),
 ("BuildGraphLab","BUILD GRAPH",0x212121,60),
 ("BootstrapLab","BOOTSTRAP",0x37474F,60),
 ("MathLab","MATH KERNEL",0x0277BD,60),
 ("SpatialLab","SPATIAL KERNEL",0x2E7D32,60),
 ("TimeLab","TIME KERNEL",0x006064,60),
 ("InputSysLab","INPUT SYSTEM",0xFF5722,60),
 ("OutputLab","OUTPUT SYSTEM",0x4CAF50,60),
 ("FeedbackLab","FEEDBACK",0xFF6F00,60),
]
def gen(n):
    base=["Create","Edit","Delete","Clone","Merge","Split","Optimize","Validate","Preview","Export","Import","Sync","Batch","Randomize","Procedural","Neural","Simulate","Analyze","Profile","Debug","Cache","Stream","Compress","Encrypt","Auth","Guard","Budget","Scheduler","Pipeline","Graph","Index","Search","Filter","LOD","Cull","Occlude","Bake","Lightmap","Probe","Reflect","Shadow","Denoise","Temporal","Spatial","Bilateral","Quantize","Distill","Prune","Accelerate","Serve","Evaluate","Benchmark","Safety","Guardrail","Explain","Trace","Log","Deploy","Scale","Monitor"]
    return [f"{n}_{b}" for b in base[:60]]
LAB={n: gen(n) for n,_,_,_ in EDITORS}
FUNC="""
local M={ValidationLab="validation",ConfigLab="config",EnvLab="environment",FeatureFlagLab="featureflag",CapabilityLab="capability",PermissionLab="permission",SandboxLab="sandbox",APIGatewayLab="apigateway",ExtensionLab="extension",HotReloadLab="hotreload",VersioningLab="versioning",MigrationLab="migration",BuildGraphLab="buildgraph",BootstrapLab="bootstrap",MathLab="math",SpatialLab="spatial",TimeLab="time",InputSysLab="input",OutputLab="output",FeedbackLab="feedback"}
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
for _,n in ipairs({"ValidationLab","ConfigLab","EnvLab","FeatureFlagLab","CapabilityLab","PermissionLab","SandboxLab","APIGatewayLab","ExtensionLab","HotReloadLab","VersioningLab","MigrationLab","BuildGraphLab","BootstrapLab","MathLab","SpatialLab","TimeLab","InputSysLab","OutputLab","FeedbackLab"}) do pcall(wire,n) end
print("[V1.14] +20 — 155 editores")
"""
def build_all_v114():
    roots=build_all_v113()
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
                    f.add(Inst("LocalScript","ARKHER_ToolsFunctional_V114",{"Source":(T_STRING,FUNC)}))
    return roots
if __name__=="__main__":
    roots=build_all_v114()
    out=os.path.join(REL,"ARKHER_STUDIO_1_GENESIS_EDITION_V1_14.rbxl")
    write(out, serialize(roots))
    print(f"V1.14 {out} ({os.path.getsize(out)/1048576:.2f} MB) - 155 editores 9320 ferramentas")
    import subprocess
    subprocess.run(["python3","tools/validate_rbxm.py",out], cwd=ROOT)
    from build_complete import arkher_installer_folder
    write(os.path.join(REL,"ARKHER_STUDIO_1_GENESIS_EDITION_V1_14.rbxm"), serialize([arkher_installer_folder()]))
    print("rbxm done")
