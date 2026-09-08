#!/usr/bin/env python3
"""GENESIS V1.38 SPECIALIZED 10 — +10 editores únicos, mantendo 10 por lote qualidade perfeita"""
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

def build_superres():
    win=base_win("ARKHER_SuperRes","SUPER RES — DLSS 4/5  •  Transformer  •  6X Dynamic",0x0288D1,"Transformer 2nd gen 5x compute  •  240 FPS")
    # Comparação
    comp=mk("Frame","Compare",{"BackgroundColor3":(T_COLOR3, col(0x0B122A)),"Position":(T_UDIM2, udim2(0,8,0,42)),"Size":(T_UDIM2, udim2(0,440,0,260)),"BorderSizePixel":(T_INT,0)})
    comp.add(mk("UICorner","C",{"CornerRadius":(T_UDIM, udim(0,8))}))
    comp.add(mk("TextLabel","L",{"BackgroundTransparency":(T_FLOAT32,1),"Size":(T_UDIM2, udim2(0.5,0,0,20)),"Text":(T_STRING,"  Native"),"TextColor3":(T_COLOR3, col(CYBER["muted"])),"TextSize":(T_FLOAT32,10),"Font":(T_ENUM,2)}))
    comp.add(mk("TextLabel","R",{"BackgroundTransparency":(T_FLOAT32,1),"Position":(T_UDIM2, udim2(0.5,0,0,0)),"Size":(T_UDIM2, udim2(0.5,0,0,20)),"Text":(T_STRING,"DLSS 6X  ▸"),"TextColor3":(T_COLOR3, col(CYBER["neon"])),"TextSize":(T_FLOAT32,10),"Font":(T_ENUM,3),"TextXAlignment":(T_ENUM,1)}))
    comp.add(mk("Frame","Native",{"BackgroundColor3":(T_COLOR3, col(0x1A1A2A)),"Position":(T_UDIM2, udim2(0,8,0,26)),"Size":(T_UDIM2, udim2(0.48,0,1,-32)),"BorderSizePixel":(T_INT,0)}))
    comp.add(mk("Frame","DLSS",{"BackgroundColor3":(T_COLOR3, col(0x0F2A4A)),"Position":(T_UDIM2, udim2(1,-8,0,26)),"AnchorPoint":(T_VECTOR2, vec2(1,0)),"Size":(T_UDIM2, udim2(0.48,0,1,-32)),"BorderSizePixel":(T_INT,0)}))
    win.add(comp)
    # Controles
    ctrl=mk("Frame","Controls",{"BackgroundColor3":(T_COLOR3, col(CYBER["panelAlt"])),"Position":(T_UDIM2, udim2(1,-232,0,42)),"Size":(T_UDIM2, udim2(0,224,0,260)),"BorderSizePixel":(T_INT,0)})
    ctrl.add(mk("UICorner","C",{"CornerRadius":(T_UDIM, udim(0,8))}))
    for i,lab in enumerate(["Quality","Balanced","Performance","Ultra"]):
        b=mk("TextButton",lab,{"BackgroundColor3":(T_COLOR3, col(CYBER["void"] if i!=2 else CYBER["neon"])),"Position":(T_UDIM2, udim2(0,8,0,12+i*32)),"Size":(T_UDIM2, udim2(1,-16,0,24)),"Text":(T_STRING,lab),"TextColor3":(T_COLOR3, col(0xFFFFFF if i==2 else CYBER["text"])),"TextSize":(T_FLOAT32,10),"Font":(T_ENUM,3)})
        b.add(mk("UICorner","C",{"CornerRadius":(T_UDIM, udim(0,6))}))
        ctrl.add(b)
    # MFG slider
    ctrl.add(mk("TextLabel","MFG",{"BackgroundTransparency":(T_FLOAT32,1),"Position":(T_UDIM2, udim2(0,8,0,148)),"Size":(T_UDIM2, udim2(1,-16,0,12)),"Text":(T_STRING,"Multi Frame Gen  2x 3x 4x 6X"),"TextColor3":(T_COLOR3, col(CYBER["muted"])),"TextSize":(T_FLOAT32,9),"Font":(T_ENUM,2)}))
    win.add(ctrl)
    # Bottom metrics
    bot=mk("Frame","Metrics",{"BackgroundColor3":(T_COLOR3, col(0x0B122A)),"Position":(T_UDIM2, udim2(0,8,1,-48)),"Size":(T_UDIM2, udim2(1,-16,0,40)),"BorderSizePixel":(T_INT,0)})
    bot.add(mk("UICorner","C",{"CornerRadius":(T_UDIM, udim(0,8))}))
    for j,met in enumerate(["FPS  240","Latency 12ms","VRAM 2.1GB"]):
        bot.add(mk("TextLabel",f"M{j}",{"BackgroundTransparency":(T_FLOAT32,1),"Position":(T_UDIM2, udim2(0, 12+j*140,0.5,0)),"AnchorPoint":(T_VECTOR2, vec2(0,0.5)),"Size":(T_UDIM2, udim2(0,120,0,20)),"Text":(T_STRING,met),"TextColor3":(T_COLOR3, col(CYBER["neon"])),"TextSize":(T_FLOAT32,11),"Font":(T_ENUM,3)}))
    win.add(bot)
    return win

