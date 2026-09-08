#!/usr/bin/env python3
"""GENESIS V1.37 SPECIALIZED 2 — Terrain voxel + Material nodes + VFX Niagara + Sculpt ZBrush, todos únicos"""
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

CYBER={"void":0x0A0E1A,"abyss":0x0E1430,"panel":0x0F1F3A,"panelAlt":0x13204A,"border":0x2A3A6A,"neon":0x00D4FF,"text":0xD0E4FF,"muted":0x7A8AB8,"sel":0x1A3A8A}
def mk(cls,name,props=None):
    return Inst(cls,name,props or {})

def build_terrain_specialized():
    win=mk("Frame","ARKHER_Terrain",{"BackgroundColor3":(T_COLOR3, col(CYBER["panel"])),"Size":(T_UDIM2, udim2(0,900,0,560)),"Position":(T_UDIM2, udim2(0.5,0,0.5,0)),"AnchorPoint":(T_VECTOR2, vec2(0.5,0.5)),"Visible":(T_BOOL, False),"BorderSizePixel":(T_INT,0)})
    win.add(mk("UICorner","C",{"CornerRadius":(T_UDIM, udim(0,10))}))
    win.add(mk("UIStroke","S",{"Color":(T_COLOR3, col(0x4CAF50)),"Thickness":(T_FLOAT32,1.5),"Transparency":(T_FLOAT32,0.3)}))
    header=mk("Frame","Header",{"BackgroundColor3":(T_COLOR3, col(0x0F2A0F)),"Size":(T_UDIM2, udim2(1,0,0,36)),"BorderSizePixel":(T_INT,0)})
    win.add(header)
    header.add(mk("TextLabel","Title",{"BackgroundTransparency":(T_FLOAT32,1),"Position":(T_UDIM2, udim2(0,12,0,0)),"Size":(T_UDIM2, udim2(0.7,0,0,20)),"Text":(T_STRING,"TERRAIN — HEIGHTFIELD VOXEL  •  Sculpt  Paint  Erosion"),"TextColor3":(T_COLOR3, col(0xA0FFA0)),"TextSize":(T_FLOAT32,12),"Font":(T_ENUM,3),"TextXAlignment":(T_ENUM,0)}))
    header.add(mk("TextLabel","Sub",{"BackgroundTransparency":(T_FLOAT32,1),"Position":(T_UDIM2, udim2(0,12,0,18)),"Size":(T_UDIM2, udim2(0.7,0,0,12)),"Text":(T_STRING,"Brush  •  HeightMap  •  Hydraulic/Thermal  •  Import"),"TextColor3":(T_COLOR3, col(CYBER["muted"])),"TextSize":(T_FLOAT32,9),"Font":(T_ENUM,2),"TextXAlignment":(T_ENUM,0)}))
    # Left Brush
    left=mk("Frame","Brush",{"BackgroundColor3":(T_COLOR3, col(CYBER["panelAlt"])),"Position":(T_UDIM2, udim2(0,6,0,42)),"Size":(T_UDIM2, udim2(0,160,0,300)),"BorderSizePixel":(T_INT,0)})
    left.add(mk("UICorner","C",{"CornerRadius":(T_UDIM, udim(0,8))}))
    left.add(mk("TextLabel","H",{"BackgroundTransparency":(T_FLOAT32,1),"Size":(T_UDIM2, udim2(1,0,0,22)),"Text":(T_STRING,"  Brush"),"TextColor3":(T_COLOR3, col(CYBER["neon"])),"TextSize":(T_FLOAT32,11),"Font":(T_ENUM,3)}))
    for i,tool in enumerate(["Draw","Smooth","Flatten","Inflate","Erode","Noise"]):
        b=mk("TextButton",tool,{"BackgroundColor3":(T_COLOR3, col(0x0B122A)),"Position":(T_UDIM2, udim2(0,8,0,26+i*32)),"Size":(T_UDIM2, udim2(1,-16,0,26)),"Text":(T_STRING,tool),"TextColor3":(T_COLOR3, col(CYBER["text"])),"TextSize":(T_FLOAT32,10),"Font":(T_ENUM,2)})
        b.add(mk("UICorner","C",{"CornerRadius":(T_UDIM, udim(0,6))}))
        left.add(b)
    # slider size/strength
    for i,lab in enumerate(["Size","Strength"]):
        row=mk("Frame",lab,{"BackgroundTransparency":(T_FLOAT32,1),"Position":(T_UDIM2, udim2(0,8,0,220+i*32)),"Size":(T_UDIM2, udim2(1,-16,0,22)),"BorderSizePixel":(T_INT,0)})
        row.add(mk("TextLabel","K",{"BackgroundTransparency":(T_FLOAT32,1),"Size":(T_UDIM2, udim2(0.4,0,1,0)),"Text":(T_STRING,lab),"TextColor3":(T_COLOR3, col(CYBER["muted"])),"TextSize":(T_FLOAT32,10),"Font":(T_ENUM,2)}))
        track=mk("Frame","Track",{"BackgroundColor3":(T_COLOR3, col(0x0B122A)),"Position":(T_UDIM2, udim2(0.4,0,0.5,0)),"AnchorPoint":(T_VECTOR2, vec2(0,0.5)),"Size":(T_UDIM2, udim2(0.6,-4,0,6)),"BorderSizePixel":(T_INT,0)})
        track.add(mk("UICorner","C",{"CornerRadius":(T_UDIM, udim(0,3))}))
        fill=mk("Frame","Fill",{"BackgroundColor3":(T_COLOR3, col(0x4CAF50)),"Size":(T_UDIM2, udim2(0.5,0,1,0)),"BorderSizePixel":(T_INT,0)})
        track.add(fill)
        row.add(track)
        left.add(row)
    win.add(left)
    # Center Viewport heightmap
    vp=mk("Frame","Viewport",{"BackgroundColor3":(T_COLOR3, col(0x1A2A1A)),"Position":(T_UDIM2, udim2(0,172,0,42)),"Size":(T_UDIM2, udim2(0,520,0,300)),"BorderSizePixel":(T_INT,0)})
    vp.add(mk("UICorner","C",{"CornerRadius":(T_UDIM, udim(0,8))}))
    vp.add(mk("TextLabel","T",{"BackgroundTransparency":(T_FLOAT32,1),"Size":(T_UDIM2, udim2(1,0,0,20)),"Text":(T_STRING,"  Heightfield  •  Wire  •  Solid"),"TextColor3":(T_COLOR3, col(CYBER["muted"])),"TextSize":(T_FLOAT32,10),"Font":(T_ENUM,2)}))
    vp.add(mk("TextLabel","HMap",{"BackgroundTransparency":(T_FLOAT32,1),"Position":(T_UDIM2, udim2(0.5,0,0.5,0)),"AnchorPoint":(T_VECTOR2, vec2(0.5,0.5)),"Size":(T_UDIM2, udim2(0,200,0,100)),"Text":(T_STRING,"▲▲\n▲▲▲  HeightMap"),"TextColor3":(T_COLOR3, col(0x6AFF6A)),"TextSize":(T_FLOAT32,18),"Font":(T_ENUM,2)}))
    win.add(vp)
    # Right Materials
    right=mk("Frame","Materials",{"BackgroundColor3":(T_COLOR3, col(CYBER["panelAlt"])),"Position":(T_UDIM2, udim2(1,-192,0,42)),"Size":(T_UDIM2, udim2(0,184,0,300)),"BorderSizePixel":(T_INT,0)})
    right.add(mk("UICorner","C",{"CornerRadius":(T_UDIM, udim(0,8))}))
    right.add(mk("TextLabel","H2",{"BackgroundTransparency":(T_FLOAT32,1),"Size":(T_UDIM2, udim2(1,0,0,22)),"Text":(T_STRING,"  Materials"),"TextColor3":(T_COLOR3, col(CYBER["neon"])),"TextSize":(T_FLOAT32,11),"Font":(T_ENUM,3)}))
    for i,mat in enumerate(["Grass","Rock","Sand","Snow","Mud"]):
        r=mk("TextButton",mat,{"BackgroundColor3":(T_COLOR3, col(CYBER["void"])),"Position":(T_UDIM2, udim2(0,8,0,26+i*28)),"Size":(T_UDIM2, udim2(1,-16,0,22)),"Text":(T_STRING,"  ● "+mat),"TextColor3":(T_COLOR3, col(CYBER["text"])),"TextSize":(T_FLOAT32,10),"Font":(T_ENUM,2),"TextXAlignment":(T_ENUM,0)})
        r.add(mk("UICorner","C",{"CornerRadius":(T_UDIM, udim(0,4))}))
        right.add(r)
    win.add(right)
    # Bottom erosion
    bot=mk("Frame","Erosion",{"BackgroundColor3":(T_COLOR3, col(0x0B122A)),"Position":(T_UDIM2, udim2(0,6,0,348)),"Size":(T_UDIM2, udim2(1,-12,0,50)),"BorderSizePixel":(T_INT,0)})
    bot.add(mk("UICorner","C",{"CornerRadius":(T_UDIM, udim(0,8))}))
    bot.add(mk("TextLabel","L",{"BackgroundTransparency":(T_FLOAT32,1),"Position":(T_UDIM2, udim2(0,8,0,6)),"Size":(T_UDIM2, udim2(0,100,0,12)),"Text":(T_STRING,"Erosion"),"TextColor3":(T_COLOR3, col(CYBER["muted"])),"TextSize":(T_FLOAT32,10),"Font":(T_ENUM,2)}))
    for j,lab in enumerate(["Hydraulic","Thermal","Sediment"]):
        b=mk("TextButton",lab,{"BackgroundColor3":(T_COLOR3, col(0x4CAF50)),"Position":(T_UDIM2, udim2(0,110+j*110,0.5,0)),"AnchorPoint":(T_VECTOR2, vec2(0,0.5)),"Size":(T_UDIM2, udim2(0,100,0,22)),"Text":(T_STRING,lab),"TextColor3":(T_COLOR3, col(0xFFFFFF)),"TextSize":(T_FLOAT32,10),"Font":(T_ENUM,3)})
        b.add(mk("UICorner","C",{"CornerRadius":(T_UDIM, udim(0,6))}))
        bot.add(b)
    win.add(bot)
    return win

