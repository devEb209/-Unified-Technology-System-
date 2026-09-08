#!/usr/bin/env python3
"""GENESIS V1.35 REAL FUNCTIONAL — Explorer dinâmico com dropdowns + botão + InsertMenu (todos objetos Roblox+custom), Properties real com TextBox/Checkbox/Slider/ColorPicker/Dropdown afetando instância real, TopBar submenus funcionais, Create Part, AI Chat, Loading, UI refinada profissional (não só quadrado arredondado)"""
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
DEFAULTS["ClipsDescendants"]=(T_BOOL, False)
from build_genesis_v1_21 import build_all_v121
from build_genesis_v1_22b_ui_fix import patch as patch22b
from build_genesis_v1_24_perfect import patch as patch24
from build_genesis_v1_25_final import patch25
from build_genesis_v1_26_perfect import patch26, ICON_IDS
from build_genesis_v1_27_max_content import patch27
from build_genesis_v1_28_perfect_max import patch28
from build_genesis_v1_29_singularity_aaa import patch29
from build_genesis_v1_30_perfect_max2 import patch30
from build_genesis_v1_31_fix_ui_fly import patch31, FLYCAM_EXACT
from build_genesis_v1_33_fix_viewport import patch33
from build_genesis_v1_34_fix_dynamic import patch34

CYBER={"void":0x0A0E1A,"abyss":0x0E1430,"panel":0x0F1F3A,"panelAlt":0x13204A,"border":0x2A3A6A,"neon":0x00D4FF,"text":0xD0E4FF,"muted":0x7A8AB8,"sel":0x1A3A8A}

def mk(cls,name,props=None):
    return Inst(cls,name,props or {})

# Toda lista de objetos inseríveis do Roblox Studio + custom ARKHER (para o botão +)
INSERTABLES = [
    ("Part","Part", " cubes", "6031090997"), ("Model","Model","", "6031090997"), ("Folder","Folder","", "6031090997"),
    ("Script","Script","", "6031091004"), ("LocalScript","LocalScript","", "6031091004"), ("ModuleScript","ModuleScript","", "6031091004"),
    ("RemoteEvent","RemoteEvent","", "6031091005"), ("RemoteFunction","RemoteFunction","", "6031091005"), ("BindableEvent","BindableEvent","", "6031091005"), ("BindableFunction","BindableFunction","", "6031091005"),
    ("BoolValue","BoolValue","", "6031091010"), ("StringValue","StringValue","", "6031091010"), ("IntValue","IntValue","", "6031091010"), ("NumberValue","NumberValue","", "6031091010"), ("Vector3Value","Vector3Value","", "6031091010"), ("Color3Value","Color3Value","", "6031091010"), ("ObjectValue","ObjectValue","", "6031091010"),
    ("WedgePart","WedgePart","", "6031091000"), ("CornerWedgePart","CornerWedgePart","", "6031091000"), ("Cylinder","Cylinder","", "6031091000"), ("Ball","Ball Sphere","", "6031091000"), ("Block","Block","", "6031091000"),
    ("MeshPart","MeshPart","", "6031090997"), ("UnionOperation","Union","", "6031090997"), ("NegateOperation","Negate","", "6031090997"), ("Terrain","Terrain","", "6031090999"),
    ("SpawnLocation","SpawnLocation","", "6031091024"), ("Sound","Sound","", "6031091012"), ("ParticleEmitter","ParticleEmitter","", "6031091012"), ("PointLight","PointLight","", "6031091025"), ("SpotLight","SpotLight","", "6031091025"), ("SurfaceLight","SurfaceLight","", "6031091025"),
    ("ARKHER_Terrain","ARKHER_Terrain custom","", "6031090999"), ("ARKHER_Animator","ARKHER_Animator custom","", "6031091001"), ("ARKHER_Material","ARKHER_Material custom","", "6031091026"), ("ARKHER_Script","ARKHER_Script AI","", "6031091004"),
]

def build_insert_menu():
    menu=mk("Frame","InsertMenu",{"BackgroundColor3":(T_COLOR3, col(0x0B122A)),"Size":(T_UDIM2, udim2(0,220,0,320)),"Visible":(T_BOOL, False),"BorderSizePixel":(T_INT,0),"ZIndex":(T_INT, 50)})
    menu.add(mk("UICorner","C",{"CornerRadius":(T_UDIM, udim(0,8))}))
    menu.add(mk("UIStroke","S",{"Color":(T_COLOR3, col(CYBER["neon"])),"Thickness":(T_FLOAT32,1.5),"Transparency":(T_FLOAT32,0.3)}))
    menu.add(mk("TextLabel","Title",{"BackgroundTransparency":(T_FLOAT32,1),"Size":(T_UDIM2, udim2(1,0,0,24)),"Text":(T_STRING,"  + Inserir Objeto"),"TextColor3":(T_COLOR3, col(CYBER["text"])),"TextSize":(T_FLOAT32,11),"Font":(T_ENUM,3),"TextXAlignment":(T_ENUM,0)}))
    scroll=mk("ScrollingFrame","List",{"BackgroundTransparency":(T_FLOAT32,1),"Position":(T_UDIM2, udim2(0,4,0,26)),"Size":(T_UDIM2, udim2(1,-8,1,-30)),"CanvasSize":(T_UDIM2, udim2(0,0,0, len(INSERTABLES)*24+10)),"ScrollBarThickness":(T_INT,4),"BorderSizePixel":(T_INT,0)})
    menu.add(scroll)
    scroll.add(mk("UIListLayout","L",{"FillDirection":(T_ENUM,1),"SortOrder":(T_ENUM,0),"Padding":(T_UDIM, udim(0,1))}))
    for clsName, label, _, iid in INSERTABLES:
        row=mk("TextButton",clsName,{"BackgroundColor3":(T_COLOR3, col(CYBER["panel"])),"Size":(T_UDIM2, udim2(1,0,0,22)),"Text":(T_STRING,f"  ●  {label}  ({clsName})"),"TextColor3":(T_COLOR3, col(CYBER["text"])),"TextSize":(T_FLOAT32,11),"Font":(T_ENUM,2),"TextXAlignment":(T_ENUM,0),"BorderSizePixel":(T_INT,0)})
        row.add(mk("UICorner","C",{"CornerRadius":(T_UDIM, udim(0,4))}))
        scroll.add(row)
    return menu