def build_houdini():
    win=base_win("ARKHER_Houdini","HOUDINI — PROCEDURAL  •  SOP  VOP  DOP",0x1B5E20,"Scatter  •  Copy  •  VDB  •  HeightField")
    graph=mk("Frame","Graph",{"BackgroundColor3":(T_COLOR3, col(0x0B122A)),"Position":(T_UDIM2, udim2(0,8,0,42)),"Size":(T_UDIM2, udim2(1,-180,1,-50)),"BorderSizePixel":(T_INT,0)})
    graph.add(mk("UICorner","C",{"CornerRadius":(T_UDIM, udim(0,8))}))
    for i,node in enumerate(["scatter","copy","mountain","erode"]):
        n=mk("Frame",node,{"BackgroundColor3":(T_COLOR3, col(CYBER["panel"])),"Position":(T_UDIM2, udim2(0,20+i*130,0,50)),"Size":(T_UDIM2, udim2(0,110,0,60)),"BorderSizePixel":(T_INT,0)})
        n.add(mk("UICorner","C",{"CornerRadius":(T_UDIM, udim(0,6))}))
        n.add(mk("TextLabel","N",{"BackgroundTransparency":(T_FLOAT32,1),"Size":(T_UDIM2, udim2(1,0,0,16)),"Text":(T_STRING,node),"TextColor3":(T_COLOR3, col(CYBER["text"])),"TextSize":(T_FLOAT32,9),"Font":(T_ENUM,3)}))
        graph.add(n)
        if i>0:
            line=mk("Frame",f"W{i}",{"BackgroundColor3":(T_COLOR3, col(0x4CAF50)),"Position":(T_UDIM2, udim2(0, 120+(i-1)*130,0,78)),"Size":(T_UDIM2, udim2(0,30,0,2)),"BorderSizePixel":(T_INT,0)})
            graph.add(line)
    win.add(graph)
    # Parms
    parms=mk("Frame","Parms",{"BackgroundColor3":(T_COLOR3, col(CYBER["panelAlt"])),"Position":(T_UDIM2, udim2(1,-164,0,42)),"Size":(T_UDIM2, udim2(0,156,1,-50)),"BorderSizePixel":(T_INT,0)})
    parms.add(mk("UICorner","C",{"CornerRadius":(T_UDIM, udim(0,8))}))
    parms.add(mk("TextLabel","H",{"BackgroundTransparency":(T_FLOAT32,1),"Size":(T_UDIM2, udim2(1,0,0,22)),"Text":(T_STRING,"  Parms"),"TextColor3":(T_COLOR3, col(CYBER["neon"])),"TextSize":(T_FLOAT32,11),"Font":(T_ENUM,3)}))
    for i,lab in enumerate(["Count 5000","Scale 1.2","Seed 42"]):
        parms.add(mk("TextLabel",f"P{i}",{"BackgroundTransparency":(T_FLOAT32,1),"Position":(T_UDIM2, udim2(0,8,0,28+i*28)),"Size":(T_UDIM2, udim2(1,-16,0,22)),"Text":(T_STRING,lab),"TextColor3":(T_COLOR3, col(CYBER["text"])),"TextSize":(T_FLOAT32,10),"Font":(T_ENUM,2)}))
    win.add(parms)
    return win

