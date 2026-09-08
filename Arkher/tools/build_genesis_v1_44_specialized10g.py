#!/usr/bin/env python3
"""GENESIS V1.44 SPECIALIZED 10g — +10 únicos 7/33 (76/332) sem parar"""
import os, subprocess
ROOT=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REL=os.path.join(ROOT,"Releases")
os.makedirs(REL,exist_ok=True)
from build_rbxm import DEFAULTS, T_FLOAT32, T_ENUM, T_STRING, T_COLOR3, T_UDIM2, T_UDIM, T_VECTOR2, T_BOOL, T_INT, col, vec2, udim, udim2, Inst, serialize, write
DEFAULTS["TextTransparency"]=(T_FLOAT32,0.0)
DEFAULTS["TextStrokeTransparency"]=(T_FLOAT32,1.0)
DEFAULTS["HorizontalAlignment"]=(T_ENUM,0)
DEFAULTS["VerticalAlignment"]=(T_ENUM,1)
DEFAULTS["Active"]=(T_BOOL, True)
DEFAULTS["PaddingLeft"]=(T_UDIM, (0,0))
DEFAULTS["PaddingRight"]=(T_UDIM, (0,0))
DEFAULTS["PaddingTop"]=(T_UDIM, (0,0))
DEFAULTS["PaddingBottom"]=(T_UDIM, (0,0))
from build_genesis_v1_21 import build_all_v121
from build_genesis_v1_22b_ui_fix import patch as patch22b
from build_genesis_v1_24_perfect import patch as patch24
from build_genesis_v1_25_final import patch25
from build_genesis_v1_26_perfect import patch26
from build_genesis_v1_27_max_content import patch27
from build_genesis_v1_28_perfect_max import patch28
from build_genesis_v1_29_singularity_aaa import patch29
from build_genesis_v1_30_perfect_max2 import patch30
from build_genesis_v1_31_fix_ui_fly import patch31
from build_genesis_v1_33_fix_viewport import patch33
from build_genesis_v1_34_fix_dynamic import patch34
from build_genesis_v1_35_real_functional import patch35
from build_genesis_v1_36_specialized import patch36
from build_genesis_v1_37_specialized2 import patch37
from build_genesis_v1_38_specialized10 import patch38
from build_genesis_v1_39_specialized10b import patch39
from build_genesis_v1_40_specialized10c import patch40
from build_genesis_v1_41_specialized10d import patch41
from build_genesis_v1_42_specialized10e import patch42
from build_genesis_v1_43_specialized10f import patch43
CYBER={"void":0x0A0E1A,"abyss":0x0E1430,"panel":0x0F1F3A,"panelAlt":0x13204A,"border":0x2A3A6A,"neon":0x00D4FF,"text":0xD0E4FF,"muted":0x7A8AB8,"sel":0x1A3A8A}
def mk(cls,name,props=None):
    return Inst(cls,name,props or {})