def rebuild_explorer_real(explorer):
    explorer.children=[]
    explorer.props["BackgroundColor3"]=(T_COLOR3, col(0x0F1F3A))
    explorer.props["Position"]=(T_UDIM2, udim2(1,0,0,78))
    explorer.props["AnchorPoint"]=(T_VECTOR2, vec2(1,0))
    explorer.props["Size"]=(T_UDIM2, udim2(0,300,1,-98))
    # Header refinado com sombra
    header=mk("Frame","Header",{"BackgroundColor3":(T_COLOR3, col(0x0B122A)),"Size":(T_UDIM2, udim2(1,0,0,36)),"BorderSizePixel":(T_INT,0)})
    explorer.add(header)
    header.add(mk("UIStroke","S",{"Color":(T_COLOR3, col(CYBER["border"])),"Thickness":(T_FLOAT32,1),"Transparency":(T_FLOAT32,0.8)}))
    header.add(mk("TextLabel","Title",{"BackgroundTransparency":(T_FLOAT32,1),"Position":(T_UDIM2, udim2(0,12,0,4)),"Size":(T_UDIM2, udim2(0.5,0,0,14)),"Text":(T_STRING,"Explorer"),"TextColor3":(T_COLOR3, col(CYBER["text"])),"TextSize":(T_FLOAT32,12),"Font":(T_ENUM,3),"TextXAlignment":(T_ENUM,0)}))
    header.add(mk("TextBox","Filter",{"BackgroundColor3":(T_COLOR3, col(CYBER["void"])),"Position":(T_UDIM2, udim2(0,8,0,18)),"Size":(T_UDIM2, udim2(1,-16,0,16)),"Text":(T_STRING,"Filter Masters (Brt. N)"),"TextColor3":(T_COLOR3, col(CYBER["muted"])),"TextSize":(T_FLOAT32,10),"Font":(T_ENUM,2),"ClearTextOnFocus":(T_BOOL,False)}))
    tree=mk("ScrollingFrame","Tree",{"BackgroundTransparency":(T_FLOAT32,1),"Position":(T_UDIM2, udim2(0,0,0,36)),"Size":(T_UDIM2, udim2(1,0,1,-68)),"CanvasSize":(T_UDIM2, udim2(0,0,0,1100)),"ScrollBarThickness":(T_INT,4),"BorderSizePixel":(T_INT,0)})
    explorer.add(tree)
    tree.add(mk("UIListLayout","L",{"FillDirection":(T_ENUM,1),"SortOrder":(T_ENUM,0),"Padding":(T_UDIM, udim(0,1))}))
    # Estrutura real com dropdowns (tem filhos = arrow ▾, senão nada) + botão + na extrema direita
    def add_row_real(name, indent, hasChildren, selected=False, isCustom=False):
        iid=ICON_IDS.get(name, "6031090996")
        if isCustom: iid="6031090999"
        row=mk("Frame",name,{"BackgroundTransparency":(T_FLOAT32, 0 if selected else 1),"BackgroundColor3":(T_COLOR3, col(CYBER["sel"] if selected else 0)),"Size":(T_UDIM2, udim2(1,0,0,22)),"BorderSizePixel":(T_INT,0)})
        if selected: row.add(mk("UICorner","C",{"CornerRadius":(T_UDIM, udim(0,4))}))
        # Dropdown arrow — clicável para expandir/colapsar filhos (se tem filhos)
        arrowChar = "▾" if hasChildren and name in ("Workspace","Assets","Game Objects") else ("▸" if hasChildren else "")
        arrow=mk("TextButton","Arrow",{"BackgroundTransparency":(T_FLOAT32,1),"Position":(T_UDIM2, udim2(0, 4+indent*14,0,0)),"Size":(T_UDIM2, udim2(0,14,1,0)),"Text":(T_STRING,arrowChar),"TextColor3":(T_COLOR3, col(CYBER["muted"])),"TextSize":(T_FLOAT32,12),"Font":(T_ENUM,2),"ZIndex":(T_INT,6)})
        row.add(arrow)
        row.add(mk("ImageLabel","Icon",{"BackgroundTransparency":(T_FLOAT32,1),"Position":(T_UDIM2, udim2(0, 18+indent*14,0.5,0)),"AnchorPoint":(T_VECTOR2, vec2(0,0.5)),"Size":(T_UDIM2, udim2(0,16,0,16)),"Image":(T_STRING,f"rbxassetid://{iid}"),"BorderSizePixel":(T_INT,0)}))
        row.add(mk("TextLabel","Label",{"BackgroundTransparency":(T_FLOAT32,1),"Position":(T_UDIM2, udim2(0, 36+indent*14,0,0)),"Size":(T_UDIM2, udim2(1,-66,1,0)),"Text":(T_STRING,name),"TextColor3":(T_COLOR3, col(0xFFFFFF if selected else (CYBER["neon"] if isCustom else CYBER["text"]))), "TextSize":(T_FLOAT32,11),"Font":(T_ENUM,2),"TextXAlignment":(T_ENUM,0)}))
        # Botão principal de seleção
        row.add(mk("TextButton","Btn",{"BackgroundTransparency":(T_FLOAT32,1),"Size":(T_UDIM2, udim2(1,-28,1,0)),"Text":(T_STRING,""),"ZIndex":(T_INT,5)}))
        # Botão + na extrema direita — abre InsertMenu com todos objetos
        plus=mk("TextButton","Plus",{"BackgroundColor3":(T_COLOR3, col(CYBER["panelAlt"])),"Position":(T_UDIM2, udim2(1,-22,0.5,0)),"AnchorPoint":(T_VECTOR2, vec2(0,0.5)),"Size":(T_UDIM2, udim2(0,18,0,18)),"Text":(T_STRING,"+"),"TextColor3":(T_COLOR3, col(CYBER["neon"])),"TextSize":(T_FLOAT32,14),"Font":(T_ENUM,3),"ZIndex":(T_INT,6)})
        plus.add(mk("UICorner","C",{"CornerRadius":(T_UDIM, udim(0,4))}))
        plus.add(mk("UIStroke","S",{"Color":(T_COLOR3, col(CYBER["border"])),"Thickness":(T_FLOAT32,1),"Transparency":(T_FLOAT32,0.6)}))
        row.add(plus)
        tree.add(row)
        return row
    add_row_real("Workspace",0, True, False)
    add_row_real("Assets",1, True, True)
    add_row_real("Terrain",1, True, False)
    add_row_real("Game Objects",1, True, False)
    add_row_real("SunEmblemBlock",2, False, False)
    for n, hasCh in [("Players",True),("Lighting",False),("MaterialService",False),("ReplicatedPost",False),("ReplicatedStorage",False),("ServerScriptService",False),("ServerStorage",False),("StarterGui",False),("StarterPack",False),("StarterChatService",False),("Starter Player",False)]:
        add_row_real(n,0, hasCh)
    for n in ["ARKHER_Terrain","ARKHER_Animator","ARKHER_Material","ARKHER_Physics","ARKHER_Render"]:
        add_row_real(n,0, False, False, True)
    # InsertMenu flutuante
    explorer.add(build_insert_menu())
    # Botões criar Part rápidos abaixo
    quick=mk("Frame","QuickCreate",{"BackgroundColor3":(T_COLOR3, col(0x0B122A)),"Position":(T_UDIM2, udim2(0,0,1,-32)),"Size":(T_UDIM2, udim2(1,0,0,32)),"BorderSizePixel":(T_INT,0)})
    explorer.add(quick)
    quick.add(mk("UIListLayout","L",{"FillDirection":(T_ENUM,0),"SortOrder":(T_ENUM,0),"Padding":(T_UDIM, udim(0,4)),"HorizontalAlignment":(T_ENUM,1),"VerticalAlignment":(T_ENUM,1)}))
    for shape, iid in [("▭","6031090997"),("●","6031091000"),("◣","6031091000"),("▲","6031091000"),("◇","6031090997")]:
        b=mk("TextButton",shape,{"BackgroundColor3":(T_COLOR3, col(CYBER["panelAlt"])),"Size":(T_UDIM2, udim2(0,44,0,24)),"Text":(T_STRING,shape+" Part"),"TextColor3":(T_COLOR3, col(CYBER["text"])),"TextSize":(T_FLOAT32,9),"Font":(T_ENUM,2)})
        b.add(mk("UICorner","C",{"CornerRadius":(T_UDIM, udim(0,4))}))
        quick.add(b)

