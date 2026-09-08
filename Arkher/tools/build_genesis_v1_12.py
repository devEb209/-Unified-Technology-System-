#!/usr/bin/env python3
"""GENESIS V1.12 — +15 editores x60 = 6920 ferramentas, 115 editores"""
import os
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REL = os.path.join(ROOT, "Releases")
os.makedirs(REL, exist_ok=True)
from build_rbxm import Inst, serialize, write, T_STRING
from build_genesis_v1_2 import build_editor_window
from build_genesis_v1_11 import build_all_v111
EDITORS = [
 ("PostProcessLab","POST PROCESS",0x00ACC1,60),
 ("VolumetricLab","VOLUMETRIC",0x37474F,60),
 ("RayTracingLab","RAY TRACING",0x01579B,60),
 ("PathTracingLab","PATH TRACING",0x0D47A1,60),
 ("DLSSLab","DLSS/FSR/XESS",0x00BCD4,60),
 ("NaniteLab","NANITE/VIRT GEO",0x4A148C,60),
 ("LumenLab","LUMEN GI",0xFF6F00,60),
 ("VirtualTexLab","VIRTUAL TEXTURE",0x5D4037,60),
 ("ShaderLab","SHADER GRAPH",0xAD1457,60),
 ("TerrainSculptLab2","TERRAIN SCULPT 2",0x2E7D32,60),
 ("MaterialGraphLab","MATERIAL GRAPH",0x6D4C41,60),
 ("ProceduralMeshLab","PROC MESH",0x4527A0,60),
 ("SplineLab","SPLINE TOOLS",0x00695C,60),
 ("FoliageLab","FOLIAGE",0x33691E,60),
 ("LandscapeLab","LANDSCAPE",0x827717,60),
]
def gen(n):
    base=["Create","Edit","Delete","Clone","Merge","Split","Optimize","Validate","Preview","Export","Import","Sync","Batch","Randomize","Procedural","Neural","Simulate","Analyze","Profile","Debug","Cache","Stream","Compress","Encrypt","Auth","Guard","Budget","Scheduler","Pipeline","Graph","Index","Search","Filter","LOD","Cull","Occlude","Bake","Lightmap","Probe","Reflect","Shadow","Denoise","Upscale","Reconstruct","Temporal","Spatial","Bilateral","Quantize","Distill","Prune","Accelerate","Serve","Stream","Cache","Evaluate","Benchmark","Safety","Guardrail","Explain","Trace","Log","Deploy"]
    return [f"{n}_{b}" for b in base[:60]]
LAB={n: gen(n) for n,_,_,_ in EDITORS}
FUNC="""
local M={PostProcessLab="postprocess",VolumetricLab="volumetric",RayTracingLab="raytracing",PathTracingLab="pathtracing",DLSSLab="dlss",NaniteLab="nanite",LumenLab="lumen",VirtualTexLab="virtualtex",ShaderLab="shader",TerrainSculptLab2="terrain",MaterialGraphLab="material",ProceduralMeshLab="procedural",SplineLab="spline",FoliageLab="foliage",LandscapeLab="landscape"}
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
for _,n in ipairs({"PostProcessLab","VolumetricLab","RayTracingLab","PathTracingLab","DLSSLab","NaniteLab","LumenLab","VirtualTexLab","ShaderLab","TerrainSculptLab2","MaterialGraphLab","ProceduralMeshLab","SplineLab","FoliageLab","LandscapeLab"}) do pcall(wire,n) end
print("[V1.12] +15 — 115 editores")
"""
def build_all_v112():
    roots=build_all_v111()
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
                    f.add(Inst("LocalScript","ARKHER_ToolsFunctional_V112",{"Source":(T_STRING,FUNC)}))
    return roots
if __name__=="__main__":
    roots=build_all_v112()
    out=os.path.join(REL,"ARKHER_STUDIO_1_GENESIS_EDITION_V1_12.rbxl")
    write(out, serialize(roots))
    print(f"V1.12 {out} ({os.path.getsize(out)/1048576:.2f} MB) - 115 editores 6920 ferramentas")
    import subprocess
    subprocess.run(["python3","tools/validate_rbxm.py",out], cwd=ROOT)
    from build_complete import arkher_installer_folder
    write(os.path.join(REL,"ARKHER_STUDIO_1_GENESIS_EDITION_V1_12.rbxm"), serialize([arkher_installer_folder()]))
    print("rbxm done")