def base_win(name,title,color,subtitle):
    win=mk("Frame",name,{"BackgroundColor3":(T_COLOR3, col(CYBER["panel"])),"Size":(T_UDIM2, udim2(0,900,0,560)),"Position":(T_UDIM2, udim2(0.5,0,0.5,0)),"AnchorPoint":(T_VECTOR2, vec2(0.5,0.5)),"Visible":(T_BOOL, False),"BorderSizePixel":(T_INT,0)})
    win.add(mk("UICorner","C",{"CornerRadius":(T_UDIM, udim(0,10))}))
    win.add(mk("UIStroke","S",{"Color":(T_COLOR3, col(color)),"Thickness":(T_FLOAT32,1.5),"Transparency":(T_FLOAT32,0.3)}))
    hdr=mk("Frame","Header",{"BackgroundColor3":(T_COLOR3, col(color & 0x3F3F3F | 0x0A0A0A)),"Size":(T_UDIM2, udim2(1,0,0,36)),"BorderSizePixel":(T_INT,0)})
    win.add(hdr)
    hdr.add(mk("TextLabel","Title",{"BackgroundTransparency":(T_FLOAT32,1),"Position":(T_UDIM2, udim2(0,12,0,2)),"Size":(T_UDIM2, udim2(0.7,0,0,18)),"Text":(T_STRING,title),"TextColor3":(T_COLOR3, col(0xFFFFFF)),"TextSize":(T_FLOAT32,12),"Font":(T_ENUM,3),"TextXAlignment":(T_ENUM,0)}))
    hdr.add(mk("TextLabel","Sub",{"BackgroundTransparency":(T_FLOAT32,1),"Position":(T_UDIM2, udim2(0,12,0,18)),"Size":(T_UDIM2, udim2(0.7,0,0,12)),"Text":(T_STRING,subtitle),"TextColor3":(T_COLOR3, col(CYBER["muted"])),"TextSize":(T_FLOAT32,9),"Font":(T_ENUM,2),"TextXAlignment":(T_ENUM,0)}))
    close=mk("TextButton","Close",{"BackgroundColor3":(T_COLOR3, col(CYBER["void"])),"Position":(T_UDIM2, udim2(1,-8,0.5,0)),"AnchorPoint":(T_VECTOR2, vec2(1,0.5)),"Size":(T_UDIM2, udim2(0,28,0,28)),"Text":(T_STRING,"✕"),"TextColor3":(T_COLOR3, col(CYBER["text"])),"TextSize":(T_FLOAT32,14),"Font":(T_ENUM,3)})
    close.add(mk("UICorner","C",{"CornerRadius":(T_UDIM, udim(0,6))}))
    hdr.add(close)
    return win
