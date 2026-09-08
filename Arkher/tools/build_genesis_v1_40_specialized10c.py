#!/usr/bin/env python3
"""GENESIS V1.40 SPECIALIZED 10c — +10 editores únicos 3/3 (total 36/332)"""
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

def b_world(): 
    win=base_win("ARKHER_WorldBuild","WORLD BUILD — World Partition  •  HLOD",0x37474F,"Cell  •  HLOD  •  Streaming")
    win.add(mk("TextLabel","T",{"BackgroundTransparency":(T_FLOAT32,1),"Position":(T_UDIM2, udim2(0.5,0,0.5,0)),"AnchorPoint":(T_VECTOR2, vec2(0.5,0.5)),"Size":(T_UDIM2, udim2(0,600,0,60)),"Text":(T_STRING,"World Partition 64km²  •  HLOD  •  Cell Streaming  •  Minimap"),"TextColor3":(T_COLOR3, col(CYBER["text"])),"TextSize":(T_FLOAT32,12),"Font":(T_ENUM,2)}))
    return win
def b_blueprint():
    win=base_win("ARKHER_Blueprint","BLUEPRINT — Visual Script  •  Node",0x0D47A1,"Event  •  Flow  •  Cast")
    graph=mk("Frame","Graph",{"BackgroundColor3":(T_COLOR3, col(0x0B122A)),"Position":(T_UDIM2, udim2(0,8,0,42)),"Size":(T_UDIM2, udim2(1,-16,1,-50)),"BorderSizePixel":(T_INT,0)})
    graph.add(mk("UICorner","C",{"CornerRadius":(T_UDIM, udim(0,8))}))
    for i,n in enumerate(["EventTick","Branch","Cast","Spawn"]):
        node=mk("Frame",n,{"BackgroundColor3":(T_COLOR3, col(CYBER["panel"])),"Position":(T_UDIM2, udim2(0,20+i*150,0,40)),"Size":(T_UDIM2, udim2(0,130,0,60)),"BorderSizePixel":(T_INT,0)})
        node.add(mk("UICorner","C",{"CornerRadius":(T_UDIM, udim(0,6))}))
        node.add(mk("TextLabel","L",{"BackgroundTransparency":(T_FLOAT32,1),"Size":(T_UDIM2, udim2(1,0,0,16)),"Text":(T_STRING,n),"TextColor3":(T_COLOR3, col(CYBER["text"])),"TextSize":(T_FLOAT32,9),"Font":(T_ENUM,3)}))
        graph.add(node)
    win.add(graph)
    return win
def b_quest():
    win=base_win("ARKHER_Quest","QUEST — Graph  •  Objectives",0xF57F17,"Mission  •  Branch  •  Reward")
    win.add(mk("TextLabel","T",{"BackgroundTransparency":(T_FLOAT32,1),"Position":(T_UDIM2, udim2(0.5,0,0.5,0)),"AnchorPoint":(T_VECTOR2, vec2(0.5,0.5)),"Size":(T_UDIM2, udim2(0,600,0,60)),"Text":(T_STRING,"Quest Graph  ○ Main → Side → Branch  •  Objectives  •  Reward"),"TextColor3":(T_COLOR3, col(0xFFE082)),"TextSize":(T_FLOAT32,12),"Font":(T_ENUM,2)}))
    return win
def b_dialogue():
    win=base_win("ARKHER_Dialogue","DIALOGUE — Tree  •  Bark",0x6A1B9A,"Line  •  Choice  •  Condition")
    win.add(mk("TextLabel","T",{"BackgroundTransparency":(T_FLOAT32,1),"Position":(T_UDIM2, udim2(0.5,0,0.5,0)),"AnchorPoint":(T_VECTOR2, vec2(0.5,0.5)),"Size":(T_UDIM2, udim2(0,600,0,60)),"Text":(T_STRING,"Dialogue Tree  ◇ Line — Choice — Condition — LipSync"),"TextColor3":(T_COLOR3, col(0xCE93D8)),"TextSize":(T_FLOAT32,12),"Font":(T_ENUM,2)}))
    return win