def build_material_specialized():
    win=mk("Frame","ARKHER_Material",{"BackgroundColor3":(T_COLOR3, col(CYBER["panel"])),"Size":(T_UDIM2, udim2(0,900,0,560)),"Position":(T_UDIM2, udim2(0.5,0,0.5,0)),"AnchorPoint":(T_VECTOR2, vec2(0.5,0.5)),"Visible":(T_BOOL, False),"BorderSizePixel":(T_INT,0)})
    win.add(mk("UICorner","C",{"CornerRadius":(T_UDIM, udim(0,10))}))
    win.add(mk("UIStroke","S",{"Color":(T_COLOR3, col(0x6D4C41)),"Thickness":(T_FLOAT32,1.5),"Transparency":(T_FLOAT32,0.3)}))
    win.add(mk("TextLabel","Title",{"BackgroundTransparency":(T_FLOAT32,1),"Position":(T_UDIM2, udim2(0,12,0,8)),"Size":(T_UDIM2, udim2(1,0,0,16)),"Text":(T_STRING,"MATERIAL — NODES  •  Principled BSDF  •  PBR"),"TextColor3":(T_COLOR3, col(0xFFD0A0)),"TextSize":(T_FLOAT32,12),"Font":(T_ENUM,3),"TextXAlignment":(T_ENUM,0)}))
    # Node graph
    graph=mk("Frame","Graph",{"BackgroundColor3":(T_COLOR3, col(0x0B122A)),"Position":(T_UDIM2, udim2(0,8,0,30)),"Size":(T_UDIM2, udim2(1,-220,1,-40)),"BorderSizePixel":(T_INT,0)})
    graph.add(mk("UICorner","C",{"CornerRadius":(T_UDIM, udim(0,8))}))
    for i,node in enumerate(["ImageTexture","Noise","Principled BSDF","Material Output"]):
        n=mk("Frame",node,{"BackgroundColor3":(T_COLOR3, col(CYBER["panelAlt"])),"Position":(T_UDIM2, udim2(0, 20+i*160,0, 40+i*60)),"Size":(T_UDIM2, udim2(0,140,0,70)),"BorderSizePixel":(T_INT,0)})
        n.add(mk("UICorner","C",{"CornerRadius":(T_UDIM, udim(0,6))}))
        n.add(mk("UIStroke","S",{"Color":(T_COLOR3, col(CYBER["neon"])),"Thickness":(T_FLOAT32,1),"Transparency":(T_FLOAT32,0.6)}))
        n.add(mk("TextLabel","N",{"BackgroundTransparency":(T_FLOAT32,1),"Size":(T_UDIM2, udim2(1,0,0,16)),"Text":(T_STRING,node),"TextColor3":(T_COLOR3, col(CYBER["text"])),"TextSize":(T_FLOAT32,9),"Font":(T_ENUM,3)}))
        # sockets
        n.add(mk("Frame","In",{"BackgroundColor3":(T_COLOR3, col(CYBER["neon"])),"Position":(T_UDIM2, udim2(0,-6,0.5,0)),"AnchorPoint":(T_VECTOR2, vec2(0,0.5)),"Size":(T_UDIM2, udim2(0,10,0,10)),"BorderSizePixel":(T_INT,0)}))
        n.add(mk("Frame","Out",{"BackgroundColor3":(T_COLOR3, col(0xFFD600)),"Position":(T_UDIM2, udim2(1,6,0.5,0)),"AnchorPoint":(T_VECTOR2, vec2(1,0.5)),"Size":(T_UDIM2, udim2(0,10,0,10)),"BorderSizePixel":(T_INT,0)}))
        graph.add(n)
        if i>0:
            line=mk("Frame",f"Wire{i}",{"BackgroundColor3":(T_COLOR3, col(CYBER["neon"])),"Position":(T_UDIM2, udim2(0, 150+(i-1)*160,0, 70)),"Size":(T_UDIM2, udim2(0,30,0,2)),"BorderSizePixel":(T_INT,0)})
            graph.add(line)
    win.add(graph)
    # Preview
    prev=mk("Frame","Preview",{"BackgroundColor3":(T_COLOR3, col(CYBER["panelAlt"])),"Position":(T_UDIM2, udim2(1,-200,0,30)),"Size":(T_UDIM2, udim2(0,192,0,192)),"BorderSizePixel":(T_INT,0)})
    prev.add(mk("UICorner","C",{"CornerRadius":(T_UDIM, udim(0,8))}))
    prev.add(mk("TextLabel","P",{"BackgroundTransparency":(T_FLOAT32,1),"Size":(T_UDIM2, udim2(1,0,0,20)),"Text":(T_STRING,"  Preview"),"TextColor3":(T_COLOR3, col(CYBER["muted"])),"TextSize":(T_FLOAT32,10),"Font":(T_ENUM,2)}))
    ball=mk("Frame","Ball",{"BackgroundColor3":(T_COLOR3, col(0x6D4C41)),"Position":(T_UDIM2, udim2(0.5,0,0.5,0)),"AnchorPoint":(T_VECTOR2, vec2(0.5,0.5)),"Size":(T_UDIM2, udim2(0,100,0,100)),"BorderSizePixel":(T_INT,0)})
    ball.add(mk("UICorner","C",{"CornerRadius":(T_UDIM, udim(0,50))}))
    ball.add(mk("UIGradient","G",{}))
    prev.add(ball)
    win.add(prev)
    return win

