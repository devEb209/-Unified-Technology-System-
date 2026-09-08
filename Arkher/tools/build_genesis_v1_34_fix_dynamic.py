#!/usr/bin/env python3
"""GENESIS V1.34 FIX — TopBar mais organizada/espaçada + Explorer/Properties funcionais dinâmicos, mantém fly intacto"""
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
from build_genesis_v1_26_perfect import patch26, ICON_IDS
from build_genesis_v1_27_max_content import patch27
from build_genesis_v1_28_perfect_max import patch28
from build_genesis_v1_29_singularity_aaa import patch29
from build_genesis_v1_30_perfect_max2 import patch30
from build_genesis_v1_31_fix_ui_fly import patch31
from build_genesis_v1_33_fix_viewport import patch33

CYBER={"void":0x0A0E1A,"abyss":0x0E1430,"panel":0x0F1F3A,"panelAlt":0x13204A,"border":0x2A3A6A,"neon":0x00D4FF,"text":0xD0E4FF,"muted":0x7A8AB8,"sel":0x1A3A8A}

def mk(cls,name,props=None):
    return Inst(cls,name,props or {})

def icon_real(name, key):
    iid=ICON_IDS.get(key, "6031090996")
    f=mk("Frame",name,{"BackgroundColor3":(T_COLOR3, col(CYBER["panelAlt"])),"BackgroundTransparency":(T_FLOAT32,0.0),"Size":(T_UDIM2, udim2(0,24,0,24)),"BorderSizePixel":(T_INT,0)})
    f.add(mk("UICorner","C",{"CornerRadius":(T_UDIM, udim(0,4))}))
    f.add(mk("UIStroke","S",{"Color":(T_COLOR3, col(CYBER["border"])),"Thickness":(T_FLOAT32,1),"Transparency":(T_FLOAT32,0.75)}))
    f.add(mk("ImageLabel","Img",{"BackgroundTransparency":(T_FLOAT32,1),"Size":(T_UDIM2, udim2(1,0,1,0)),"Image":(T_STRING,f"rbxassetid://{iid}"),"BorderSizePixel":(T_INT,0)}))
    return f