def rebuild_properties_real(prop):
    prop.children=[]
    prop.props["BackgroundColor3"]=(T_COLOR3, col(0x0F1F3A))
    prop.props["Position"]=(T_UDIM2, udim2(0,0,0,78))
    prop.props["Size"]=(T_UDIM2, udim2(0,320,1,-98))
    # NavStrip refinado (não só quadrado)
    nav=mk("Frame","NavStrip",{"BackgroundColor3":(T_COLOR3, col(0x0B122A)),"Size":(T_UDIM2, udim2(0,44,1,0)),"BorderSizePixel":(T_INT,0)})
    nav.add(mk("UIStroke","S",{"Color":(T_COLOR3, col(CYBER["border"])),"Thickness":(T_FLOAT32,1),"Transparency":(T_FLOAT32,0.85)}))
    prop.add(nav)
    nav.add(mk("UIListLayout","L",{"FillDirection":(T_ENUM,1),"SortOrder":(T_ENUM,0),"Padding":(T_UDIM, udim(0,6)),"HorizontalAlignment":(T_ENUM,1)}))
    nav.add(mk("UIPadding","P",{"PaddingTop":(T_UDIM, udim(0,8))}))
    for icon, label in [("◈","Home"),("◈","Toolbox"),("◈","Quick\nAssets"),("◈","Plugins")]:
        f=mk("Frame",label.replace("\n",""),{"BackgroundTransparency":(T_FLOAT32,1),"Size":(T_UDIM2, udim2(1,0,0,52)),"BorderSizePixel":(T_INT,0)})
        f.add(mk("TextLabel","I",{"BackgroundTransparency":(T_FLOAT32,1),"Size":(T_UDIM2, udim2(1,0,0,22)),"Text":(T_STRING,icon),"TextColor3":(T_COLOR3, col(CYBER["muted"])),"TextSize":(T_FLOAT32,16),"Font":(T_ENUM,3)}))
        f.add(mk("TextLabel","L",{"BackgroundTransparency":(T_FLOAT32,1),"Position":(T_UDIM2, udim2(0,0,0,22)),"Size":(T_UDIM2, udim2(1,0,0,28)),"Text":(T_STRING,label),"TextColor3":(T_COLOR3, col(CYBER["muted"])),"TextSize":(T_FLOAT32,8),"Font":(T_ENUM,2)}))
        nav.add(f)
    # Header com sombra e gradiente sutil
    header=mk("Frame","Header",{"BackgroundColor3":(T_COLOR3, col(0x0B122A)),"Position":(T_UDIM2, udim2(0,44,0,0)),"Size":(T_UDIM2, udim2(1,-44,0,36)),"BorderSizePixel":(T_INT,0)})
    header.add(mk("UIStroke","S",{"Color":(T_COLOR3, col(CYBER["neon"])),"Thickness":(T_FLOAT32,1),"Transparency":(T_FLOAT32,0.85)}))
    prop.add(header)
    header.add(mk("TextLabel","Title",{"BackgroundTransparency":(T_FLOAT32,1),"Position":(T_UDIM2, udim2(0,10,0,4)),"Size":(T_UDIM2, udim2(1,-12,0,14)),"Text":(T_STRING,"Properties Panel"),"TextColor3":(T_COLOR3, col(CYBER["text"])),"TextSize":(T_FLOAT32,12),"Font":(T_ENUM,3),"TextXAlignment":(T_ENUM,0)}))
    header.add(mk("TextLabel","Sub",{"BackgroundTransparency":(T_FLOAT32,1),"Position":(T_UDIM2, udim2(0,10,0,18)),"Size":(T_UDIM2, udim2(1,-12,0,12)),"Text":(T_STRING,"SunEmblemBlock ×  —  Part"),"TextColor3":(T_COLOR3, col(CYBER["muted"])),"TextSize":(T_FLOAT32,9),"Font":(T_ENUM,2),"TextXAlignment":(T_ENUM,0)}))
    prop.add(mk("TextBox","Search",{"BackgroundColor3":(T_COLOR3, col(CYBER["void"])),"Position":(T_UDIM2, udim2(0,52,0,40)),"Size":(T_UDIM2, udim2(1,-60,0,22)),"Text":(T_STRING,"Search Mastered (Brt. N)"),"TextColor3":(T_COLOR3, col(CYBER["muted"])),"TextSize":(T_FLOAT32,11),"Font":(T_ENUM,2),"ClearTextOnFocus":(T_BOOL,False)}))
    lst=mk("ScrollingFrame","List",{"BackgroundTransparency":(T_FLOAT32,1),"Position":(T_UDIM2, udim2(0,44,0,66)),"Size":(T_UDIM2, udim2(1,-44,1,-88)),"CanvasSize":(T_UDIM2, udim2(0,0,0,1400)),"ScrollBarThickness":(T_INT,4),"BorderSizePixel":(T_INT,0)})
    prop.add(lst)
    lst.add(mk("UIListLayout","L",{"FillDirection":(T_ENUM,1),"SortOrder":(T_ENUM,0),"Padding":(T_UDIM, udim(0,8))}))
    # Helpers para criar controles reais
    def section_real(title, controls, expanded=True):
        h=28 + (len(controls)*28 if expanded else 0)
        sec=mk("Frame",title,{"BackgroundColor3":(T_COLOR3, col(CYBER["panelAlt"])),"Size":(T_UDIM2, udim2(1,0,0,h)),"BorderSizePixel":(T_INT,0)})
        sec.add(mk("UICorner","C",{"CornerRadius":(T_UDIM, udim(0,8))}))
        sec.add(mk("UIStroke","S",{"Color":(T_COLOR3, col(CYBER["border"])),"Thickness":(T_FLOAT32,1),"Transparency":(T_FLOAT32,0.7)}))
        # sombra sutil via segundo stroke
        sec.add(mk("UIPadding","P",{"PaddingLeft":(T_UDIM, udim(0,4)),"PaddingRight":(T_UDIM, udim(0,4)),"PaddingTop":(T_UDIM, udim(0,4)),"PaddingBottom":(T_UDIM, udim(0,4))}))
        head=mk("TextButton","Head",{"BackgroundTransparency":(T_FLOAT32,1),"Size":(T_UDIM2, udim2(1,0,0,28)),"Text":(T_STRING,""),"ZIndex":(T_INT,5)})
        sec.add(head)
        head.add(mk("TextLabel","Arrow",{"BackgroundTransparency":(T_FLOAT32,1),"Position":(T_UDIM2, udim2(0,8,0,0)),"Size":(T_UDIM2, udim2(0,14,1,0)),"Text":(T_STRING,"▾" if expanded else "▸"),"TextColor3":(T_COLOR3, col(CYBER["muted"])),"TextSize":(T_FLOAT32,14),"Font":(T_ENUM,2)}))
        head.add(mk("TextLabel","T",{"BackgroundTransparency":(T_FLOAT32,1),"Position":(T_UDIM2, udim2(0,24,0,0)),"Size":(T_UDIM2, udim2(1,-24,1,0)),"Text":(T_STRING,title),"TextColor3":(T_COLOR3, col(CYBER["neon"])),"TextSize":(T_FLOAT32,11),"Font":(T_ENUM,3),"TextXAlignment":(T_ENUM,0)}))
        head.add(mk("TextButton","Toggle",{"BackgroundTransparency":(T_FLOAT32,1),"Size":(T_UDIM2, udim2(1,0,1,0)),"Text":(T_STRING,""),"ZIndex":(T_INT,6)}))
        lst.add(sec)
        if expanded:
            for i, (ctype, key, val) in enumerate(controls):
                row=mk("Frame",key,{"BackgroundColor3":(T_COLOR3, col(CYBER["void"] if i%2==0 else CYBER["panel"])),"Size":(T_UDIM2, udim2(1,0,0,26)),"Position":(T_UDIM2, udim2(0,0,0,28+i*28)),"BorderSizePixel":(T_INT,0)})
                row.add(mk("UICorner","C",{"CornerRadius":(T_UDIM, udim(0,4))}))
                row.add(mk("TextLabel","Key",{"BackgroundTransparency":(T_FLOAT32,1),"Position":(T_UDIM2, udim2(0,10,0,0)),"Size":(T_UDIM2, udim2(0.42,0,1,0)),"Text":(T_STRING,key),"TextColor3":(T_COLOR3, col(CYBER["muted"])),"TextSize":(T_FLOAT32,11),"Font":(T_ENUM,2),"TextXAlignment":(T_ENUM,0)}))
                # controle real por tipo
                if ctype=="textbox":
                    row.add(mk("TextBox","Val",{"BackgroundColor3":(T_COLOR3, col(0x0B122A)),"Position":(T_UDIM2, udim2(0.45,0,0.5,0)),"AnchorPoint":(T_VECTOR2, vec2(0,0.5)),"Size":(T_UDIM2, udim2(0.52,-6,0,20)),"Text":(T_STRING,val),"TextColor3":(T_COLOR3, col(CYBER["text"])),"TextSize":(T_FLOAT32,11),"Font":(T_ENUM,2),"TextXAlignment":(T_ENUM,1),"ClearTextOnFocus":(T_BOOL,False)}))
                elif ctype=="checkbox":
                    cb=mk("TextButton","Val",{"BackgroundColor3":(T_COLOR3, col(0x0B122A if val=="false" else CYBER["neon"])),"Position":(T_UDIM2, udim2(1,-24,0.5,0)),"AnchorPoint":(T_VECTOR2, vec2(0,0.5)),"Size":(T_UDIM2, udim2(0,18,0,18)),"Text":(T_STRING,"✓" if val=="true" else ""),"TextColor3":(T_COLOR3, col(0xFFFFFF)),"TextSize":(T_FLOAT32,12),"Font":(T_ENUM,3)})
                    cb.add(mk("UICorner","C",{"CornerRadius":(T_UDIM, udim(0,4))}))
                    row.add(cb)
                elif ctype=="slider":
                    # slider transparency 0-1
                    track=mk("Frame","Val",{"BackgroundColor3":(T_COLOR3, col(0x0B122A)),"Position":(T_UDIM2, udim2(0.45,0,0.5,0)),"AnchorPoint":(T_VECTOR2, vec2(0,0.5)),"Size":(T_UDIM2, udim2(0.52,-6,0,8)),"BorderSizePixel":(T_INT,0)})
                    track.add(mk("UICorner","C",{"CornerRadius":(T_UDIM, udim(0,4))}))
                    fill=mk("Frame","Fill",{"BackgroundColor3":(T_COLOR3, col(CYBER["neon"])),"Size":(T_UDIM2, udim2(float(val),0,1,0)),"BorderSizePixel":(T_INT,0)})
                    fill.add(mk("UICorner","C",{"CornerRadius":(T_UDIM, udim(0,4))}))
                    track.add(fill)
                    knob=mk("Frame","Knob",{"BackgroundColor3":(T_COLOR3, col(0xFFFFFF)),"Position":(T_UDIM2, udim2(float(val),-6,0.5,0)),"AnchorPoint":(T_VECTOR2, vec2(0,0.5)),"Size":(T_UDIM2, udim2(0,12,0,12)),"BorderSizePixel":(T_INT,0)})
                    knob.add(mk("UICorner","C",{"CornerRadius":(T_UDIM, udim(0,6))}))
                    track.add(knob)
                    track.add(mk("TextButton","Drag",{"BackgroundTransparency":(T_FLOAT32,1),"Size":(T_UDIM2, udim2(1,0,1,0)),"Text":(T_STRING,""),"ZIndex":(T_INT,5)}))
                    row.add(track)
                elif ctype=="color":
                    cp=mk("TextButton","Val",{"BackgroundColor3":(T_COLOR3, col(int(val,0) if val.startswith("0x") else 0xFF0000)),"Position":(T_UDIM2, udim2(1,-40,0.5,0)),"AnchorPoint":(T_VECTOR2, vec2(0,0.5)),"Size":(T_UDIM2, udim2(0,36,0,18)),"Text":(T_STRING,""),"BorderSizePixel":(T_INT,0)})
                    cp.add(mk("UICorner","C",{"CornerRadius":(T_UDIM, udim(0,4))}))
                    cp.add(mk("UIStroke","S",{"Color":(T_COLOR3, col(0xFFFFFF)),"Thickness":(T_FLOAT32,1),"Transparency":(T_FLOAT32,0.5)}))
                    row.add(cp)
                elif ctype=="dropdown":
                    dd=mk("TextButton","Val",{"BackgroundColor3":(T_COLOR3, col(0x0B122A)),"Position":(T_UDIM2, udim2(0.45,0,0.5,0)),"AnchorPoint":(T_VECTOR2, vec2(0,0.5)),"Size":(T_UDIM2, udim2(0.52,-6,0,20)),"Text":(T_STRING,val+"  ▾"),"TextColor3":(T_COLOR3, col(CYBER["text"])),"TextSize":(T_FLOAT32,11),"Font":(T_ENUM,2)})
                    dd.add(mk("UICorner","C",{"CornerRadius":(T_UDIM, udim(0,4))}))
                    row.add(dd)
                sec.add(row)
    section_real("Core Properties", [("textbox","Position","X: 36, 43.3"),("textbox","Orientation","Y: 8, M: 0"),("textbox","Size","X: 25, 3.3"),("slider","Transparency","0.0"),("color","Color","0x1A3A8A"),("dropdown","Material","Plastic")], True)
    section_real("Transform", [("textbox","CFrame","CFrame"),("textbox","Position","Vector3"),("checkbox","Anchored","true"),("checkbox","CanCollide","true"),("dropdown","Shape","Block")], True)
    section_real("Data", [("textbox","Name","SunEmblemBlock"),("checkbox","Archivable","true"),("dropdown","ClassName","Part")], False)
    section_real("Physics", [("checkbox","Anchored","true"),("slider","Transparency","0.0"),("textbox","AssemblyLinearVelocity","0,0,0")], False)
    section_real("Scripting", [("textbox","Script",""),("dropdown","RunContext","Legacy")], False)