def b_inventory():
    win=base_win("ARKHER_Inventory","INVENTORY — Grid  •  Craft",0x3E2723,"Slot  •  Stack  •  Recipe")
    grid=mk("Frame","Grid",{"BackgroundColor3":(T_COLOR3, col(0x0B122A)),"Position":(T_UDIM2, udim2(0.5,0,0.5,0)),"AnchorPoint":(T_VECTOR2, vec2(0.5,0.5)),"Size":(T_UDIM2, udim2(0,360,0,240)),"BorderSizePixel":(T_INT,0)})
    grid.add(mk("UICorner","C",{"CornerRadius":(T_UDIM, udim(0,8))}))
    grid.add(mk("UIGridLayout","G",{"CellPadding":(T_UDIM2, udim2(0,6,0,6)),"CellSize":(T_UDIM2, udim2(0,64,0,64))}))
    for i in range(12):
        s=mk("Frame",f"Slot{i}",{"BackgroundColor3":(T_COLOR3, col(CYBER["panelAlt"])),"BorderSizePixel":(T_INT,0)})
        s.add(mk("UICorner","C",{"CornerRadius":(T_UDIM, udim(0,6))}))
        grid.add(s)
    win.add(grid)
    return win
def b_combat():
    win=base_win("ARKHER_Combat","COMBAT — Hitbox  •  Combo",0xB71C1C,"Frame  •  Cancel  •  Damage")
    win.add(mk("TextLabel","T",{"BackgroundTransparency":(T_FLOAT32,1),"Position":(T_UDIM2, udim2(0.5,0,0.5,0)),"AnchorPoint":(T_VECTOR2, vec2(0.5,0.5)),"Size":(T_UDIM2, udim2(0,500,0,60)),"Text":(T_STRING,"Hitbox Frame 1-12  •  Combo A→B→C  •  Damage  •  Stun"),"TextColor3":(T_COLOR3, col(0xFF8A80)),"TextSize":(T_FLOAT32,12),"Font":(T_ENUM,2)}))
    return win
def b_vehicle():
    win=base_win("ARKHER_Vehicle","VEHICLE — Chaos  •  Suspension",0x4E342E,"Engine  •  Gear  •  Suspension")
    win.add(mk("TextLabel","T",{"BackgroundTransparency":(T_FLOAT32,1),"Position":(T_UDIM2, udim2(0.5,0,0.5,0)),"AnchorPoint":(T_VECTOR2, vec2(0.5,0.5)),"Size":(T_UDIM2, udim2(0,600,0,60)),"Text":(T_STRING,"Chaos Vehicle  •  Engine 400hp  •  Suspension  •  Tire Friction"),"TextColor3":(T_COLOR3, col(0xBCAAA4)),"TextSize":(T_FLOAT32,12),"Font":(T_ENUM,2)}))
    return win
def b_ai():
    win=base_win("ARKHER_AI","AI — BehaviorTree  •  EQS",0x1B5E20,"Selector  •  Sequence  •  Service")
    win.add(mk("TextLabel","T",{"BackgroundTransparency":(T_FLOAT32,1),"Position":(T_UDIM2, udim2(0.5,0,0.5,0)),"AnchorPoint":(T_VECTOR2, vec2(0.5,0.5)),"Size":(T_UDIM2, udim2(0,600,0,60)),"Text":(T_STRING,"BehaviorTree  Selector → Sequence → Task  •  Blackboard  •  EQS"),"TextColor3":(T_COLOR3, col(0xA5D6A7)),"TextSize":(T_FLOAT32,12),"Font":(T_ENUM,2)}))
    return win
def b_nav():
    win=base_win("ARKHER_NavMesh","NAVMESH — Recast  •  Detour",0x01579B,"Voxel  •  Region  •  Contour")
    win.add(mk("TextLabel","T",{"BackgroundTransparency":(T_FLOAT32,1),"Position":(T_UDIM2, udim2(0.5,0,0.5,0)),"AnchorPoint":(T_VECTOR2, vec2(0.5,0.5)),"Size":(T_UDIM2, udim2(0,600,0,60)),"Text":(T_STRING,"Recast  Voxel → Region → Contour  •  NavMesh  •  Crowd Agent"),"TextColor3":(T_COLOR3, col(0x81D4FA)),"TextSize":(T_FLOAT32,12),"Font":(T_ENUM,2)}))
    return win