def b_shader(): win=base_win("ARKHER_Shader","SHADER — HLSL  •  Graph",0x37474F,"Code  •  Graph  •  Compile"); win.add(mk("TextLabel","T",{"BackgroundTransparency":(T_FLOAT32,1),"Position":(T_UDIM2, udim2(0.5,0,0.5,0)),"AnchorPoint":(T_VECTOR2, vec2(0.5,0.5)),"Size":(T_UDIM2, udim2(0,500,0,60)),"Text":(T_STRING,"HLSL  •  Graph  •  Compile DXIL  •  Error Lens"),"TextColor3":(T_COLOR3, col(CYBER["text"])),"TextSize":(T_FLOAT32,12),"Font":(T_ENUM,2)})); return win
def b_compute(): win=base_win("ARKHER_Compute","COMPUTE — Dispatch  •  UAV",0x00838F,"Thread  •  Group  •  Barrier"); win.add(mk("TextLabel","T",{"BackgroundTransparency":(T_FLOAT32,1),"Position":(T_UDIM2, udim2(0.5,0,0.5,0)),"AnchorPoint":(T_VECTOR2, vec2(0.5,0.5)),"Size":(T_UDIM2, udim2(0,500,0,60)),"Text":(T_STRING,"Dispatch 64×64  •  UAV  •  Barrier"),"TextColor3":(T_COLOR3, col(0x80DEEA)),"TextSize":(T_FLOAT32,12),"Font":(T_ENUM,2)})); return win
def b_ray(): win=base_win("ARKHER_Ray","RAY TRACING — BVH  •  Hit",0xBF360C,"Ray  •  Hit  •  Miss"); win.add(mk("TextLabel","T",{"BackgroundTransparency":(T_FLOAT32,1),"Position":(T_UDIM2, udim2(0.5,0,0.5,0)),"AnchorPoint":(T_VECTOR2, vec2(0.5,0.5)),"Size":(T_UDIM2, udim2(0,500,0,60)),"Text":(T_STRING,"BVH  •  RayGen  •  Hit  •  Miss  •  TLAS Build"),"TextColor3":(T_COLOR3, col(0xFFAB91)),"TextSize":(T_FLOAT32,12),"Font":(T_ENUM,2)})); return win
def b_path(): win=base_win("ARKHER_Path","PATH TRACING — Bounce  •  Denoise",0xAD1457,"Bounce  •  Sample  •  Denoise"); win.add(mk("TextLabel","T",{"BackgroundTransparency":(T_FLOAT32,1),"Position":(T_UDIM2, udim2(0.5,0,0.5,0)),"AnchorPoint":(T_VECTOR2, vec2(0.5,0.5)),"Size":(T_UDIM2, udim2(0,500,0,60)),"Text":(T_STRING,"Bounce 4  •  Sample 16  •  Denoise OIDN"),"TextColor3":(T_COLOR3, col(0xF48FB1)),"TextSize":(T_FLOAT32,12),"Font":(T_ENUM,2)})); return win
def b_denoise(): win=base_win("ARKHER_Denoiser","DENOISER — OIDN  •  NRD",0x1B5E20,"History  •  Variance  •  Filter"); win.add(mk("TextLabel","T",{"BackgroundTransparency":(T_FLOAT32,1),"Position":(T_UDIM2, udim2(0.5,0,0.5,0)),"AnchorPoint":(T_VECTOR2, vec2(0.5,0.5)),"Size":(T_UDIM2, udim2(0,500,0,60)),"Text":(T_STRING,"History  •  Variance  •  Filter  •  2ms"),"TextColor3":(T_COLOR3, col(0xA5D6A7)),"TextSize":(T_FLOAT32,12),"Font":(T_ENUM,2)})); return win
def b_lightmass(): win=base_win("ARKHER_Lightmass","LIGHTMASS — Bake  •  UV",0xFFD600,"Probe  •  Bake  •  Irradiance"); win.add(mk("TextLabel","T",{"BackgroundTransparency":(T_FLOAT32,1),"Position":(T_UDIM2, udim2(0.5,0,0.5,0)),"AnchorPoint":(T_VECTOR2, vec2(0.5,0.5)),"Size":(T_UDIM2, udim2(0,500,0,60)),"Text":(T_STRING,"Bake  •  UV Lightmap  •  Irradiance Cache"),"TextColor3":(T_COLOR3, col(0xFFF59D)),"TextSize":(T_FLOAT32,12),"Font":(T_ENUM,2)})); return win
def b_probe(): win=base_win("ARKHER_Probe","PROBE — DDGI  •  Capture",0x4A148C,"Probe  •  Update  •  Blend"); win.add(mk("TextLabel","T",{"BackgroundTransparency":(T_FLOAT32,1),"Position":(T_UDIM2, udim2(0.5,0,0.5,0)),"AnchorPoint":(T_VECTOR2, vec2(0.5,0.5)),"Size":(T_UDIM2, udim2(0,500,0,60)),"Text":(T_STRING,"DDGI Probe  •  Update  •  Blend  •  Visibility"),"TextColor3":(T_COLOR3, col(0xCE93D8)),"TextSize":(T_FLOAT32,12),"Font":(T_ENUM,2)})); return win
def b_decals(): win=base_win("ARKHER_Decals","DECALS — Project  •  Atlas",0x00695C,"Project  •  Atlas  •  Parallax"); win.add(mk("TextLabel","T",{"BackgroundTransparency":(T_FLOAT32,1),"Position":(T_UDIM2, udim2(0.5,0,0.5,0)),"AnchorPoint":(T_VECTOR2, vec2(0.5,0.5)),"Size":(T_UDIM2, udim2(0,500,0,60)),"Text":(T_STRING,"Project  •  Atlas  •  Parallax  •  Fade"),"TextColor3":(T_COLOR3, col(0x80CBC4)),"TextSize":(T_FLOAT32,12),"Font":(T_ENUM,2)})); return win
def b_terrain2(): win=base_win("ARKHER_Terrain2","TERRAIN2 — Voxel  •  Marching",0x2E7D32,"Voxel  •  March  •  LOD"); win.add(mk("TextLabel","T",{"BackgroundTransparency":(T_FLOAT32,1),"Position":(T_UDIM2, udim2(0.5,0,0.5,0)),"AnchorPoint":(T_VECTOR2, vec2(0.5,0.5)),"Size":(T_UDIM2, udim2(0,500,0,60)),"Text":(T_STRING,"Voxel  •  Marching Cubes  •  LOD  •  Collision"),"TextColor3":(T_COLOR3, col(0xA5D6A7)),"TextSize":(T_FLOAT32,12),"Font":(T_ENUM,2)})); return win
def b_grass(): win=base_win("ARKHER_Grass","GRASS — Groom  •  Strand",0x33691E,"Strand  •  Clump  •  Wind"); win.add(mk("TextLabel","T",{"BackgroundTransparency":(T_FLOAT32,1),"Position":(T_UDIM2, udim2(0.5,0,0.5,0)),"AnchorPoint":(T_VECTOR2, vec2(0.5,0.5)),"Size":(T_UDIM2, udim2(0,500,0,60)),"Text":(T_STRING,"Strand  •  Clump  •  Wind  •  LOD"),"TextColor3":(T_COLOR3, col(0xAED581)),"TextSize":(T_FLOAT32,12),"Font":(T_ENUM,2)})); return win
def patch44(roots):
    names=["ARKHER_Shader","ARKHER_Compute","ARKHER_Ray","ARKHER_Path","ARKHER_Denoiser","ARKHER_Lightmass","ARKHER_Probe","ARKHER_Decals","ARKHER_Terrain2","ARKHER_Grass"]
    builders=[b_shader,b_compute,b_ray,b_path,b_denoise,b_lightmass,b_probe,b_decals,b_terrain2,b_grass]
    for r in roots:
        if r.cls=="StarterGui":
            for sg in r.children:
                if sg.name=="ARKHER_STUDIO":
                    for child in sg.children:
                        if child.name=="Root":
                            child.children=[c for c in child.children if c.name not in names]
                            for b in builders: child.add(b())
    FUNC44="""
local P=game:GetService("Players") local pl=P.LocalPlayer task.wait(0.5)
local gui=pl.PlayerGui:FindFirstChild("ARKHER_STUDIO") if not gui then return end
for _,n in ipairs({"ARKHER_Shader","ARKHER_Compute","ARKHER_Ray","ARKHER_Path","ARKHER_Denoiser","ARKHER_Lightmass","ARKHER_Probe","ARKHER_Decals","ARKHER_Terrain2","ARKHER_Grass"}) do
 local w=gui.Root:FindFirstChild(n) if w then for _,b in ipairs(w:GetDescendants()) do if b:IsA("TextButton") then b.Activated:Connect(function() print("["..n.."] "..b.Name) end) end end
 local hd=w:FindFirstChild("Header",true) if hd then for _,c in ipairs(hd:GetChildren()) do if c:IsA("TextButton") and c.Text=="✕" then c.Activated:Connect(function() w.Visible=false end) end end end
 end
end
print("[V1.44 10x] Shader/Compute/Ray/Path/Denoiser/Lightmass/Probe/Decals/Terrain2/Grass 76/332")
"""
    for r in roots:
        if r.cls=="StarterPlayer":
            for f in r.children:
                if f.name=="StarterPlayerScripts":
                    f.add(Inst("LocalScript","ARKHER_Specialized_44",{"Source":(T_STRING, FUNC44)}))
    return roots