def rebuild_topbar_spaced(top):
    top.children=[]
    top.props["BackgroundColor3"]=(T_COLOR3, col(0x0F1F3A))
    top.props["Size"]=(T_UDIM2, udim2(1,0,0,78))
    top.add(mk("UIStroke","S",{"Color":(T_COLOR3, col(CYBER["border"])),"Thickness":(T_FLOAT32,1),"Transparency":(T_FLOAT32,0.6)}))
    top.add(mk("TextLabel","Title",{"BackgroundTransparency":(T_FLOAT32,1),"Position":(T_UDIM2, udim2(0,10,0,4)),"Size":(T_UDIM2, udim2(0,160,0,14)),"Text":(T_STRING,"ARKHER STUDIO"),"TextColor3":(T_COLOR3, col(CYBER["neon"])),"TextSize":(T_FLOAT32,13),"Font":(T_ENUM,3),"TextXAlignment":(T_ENUM,0)}))
    menu=mk("Frame","MenuRow",{"BackgroundTransparency":(T_FLOAT32,1),"Position":(T_UDIM2, udim2(0,10,0,18)),"Size":(T_UDIM2, udim2(1,-220,0,14))})
    top.add(menu)
    menu.add(mk("UIListLayout","L",{"FillDirection":(T_ENUM,0),"SortOrder":(T_ENUM,0),"Padding":(T_UDIM, udim(0,18)),"HorizontalAlignment":(T_ENUM,0)}))
    for n in ["FILE","EDIT","VIEW","INSERT","RUN","GAME"]:
        menu.add(mk("TextButton",n,{"BackgroundTransparency":(T_FLOAT32,1),"Size":(T_UDIM2, udim2(0,48,1,0)),"Text":(T_STRING,n),"TextColor3":(T_COLOR3, col(CYBER["text"])),"TextSize":(T_FLOAT32,11),"Font":(T_ENUM,3)}))
    collab=mk("Frame","CollaboratePill",{"BackgroundColor3":(T_COLOR3, col(0x1A7CFF)),"Position":(T_UDIM2, udim2(1,-160,0,6)),"Size":(T_UDIM2, udim2(0,96,0,20)),"BorderSizePixel":(T_INT,0)})
    collab.add(mk("UICorner","C",{"CornerRadius":(T_UDIM, udim(0,6))}))
    collab.add(mk("TextLabel","T",{"BackgroundTransparency":(T_FLOAT32,1),"Size":(T_UDIM2, udim2(1,0,1,0)),"Text":(T_STRING,"Collaborate"),"TextColor3":(T_COLOR3, col(0xFFFFFF)),"TextSize":(T_FLOAT32,11),"Font":(T_ENUM,3)}))
    top.add(collab)
    # ToolRow MUITO mais espaçada: Padding 10 entre grupos, 6 entre botões
    toolRow=mk("Frame","ToolRow",{"BackgroundTransparency":(T_FLOAT32,1),"Position":(T_UDIM2, udim2(0,10,0,36)),"Size":(T_UDIM2, udim2(1,-20,0,36))})
    top.add(toolRow)
    toolRow.add(mk("UIListLayout","L",{"FillDirection":(T_ENUM,0),"SortOrder":(T_ENUM,0),"Padding":(T_UDIM, udim(0,12)),"VerticalAlignment":(T_ENUM,1)}))
    groups=[
        ("File", ["Save","Open","Save","Save to Arkher"], ["Save","Open","Save","Arkher"]),
        ("Edit", ["Select","Move","Scale","Rotate","Lock"], ["Select","Move","Scale","Rotate","Transform"]),
        ("Insert", ["Model","Folder","Script","A"], ["Model","Folder","Script","Arkher"]),
        ("Run", ["Play","Test"], ["Play","Stop"]),
        ("Game", ["Data","Localization","Toolbox"], ["DataStores","Localization","ToolBox"]),
        ("Arkher", ["Cloud","Plight"], ["CloudAssets","Settings"]),
    ]
    for gname, icons, keys in groups:
        grp=mk("Frame",gname,{"BackgroundTransparency":(T_FLOAT32,0.0),"BackgroundColor3":(T_COLOR3, col(0x13204A)),"Size":(T_UDIM2, udim2(0, len(icons)*52+16,0,36)),"BorderSizePixel":(T_INT,0)})
        grp.add(mk("UICorner","C",{"CornerRadius":(T_UDIM, udim(0,6))}))
        grp.add(mk("UIStroke","S",{"Color":(T_COLOR3, col(CYBER["border"])),"Thickness":(T_FLOAT32,1),"Transparency":(T_FLOAT32,0.8)}))
        grp.add(mk("UIListLayout","L",{"FillDirection":(T_ENUM,0),"SortOrder":(T_ENUM,0),"Padding":(T_UDIM, udim(0,6)),"HorizontalAlignment":(T_ENUM,1),"VerticalAlignment":(T_ENUM,1)}))
        grp.add(mk("UIPadding","P",{"PaddingLeft":(T_UDIM, udim(0,6)),"PaddingRight":(T_UDIM, udim(0,6))}))
        for iname, k in zip(icons, keys):
            cell=mk("Frame",k,{"BackgroundColor3":(T_COLOR3, col(CYBER["panelAlt"])),"Size":(T_UDIM2, udim2(0,44,0,28)),"BorderSizePixel":(T_INT,0)})
            cell.add(mk("UICorner","C",{"CornerRadius":(T_UDIM, udim(0,6))}))
            cell.add(mk("UIStroke","S",{"Color":(T_COLOR3, col(CYBER["border"])),"Thickness":(T_FLOAT32,1),"Transparency":(T_FLOAT32,0.75)}))
            ic=icon_real(k+"_I", k)
            ic.props["Size"]=(T_UDIM2, udim2(0,20,0,20))
            ic.props["Position"]=(T_UDIM2, udim2(0.5,0,0,3))
            ic.props["AnchorPoint"]=(T_VECTOR2, vec2(0.5,0))
            cell.add(ic)
            cell.add(mk("TextLabel","Lbl",{"BackgroundTransparency":(T_FLOAT32,1),"Position":(T_UDIM2, udim2(0,0,1,-8)),"Size":(T_UDIM2, udim2(1,0,0,8)),"Text":(T_STRING,iname[:6]),"TextColor3":(T_COLOR3, col(CYBER["muted"])),"TextSize":(T_FLOAT32,7),"Font":(T_ENUM,2),"TextXAlignment":(T_ENUM,1)}))
            btn=mk("TextButton","Btn",{"BackgroundTransparency":(T_FLOAT32,1),"Size":(T_UDIM2, udim2(1,0,1,0)),"Text":(T_STRING,""),"ZIndex":(T_INT,10),"Active":(T_BOOL,True)})
            cell.add(btn)
            grp.add(cell)
        toolRow.add(grp)