def build_audio():
    win=base_win("ARKHER_Audio","AUDIO — MIXER  •  HRTF  •  Wwise",0x880E4F,"Bus  •  Reverb  •  Occlusion")
    mixer=mk("Frame","Mixer",{"BackgroundColor3":(T_COLOR3, col(0x0B122A)),"Position":(T_UDIM2, udim2(0,8,0,42)),"Size":(T_UDIM2, udim2(1,-16,1,-50)),"BorderSizePixel":(T_INT,0)})
    mixer.add(mk("UICorner","C",{"CornerRadius":(T_UDIM, udim(0,8))}))
    mixer.add(mk("UIListLayout","L",{"FillDirection":(T_ENUM,0),"Padding":(T_UDIM, udim(0,8)),"HorizontalAlignment":(T_ENUM,1),"VerticalAlignment":(T_ENUM,1)}))
    for ch in ["Master","Music","SFX","Voice","Ambience"]:
        strip=mk("Frame",ch,{"BackgroundColor3":(T_COLOR3, col(CYBER["panel"])),"Size":(T_UDIM2, udim2(0,110,0,220)),"BorderSizePixel":(T_INT,0)})
        strip.add(mk("UICorner","C",{"CornerRadius":(T_UDIM, udim(0,6))}))
        strip.add(mk("TextLabel","L",{"BackgroundTransparency":(T_FLOAT32,1),"Size":(T_UDIM2, udim2(1,0,0,16)),"Text":(T_STRING,ch),"TextColor3":(T_COLOR3, col(CYBER["text"])),"TextSize":(T_FLOAT32,9),"Font":(T_ENUM,3)}))
        # fader
        fader=mk("Frame","Fader",{"BackgroundColor3":(T_COLOR3, col(0x0B122A)),"Position":(T_UDIM2, udim2(0.5,0,0,22)),"AnchorPoint":(T_VECTOR2, vec2(0.5,0)),"Size":(T_UDIM2, udim2(0,8,0,160)),"BorderSizePixel":(T_INT,0)})
        fader.add(mk("UICorner","C",{"CornerRadius":(T_UDIM, udim(0,4))}))
        knob=mk("Frame","Knob",{"BackgroundColor3":(T_COLOR3, col(0x880E4F)),"Position":(T_UDIM2, udim2(0.5,0,0.3,0)),"AnchorPoint":(T_VECTOR2, vec2(0.5,0)),"Size":(T_UDIM2, udim2(0,16,0,16)),"BorderSizePixel":(T_INT,0)})
        knob.add(mk("UICorner","C",{"CornerRadius":(T_UDIM, udim(0,8))}))
        fader.add(knob)
        strip.add(fader)
        mixer.add(strip)
    win.add(mixer)
    return win

def build_physics():
    win=base_win("ARKHER_Physics","PHYSICS — SOLVER  •  Deterministic",0xFF3B30,"Rigid  •  Cloth  •  Fluid  •  240Hz")
    left=mk("Frame","Solver",{"BackgroundColor3":(T_COLOR3, col(CYBER["panelAlt"])),"Position":(T_UDIM2, udim2(0,8,0,42)),"Size":(T_UDIM2, udim2(0,200,1,-50)),"BorderSizePixel":(T_INT,0)})
    left.add(mk("UICorner","C",{"CornerRadius":(T_UDIM, udim(0,8))}))
    for i,lab in enumerate(["Solver  TGS","Iter  8","Substep 2","Gravity  -9.8"]):
        left.add(mk("TextLabel",f"S{i}",{"BackgroundTransparency":(T_FLOAT32,1),"Position":(T_UDIM2, udim2(0,8,0,12+i*28)),"Size":(T_UDIM2, udim2(1,-16,0,22)),"Text":(T_STRING,lab),"TextColor3":(T_COLOR3, col(CYBER["text"])),"TextSize":(T_FLOAT32,10),"Font":(T_ENUM,2)}))
    win.add(left)
    view=mk("Frame","View",{"BackgroundColor3":(T_COLOR3, col(0x0B122A)),"Position":(T_UDIM2, udim2(0,214,0,42)),"Size":(T_UDIM2, udim2(1,-222,1,-50)),"BorderSizePixel":(T_INT,0)})
    view.add(mk("UICorner","C",{"CornerRadius":(T_UDIM, udim(0,8))}))
    view.add(mk("TextLabel","T",{"BackgroundTransparency":(T_FLOAT32,1),"Position":(T_UDIM2, udim2(0.5,0,0.5,0)),"AnchorPoint":(T_VECTOR2, vec2(0.5,0.5)),"Size":(T_UDIM2, udim2(0,200,0,80)),"Text":(T_STRING,"⬢  Rigid  Cloth  Fluid\nDeterministic 240Hz"),"TextColor3":(T_COLOR3, col(0xFF8A80)),"TextSize":(T_FLOAT32,13),"Font":(T_ENUM,2)}))
    win.add(view)
    return win