if __name__=="__main__":
    roots=build_all_v121()
    roots=patch22b(roots); roots=patch24(roots); roots=patch25(roots); roots=patch26(roots); roots=patch27(roots); roots=patch28(roots); roots=patch29(roots); roots=patch30(roots); roots=patch31(roots); roots=patch33(roots); roots=patch34(roots)
    from build_genesis_v1_35_real_functional import patch35
    roots=patch35(roots)
    from build_genesis_v1_36_specialized import patch36
    roots=patch36(roots)
    from build_genesis_v1_37_specialized2 import patch37
    roots=patch37(roots)
    from build_genesis_v1_38_specialized10 import patch38
    roots=patch38(roots)
    from build_genesis_v1_39_specialized10b import patch39
    roots=patch39(roots)
    from build_genesis_v1_40_specialized10c import patch40
    roots=patch40(roots)
    from build_genesis_v1_41_specialized10d import patch41
    roots=patch41(roots)
    from build_genesis_v1_42_specialized10e import patch42
    roots=patch42(roots)
    from build_genesis_v1_43_specialized10f import patch43
    roots=patch43(roots)
    roots=patch44(roots)
    out=os.path.join(REL,"ARKHER_STUDIO_1_GENESIS_EDITION_V1_44.rbxl")
    write(out, serialize(roots))
    print(f"V1.44 10x {out} ({os.path.getsize(out)/1048576:.2f} MB)")
    subprocess.run(["python3","tools/validate_rbxm.py",out], cwd=ROOT)
    from build_complete import arkher_installer_folder
    write(os.path.join(REL,"ARKHER_STUDIO_1_GENESIS_EDITION_V1_44.rbxm"), serialize([arkher_installer_folder()]))
    print("rbxm V1.44 done")