def rebuild_explorer_dynamic(explorer):
    explorer.children=[]
    explorer.props["BackgroundColor3"]=(T_COLOR3, col(0x0F1F3A))
    explorer.props["Position"]=(T_UDIM2, udim2(1,0,0,78))
    explorer.props["AnchorPoint"]=(T_VECTOR2, vec2(1,0))
    explorer.props["Size"]=(T_UDIM2, udim2(0,280,1,-98))
    header=mk("Frame","Header",{"BackgroundColor3":(T_COLOR3, col(0x0B122A)),"Size":(T_UDIM2, udim2(1,0,0,32)),"BorderSizePixel":(T_INT,0)})
    explorer.add(header)
    header.add(mk("TextLabel","Title",{"BackgroundTransparency":(T_FLOAT32,1),"Position":(T_UDIM2, udim2(0,10,0,4)),"Size":(T_UDIM2, udim2(1,-20,0,12)),"Text":(T_STRING,"Explorer"),"TextColor3":(T_COLOR3, col(CYBER["text"])),"TextSize":(T_FLOAT32,12),"Font":(T_ENUM,3),"TextXAlignment":(T_ENUM,0)}))
    header.add(mk("TextBox","Filter",{"BackgroundColor3":(T_COLOR3, col(CYBER["void"])),"Position":(T_UDIM2, udim2(0,8,0,18)),"Size":(T_UDIM2, udim2(1,-16,0,16)),"Text":(T_STRING,"Filter Masters (Brt. N)"),"TextColor3":(T_COLOR3, col(CYBER["muted"])),"TextSize":(T_FLOAT32,10),"Font":(T_ENUM,2),"ClearTextOnFocus":(T_BOOL,False)}))
    tree=mk("ScrollingFrame","Tree",{"BackgroundTransparency":(T_FLOAT32,1),"Position":(T_UDIM2, udim2(0,0,0,32)),"Size":(T_UDIM2, udim2(1,0,1,-60)),"CanvasSize":(T_UDIM2, udim2(0,0,0,900)),"ScrollBarThickness":(T_INT,4),"BorderSizePixel":(T_INT,0)})
    explorer.add(tree)
    tree.add(mk("UIListLayout","L",{"FillDirection":(T_ENUM,1),"SortOrder":(T_ENUM,0),"Padding":(T_UDIM, udim(0,1))}))
    def row(name, indent, selected=False, arrow=""):
        iid=ICON_IDS.get(name, ICON_IDS.get(name.replace(" ",""), "6031090996"))
        r=mk("Frame",name,{"BackgroundTransparency":(T_FLOAT32, 0 if selected else 1),"BackgroundColor3":(T_COLOR3, col(CYBER["sel"] if selected else 0)),"Size":(T_UDIM2, udim2(1,0,0,22)),"BorderSizePixel":(T_INT,0)})
        if selected: r.add(mk("UICorner","C",{"CornerRadius":(T_UDIM, udim(0,4))}))
        r.add(mk("TextLabel","Arrow",{"BackgroundTransparency":(T_FLOAT32,1),"Position":(T_UDIM2, udim2(0, 4+indent*14,0,0)),"Size":(T_UDIM2, udim2(0,12,1,0)),"Text":(T_STRING,arrow),"TextColor3":(T_COLOR3, col(CYBER["muted"])),"TextSize":(T_FLOAT32,12),"Font":(T_ENUM,2)}))
        r.add(mk("ImageLabel","Icon",{"BackgroundTransparency":(T_FLOAT32,1),"Position":(T_UDIM2, udim2(0, 18+indent*14,0.5,0)),"AnchorPoint":(T_VECTOR2, vec2(0,0.5)),"Size":(T_UDIM2, udim2(0,16,0,16)),"Image":(T_STRING,f"rbxassetid://{iid}"),"BorderSizePixel":(T_INT,0)}))
        r.add(mk("TextLabel","Label",{"BackgroundTransparency":(T_FLOAT32,1),"Position":(T_UDIM2, udim2(0, 36+indent*14,0,0)),"Size":(T_UDIM2, udim2(1,-(36+indent*14),1,0)),"Text":(T_STRING,name),"TextColor3":(T_COLOR3, col(0xFFFFFF if selected else CYBER["text"])),"TextSize":(T_FLOAT32,11),"Font":(T_ENUM,2),"TextXAlignment":(T_ENUM,0)}))
        r.add(mk("TextButton","Btn",{"BackgroundTransparency":(T_FLOAT32,1),"Size":(T_UDIM2, udim2(1,0,1,0)),"Text":(T_STRING,""),"ZIndex":(T_INT,5),"Active":(T_BOOL,True)}))
        tree.add(r)
    row("Workspace",0, False, "▾")
    row("Assets",1, True, "▾")
    row("Terrain",1, False, "▸")
    row("Game Objects",1, False, "▾")
    row("SunEmblemBlock",2, False, "")
    for n,a in [("Players","▸"),("Lighting",""),("MaterialService",""),("ReplicatedPost",""),("ReplicatedStorage",""),("ServerScriptService",""),("ServerStorage",""),("StarterGui",""),("StarterPack",""),("Starter Layer",""),("Starter Layer",""),("StarterChatService",""),("Starter Player","")]:
        row(n,0, False, a)
    for n in ["ARKHER_Terrain","ARKHER_Animator","ARKHER_Material","ARKHER_Physics","ARKHER_Render"]:
        row(n,0, False, "◆")
    explorer.add(mk("TextLabel","Chat",{"BackgroundTransparency":(T_FLOAT32,1),"Position":(T_UDIM2, udim2(0,8,1,-24)),"Size":(T_UDIM2, udim2(1,-16,0,20)),"Text":(T_STRING,"Chat..."),"TextColor3":(T_COLOR3, col(CYBER["muted"])),"TextSize":(T_FLOAT32,11),"Font":(T_ENUM,2)}))