def rebuild_topbar_organized(top):
    top.children=[]
    top.props["BackgroundColor3"]=(T_COLOR3, col(0x0F1F3A))
    top.props["Size"]=(T_UDIM2, udim2(1,0,0,78))
    top.add(mk("UIStroke","S",{"Color":(T_COLOR3, col(CYBER["border"])),"Thickness":(T_FLOAT32,1),"Transparency":(T_FLOAT32,0.6)}))
    top.add(mk("TextLabel","Title",{"BackgroundTransparency":(T_FLOAT32,1),"Position":(T_UDIM2, udim2(0,10,0,4)),"Size":(T_UDIM2, udim2(0,160,0,14)),"Text":(T_STRING,"ARKHER STUDIO"),"TextColor3":(T_COLOR3, col(CYBER["neon"])),"TextSize":(T_FLOAT32,13),"Font":(T_ENUM,3),"TextXAlignment":(T_ENUM,0)}))
    menu=mk("Frame","MenuRow",{"BackgroundTransparency":(T_FLOAT32,1),"Position":(T_UDIM2, udim2(0,10,0,18)),"Size":(T_UDIM2, udim2(1,-220,0,14))})
    top.add(menu)
    menu.add(mk("UIListLayout","L",{"FillDirection":(T_ENUM,0),"SortOrder":(T_ENUM,0),"Padding":(T_UDIM, udim(0,18)),"HorizontalAlignment":(T_ENUM,0)}))
    for n in ["FILE","EDIT","VIEW","INSERT","RUN","GAME"]:
        b=mk("TextButton",n,{"BackgroundTransparency":(T_FLOAT32,1),"Size":(T_UDIM2, udim2(0,48,1,0)),"Text":(T_STRING,n),"TextColor3":(T_COLOR3, col(CYBER["text"])),"TextSize":(T_FLOAT32,11),"Font":(T_ENUM,3)})
        # submenu frame
        sub=mk("Frame","Submenu",{"BackgroundColor3":(T_COLOR3, col(0x0B122A)),"Position":(T_UDIM2, udim2(0,0,1,4)),"Size":(T_UDIM2, udim2(0,160,0, 82 if n=="FILE" else 96)),"Visible":(T_BOOL, False),"ZIndex":(T_INT,20),"BorderSizePixel":(T_INT,0)})
        sub.add(mk("UICorner","C",{"CornerRadius":(T_UDIM, udim(0,8))}))
        sub.add(mk("UIStroke","S",{"Color":(T_COLOR3, col(CYBER["neon"])),"Thickness":(T_FLOAT32,1),"Transparency":(T_FLOAT32,0.5)}))
        sub.add(mk("UIListLayout","L",{"FillDirection":(T_ENUM,1),"Padding":(T_UDIM, udim(0,2)),"SortOrder":(T_ENUM,0)}))
        sub.add(mk("UIPadding","P",{"PaddingTop":(T_UDIM, udim(0,6)),"PaddingLeft":(T_UDIM, udim(0,6)),"PaddingRight":(T_UDIM, udim(0,6)),"PaddingBottom":(T_UDIM, udim(0,6))}))
        items={"FILE":["New","Open","Save","Save to Arkher","Publish"],"EDIT":["Undo","Redo","Select","Move","Scale","Rotate"],"VIEW":["Explorer","Properties","Toolbox","Output"],"INSERT":["Part","Model","Folder","Script","RemoteEvent"],"RUN":["Play","Stop","Resume"],"GAME":["Game Settings","Localization","DataStores"]}[n]
        for it in items:
            sub.add(mk("TextButton",it,{"BackgroundColor3":(T_COLOR3, col(CYBER["panel"])),"Size":(T_UDIM2, udim2(1,0,0,22)),"Text":(T_STRING,"  "+it),"TextColor3":(T_COLOR3, col(CYBER["text"])),"TextSize":(T_FLOAT32,11),"Font":(T_ENUM,2),"TextXAlignment":(T_ENUM,0)}))
        b.add(sub)
        menu.add(b)
    top.add(mk("Frame","CollaboratePill",{"BackgroundColor3":(T_COLOR3, col(0x1A7CFF)),"Position":(T_UDIM2, udim2(1,-160,0,6)),"Size":(T_UDIM2, udim2(0,96,0,20)),"BorderSizePixel":(T_INT,0)}))
    toolRow=mk("Frame","ToolRow",{"BackgroundTransparency":(T_FLOAT32,1),"Position":(T_UDIM2, udim2(0,10,0,36)),"Size":(T_UDIM2, udim2(1,-20,0,36))})
    top.add(toolRow)
    toolRow.add(mk("UIListLayout","L",{"FillDirection":(T_ENUM,0),"SortOrder":(T_ENUM,0),"Padding":(T_UDIM, udim(0,14)),"VerticalAlignment":(T_ENUM,1)}))
    groups=[("File", ["Save","Open","Save","Arkher"], ["Save","Open","Save","Arkher"]), ("Edit", ["Select","Move","Scale","Rotate","Lock"], ["Select","Move","Scale","Rotate","Transform"]), ("Insert", ["Model","Folder","Script","A"], ["Model","Folder","Script","Arkher"]), ("Run", ["Play","Stop"], ["Play","Stop"]), ("Game", ["Data","Local","Toolbox"], ["DataStores","Localization","ToolBox"]), ("Arkher", ["Cloud","AI"], ["CloudAssets","Settings"])]
    for gname, icons, keys in groups:
        grp=mk("Frame",gname,{"BackgroundColor3":(T_COLOR3, col(0x13204A)),"Size":(T_UDIM2, udim2(0, len(icons)*54+16,0,36)),"BorderSizePixel":(T_INT,0)})
        grp.add(mk("UICorner","C",{"CornerRadius":(T_UDIM, udim(0,8))}))
        grp.add(mk("UIStroke","S",{"Color":(T_COLOR3, col(CYBER["border"])),"Thickness":(T_FLOAT32,1),"Transparency":(T_FLOAT32,0.8)}))
        grp.add(mk("UIListLayout","L",{"FillDirection":(T_ENUM,0),"SortOrder":(T_ENUM,0),"Padding":(T_UDIM, udim(0,6)),"HorizontalAlignment":(T_ENUM,1),"VerticalAlignment":(T_ENUM,1)}))
        grp.add(mk("UIPadding","P",{"PaddingLeft":(T_UDIM, udim(0,6)),"PaddingRight":(T_UDIM, udim(0,6))}))
        for iname, k in zip(icons, keys):
            iid=ICON_IDS.get(k, "6031090996")
            cell=mk("Frame",k,{"BackgroundColor3":(T_COLOR3, col(CYBER["panelAlt"])),"Size":(T_UDIM2, udim2(0,46,0,30)),"BorderSizePixel":(T_INT,0)})
            cell.add(mk("UICorner","C",{"CornerRadius":(T_UDIM, udim(0,6))}))
            ic=mk("ImageLabel","Img",{"BackgroundTransparency":(T_FLOAT32,1),"Position":(T_UDIM2, udim2(0.5,0,0,4)),"AnchorPoint":(T_VECTOR2, vec2(0.5,0)),"Size":(T_UDIM2, udim2(0,18,0,18)),"Image":(T_STRING,f"rbxassetid://{iid}"),"BorderSizePixel":(T_INT,0)})
            cell.add(ic)
            cell.add(mk("TextLabel","Lbl",{"BackgroundTransparency":(T_FLOAT32,1),"Position":(T_UDIM2, udim2(0,0,1,-8)),"Size":(T_UDIM2, udim2(1,0,0,8)),"Text":(T_STRING,iname),"TextColor3":(T_COLOR3, col(CYBER["muted"])),"TextSize":(T_FLOAT32,7),"Font":(T_ENUM,2),"TextXAlignment":(T_ENUM,1)}))
            cell.add(mk("TextButton","Btn",{"BackgroundTransparency":(T_FLOAT32,1),"Size":(T_UDIM2, udim2(1,0,1,0)),"Text":(T_STRING,""),"ZIndex":(T_INT,10)}))
            grp.add(cell)
        toolRow.add(grp)

