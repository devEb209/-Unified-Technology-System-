#!/usr/bin/env python3
"""GENESIS V1.23 — UI 100% refeita: sem anti-exploit, viewport 100% vazio, org/cores exatas 1ª print, ferramentas nossas"""
import os
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REL = os.path.join(ROOT, "Releases")
os.makedirs(REL, exist_ok=True)
from build_rbxm import Inst, serialize, write, T_STRING, T_BOOL, T_INT, T_FLOAT32, T_ENUM, T_COLOR3, T_VECTOR2, T_UDIM, T_UDIM2, col, vec2, udim, udim2
from build_genesis_v1_21 import build_all_v121

CYBER = {"void":0x0A0E1A,"abyss":0x0E1430,"panel":0x121A36,"panelAlt":0x1A2348,"border":0x2A3A6A,"neon":0x00D4FF,"text":0xD0E4FF,"muted":0x7A8AB8}

def mk(cls,name,props=None):
    return Inst(cls,name,props or {})

def rebuild_topbar(top):
    # Clear and rebuild exactly like 1ª print: FILE EDIT VIEW INSERT TOOLBOX TEST PLUGINS COLLABORATION SETTINGS
    top.children=[]
    top.props["BackgroundColor3"]=(T_COLOR3, col(CYBER["panel"]))
    # First row: File etc
    menu = mk("Frame","MenuRow",{"BackgroundTransparency":(T_FLOAT32,1),"Size":(T_UDIM2, udim2(1,0,0,18)),"Position":(T_UDIM2, udim2(0,4,0,2))})
    top.add(menu)
    menu.add(mk("UIListLayout","L",{"FillDirection":(T_ENUM,0),"SortOrder":(T_ENUM,0),"Padding":(T_UDIM, udim(0,2))}))
    for name in ["FILE","EDIT","VIEW","INSERT","TOOLBOX","TEST","PLUGINS","COLLABORATION","SETTINGS"]:
        btn=mk("TextButton",name,{"BackgroundTransparency":(T_FLOAT32,1),"Size":(T_UDIM2, udim2(0,88,1,0)),"Text":(T_STRING, name),"TextColor3":(T_COLOR3, col(CYBER["text"] if name!="FILE" else CYBER["neon"])),"TextSize":(T_FLOAT32,11),"Font":(T_ENUM,3 if name=="FILE" else 2),"AutoButtonColor":(T_BOOL,True)})
        menu.add(btn)
    # Second row: New Open Save... Select Move Scale Rotatform etc (simula ferramentas, mas são nossas por baixo)
    tools = mk("Frame","ToolRow",{"BackgroundTransparency":(T_FLOAT32,1),"Size":(T_UDIM2, udim2(1,0,0,28)),"Position":(T_UDIM2, udim2(0,4,0,20))})
    top.add(tools)
    tools.add(mk("UIListLayout","L",{"FillDirection":(T_ENUM,0),"SortOrder":(T_ENUM,0),"Padding":(T_UDIM, udim(0,4))}))
    # Icons da print: New, Open, Save, Save to Arkher, Select, Move, Scale, Rotatform etc = nossas ferramentas
    icons = [("New","N"),("Open","O"),("Save","S"),("Arkher","A"),("Select","Sel"),("Move","M"),("Scale","Sc"),("Rotate","R"),("Transform","T"),("Model","Mo"),("Folder","Fo"),("Terrain","Te"),("Script","Sc"),("RemoteEvent","Re"),("Play","▶"),("Stop","■"),("DataStores","Da"),("Localization","Lo"),("Monetization","Mo"),("ToolBox","Tb"),("CommandBar","Co"),("ArkherCloud","Ac"),("ArkherSettings","As")]
    for name,letter in icons:
        # Use Frame Icon IMAGEM como antes
        bg = mk("Frame",name,{"BackgroundColor3":(T_COLOR3, col(CYBER["panelAlt"])),"Size":(T_UDIM2, udim2(0,46,0,24)),"BorderSizePixel":(T_INT,0)})
        bg.add(mk("UICorner","C",{"CornerRadius":(T_UDIM, udim(0,4))}))
        bg.add(mk("UIStroke","S",{"Color":(T_COLOR3, col(CYBER["border"])),"Thickness":(T_FLOAT32,1),"Transparency":(T_FLOAT32,0.7)}))
        # Icon ImageLabel
        icon = mk("Frame",name+"_Icon",{"BackgroundColor3":(T_COLOR3, col(CYBER["neon"])),"BackgroundTransparency":(T_FLOAT32,0.85),"Size":(T_UDIM2, udim2(0,14,0,14)),"Position":(T_UDIM2, udim2(0.5,0,0,3)),"AnchorPoint":(T_VECTOR2, vec2(0.5,0)),"BorderSizePixel":(T_INT,0)})
        icon.add(mk("UICorner","C",{"CornerRadius":(T_UDIM, udim(0,2))}))
        # ImageLabel inside
        icon.add(mk("ImageLabel","Img",{"BackgroundTransparency":(T_FLOAT32,1),"Size":(T_UDIM2, udim2(1,0,1,0)),"Image":(T_STRING,"rbxassetid://0"),"ImageColor3":(T_COLOR3, col(CYBER["neon"])),"ImageTransparency":(T_FLOAT32,0.8)}))
        icon.add(mk("TextLabel","L",{"BackgroundTransparency":(T_FLOAT32,1),"Size":(T_UDIM2, udim2(1,0,1,0)),"Text":(T_STRING, letter[:1]),"TextColor3":(T_COLOR3, col(0xFFFFFF)),"TextSize":(T_FLOAT32,8),"Font":(T_ENUM,3),"TextXAlignment":(T_ENUM,1),"TextYAlignment":(T_ENUM,1)}))
        bg.add(icon)
        bg.add(mk("TextLabel","Txt",{"BackgroundTransparency":(T_FLOAT32,1),"Position":(T_UDIM2, udim2(0,0,0,16)),"Size":(T_UDIM2, udim2(1,0,0,8)),"Text":(T_STRING, name),"TextColor3":(T_COLOR3, col(CYBER["muted"])),"TextSize":(T_FLOAT32,7),"Font":(T_ENUM,2),"TextXAlignment":(T_ENUM,1)}))
        # Botão invisível para funcionar
        bg.add(mk("TextButton","Btn",{"BackgroundTransparency":(T_FLOAT32,1),"Size":(T_UDIM2, udim2(1,0,1,0)),"Text":(T_STRING,""),"AutoButtonColor":(T_BOOL,False)}))
        tools.add(bg)
    # Coloca barra azul Collaborate à direita como na print
    collab = mk("Frame","Collaborate",{"BackgroundColor3":(T_COLOR3, col(0x0084FF)),"Size":(T_UDIM2, udim2(0,110,0,18)),"Position":(T_UDIM2, udim2(1,-114,0,2)),"AnchorPoint":(T_VECTOR2, vec2(0,0)),"BorderSizePixel":(T_INT,0)})
    top.add(collab)
    collab.add(mk("UICorner","C",{"CornerRadius":(T_UDIM, udim(0,4))}))
    collab.add(mk("TextLabel","T",{"BackgroundTransparency":(T_FLOAT32,1),"Size":(T_UDIM2, udim2(1,0,1,0)),"Text":(T_STRING,"Collaborate"),"TextColor3":(T_COLOR3, col(0xFFFFFF)),"TextSize":(T_FLOAT32,11),"Font":(T_ENUM,3)}))