def build_vfx_specialized():
    win=mk("Frame","ARKHER_VFX",{"BackgroundColor3":(T_COLOR3, col(CYBER["panel"])),"Size":(T_UDIM2, udim2(0,900,0,560)),"Position":(T_UDIM2, udim2(0.5,0,0.5,0)),"AnchorPoint":(T_VECTOR2, vec2(0.5,0.5)),"Visible":(T_BOOL, False),"BorderSizePixel":(T_INT,0)})
    win.add(mk("UICorner","C",{"CornerRadius":(T_UDIM, udim(0,10))}))
    win.add(mk("UIStroke","S",{"Color":(T_COLOR3, col(0xE65100)),"Thickness":(T_FLOAT32,1.5),"Transparency":(T_FLOAT32,0.3)}))
    win.add(mk("TextLabel","Title",{"BackgroundTransparency":(T_FLOAT32,1),"Position":(T_UDIM2, udim2(0,12,0,8)),"Size":(T_UDIM2, udim2(1,0,0,16)),"Text":(T_STRING,"VFX — NIAGARA  •  Emitter  •  System"),"TextColor3":(T_COLOR3, col(0xFFB080)),"TextSize":(T_FLOAT32,12),"Font":(T_ENUM,3)}))
    # Emitter list left
    left=mk("Frame","Emitters",{"BackgroundColor3":(T_COLOR3, col(CYBER["panelAlt"])),"Position":(T_UDIM2, udim2(0,8,0,30)),"Size":(T_UDIM2, udim2(0,160,1,-40)),"BorderSizePixel":(T_INT,0)})
    left.add(mk("UICorner","C",{"CornerRadius":(T_UDIM, udim(0,8))}))
    left.add(mk("TextLabel","H",{"BackgroundTransparency":(T_FLOAT32,1),"Size":(T_UDIM2, udim2(1,0,0,22)),"Text":(T_STRING,"  Emitters"),"TextColor3":(T_COLOR3, col(CYBER["neon"])),"TextSize":(T_FLOAT32,11),"Font":(T_ENUM,3)}))
    for i,e in enumerate(["Fire","Smoke","Sparks","Debris","Light"]):
        b=mk("TextButton",e,{"BackgroundColor3":(T_COLOR3, col(CYBER["void"] if i!=0 else CYBER["sel"])),"BackgroundTransparency":(T_FLOAT32, 0.3 if i==0 else 1),"Position":(T_UDIM2, udim2(0,4,0,26+i*28)),"Size":(T_UDIM2, udim2(1,-8,0,24)),"Text":(T_STRING,"  ● "+e),"TextColor3":(T_COLOR3, col(CYBER["text"])),"TextSize":(T_FLOAT32,10),"Font":(T_ENUM,2),"TextXAlignment":(T_ENUM,0)})
        b.add(mk("UICorner","C",{"CornerRadius":(T_UDIM, udim(0,4))}))
        left.add(b)
    win.add(left)
    # Graph center
    graph=mk("Frame","Graph",{"BackgroundColor3":(T_COLOR3, col(0x0B122A)),"Position":(T_UDIM2, udim2(0,174,0,30)),"Size":(T_UDIM2, udim2(0,500,1,-40)),"BorderSizePixel":(T_INT,0)})
    graph.add(mk("UICorner","C",{"CornerRadius":(T_UDIM, udim(0,8))}))
    graph.add(mk("TextLabel","GT",{"BackgroundTransparency":(T_FLOAT32,1),"Size":(T_UDIM2, udim2(1,0,0,20)),"Text":(T_STRING,"  Spawn  →  Update  →  Output"),"TextColor3":(T_COLOR3, col(CYBER["muted"])),"TextSize":(T_FLOAT32,10),"Font":(T_ENUM,2)}))
    for i,n in enumerate(["SpawnRate","Velocity","Turbulence","Color"]):
        node=mk("Frame",n,{"BackgroundColor3":(T_COLOR3, col(CYBER["panel"])),"Position":(T_UDIM2, udim2(0,20+i*110,0,40)),"Size":(T_UDIM2, udim2(0,100,0,50)),"BorderSizePixel":(T_INT,0)})
        node.add(mk("UICorner","C",{"CornerRadius":(T_UDIM, udim(0,6))}))
        node.add(mk("TextLabel","L",{"BackgroundTransparency":(T_FLOAT32,1),"Size":(T_UDIM2, udim2(1,0,0,16)),"Text":(T_STRING,n),"TextColor3":(T_COLOR3, col(CYBER["text"])),"TextSize":(T_FLOAT32,9),"Font":(T_ENUM,3)}))
        graph.add(node)
    win.add(graph)
    # Preview right
    prev=mk("Frame","Preview",{"BackgroundColor3":(T_COLOR3, col(CYBER["panelAlt"])),"Position":(T_UDIM2, udim2(1,-208,0,30)),"Size":(T_UDIM2, udim2(0,200,1,-40)),"BorderSizePixel":(T_INT,0)})
    prev.add(mk("UICorner","C",{"CornerRadius":(T_UDIM, udim(0,8))}))
    prev.add(mk("TextLabel","PH",{"BackgroundTransparency":(T_FLOAT32,1),"Size":(T_UDIM2, udim2(1,0,0,22)),"Text":(T_STRING,"  Preview"),"TextColor3":(T_COLOR3, col(CYBER["neon"])),"TextSize":(T_FLOAT32,11),"Font":(T_ENUM,3)}))
    prev.add(mk("TextLabel","Particles",{"BackgroundTransparency":(T_FLOAT32,1),"Position":(T_UDIM2, udim2(0.5,0,0.5,0)),"AnchorPoint":(T_VECTOR2, vec2(0.5,0.5)),"Size":(T_UDIM2, udim2(1,0,0,40)),"Text":(T_STRING,"✦ ✦ ✦\n✦ ✦"),"TextColor3":(T_COLOR3, col(0xFF8C00)),"TextSize":(T_FLOAT32,20),"Font":(T_ENUM,2)}))
    win.add(prev)
    return win

