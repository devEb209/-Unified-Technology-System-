#!/usr/bin/env python3
"""GENESIS V1.67 SPECIALIZED 10ad — +10 únicos 30/33 (306/332) sem parar"""
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
from build_genesis_v1_44_specialized10g import patch44
from build_genesis_v1_45_specialized10h import patch45
from build_genesis_v1_46_specialized10i import patch46
from build_genesis_v1_47_specialized10j import patch47
from build_genesis_v1_48_specialized10k import patch48
from build_genesis_v1_49_specialized10l import patch49
from build_genesis_v1_50_specialized10m import patch50
from build_genesis_v1_51_specialized10n import patch51
from build_genesis_v1_52_specialized10o import patch52
from build_genesis_v1_53_specialized10p import patch53
from build_genesis_v1_54_specialized10q import patch54
from build_genesis_v1_55_specialized10r import patch55
from build_genesis_v1_56_specialized10s import patch56
from build_genesis_v1_57_specialized10t import patch57
from build_genesis_v1_58_specialized10u import patch58
from build_genesis_v1_59_specialized10v import patch59
from build_genesis_v1_60_specialized10w import patch60
from build_genesis_v1_61_specialized10x import patch61
from build_genesis_v1_62_specialized10y import patch62
from build_genesis_v1_63_specialized10z import patch63
from build_genesis_v1_64_specialized10aa import patch64
from build_genesis_v1_65_specialized10ab import patch65
from build_genesis_v1_66_specialized10ac import patch66
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
def simple(name,title,color,sub,body):
    win=base_win(name,title,color,sub)
    win.add(mk("TextLabel","T",{"BackgroundTransparency":(T_FLOAT32,1),"Position":(T_UDIM2, udim2(0.5,0,0.5,0)),"AnchorPoint":(T_VECTOR2, vec2(0.5,0.5)),"Size":(T_UDIM2, udim2(0,600,0,60)),"Text":(T_STRING,body),"TextColor3":(T_COLOR3, col(CYBER["text"])),"TextSize":(T_FLOAT32,12),"Font":(T_ENUM,2)}))
    return win
