#!/usr/bin/env python3
"""GENESIS V1.33 FIX — remove Viewport falso (Roblox já tem viewport), corrige UI não aparece + botões não funcionam"""
import os, subprocess
ROOT=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REL=os.path.join(ROOT,"Releases")
os.makedirs(REL,exist_ok=True)
from build_rbxm import DEFAULTS, T_FLOAT32, T_ENUM, T_STRING, T_COLOR3, T_UDIM2, T_UDIM, T_VECTOR2, T_BOOL, T_INT, col, vec2, udim, udim2, Inst, serialize, write
DEFAULTS["TextTransparency"]=(T_FLOAT32,0.0)
DEFAULTS["TextStrokeTransparency"]=(T_FLOAT32,1.0)
DEFAULTS["HorizontalAlignment"]=(T_ENUM,0)
DEFAULTS["VerticalAlignment"]=(T_ENUM,1)
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

def patch33(roots):
    for r in roots:
        if r.cls=="StarterGui":
            for sg in r.children:
                if sg.name=="ARKHER_STUDIO":
                    sg.props["Enabled"]=(T_BOOL, True)
                    sg.props["IgnoreGuiInset"]=(T_BOOL, True)
                    sg.props["DisplayOrder"]=(T_INT, 10)
                    sg.props["ResetOnSpawn"]=(T_BOOL, False)
                    sg.props["ZIndexBehavior"]=(T_ENUM, 1)
                    for child in list(sg.children):
                        if child.name=="Root":
                            # REMOVE Viewport falso completamente — Roblox já tem viewport próprio
                            child.children=[c for c in child.children if c.name not in ("Viewport","Grid","Plate")]
                            # Garante Root 100% transparente e cobrindo tela sem bloquear
                            child.props["BackgroundTransparency"]=(T_FLOAT32,1)
                            child.props["Size"]=(T_UDIM2, udim2(1,0,1,0))
                            child.props["Position"]=(T_UDIM2, udim2(0,0,0,0))
                            child.props["ClipsDescendants"]=(T_BOOL, False)
                            for c in child.children:
                                if c.name=="TopBar":
                                    c.props["Visible"]=(T_BOOL, True)
                                    c.props["ZIndex"]=(T_INT, 10)
                                if c.name=="Properties":
                                    c.props["Visible"]=(T_BOOL, True)
                                    c.props["ZIndex"]=(T_INT, 10)
                                    # garante que Properties está ESQUERDA e visível
                                    c.props["Position"]=(T_UDIM2, udim2(0,0,0,72))
                                    c.props["Size"]=(T_UDIM2, udim2(0,280,1,-92))
                                if c.name=="Explorer":
                                    c.props["Visible"]=(T_BOOL, True)
                                    c.props["ZIndex"]=(T_INT, 10)
                                    c.props["Position"]=(T_UDIM2, udim2(1,0,0,72))
                                    c.props["AnchorPoint"]=(T_VECTOR2, vec2(1,0))
                                    c.props["Size"]=(T_UDIM2, udim2(0,280,1,-92))
                                if c.name=="StatusBar":
                                    c.props["Visible"]=(T_BOOL, True)
                                    c.props["ZIndex"]=(T_INT, 10)
                                # Editores ARKHER_* devem ficar invisíveis até abrir via category, mas não bloquear
                                if c.name.startswith("ARKHER_"):
                                    c.props["Visible"]=(T_BOOL, False)
                                    c.props["ZIndex"]=(T_INT, 20)
    # Garante GlobalFunc_31 está ativo e todos Btn com ZIndex alto e Active
    GFIX = """
local P=game:GetService("Players") local pl=P.LocalPlayer task.wait(0.6)
local gui=pl.PlayerGui:FindFirstChild("ARKHER_STUDIO") if not gui then warn("[FIX] ARKHER_STUDIO não encontrado") return end
print("[FIX] UI encontrada: Root TopBar="..tostring(gui.Root:FindFirstChild("TopBar")~=nil).." Properties="..tostring(gui.Root:FindFirstChild("Properties")~=nil).." Explorer="..tostring(gui.Root:FindFirstChild("Explorer")~=nil))
-- Força visibilidade
gui.Enabled=true
gui.Root.BackgroundTransparency=1
for _,v in ipairs({"TopBar","Properties","Explorer","StatusBar"}) do
 local f=gui.Root:FindFirstChild(v) if f then f.Visible=true f.ZIndex=10 end
end
-- Hook todos Btn — garante que funcionam mesmo com viewport removido
local function hook(btn)
 if btn:GetAttribute("Hooked33") then return end btn:SetAttribute("Hooked33",true)
 btn.ZIndex=50 btn.Active=true
 local fr=btn.Parent
 local col=fr:IsA("Frame") and fr.BackgroundColor3 or Color3.fromRGB(15,31,58)
 btn.Activated:Connect(function()
  if fr:IsA("Frame") then fr.BackgroundColor3=Color3.fromRGB(0,212,255) task.delay(0.2,function() if fr.Parent then fr.BackgroundColor3=col end end) end
  local e=_G.ARKHER if e then local f=e:findSystems(string.lower(fr.Name)) if #f>0 then pcall(function() if f[1].instance.selfTest then f[1].instance.selfTest() end end) print("[FIX FUNC] "..fr.Name.." -> "..f[1].key) end end
  local s=gui.Root:FindFirstChild("StatusBar",true) if s then local l=s:FindFirstChild("Cmd") if l then l.Text=fr.Name.." ✓ FIX" end end
 end)
 btn.MouseEnter:Connect(function() if fr:IsA("Frame") then fr.BackgroundColor3=Color3.fromRGB(26,58,138) end end)
 btn.MouseLeave:Connect(function() if fr:IsA("Frame") then fr.BackgroundColor3=col end end)
end
for _,b in ipairs(gui:GetDescendants()) do if b:IsA("TextButton") and b.Name=="Btn" then pcall(hook,b) end end
-- CategoryRow pill click abre editor
local catRow=gui.Root.TopBar:FindFirstChild("CategoryRow")
if catRow then for _,pill in ipairs(catRow:GetChildren()) do if pill:IsA("Frame") then local btn=pill:FindFirstChild("Btn") if btn then hook(btn) end end end end
print("[V1.33 FIX] Viewport falso removido — viewport real do Roblox livre | UI visível ZIndex 10/50 | todos Btn hookeados")
"""
    for r in roots:
        if r.cls=="StarterPlayer":
            for f in r.children:
                if f.name=="StarterPlayerScripts":
                    # remove globals antigos e adiciona fix
                    f.children=[c for c in f.children if not c.name.startswith("ARKHER_Global")]
                    f.add(Inst("LocalScript","ARKHER_Global_33_FIX",{"Source":(T_STRING, GFIX)}))
    return roots

if __name__=="__main__":
    roots=build_all_v121()
    roots=patch22b(roots)
    roots=patch24(roots)
    roots=patch25(roots)
    roots=patch26(roots)
    roots=patch27(roots)
    roots=patch28(roots)
    roots=patch29(roots)
    roots=patch30(roots)
    roots=patch31(roots)
    roots=patch33(roots)
    out=os.path.join(REL,"ARKHER_STUDIO_1_GENESIS_EDITION_V1_33.rbxl")
    write(out, serialize(roots))
    print(f"V1.33 FIX {out} ({os.path.getsize(out)/1048576:.2f} MB)")
    subprocess.run(["python3","tools/validate_rbxm.py",out], cwd=ROOT)
    from build_complete import arkher_installer_folder
    write(os.path.join(REL,"ARKHER_STUDIO_1_GENESIS_EDITION_V1_33.rbxm"), serialize([arkher_installer_folder()]))
    print("rbxm V1.33 done")