def build_sculpt_specialized():
    win=mk("Frame","ARKHER_Sculpt",{"BackgroundColor3":(T_COLOR3, col(CYBER["panel"])),"Size":(T_UDIM2, udim2(0,900,0,560)),"Position":(T_UDIM2, udim2(0.5,0,0.5,0)),"AnchorPoint":(T_VECTOR2, vec2(0.5,0.5)),"Visible":(T_BOOL, False),"BorderSizePixel":(T_INT,0)})
    win.add(mk("UICorner","C",{"CornerRadius":(T_UDIM, udim(0,10))}))
    win.add(mk("UIStroke","S",{"Color":(T_COLOR3, col(0x6A1B9A)),"Thickness":(T_FLOAT32,1.5),"Transparency":(T_FLOAT32,0.3)}))
    win.add(mk("TextLabel","Title",{"BackgroundTransparency":(T_FLOAT32,1),"Position":(T_UDIM2, udim2(0,12,0,8)),"Size":(T_UDIM2, udim2(1,0,0,16)),"Text":(T_STRING,"SCULPT — ZBRUSH  •  Dyntopo  •  Multires"),"TextColor3":(T_COLOR3, col(0xD0A0FF)),"TextSize":(T_FLOAT32,12),"Font":(T_ENUM,3)}))
    # Brush palette
    palette=mk("Frame","Palette",{"BackgroundColor3":(T_COLOR3, col(CYBER["panelAlt"])),"Position":(T_UDIM2, udim2(0,8,0,30)),"Size":(T_UDIM2, udim2(0,120,1,-40)),"BorderSizePixel":(T_INT,0)})
    palette.add(mk("UICorner","C",{"CornerRadius":(T_UDIM, udim(0,8))}))
    palette.add(mk("UIGridLayout","G",{"CellPadding":(T_UDIM2, udim2(0,4,0,4)),"CellSize":(T_UDIM2, udim2(0,52,0,52))}))
    for b in ["Draw","Smooth","Inflate","Grab","Clay","Crease","Flatten","Scrape"]:
        btn=mk("TextButton",b,{"BackgroundColor3":(T_COLOR3, col(0x0B122A)),"Text":(T_STRING,b),"TextColor3":(T_COLOR3, col(CYBER["text"])),"TextSize":(T_FLOAT32,8),"Font":(T_ENUM,2)})
        btn.add(mk("UICorner","C",{"CornerRadius":(T_UDIM, udim(0,6))}))
        palette.add(btn)
    win.add(palette)
    # Viewport
    vp=mk("Frame","Viewport",{"BackgroundColor3":(T_COLOR3, col(0x0B122A)),"Position":(T_UDIM2, udim2(0,134,0,30)),"Size":(T_UDIM2, udim2(0,500,1,-40)),"BorderSizePixel":(T_INT,0)})
    vp.add(mk("UICorner","C",{"CornerRadius":(T_UDIM, udim(0,8))}))
    vp.add(mk("TextLabel","Mesh",{"BackgroundTransparency":(T_FLOAT32,1),"Position":(T_UDIM2, udim2(0.5,0,0.5,0)),"AnchorPoint":(T_VECTOR2, vec2(0.5,0.5)),"Size":(T_UDIM2, udim2(0,200,0,100)),"Text":(T_STRING,"⬢\nHigh Poly  2.4M tris"),"TextColor3":(T_COLOR3, col(0xFFFFFF)),"TextSize":(T_FLOAT32,16),"Font":(T_ENUM,2)}))
    win.add(vp)
    # Properties
    props=mk("Frame","Props",{"BackgroundColor3":(T_COLOR3, col(CYBER["panelAlt"])),"Position":(T_UDIM2, udim2(1,-208,0,30)),"Size":(T_UDIM2, udim2(0,200,1,-40)),"BorderSizePixel":(T_INT,0)})
    props.add(mk("UICorner","C",{"CornerRadius":(T_UDIM, udim(0,8))}))
    props.add(mk("TextLabel","H",{"BackgroundTransparency":(T_FLOAT32,1),"Size":(T_UDIM2, udim2(1,0,0,22)),"Text":(T_STRING,"  Dyntopo"),"TextColor3":(T_COLOR3, col(CYBER["neon"])),"TextSize":(T_FLOAT32,11),"Font":(T_ENUM,3)}))
    for i,lab in enumerate(["Detail Size","Remesh","Symmetry"]):
        row=mk("Frame",lab,{"BackgroundTransparency":(T_FLOAT32,1),"Position":(T_UDIM2, udim2(0,8,0,30+i*28)),"Size":(T_UDIM2, udim2(1,-16,0,22)),"BorderSizePixel":(T_INT,0)})
        row.add(mk("TextLabel","K",{"BackgroundTransparency":(T_FLOAT32,1),"Size":(T_UDIM2, udim2(0.5,0,1,0)),"Text":(T_STRING,lab),"TextColor3":(T_COLOR3, col(CYBER["muted"])),"TextSize":(T_FLOAT32,10),"Font":(T_ENUM,2)}))
        row.add(mk("TextButton","V",{"BackgroundColor3":(T_COLOR3, col(0x0B122A)),"Position":(T_UDIM2, udim2(1,-60,0.5,0)),"AnchorPoint":(T_VECTOR2, vec2(0,0.5)),"Size":(T_UDIM2, udim2(0,60,0,18)),"Text":(T_STRING,"32 ▾"),"TextColor3":(T_COLOR3, col(CYBER["text"])),"TextSize":(T_FLOAT32,10),"Font":(T_ENUM,2)}))
        props.add(row)
    win.add(props)
    return win