def build_compositor():
    win=base_win("ARKHER_Compositor","COMPOSITOR — NUKE  •  Merge  •  Keyer",0x1A237E," Grade  •  Roto  •  Tracker")
    graph=mk("Frame","Graph",{"BackgroundColor3":(T_COLOR3, col(0x0B122A)),"Position":(T_UDIM2, udim2(0,8,0,42)),"Size":(T_UDIM2, udim2(1,-16,0,260)),"BorderSizePixel":(T_INT,0)})
    graph.add(mk("UICorner","C",{"CornerRadius":(T_UDIM, udim(0,8))}))
    for i,n in enumerate(["Read","Keyer","Merge","Write"]):
        node=mk("Frame",n,{"BackgroundColor3":(T_COLOR3, col(CYBER["panel"])),"Position":(T_UDIM2, udim2(0,30+i*160,0,40)),"Size":(T_UDIM2, udim2(0,110,0,50)),"BorderSizePixel":(T_INT,0)})
        node.add(mk("UICorner","C",{"CornerRadius":(T_UDIM, udim(0,6))}))
        node.add(mk("TextLabel","L",{"BackgroundTransparency":(T_FLOAT32,1),"Size":(T_UDIM2, udim2(1,0,0,16)),"Text":(T_STRING,n),"TextColor3":(T_COLOR3, col(CYBER["text"])),"TextSize":(T_FLOAT32,9),"Font":(T_ENUM,3)}))
        graph.add(node)
    win.add(graph)
    viewer=mk("Frame","Viewer",{"BackgroundColor3":(T_COLOR3, col(CYBER["panelAlt"])),"Position":(T_UDIM2, udim2(0,8,1,-100)),"Size":(T_UDIM2, udim2(1,-16,0,92)),"BorderSizePixel":(T_INT,0)})
    viewer.add(mk("UICorner","C",{"CornerRadius":(T_UDIM, udim(0,8))}))
    viewer.add(mk("TextLabel","V",{"BackgroundTransparency":(T_FLOAT32,1),"Position":(T_UDIM2, udim2(0.5,0,0.5,0)),"AnchorPoint":(T_VECTOR2, vec2(0.5,0.5)),"Size":(T_UDIM2, udim2(0,200,0,20)),"Text":(T_STRING,"Viewer  •  A/B  •  Wipe"),"TextColor3":(T_COLOR3, col(CYBER["muted"])),"TextSize":(T_FLOAT32,11),"Font":(T_ENUM,2)}))
    win.add(viewer)
    return win