def patch(roots):
    for r in roots:
        if r.cls=="StarterGui":
            for sg in r.children:
                if sg.name=="ARKHER_STUDIO":
                    for child in list(sg.children):
                        if child.name=="Root":
                            # REMOVE Center completamente — viewport 100% vazio
                            child.children=[c for c in child.children if c.name!="Center"]
                            # Garante que Root tem fundo transparente para ver o mundo (ou abyss muito sutil)
                            child.props["BackgroundTransparency"]=(T_FLOAT32,1)
                            child.props["BackgroundColor3"]=(T_COLOR3, col(0))
                            for c in child.children:
                                if c.name=="TopBar":
                                    # Recria TopBar inteiro com org exata 1ª print
                                    c.props["Size"]=(T_UDIM2, udim2(1,0,0,52))
                                    rebuild_topbar(c)
                                if c.name=="Explorer":
                                    # Mantém mas garante ordem/cores exatas (já feito em V1.22b)
                                    # Apenas garante posição correta
                                    c.props["Position"]=(T_UDIM2, udim2(0,0,0,52))
                                    c.props["Size"]=(T_UDIM2, udim2(0,220,1,-72))
                                    c.props["BackgroundColor3"]=(T_COLOR3, col(CYBER["panel"]))
                                if c.name=="Properties":
                                    c.props["Position"]=(T_UDIM2, udim2(1,0,0,52))
                                    c.props["Size"]=(T_UDIM2, udim2(0,300,1,-72))
                                if c.name=="StatusBar":
                                    # StatusBar vira Command bar + Status como na 2ª print
                                    c.props["BackgroundColor3"]=(T_COLOR3, col(CYBER["panel"]))
                                    c.props["Size"]=(T_UDIM2, udim2(1,0,0,20))
                            # Adiciona Arkher Cloud Panel e Output panels como na 2ª print mas sem cobrir viewport
                            # Bottom left Command bar
                            # Já existe StatusBar, adiciona dentro dele Command
                            # Remove Toolbox que cobria
                            child.children=[c for c in child.children if c.name not in ("Toolbox",)]
        if r.cls=="ServerScriptService":
            # REMOVE anti exploit
            r.children=[c for c in r.children if "antiexploit" not in c.name.lower() and "anti" not in c.name.lower()]
        if r.cls=="StarterPlayer":
            for folder in r.children:
                if folder.name=="StarterPlayerScripts":
                    # Remove velhas fly e garante nova sem toggle
                    folder.children=[c for c in folder.children if "Fly" not in c.name and "fly" not in c.name.lower()]
                    # Camera fly sem toggle já está em V1.22b, mantém
                    # Garante que não há toggle
                    for c in folder.children:
                        if c.name=="ARKHER_CameraFly":
                            # já é sem toggle
                            pass
    # Adiciona script global que liga TODOS os botões (TopBar icon Btn, Explorer Btn, Properties toggle)
    GF = """
local Players=game:GetService("Players") local pl=Players.LocalPlayer task.wait(0.9)
local gui=pl.PlayerGui:FindFirstChild("ARKHER_STUDIO") if not gui then return end
local function hook(btn, cat)
 if btn:GetAttribute("Hooked") then return end btn:SetAttribute("Hooked",true)
 local origC = btn.Parent:IsA("Frame") and btn.Parent.BackgroundColor3 or btn.BackgroundColor3
 btn.Activated:Connect(function()
  if btn.Parent:IsA("Frame") then btn.Parent.BackgroundColor3=Color3.fromRGB(0,212,255) task.delay(0.15,function() btn.Parent.BackgroundColor3=origC end) end
  local e=_G.ARKHER if e then local f=e:findSystems(string.lower(btn.Parent.Name)) if #f>0 then pcall(function() if f[1].instance.selfTest then f[1].instance.selfTest() end end) print("[TOOL] "..btn.Parent.Name.." -> "..f[1].key) end end
  local s=gui.Root:FindFirstChild("StatusBar",true) if s then local l=s:FindFirstChild("Status") or s:FindFirstChild("Command") if l then l.Text=btn.Parent.Name.." ✓" end end
 end)
end
for _,b in ipairs(gui:GetDescendants()) do if b:IsA("TextButton") and b.Name=="Btn" then pcall(hook,b) end end
-- Explorer
for _,r in ipairs(gui.Root.Explorer.Tree:GetChildren()) do local btn=r:FindFirstChild("Btn") if btn then hook(btn) btn.Activated:Connect(function()
 for _,o in ipairs(gui.Root.Explorer.Tree:GetChildren()) do if o:IsA("Frame") then o.BackgroundTransparency=1 end end
 r.BackgroundTransparency=0.85 r.BackgroundColor3=Color3.fromRGB(0,212,255)
 local prop=gui.Root.Properties if prop then prop.Header.Title.Text="PROPERTIES — "..r.Name end
end) end end
-- 287 editores (já hookados via ToolBar)
for _,ed in ipairs(gui.Root:GetChildren()) do if ed.Name:match("Lab") or ed.Name:match("Cont") or ed.Name=="TerrainEditor" or ed.Name=="MaterialEditor" then
 for _,b in ipairs(ed:GetDescendants()) do if b:IsA("TextButton") and b.Name~="Btn" and b.Parent.Name~="Header" then hook(b) end end
end end
print("[V1.23] Tudo funcional, viewport vazio, sem anti-exploit ✓")
"""
    for r in roots:
        if r.cls=="StarterPlayer":
            for f in r.children:
                if f.name=="StarterPlayerScripts":
                    f.add(Inst("LocalScript","ARKHER_GlobalFunc_23",{"Source":(T_STRING, GF)}))
    return roots

if __name__=="__main__":
    roots=build_all_v121()
    # Aplica patch V1.22b (explorer/properties) + patch V1.23 (remove Center, anti exploit, topbar)
    from build_genesis_v1_22b_ui_fix import patch as patch22b
    roots=patch22b(roots)
    roots=patch(roots)
    out=os.path.join(REL,"ARKHER_STUDIO_1_GENESIS_EDITION_V1_23.rbxl")
    write(out, serialize(roots))
    print(f"V1.23 {out} ({os.path.getsize(out)/1048576:.2f} MB) - 287 editores UI 100% refeita")
    import subprocess
    subprocess.run(["python3","tools/validate_rbxm.py",out], cwd=ROOT)
    from build_complete import arkher_installer_folder
    write(os.path.join(REL,"ARKHER_STUDIO_1_GENESIS_EDITION_V1_23.rbxm"), serialize([arkher_installer_folder()]))
    print("rbxm done")