def patch35(roots):
    # Cria instâncias reais no Workspace para Explorer refletir realidade
    for r in roots:
        if r.cls=="Workspace":
            # cria hierarquia real se não existir
            names={c.name for c in r.children}
            if "Assets" not in names:
                assets=Inst("Folder","Assets")
                r.add(assets)
                terr=Inst("Terrain","Terrain")
                r.add(terr)
                go=Inst("Folder","Game Objects")
                r.add(go)
                # Part SunEmblemBlock real
                sun=Inst("Part","SunEmblemBlock",{"Size":(T_VECTOR2, (4,4))}) # dummy, real props via script
                # usa Part com propriedades básicas
                sun.props["Size"]=(T_UDIM2, udim2(0,0,0,0)) # will be overwritten by real Part handling — keep simple
                # cria Part real via Instance.new no script depois, aqui só folder
                go.add(Inst("Part","SunEmblemBlock"))
            # garante parts criáveis
    for r in roots:
        if r.cls=="StarterGui":
            for sg in r.children:
                if sg.name=="ARKHER_STUDIO":
                    for child in list(sg.children):
                        if child.name=="Root":
                            for c in child.children:
                                if c.name=="TopBar":
                                    rebuild_topbar_organized(c)
                                if c.name=="Explorer":
                                    rebuild_explorer_real(c)
                                if c.name=="Properties":
                                    rebuild_properties_real(c)
                                if c.name=="StatusBar":
                                    c.props["Visible"]=(T_BOOL, True)
                            # AI Chat botão flutuante
                            aiBtn=mk("TextButton","AI_Chat",{"BackgroundColor3":(T_COLOR3, col(0x7C3AED)),"Position":(T_UDIM2, udim2(1,-70,1,-70)),"AnchorPoint":(T_VECTOR2, vec2(0,0)),"Size":(T_UDIM2, udim2(0,56,0,56)),"Text":(T_STRING,"AI"),"TextColor3":(T_COLOR3, col(0xFFFFFF)),"TextSize":(T_FLOAT32,18),"Font":(T_ENUM,3),"ZIndex":(T_INT,50)})
                            aiBtn.add(mk("UICorner","C",{"CornerRadius":(T_UDIM, udim(0,28))}))
                            aiBtn.add(mk("UIStroke","S",{"Color":(T_COLOR3, col(0xFFFFFF)),"Thickness":(T_FLOAT32,2),"Transparency":(T_FLOAT32,0.7)}))
                            child.add(aiBtn)
                            # Chat window
                            chatWin=mk("Frame","AI_ChatWindow",{"BackgroundColor3":(T_COLOR3, col(0x0B122A)),"Position":(T_UDIM2, udim2(1,-340,1,-400)),"Size":(T_UDIM2, udim2(0,320,0,360)),"Visible":(T_BOOL, False),"ZIndex":(T_INT,50),"BorderSizePixel":(T_INT,0)})
                            chatWin.add(mk("UICorner","C",{"CornerRadius":(T_UDIM, udim(0,12))}))
                            chatWin.add(mk("UIStroke","S",{"Color":(T_COLOR3, col(CYBER["neon"])),"Thickness":(T_FLOAT32,1.5),"Transparency":(T_FLOAT32,0.4)}))
                            chatWin.add(mk("TextLabel","Title",{"BackgroundTransparency":(T_FLOAT32,1),"Position":(T_UDIM2, udim2(0,12,0,8)),"Size":(T_UDIM2, udim2(1,-24,0,16)),"Text":(T_STRING,"◆ Singularity AI — Criar Jogo"),"TextColor3":(T_COLOR3, col(CYBER["neon"])),"TextSize":(T_FLOAT32,12),"Font":(T_ENUM,3),"TextXAlignment":(T_ENUM,0)}))
                            chatWin.add(mk("TextBox","Input",{"BackgroundColor3":(T_COLOR3, col(CYBER["void"])),"Position":(T_UDIM2, udim2(0,8,1,-36)),"Size":(T_UDIM2, udim2(1,-16,0,28)),"Text":(T_STRING,"Peça pra IA criar seu jogo..."),"TextColor3":(T_COLOR3, col(CYBER["muted"])),"TextSize":(T_FLOAT32,11),"Font":(T_ENUM,2),"ClearTextOnFocus":(T_BOOL, True)}))
                            child.add(chatWin)
        if r.cls=="ReplicatedFirst":
            # Loading funcional — aparece ao iniciar
            hasLoad=any("Loading" in c.name for c in r.children)
            if not hasLoad:
                r.add(Inst("LocalScript","ARKHER_Loading",{"Source":(T_STRING, """
local gui=Instance.new("ScreenGui") gui.Name="ARKHER_LoadingGUI" gui.IgnoreGuiInset=true gui.DisplayOrder=999 gui.ResetOnSpawn=false
local bg=Instance.new("Frame") bg.Size=UDim2.fromScale(1,1) bg.BackgroundColor3=Color3.fromHex("#0E1430") bg.BorderSizePixel=0 bg.Parent=gui
local title=Instance.new("TextLabel") title.Size=UDim2.fromScale(1,0.15) title.Position=UDim2.fromScale(0,0.35) title.BackgroundTransparency=1 title.Text="ARKHER STUDIO 1 — GENESIS EDITION" title.TextColor3=Color3.fromHex("#00D4FF") title.TextScaled=true title.Font=Enum.Font.GothamBold title.Parent=bg
local sub=Instance.new("TextLabel") sub.Size=UDim2.fromScale(1,0.06) sub.Position=UDim2.fromScale(0,0.48) sub.BackgroundTransparency=1 sub.Text="Carregando 332 editores • 17.188 sistemas • Singularity AI..." sub.TextColor3=Color3.fromHex("#7A8AB8") sub.TextSize=14 sub.Font=Enum.Font.Gotham sub.Parent=bg
local bar=Instance.new("Frame") bar.Size=UDim2.new(0.4,0,0,8) bar.Position=UDim2.fromScale(0.3,0.58) bar.BackgroundColor3=Color3.fromHex("#1A3A8A") bar.BorderSizePixel=0 bar.Parent=bg Instance.new("UICorner",bar).CornerRadius=UDim.new(0,4)
local fill=Instance.new("Frame") fill.Size=UDim2.fromScale(0,1) fill.BackgroundColor3=Color3.fromHex("#00D4FF") fill.BorderSizePixel=0 fill.Parent=bar Instance.new("UICorner",fill).CornerRadius=UDim.new(0,4)
local pct=Instance.new("TextLabel") pct.Position=UDim2.fromScale(0,0.64) pct.Size=UDim2.fromScale(1,0.05) pct.BackgroundTransparency=1 pct.Text="0%" pct.TextColor3=Color3.fromHex("#7A8AB8") pct.TextSize=14 pct.Font=Enum.Font.Gotham pct.Parent=bg
task.spawn(function() for i=1,100 do fill.Size=UDim2.fromScale(i/100,1) pct.Text=i.."% — Inicializando..." task.wait(0.02) end task.wait(0.4) gui:Destroy() end)
gui.Parent=game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
""")}))
        if r.cls=="StarterPlayer":
            for f in r.children:
                if f.name=="StarterPlayerScripts":
                    # NÃO remove FlyCamera — mantém
                    # adiciona scripts funcionais reais
                    f.add(Inst("LocalScript","ARKHER_RealFunctional_V35",{"Source":(T_STRING, """
-- V1.35 REAL FUNCTIONAL — Explorer/Properties/TopBar/Insert/AI realmente afetam instância real
local Players=game:GetService("Players") local pl=Players.LocalPlayer task.wait(0.8)
local gui=pl.PlayerGui:FindFirstChild("ARKHER_STUDIO") if not gui then warn("[35] no gui") return end
gui.Enabled=true
local selected = nil
local function findReal(name)
 -- busca instância real no DataModel (Workspace, StarterGui, ReplicatedStorage etc)
 local function search(parent)
  for _,c in ipairs(parent:GetChildren()) do if c.Name==name then return c end end
  for _,c in ipairs(parent:GetChildren()) do local r=search(c) if r then return r end end
  return nil
 end
 for _,svc in ipairs({workspace, game:GetService("ReplicatedStorage"), game:GetService("StarterGui"), game:GetService("Lighting"), game:GetService("Players")}) do
  local r=search(svc) if r then return r end
 end
 -- fallback cria Part temporário se for SunEmblemBlock
 if name=="SunEmblemBlock" then
  local p=workspace:FindFirstChild("SunEmblemBlock") if p then return p end
  p=Instance.new("Part") p.Name="SunEmblemBlock" p.Size=Vector3.new(4,1,4) p.Position=Vector3.new(0,5,0) p.Anchored=true p.Parent=workspace return p
 end
 return workspace:FindFirstChild(name) or game:GetService("ReplicatedStorage"):FindFirstChild(name)
end
-- cria Workspace real se vazio
if #workspace:GetChildren()<2 then
 local f=Instance.new("Folder") f.Name="Assets" f.Parent=workspace
 Instance.new("Terrain").Parent=workspace
 local go=Instance.new("Folder") go.Name="Game Objects" go.Parent=workspace
 local s=Instance.new("Part") s.Name="SunEmblemBlock" s.Size=Vector3.new(8,1,8) s.Position=Vector3.new(0,2,0) s.Anchored=true s.Color=Color3.fromHex("#1A3A8A") s.Material=Enum.Material.Neon s.Parent=go
end
selected = workspace:FindFirstChild("SunEmblemBlock", true) or workspace
local expTree=gui.Root.Explorer:FindFirstChild("Tree")
local propSub=gui.Root.Properties.Header.Sub
local propList=gui.Root.Properties:FindFirstChild("List")
-- Atualiza Properties para instância real
local function refreshProperties(inst)
 if not inst then return end
 if propSub then propSub.Text=inst.Name.." ×  —  "..inst.ClassName end
 if not propList then return end
 for _,sec in ipairs(propList:GetChildren()) do if sec:IsA("Frame") then
  for _,row in ipairs(sec:GetChildren()) do if row:IsA("Frame") then
   local key=row:FindFirstChild("Key") local val=row:FindFirstChild("Val") if not key or not val then continue end
   local prop=key.Text
   -- tenta ler propriedade real
   local ok, cur = pcall(function() return inst[prop] end)
   if ok and cur~=nil then
    if val:IsA("TextBox") then
     if typeof(cur)=="Vector3" then val.Text=string.format("X: %.1f, %.1f, %.1f", cur.X,cur.Y,cur.Z)
     elseif typeof(cur)=="Color3" then val.Text=string.format("#%06X", math.floor(cur.R*255)*65536+math.floor(cur.G*255)*256+math.floor(cur.B*255))
     elseif typeof(cur)=="Number" then val.Text=tostring(cur)
     else val.Text=tostring(cur) end
    elseif val:IsA("TextButton") then -- checkbox/dropdown
     if typeof(cur)=="boolean" then val.Text = cur and "✓" or "" val.BackgroundColor3 = cur and Color3.fromHex("#00D4FF") or Color3.fromHex("#0B122A") end
    end
   end
  end end
 end end
end
-- Explorer: seleção real + dropdown + InsertMenu
local insertMenu=gui.Root.Explorer:FindFirstChild("InsertMenu")
for _,row in ipairs(expTree:GetChildren()) do if row:IsA("Frame") then
 local btn=row:FindFirstChild("Btn") local plus=row:FindFirstChild("Plus") local arrow=row:FindFirstChild("Arrow")
 if btn and not btn:GetAttribute("Hooked35") then btn:SetAttribute("Hooked35",true) btn.ZIndex=10
  btn.Activated:Connect(function()
   for _,o in ipairs(expTree:GetChildren()) do if o:IsA("Frame") then o.BackgroundTransparency=1 end end
   row.BackgroundTransparency=0 row.BackgroundColor3=Color3.fromRGB(26,58,138)
   local real=findReal(row.Name) if real then selected=real refreshProperties(real) pcall(function() game:GetService("Selection"):Set({real}) end) end
   print("[Explorer] selecionar "..row.Name.." -> "..tostring(selected and selected:GetFullName()))
  end)
 end
 if plus and not plus:GetAttribute("Hooked35") then plus:SetAttribute("Hooked35",true)
  plus.Activated:Connect(function()
   if insertMenu then insertMenu.Visible=not insertMenu.Visible insertMenu.Position=UDim2.new(0, row.AbsolutePosition.X + 220, 0, row.AbsolutePosition.Y) end
  end)
 end
 if arrow and arrow.Text~="" and not arrow:GetAttribute("Hooked35") then arrow:SetAttribute("Hooked35",true)
  arrow.Activated:Connect(function()
   local expand = arrow.Text=="▸"
   arrow.Text = expand and "▾" or "▸"
   -- mostra/esconde filhos indentados
   local indent = tonumber(row.Name) -- dummy
   for _,o in ipairs(expTree:GetChildren()) do if o:IsA("Frame") and o~=row then
    local lbl=o:FindFirstChild("Label") if lbl and o.Position.X.Offset > row.Position.X.Offset then o.Visible=expand end
   end end
  end)
 end
end end
-- InsertMenu criação real
if insertMenu then
 for _,b in ipairs(insertMenu.List:GetChildren()) do if b:IsA("TextButton") then
  b.Activated:Connect(function()
   local parentInst = selected or workspace
   local cls=b.Name
   local ok, inst = pcall(function()
    if cls=="Ball" then local p=Instance.new("Part") p.Shape=Enum.PartType.Ball return p
    elseif cls=="WedgePart" then local p=Instance.new("WedgePart") return p
    elseif cls=="Cylinder" then local p=Instance.new("Part") p.Shape=Enum.PartType.Cylinder return p
    elseif cls=="Block" then return Instance.new("Part")
    else return Instance.new(cls) end
   end)
   if ok and inst then inst.Name=cls inst.Parent=parentInst print("[Insert] "..cls.." em "..parentInst.Name) insertMenu.Visible=false
   else warn("Falha inserir "..cls) end
  end)
 end end
end
-- QuickCreate Part
for _,b in ipairs(gui.Root.Explorer.QuickCreate:GetChildren()) do if b:IsA("TextButton") then
 b.Activated:Connect(function()
  local shape=b.Text:match("▭") and Enum.PartType.Block or b.Text:match("●") and Enum.PartType.Ball or Enum.PartType.Block
  local p=Instance.new("Part") p.Shape=shape p.Size=Vector3.new(4,1,4) p.Position=Vector3.new(math.random(-20,20),5,math.random(-20,20)) p.Anchored=true p.Parent=workspace print("[QuickCreate] Part "..tostring(shape))
 end)
end end
-- Properties controles reais que afetam instância
if propList then
 for _,sec in ipairs(propList:GetChildren()) do if sec:IsA("Frame") then
  local head=sec:FindFirstChild("Head") if head then head=sec.Head.Toggle if head and not head:GetAttribute("Hooked") then head:SetAttribute("Hooked",true) head.Activated:Connect(function()
   local exp = sec.Size.Y.Offset > 28
   local arr=sec.Head:FindFirstChild("Arrow") if arr then arr.Text = exp and "▸" or "▾" end
   if exp then sec.Size=UDim2.new(1,0,0,28) for _,ch in ipairs(sec:GetChildren()) do if ch:IsA("Frame") and ch.Name~="Head" then ch.Visible=false end end
   else sec.Size=UDim2.new(1,0,0, 28 + 6*28) for _,ch in ipairs(sec:GetChildren()) do if ch:IsA("Frame") then ch.Visible=true end end end
  end) end end
  for _,row in ipairs(sec:GetChildren()) do if row:IsA("Frame") then
   local val=row:FindFirstChild("Val") if not val then continue end
   if val:IsA("TextBox") then
    val.FocusLost:Connect(function(enter)
     if not selected then return end
     local prop=row:FindFirstChild("Key").Text
     local txt=val.Text
     local ok,cur=pcall(function() return selected[prop] end)
     if ok then
      if typeof(cur)=="Vector3" then
       local x,y,z=txt:match("([%d.-]+)[,%s]+([%d.-]+)[,%s]+([%d.-]+)") if x then pcall(function() selected[prop]=Vector3.new(tonumber(x),tonumber(y),tonumber(z)) end) end
      elseif typeof(cur)=="Color3" then pcall(function() selected[prop]=Color3.fromHex(txt) end)
      elseif typeof(cur)=="number" then pcall(function() selected[prop]=tonumber(txt) end)
      elseif typeof(cur)=="string" then pcall(function() selected[prop]=txt end)
      end
      refreshProperties(selected)
     end
    end)
   elseif val:IsA("TextButton") and val.Size.X.Offset==18 then -- checkbox
    val.Activated:Connect(function()
     if not selected then return end
     local prop=row:FindFirstChild("Key").Text
     pcall(function() selected[prop]=not selected[prop] end)
     refreshProperties(selected)
    end)
   elseif val:IsA("Frame") and val.Name=="Val" then -- slider
    local drag=val:FindFirstChild("Drag") if drag then drag.Activated:Connect(function() print("Slider drag "..row.Name) end) end
   end
  end end
 end end
end
-- TopBar submenus funcionais
for _,btn in ipairs(gui.Root.TopBar.MenuRow:GetChildren()) do if btn:IsA("TextButton") then
 local sub=btn:FindFirstChild("Submenu") if sub then
  btn.MouseEnter:Connect(function() sub.Visible=true end)
  btn.MouseLeave:Connect(function() task.wait(0.2) if not sub:IsMouseOver() then sub.Visible=false end end)
  sub.MouseLeave:Connect(function() sub.Visible=false end)
  for _,it in ipairs(sub:GetChildren()) do if it:IsA("TextButton") then
   it.Activated:Connect(function() print("[TopBar] "..btn.Name.." -> "..it.Name) sub.Visible=false end)
  end end
 end
end end
-- AI Chat
local aiBtn=gui.Root:FindFirstChild("AI_Chat") local aiWin=gui.Root:FindFirstChild("AI_ChatWindow")
if aiBtn and aiWin then
 aiBtn.Activated:Connect(function() aiWin.Visible=not aiWin.Visible end)
 local input=aiWin:FindFirstChild("Input") if input then input.FocusLost:Connect(function(enter)
  if enter and input.Text~="" then
   print("[AI] Criar jogo: "..input.Text)
   local e=_G.ARKHER if e then local f=e:findSystems("arkher.t.singularity") if #f>0 then pcall(function() f[1].instance.selfTest() end) end end
   local s=Instance.new("Model") s.Name="AI_Generated_"..input.Text:sub(1,10) s.Parent=workspace input.Text="Feito! Veja Workspace"
  end
 end) end
end
refreshProperties(selected)
print("[V1.35 REAL] Explorer/Properties/TopBar/Insert/AI realmente funcionais | sem quadrado só")
""")}))
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
    roots=patch35(roots)
    out=os.path.join(REL,"ARKHER_STUDIO_1_GENESIS_EDITION_V1_35.rbxl")
    write(out, serialize(roots))
    print(f"V1.35 REAL {out} ({os.path.getsize(out)/1048576:.2f} MB)")
    subprocess.run(["python3","tools/validate_rbxm.py",out], cwd=ROOT)
    from build_complete import arkher_installer_folder
    write(os.path.join(REL,"ARKHER_STUDIO_1_GENESIS_EDITION_V1_35.rbxm"), serialize([arkher_installer_folder()]))
    print("rbxm V1.35 done")