def b_network():
    win=base_win("ARKHER_Network","NETWORK — Replication  •  Netcode",0x311B92,"Server  •  Client  •  Prediction")
    win.add(mk("TextLabel","T",{"BackgroundTransparency":(T_FLOAT32,1),"Position":(T_UDIM2, udim2(0.5,0,0.5,0)),"AnchorPoint":(T_VECTOR2, vec2(0.5,0.5)),"Size":(T_UDIM2, udim2(0,600,0,60)),"Text":(T_STRING,"Replication Graph  •  Prediction / Rollback  •  Lag Comp 20ms"),"TextColor3":(T_COLOR3, col(0xB39DDB)),"TextSize":(T_FLOAT32,12),"Font":(T_ENUM,2)}))
    return win

def patch40(roots):
    names=["ARKHER_WorldBuild","ARKHER_Blueprint","ARKHER_Quest","ARKHER_Dialogue","ARKHER_Inventory","ARKHER_Combat","ARKHER_Vehicle","ARKHER_AI","ARKHER_NavMesh","ARKHER_Network"]
    builders=[b_world,b_blueprint,b_quest,b_dialogue,b_inventory,b_combat,b_vehicle,b_ai,b_nav,b_network]
    for r in roots:
        if r.cls=="StarterGui":
            for sg in r.children:
                if sg.name=="ARKHER_STUDIO":
                    for child in sg.children:
                        if child.name=="Root":
                            child.children=[c for c in child.children if c.name not in names]
                            for b in builders:
                                child.add(b())
    FUNC40="""
local P=game:GetService("Players") local pl=P.LocalPlayer task.wait(0.5)
local gui=pl.PlayerGui:FindFirstChild("ARKHER_STUDIO") if not gui then return end
for _,n in ipairs({"ARKHER_WorldBuild","ARKHER_Blueprint","ARKHER_Quest","ARKHER_Dialogue","ARKHER_Inventory","ARKHER_Combat","ARKHER_Vehicle","ARKHER_AI","ARKHER_NavMesh","ARKHER_Network"}) do
 local w=gui.Root:FindFirstChild(n) if w then for _,b in ipairs(w:GetDescendants()) do if b:IsA("TextButton") then b.Activated:Connect(function() print("["..n.."] "..b.Name) end) end end
 local hd=w:FindFirstChild("Header",true) if hd then for _,c in ipairs(hd:GetChildren()) do if c:IsA("TextButton") and c.Text=="✕" then c.Activated:Connect(function() w.Visible=false end) end end end
 end
end
print("[V1.40 10x] World/Blueprint/Quest/Dialogue/Inventory/Combat/Vehicle/AI/NavMesh/Network")
"""
    for r in roots:
        if r.cls=="StarterPlayer":
            for f in r.children:
                if f.name=="StarterPlayerScripts":
                    f.add(Inst("LocalScript","ARKHER_Specialized_40",{"Source":(T_STRING, FUNC40)}))
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
    from build_genesis_v1_38_specialized10 import patch38
    roots=patch38(roots)
    from build_genesis_v1_39_specialized10b import patch39
    roots=patch39(roots)
    roots=patch40(roots)
    out=os.path.join(REL,"ARKHER_STUDIO_1_GENESIS_EDITION_V1_40.rbxl")
    write(out, serialize(roots))
    print(f"V1.40 10x {out} ({os.path.getsize(out)/1048576:.2f} MB)")
    subprocess.run(["python3","tools/validate_rbxm.py",out], cwd=ROOT)
    from build_complete import arkher_installer_folder
    write(os.path.join(REL,"ARKHER_STUDIO_1_GENESIS_EDITION_V1_40.rbxm"), serialize([arkher_installer_folder()]))
    print("rbxm V1.40 done")