def patch37(roots):
    for r in roots:
        if r.cls=="StarterGui":
            for sg in r.children:
                if sg.name=="ARKHER_STUDIO":
                    for child in sg.children:
                        if child.name=="Root":
                            # remove genéricos antigos
                            child.children=[c for c in child.children if c.name not in ("ARKHER_Terrain","ARKHER_Material","ARKHER_VFX","ARKHER_Sculpt")]
                            child.add(build_terrain_specialized())
                            child.add(build_material_specialized())
                            child.add(build_vfx_specialized())
                            child.add(build_sculpt_specialized())
    FUNC37="""
local P=game:GetService("Players") local pl=P.LocalPlayer task.wait(0.7)
local gui=pl.PlayerGui:FindFirstChild("ARKHER_STUDIO") if not gui then return end
local function hookWin(name)
 local w=gui.Root:FindFirstChild(name) if not w then return end
 for _,b in ipairs(w:GetDescendants()) do if b:IsA("TextButton") then
  b.Activated:Connect(function() print("["..name.."] "..b.Name) local e=_G.ARKHER if e then local f=e:findSystems(string.lower(b.Name)) if #f>0 then pcall(function() f[1].instance.selfTest() end) end end end)
 end end
 local hd=w:FindFirstChild("Header",true) if hd then for _,c in ipairs(hd:GetChildren()) do if c:IsA("TextButton") and c.Text=="✕" then c.Activated:Connect(function() w.Visible=false end) end end end
end
for _,n in ipairs({"ARKHER_Terrain","ARKHER_Material","ARKHER_VFX","ARKHER_Sculpt"}) do hookWin(n) end
-- Category abre especializados
local cat=gui.Root.TopBar:FindFirstChild("CategoryRow")
if cat then
 local map={Cat_D="ARKHER_Terrain",Cat_E="ARKHER_Material",Cat_N="ARKHER_VFX",Cat_Sculp="ARKHER_Sculpt"}
 for _,pill in ipairs(cat:GetChildren()) do if pill:IsA("Frame") then
  local btn=pill:FindFirstChild("Btn") if btn then btn.Activated:Connect(function()
   local target=map[pill.Name] if target then local w=gui.Root:FindFirstChild(target) if w then w.Visible=not w.Visible end end
  end) end
 end end
end
print("[V1.37 SPECIALIZED2] Terrain/Material/VFX/Sculpt refeitos únicos")
"""
    for r in roots:
        if r.cls=="StarterPlayer":
            for f in r.children:
                if f.name=="StarterPlayerScripts":
                    f.add(Inst("LocalScript","ARKHER_Specialized_37",{"Source":(T_STRING, FUNC37)}))
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
    from build_genesis_v1_35_real_functional import patch35
    roots=patch35(roots)
    from build_genesis_v1_36_specialized import patch36
    roots=patch36(roots)
    roots=patch37(roots)
    out=os.path.join(REL,"ARKHER_STUDIO_1_GENESIS_EDITION_V1_37.rbxl")
    write(out, serialize(roots))
    print(f"V1.37 SPECIALIZED2 {out} ({os.path.getsize(out)/1048576:.2f} MB)")
    subprocess.run(["python3","tools/validate_rbxm.py",out], cwd=ROOT)
    from build_complete import arkher_installer_folder
    write(os.path.join(REL,"ARKHER_STUDIO_1_GENESIS_EDITION_V1_37.rbxm"), serialize([arkher_installer_folder()]))
    print("rbxm V1.37 done")