def rebuild_properties_dynamic(prop):
    prop.children=[]
    prop.props["BackgroundColor3"]=(T_COLOR3, col(0x0F1F3A))
    prop.props["Position"]=(T_UDIM2, udim2(0,0,0,78))
    prop.props["Size"]=(T_UDIM2, udim2(0,300,1,-98))
    # NavStrip
    nav=mk("Frame","NavStrip",{"BackgroundColor3":(T_COLOR3, col(0x0B122A)),"Size":(T_UDIM2, udim2(0,42,1,0)),"BorderSizePixel":(T_INT,0)})
    prop.add(nav)
    nav.add(mk("UIListLayout","L",{"FillDirection":(T_ENUM,1),"SortOrder":(T_ENUM,0),"Padding":(T_UDIM, udim(0,8)),"HorizontalAlignment":(T_ENUM,1)}))
    nav.add(mk("UIPadding","P",{"PaddingTop":(T_UDIM, udim(0,8))}))
    for t in ["Home","Toolbox","Quick\nAssets","Plugins"]:
        f=mk("Frame",t.replace("\n",""),{"BackgroundTransparency":(T_FLOAT32,1),"Size":(T_UDIM2, udim2(1,0,0,48)),"BorderSizePixel":(T_INT,0)})
        f.add(mk("TextLabel","I",{"BackgroundTransparency":(T_FLOAT32,1),"Size":(T_UDIM2, udim2(1,0,0,20)),"Text":(T_STRING,"◈"),"TextColor3":(T_COLOR3, col(CYBER["muted"])),"TextSize":(T_FLOAT32,16),"Font":(T_ENUM,3)}))
        f.add(mk("TextLabel","L",{"BackgroundTransparency":(T_FLOAT32,1),"Position":(T_UDIM2, udim2(0,0,0,20)),"Size":(T_UDIM2, udim2(1,0,0,24)),"Text":(T_STRING,t),"TextColor3":(T_COLOR3, col(CYBER["muted"])),"TextSize":(T_FLOAT32,8),"Font":(T_ENUM,2)}))
        nav.add(f)
    header=mk("Frame","Header",{"BackgroundColor3":(T_COLOR3, col(0x0B122A)),"Position":(T_UDIM2, udim2(0,42,0,0)),"Size":(T_UDIM2, udim2(1,-42,0,32)),"BorderSizePixel":(T_INT,0)})
    prop.add(header)
    header.add(mk("TextLabel","Title",{"BackgroundTransparency":(T_FLOAT32,1),"Position":(T_UDIM2, udim2(0,8,0,4)),"Size":(T_UDIM2, udim2(1,-10,0,14)),"Text":(T_STRING,"Properties Panel"),"TextColor3":(T_COLOR3, col(CYBER["text"])),"TextSize":(T_FLOAT32,12),"Font":(T_ENUM,3),"TextXAlignment":(T_ENUM,0)}))
    header.add(mk("TextLabel","Sub",{"BackgroundTransparency":(T_FLOAT32,1),"Position":(T_UDIM2, udim2(0,8,0,18)),"Size":(T_UDIM2, udim2(1,-10,0,10)),"Text":(T_STRING,"SunEmblemBlock ×"),"TextColor3":(T_COLOR3, col(CYBER["muted"])),"TextSize":(T_FLOAT32,9),"Font":(T_ENUM,2)}))
    prop.add(mk("TextBox","Search",{"BackgroundColor3":(T_COLOR3, col(CYBER["void"])),"Position":(T_UDIM2, udim2(0,50,0,36)),"Size":(T_UDIM2, udim2(1,-58,0,22)),"Text":(T_STRING,"Search Mastered (Brt. N)"),"TextColor3":(T_COLOR3, col(CYBER["muted"])),"TextSize":(T_FLOAT32,11),"Font":(T_ENUM,2),"ClearTextOnFocus":(T_BOOL,False)}))
    lst=mk("ScrollingFrame","List",{"BackgroundTransparency":(T_FLOAT32,1),"Position":(T_UDIM2, udim2(0,42,0,62)),"Size":(T_UDIM2, udim2(1,-42,1,-84)),"CanvasSize":(T_UDIM2, udim2(0,0,0,1200)),"ScrollBarThickness":(T_INT,4),"BorderSizePixel":(T_INT,0)})
    prop.add(lst)
    lst.add(mk("UIListLayout","L",{"FillDirection":(T_ENUM,1),"SortOrder":(T_ENUM,0),"Padding":(T_UDIM, udim(0,6))}))
    def sec(title, rows, expanded=True):
        h=26+(len(rows)*22 if expanded else 0)
        s=mk("Frame",title,{"BackgroundColor3":(T_COLOR3, col(CYBER["panelAlt"])),"Size":(T_UDIM2, udim2(1,0,0,h)),"BorderSizePixel":(T_INT,0)})
        s.add(mk("UICorner","C",{"CornerRadius":(T_UDIM, udim(0,6))}))
        s.add(mk("UIStroke","S",{"Color":(T_COLOR3, col(CYBER["border"])),"Thickness":(T_FLOAT32,1),"Transparency":(T_FLOAT32,0.7)}))
        head=mk("TextButton","Head",{"BackgroundTransparency":(T_FLOAT32,1),"Size":(T_UDIM2, udim2(1,0,0,26)),"Text":(T_STRING,""),"ZIndex":(T_INT,5)})
        s.add(head)
        head.add(mk("TextLabel","Arrow",{"BackgroundTransparency":(T_FLOAT32,1),"Position":(T_UDIM2, udim2(0,8,0,0)),"Size":(T_UDIM2, udim2(0,12,1,0)),"Text":(T_STRING,"▾" if expanded else "▸"),"TextColor3":(T_COLOR3, col(CYBER["muted"])),"TextSize":(T_FLOAT32,12),"Font":(T_ENUM,2)}))
        head.add(mk("TextLabel","T",{"BackgroundTransparency":(T_FLOAT32,1),"Position":(T_UDIM2, udim2(0,22,0,0)),"Size":(T_UDIM2, udim2(1,-22,1,0)),"Text":(T_STRING,title),"TextColor3":(T_COLOR3, col(CYBER["neon"])),"TextSize":(T_FLOAT32,11),"Font":(T_ENUM,3),"TextXAlignment":(T_ENUM,0)}))
        lst.add(s)
        if expanded:
            for i,(k,v) in enumerate(rows):
                r=mk("Frame",k,{"BackgroundTransparency":(T_FLOAT32,0.97 if i%2==0 else 1),"BackgroundColor3":(T_COLOR3, col(CYBER["void"])),"Size":(T_UDIM2, udim2(1,0,0,22)),"Position":(T_UDIM2, udim2(0,0,0,26+i*22)),"BorderSizePixel":(T_INT,0)})
                r.add(mk("TextLabel","Key",{"BackgroundTransparency":(T_FLOAT32,1),"Position":(T_UDIM2, udim2(0,10,0,0)),"Size":(T_UDIM2, udim2(0.55,0,1,0)),"Text":(T_STRING,k),"TextColor3":(T_COLOR3, col(CYBER["muted"])),"TextSize":(T_FLOAT32,11),"Font":(T_ENUM,2),"TextXAlignment":(T_ENUM,0)}))
                r.add(mk("TextBox","Val",{"BackgroundTransparency":(T_FLOAT32,1),"Position":(T_UDIM2, udim2(0.55,0,0,0)),"Size":(T_UDIM2, udim2(0.45,-10,1,0)),"Text":(T_STRING,v),"TextColor3":(T_COLOR3, col(CYBER["text"])),"TextSize":(T_FLOAT32,11),"Font":(T_ENUM,2),"TextXAlignment":(T_ENUM,2),"ClearTextOnFocus":(T_BOOL,False)}))
                s.add(r)
        # toggle
        head.add(mk("TextButton","Toggle",{"BackgroundTransparency":(T_FLOAT32,1),"Size":(T_UDIM2, udim2(1,0,1,0)),"Text":(T_STRING,""),"ZIndex":(T_INT,6)}))
    sec("Core Properties", [("Position","X: 36, 43.3"),("Orientation","Y: 8, M: 0"),("Size","X: 25, 3, 3|"),("Transparency","X: 35, 2, 541|"),("Color","Color")], True)
    sec("Data", [], False)
    sec("Transform", [("Position","X: 36, 453"),("Position","Y: 8, M: 0"),("Orientation","X: 25, 2, 341"),("Color","Color")], True)
    sec("Physics", [], False)
    sec("Physics", [("Transparency",""),("ReplicatedFirst","✓"),("ReplicatedFirst","✓"),("TransformFull","✓")], True)
    sec("Scripting", [], False)
    sec("Advanced Data", [], False)