def build_color():
    win=base_win("ARKHER_Color","COLOR — DAVINCI  •  Wheels  •  Curves",0xFF6B35,"Primary  •  Log  •  HDR")
    wheels=mk("Frame","Wheels",{"BackgroundColor3":(T_COLOR3, col(0x0B122A)),"Position":(T_UDIM2, udim2(0,8,0,42)),"Size":(T_UDIM2, udim2(1,-16,0,220)),"BorderSizePixel":(T_INT,0)})
    wheels.add(mk("UICorner","C",{"CornerRadius":(T_UDIM, udim(0,8))}))
    wheels.add(mk("UIListLayout","L",{"FillDirection":(T_ENUM,0),"Padding":(T_UDIM, udim(0,12)),"HorizontalAlignment":(T_ENUM,1)}))
    for w in ["Lift","Gamma","Gain","Offset"]:
        wheel=mk("Frame",w,{"BackgroundColor3":(T_COLOR3, col(CYBER["panel"])),"Size":(T_UDIM2, udim2(0,110,0,140)),"BorderSizePixel":(T_INT,0)})
        wheel.add(mk("UICorner","C",{"CornerRadius":(T_UDIM, udim(0,8))}))
        wheel.add(mk("TextLabel","L",{"BackgroundTransparency":(T_FLOAT32,1),"Size":(T_UDIM2, udim2(1,0,0,16)),"Text":(T_STRING,w),"TextColor3":(T_COLOR3, col(CYBER["text"])),"TextSize":(T_FLOAT32,10),"Font":(T_ENUM,3)}))
        circle=mk("Frame","C",{"BackgroundColor3":(T_COLOR3, col(0xFF6B35)),"Position":(T_UDIM2, udim2(0.5,0,0.5,0)),"AnchorPoint":(T_VECTOR2, vec2(0.5,0.5)),"Size":(T_UDIM2, udim2(0,70,0,70)),"BorderSizePixel":(T_INT,0)})
        circle.add(mk("UICorner","C",{"CornerRadius":(T_UDIM, udim(0,35))}))
        wheel.add(circle)
        wheels.add(wheel)
    win.add(wheels)
    return win

def build_mocap():
    win=base_win("ARKHER_Mocap","MOCAP — VICON  •  Retarget",0xB983FF,"Capture  •  Solve  •  LiveLink")
    win.add(mk("TextLabel","Body",{"BackgroundTransparency":(T_FLOAT32,1),"Position":(T_UDIM2, udim2(0.5,0,0.5,0)),"AnchorPoint":(T_VECTOR2, vec2(0.5,0.5)),"Size":(T_UDIM2, udim2(0,400,0,100)),"Text":(T_STRING,"● Capture  →  Solve  →  Retarget  →  LiveLink Unreal"),"TextColor3":(T_COLOR3, col(0xE0C0FF)),"TextSize":(T_FLOAT32,13),"Font":(T_ENUM,2)}))
    return win

def build_facial():
    win=base_win("ARKHER_Facial","FACIAL — ARKit 52  •  Wrinkle",0x00ACC1,"BlendShape  •  ARKit  •  Corrective")
    grid=mk("Frame","Grid",{"BackgroundTransparency":(T_FLOAT32,1),"Position":(T_UDIM2, udim2(0,8,0,42)),"Size":(T_UDIM2, udim2(1,-16,1,-50)),"BorderSizePixel":(T_INT,0)})
    grid.add(mk("UIGridLayout","G",{"CellPadding":(T_UDIM2, udim2(0,6,0,6)),"CellSize":(T_UDIM2, udim2(0,100,0,40))}))
    for s in ["BrowUp","Blink","Smile","JawOpen","Puff","Sneer","ARKit 52"]:
        b=mk("TextButton",s,{"BackgroundColor3":(T_COLOR3, col(CYBER["panelAlt"])),"Text":(T_STRING,s),"TextColor3":(T_COLOR3, col(CYBER["text"])),"TextSize":(T_FLOAT32,9),"Font":(T_ENUM,2)})
        b.add(mk("UICorner","C",{"CornerRadius":(T_UDIM, udim(0,6))}))
        grid.add(b)
    win.add(grid)
    return win

def build_crowd():
    win=base_win("ARKHER_Crowd","CROWD — MASSIVE  •  Agents",0x4CAF50,"BehaviorTree  •  Avoidance  •  Formation")
    win.add(mk("TextLabel","Info",{"BackgroundTransparency":(T_FLOAT32,1),"Position":(T_UDIM2, udim2(0.5,0,0.5,0)),"AnchorPoint":(T_VECTOR2, vec2(0.5,0.5)),"Size":(T_UDIM2, udim2(0,500,0,80)),"Text":(T_STRING,"Agents 5000  •  RVO Avoidance  •  Flocking  •  Formation\nBoids  Separation / Alignment / Cohesion"),"TextColor3":(T_COLOR3, col(0xA0FFA0)),"TextSize":(T_FLOAT32,12),"Font":(T_ENUM,2)}))
    return win