def patch67(roots):
    items=[
        ("ARKHER_Discord","DISCORD — Link  •  Invite",0x5865F2,"Link  •  Invite  •  Bot","Link Invite Bot  •  discord.gg/arkher"),
        ("ARKHER_Twitter","TWITTER — Post  •  Hashtag",0x1DA1F2,"Post  •  Hashtag  •  Trend","Post Hashtag Trend  •  #ARKHER"),
        ("ARKHER_YT","YOUTUBE — Channel  •  Video",0xFF0000,"Channel  •  Video  •  Live","Channel Video Live  •  Subscribe"),
        ("ARKHER_Twitch","TWITCH — Stream  •  Clip",0x9146FF,"Stream  •  Clip  •  Raid","Stream Clip Raid  •  Live"),
        ("ARKHER_TikTok","TIKTOK — Short  •  Effect",0x000000,"Short  •  Effect  •  Sound","Short Effect Sound  •  Viral"),
        ("ARKHER_Reddit","REDDIT — Post  •  Vote",0xFF4500,"Post  •  Vote  •  Comment","Post Vote Comment  •  r/arkher"),
        ("ARKHER_Steam","STEAM — Store  •  Workshop",0x1B2838,"Store  •  Workshop  •  Review","Store Workshop Review  •  Wishlist"),
        ("ARKHER_Epic","EPIC — Store  •  Free",0x313131,"Store  •  Free  •  Coupon","Store Free Coupon  •  EGSP"),
        ("ARKHER_Google","GOOGLE — Play  •  Review",0x4285F4,"Play  •  Review  •  Install","Play Review Install  •  4.8"),
        ("ARKHER_Apple","APPLE — AppStore  •  Review",0x000000,"AppStore  •  Review  •  Feature","AppStore Review Feature  •  Featured"),
    ]
    names=[x[0] for x in items]
    for r in roots:
        if r.cls=="StarterGui":
            for sg in r.children:
                if sg.name=="ARKHER_STUDIO":
                    for child in sg.children:
                        if child.name=="Root":
                            child.children=[c for c in child.children if c.name not in names]
                            for n,t,c,s,b in items: child.add(simple(n,t,c,s,b))
    FUNC67="""
local P=game:GetService("Players") local pl=P.LocalPlayer task.wait(0.5)
local gui=pl.PlayerGui:FindFirstChild("ARKHER_STUDIO") if not gui then return end
for _,n in ipairs({"ARKHER_Discord","ARKHER_Twitter","ARKHER_YT","ARKHER_Twitch","ARKHER_TikTok","ARKHER_Reddit","ARKHER_Steam","ARKHER_Epic","ARKHER_Google","ARKHER_Apple"}) do
 local w=gui.Root:FindFirstChild(n) if w then for _,b in ipairs(w:GetDescendants()) do if b:IsA("TextButton") then b.Activated:Connect(function() print("["..n.."] "..b.Name) end) end end
 local hd=w:FindFirstChild("Header",true) if hd then for _,c in ipairs(hd:GetChildren()) do if c:IsA("TextButton") and c.Text=="✕" then c.Activated:Connect(function() w.Visible=false end) end end end
 end
end
print("[V1.67 10x] Discord/Twitter/YT/Twitch/TikTok/Reddit/Steam/Epic/Google/Apple 306/332")
"""
    for r in roots:
        if r.cls=="StarterPlayer":
            for f in r.children:
                if f.name=="StarterPlayerScripts":
                    f.add(Inst("LocalScript","ARKHER_Specialized_67",{"Source":(T_STRING, FUNC67)}))
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
    from build_genesis_v1_44_specialized10g import patch44
    roots=patch44(roots)
    from build_genesis_v1_45_specialized10h import patch45
    roots=patch45(roots)
    from build_genesis_v1_46_specialized10i import patch46
    roots=patch46(roots)
    from build_genesis_v1_47_specialized10j import patch47
    roots=patch47(roots)
    from build_genesis_v1_48_specialized10k import patch48
    roots=patch48(roots)
    from build_genesis_v1_49_specialized10l import patch49
    roots=patch49(roots)
    from build_genesis_v1_50_specialized10m import patch50
    roots=patch50(roots)
    from build_genesis_v1_51_specialized10n import patch51
    roots=patch51(roots)
    from build_genesis_v1_52_specialized10o import patch52
    roots=patch52(roots)
    from build_genesis_v1_53_specialized10p import patch53
    roots=patch53(roots)
    from build_genesis_v1_54_specialized10q import patch54
    roots=patch54(roots)
    from build_genesis_v1_55_specialized10r import patch55
    roots=patch55(roots)
    from build_genesis_v1_56_specialized10s import patch56
    roots=patch56(roots)
    from build_genesis_v1_57_specialized10t import patch57
    roots=patch57(roots)
    from build_genesis_v1_58_specialized10u import patch58
    roots=patch58(roots)
    from build_genesis_v1_59_specialized10v import patch59
    roots=patch59(roots)
    from build_genesis_v1_60_specialized10w import patch60
    roots=patch60(roots)
    from build_genesis_v1_61_specialized10x import patch61
    roots=patch61(roots)
    from build_genesis_v1_62_specialized10y import patch62
    roots=patch62(roots)
    from build_genesis_v1_63_specialized10z import patch63
    roots=patch63(roots)
    from build_genesis_v1_64_specialized10aa import patch64
    roots=patch64(roots)
    from build_genesis_v1_65_specialized10ab import patch65
    roots=patch65(roots)
    from build_genesis_v1_66_specialized10ac import patch66
    roots=patch66(roots)
    roots=patch67(roots)
    out=os.path.join(REL,"ARKHER_STUDIO_1_GENESIS_EDITION_V1_67.rbxl")
    write(out, serialize(roots))
    print(f"V1.67 10x {out} ({os.path.getsize(out)/1048576:.2f} MB)")
    subprocess.run(["python3","tools/validate_rbxm.py",out], cwd=ROOT)
    from build_complete import arkher_installer_folder
    write(os.path.join(REL,"ARKHER_STUDIO_1_GENESIS_EDITION_V1_67.rbxm"), serialize([arkher_installer_folder()]))
    print("rbxm V1.67 done")