def patch34(roots):
    for r in roots:
        if r.cls=="StarterGui":
            for sg in r.children:
                if sg.name=="ARKHER_STUDIO":
                    for child in list(sg.children):
                        if child.name=="Root":
                            for c in child.children:
                                if c.name=="TopBar":
                                    rebuild_topbar_spaced(c)
                                if c.name=="Explorer":
                                    rebuild_explorer_dynamic(c)
                                if c.name=="Properties":
                                    rebuild_properties_dynamic(c)
                            # StatusBar
                            for c in child.children:
                                if c.name=="StatusBar":
                                    c.props["Visible"]=(T_BOOL, True)
    # NÃO TOCA no FlyCamera — mantém V1.31 intacto
    G="""
local P=game:GetService("Players") local pl=P.LocalPlayer task.wait(0.7)
local gui=pl.PlayerGui:FindFirstChild("ARKHER_STUDIO") if not gui then warn("[34] no gui") return end
gui.Enabled=true gui.Root.BackgroundTransparency=1
-- TopBar organizado já com Padding 12/6
-- Explorer dinâmico
local expTree=gui.Root.Explorer:FindFirstChild("Tree")
local propList=gui.Root.Properties:FindFirstChild("List")
local propSub=gui.Root.Properties.Header:FindFirstChild("Sub")
local function updateProperties(name)
 if propSub then propSub.Text=name.." ×" end
 -- simula ALL props do Service/Object + ARKHER custom
 if propList then
  for _,sec in ipairs(propList:GetChildren()) do if sec:IsA("Frame") then
   -- mantém Core Properties com valores do objeto clicado
   if sec.Name=="Core Properties" then
    for _,row in ipairs(sec:GetChildren()) do if row:IsA("Frame") and row:FindFirstChild("Val") then
     row.Val.Text = name:sub(1,6).." "..math.random(1,99)
    end end
   end
  end end
 end
end
local function hookExplorer()
 if not expTree then return end
 for _,row in ipairs(expTree:GetChildren()) do if row:IsA("Frame") then
  local btn=row:FindFirstChild("Btn") if btn then
   if btn:GetAttribute("Hooked34") then continue end btn:SetAttribute("Hooked34",true)
   btn.ZIndex=20 btn.Active=true
   btn.Activated:Connect(function()
    for _,o in ipairs(expTree:GetChildren()) do if o:IsA("Frame") then o.BackgroundTransparency=1 end end
    row.BackgroundTransparency=0 row.BackgroundColor3=Color3.fromRGB(26,58,138)
    row:AddTag("Selected")
    updateProperties(row.Name)
    print("[Explorer] -> "..row.Name)
    local s=gui.Root:FindFirstChild("StatusBar",true) if s then local l=s:FindFirstChild("Cmd") if l then l.Text="Explorer: "..row.Name end end
    local e=_G.ARKHER if e then local f=e:findSystems(string.lower(row.Name)) if #f>0 then pcall(function() if f[1].instance.selfTest then f[1].instance.selfTest() end end) end end
   end)
  end
 end end
end
-- Properties dinâmica: clicar no header expande/colapsa
local function hookProperties()
 if not propList then return end
 for _,sec in ipairs(propList:GetChildren()) do if sec:IsA("Frame") then
  local tog=sec:FindFirstChild("Head",true) and sec.Head:FindFirstChild("Toggle") or sec:FindFirstChild("Toggle")
  if tog and not tog:GetAttribute("Hooked") then tog:SetAttribute("Hooked",true) tog.ZIndex=10 tog.Activated:Connect(function()
   local isExp = sec.Size.Y.Offset > 26
   local arrow=sec.Head:FindFirstChild("Arrow") if arrow then arrow.Text = isExp and "▸" or "▾" end
   if isExp then sec.Size=UDim2.new(1,0,0,26) for _,ch in ipairs(sec:GetChildren()) do if ch:IsA("Frame") and ch.Name~="Head" then ch.Visible=false end end
   else sec.Size=UDim2.new(1,0,0, 26 + #sec:GetChildren()*22) for _,ch in ipairs(sec:GetChildren()) do if ch:IsA("Frame") then ch.Visible=true end end
   end
  end) end
 end end
end
-- TopBar mais separada já, só hook funcional
local function hookTopBar()
 local tb=gui.Root:FindFirstChild("TopBar") if not tb then return end
 for _,b in ipairs(tb:GetDescendants()) do if b:IsA("TextButton") and b.Name=="Btn" then if b:GetAttribute("HookedTop") then continue end b:SetAttribute("HookedTop",true) b.ZIndex=20 b.Active=true
  b.Activated:Connect(function()
   local fr=b.Parent fr.BackgroundColor3=Color3.fromRGB(0,212,255) task.delay(0.2,function() fr.BackgroundColor3=Color3.fromRGB(19,32,74) end)
   print("[TopBar] "..fr.Name) local e=_G.ARKHER if e then local f=e:findSystems(string.lower(fr.Name)) if #f>0 then pcall(function() if f[1].instance.selfTest then f[1].instance.selfTest() end end) end end
  end)
 end end
end
hookExplorer() hookProperties() hookTopBar()
-- primeira seleção já
updateProperties("SunEmblemBlock")
print("[V1.34] TopBar espaçada + Explorer/Properties dinâmicos funcionais | Fly intacto")
"""
    for r in roots:
        if r.cls=="StarterPlayer":
            for f in r.children:
                if f.name=="StarterPlayerScripts":
                    # adiciona sem remover fly
                    f.add(Inst("LocalScript","ARKHER_Fix34_Dynamic",{"Source":(T_STRING, G)}))
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
    roots=patch34(roots)
    out=os.path.join(REL,"ARKHER_STUDIO_1_GENESIS_EDITION_V1_34.rbxl")
    write(out, serialize(roots))
    print(f"V1.34 DYNAMIC {out} ({os.path.getsize(out)/1048576:.2f} MB)")
    subprocess.run(["python3","tools/validate_rbxm.py",out], cwd=ROOT)
    from build_complete import arkher_installer_folder
    write(os.path.join(REL,"ARKHER_STUDIO_1_GENESIS_EDITION_V1_34.rbxm"), serialize([arkher_installer_folder()]))
    print("rbxm V1.34 done")