def build_traffic():
    win=base_win("ARKHER_Traffic","TRAFFIC — RAGE  •  Road Graph",0xFFB800,"Lanes  •  Lights  •  Flow")
    win.add(mk("TextLabel","Road",{"BackgroundTransparency":(T_FLOAT32,1),"Position":(T_UDIM2, udim2(0.5,0,0.5,0)),"AnchorPoint":(T_VECTOR2, vec2(0.5,0.5)),"Size":(T_UDIM2, udim2(0,600,0,60)),"Text":(T_STRING,"Road — Lane — Intersection — TrafficLight — Flow 1200 veh/h"),"TextColor3":(T_COLOR3, col(0xFFE082)),"TextSize":(T_FLOAT32,11),"Font":(T_ENUM,2)}))
    return win

def patch38(roots):
    for r in roots:
        if r.cls=="StarterGui":
            for sg in r.children:
                if sg.name=="ARKHER_STUDIO":
                    for child in sg.children:
                        if child.name=="Root":
                            keep=[c for c in child.children if c.name not in ("ARKHER_SuperRes","ARKHER_Houdini","ARKHER_Audio","ARKHER_Physics","ARKHER_Compositor","ARKHER_Color","ARKHER_Mocap","ARKHER_Facial","ARKHER_Crowd","ARKHER_Traffic")]
                            child.children=keep
                            for w in [build_superres(), build_houdini(), build_audio(), build_physics(), build_compositor(), build_color(), build_mocap(), build_facial(), build_crowd(), build_traffic()]:
                                child.add(w)
    FUNC38="""
local P=game:GetService("Players") local pl=P.LocalPlayer task.wait(0.6)
local gui=pl.PlayerGui:FindFirstChild("ARKHER_STUDIO") if not gui then return end
local function hook(name)
 local w=gui.Root:FindFirstChild(name) if not w then return end
 for _,b in ipairs(w:GetDescendants()) do if b:IsA("TextButton") then b.Activated:Connect(function() print("["..name.."] "..b.Name) local e=_G.ARKHER if e then local f=e:findSystems(string.lower(b.Name)) if #f>0 then pcall(function() f[1].instance.selfTest() end) end end end) end end
 local hd=w:FindFirstChild("Header",true) if hd then for _,c in ipairs(hd:GetChildren()) do if c:IsA("TextButton") and c.Text=="✕" then c.Activated:Connect(function() w.Visible=false end) end end end
end
for _,n in ipairs({"ARKHER_SuperRes","ARKHER_Houdini","ARKHER_Audio","ARKHER_Physics","ARKHER_Compositor","ARKHER_Color","ARKHER_Mocap","ARKHER_Facial","ARKHER_Crowd","ARKHER_Traffic"}) do hook(n) end
print("[V1.38 10x] 10 editores refeitos únicos")
"""
    for r in roots:
        if r.cls=="StarterPlayer":
            for f in r.children:
                if f.name=="StarterPlayerScripts":
                    f.add(Inst("LocalScript","ARKHER_Specialized_38",{"Source":(T_STRING, FUNC38)}))
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
    from build_genesis_v1_37_specialized2 import patch37
    roots=patch37(roots)
    roots=patch38(roots)
    out=os.path.join(REL,"ARKHER_STUDIO_1_GENESIS_EDITION_V1_38.rbxl")
    write(out, serialize(roots))
    print(f"V1.38 10x {out} ({os.path.getsize(out)/1048576:.2f} MB)")
    subprocess.run(["python3","tools/validate_rbxm.py",out], cwd=ROOT)
    from build_complete import arkher_installer_folder
    write(os.path.join(REL,"ARKHER_STUDIO_1_GENESIS_EDITION_V1_38.rbxm"), serialize([arkher_installer_folder()]))
    print("rbxm V1.38 done")
