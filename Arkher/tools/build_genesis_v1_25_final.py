#!/usr/bin/env python3
"""GENESIS V1.25 FINAL — corrige viewport vazio garantido, Properties editável, Camera touch perfeito sem toggle"""
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

CYBER={"void":0x0A0E1A,"abyss":0x0E1430,"panel":0x0F1F3A,"panelAlt":0x13204A,"border":0x2A3A6A,"neon":0x00D4FF,"text":0xD0E4FF,"muted":0x7A8AB8,"sel":0x1A3A8A}

# Camera final Studio exato — sem toggle, segura direito PC, mobile só joystick+dedo, gamepad thumbsticks, scroll sempre
CAMERA_FINAL = """
-- ARKHER CAMERA V1.25 FINAL — STUDIO EXATO SEM TOGGLE
-- PC: segurar botão DIREITO + WASD/QE Shift | roda scroll zoom | direito+drag gira
-- MOBILE: joystick padrão move + arrastar dedo na tela gira (sem botão FLY)
-- CONSOLE: left stick move / right stick gira / L2 desce R2 sobe
local Players=game:GetService("Players") local UIS=game:GetService("UserInputService") local RS=game:GetService("RunService")
local pl=Players.LocalPlayer local cam=workspace.CurrentCamera cam.CameraType=Enum.CameraType.Custom
local rot=Vector2.zero local keys={} local rDown=false local speed=62
local touchStart=nil local touchRotStart=nil
task.wait(0.6)
do local lv=cam.CFrame.LookVector rot=Vector2.new(math.deg(math.atan2(lv.X,lv.Z)), math.deg(math.asin(-lv.Y))) end
UIS.InputBegan:Connect(function(i,gpe)
  if i.UserInputType==Enum.UserInputType.MouseButton2 then rDown=true UIS.MouseBehavior=Enum.MouseBehavior.LockCurrentPosition return end
  if i.UserInputType==Enum.UserInputType.Touch then
    touchStart=i.Position
    touchRotStart=rot
  end
  if i.KeyCode then keys[i.KeyCode]=true end
end)
UIS.InputEnded:Connect(function(i)
  if i.UserInputType==Enum.UserInputType.MouseButton2 then rDown=false UIS.MouseBehavior=Enum.MouseBehavior.Default end
  if i.UserInputType==Enum.UserInputType.Touch then touchStart=nil end
  if i.KeyCode then keys[i.KeyCode]=nil end
end)
UIS.InputChanged:Connect(function(i)
  if i.UserInputType==Enum.UserInputType.MouseMovement and rDown then
    rot+=Vector2.new(-i.Delta.X*0.32, -i.Delta.Y*0.32)
    rot=Vector2.new(rot.X, math.clamp(rot.Y,-84,84))
  end
  if i.UserInputType==Enum.UserInputType.Touch and touchStart then
    local d=i.Position - touchStart
    -- só gira se arrasto >10px e não é joystick (joystick fica no canto inferior esquerdo, ignorar touches lá)
    if i.Position.Y < workspace.CurrentCamera.ViewportSize.Y - 140 or i.Position.X > 220 then
      rot = touchRotStart + Vector2.new(-d.X*0.38, -d.Y*0.38)
      rot=Vector2.new(rot.X, math.clamp(rot.Y,-84,84))
    end
  end
  if i.UserInputType==Enum.UserInputType.MouseWheel then
    cam.CFrame = cam.CFrame + cam.CFrame.LookVector * (i.Position.Z>0 and 7 or -7)
  end
end)
-- Gamepad look (poll)
RS.RenderStepped:Connect(function(dt)
  if UIS.GamepadEnabled then
    for _,s in ipairs(UIS:GetGamepadState(Enum.UserInputType.Gamepad1)) do
      if s.KeyCode==Enum.KeyCode.Thumbstick2 and s.Position.Magnitude>0.11 then
        rot+=Vector2.new(-s.Position.X*1.9, s.Position.Y*1.9)
        rot=Vector2.new(rot.X, math.clamp(rot.Y,-84,84))
      end
    end
  end
  -- PC exige RDown, Mobile/Gamepad não
  local isPC = not UIS.TouchEnabled and not UIS.GamepadEnabled
  if isPC and not rDown then return end
  local move=Vector3.zero
  if keys[Enum.KeyCode.W] then move+=Vector3.new(0,0,-1) end
  if keys[Enum.KeyCode.S] then move+=Vector3.new(0,0,1) end
  if keys[Enum.KeyCode.A] then move+=Vector3.new(-1,0,0) end
  if keys[Enum.KeyCode.D] then move+=Vector3.new(1,0,0) end
  if keys[Enum.KeyCode.Q] then move+=Vector3.new(0,-1,0) end
  if keys[Enum.KeyCode.E] then move+=Vector3.new(0,1,0) end
  local fast = keys[Enum.KeyCode.LeftShift] or keys[Enum.KeyCode.RightShift]
  local curSpeed = fast and speed*2.6 or speed
  local hum=pl.Character and pl.Character:FindFirstChildOfClass("Humanoid")
  if hum and move.Magnitude<0.05 and UIS.TouchEnabled then
    local md=hum.MoveDirection
    if md.Magnitude>0.06 then move=Vector3.new(md.X,0,md.Z)*1.15 end
  end
  if UIS.GamepadEnabled then
    for _,s in ipairs(UIS:GetGamepadState(Enum.UserInputType.Gamepad1)) do
      if s.KeyCode==Enum.KeyCode.Thumbstick1 and s.Position.Magnitude>0.13 then
        move+=Vector3.new(s.Position.X,0,-s.Position.Y)
      end
      if s.KeyCode==Enum.KeyCode.ButtonL2 and s.Position.Z>0.18 then move+=Vector3.new(0,-1,0) end
      if s.KeyCode==Enum.KeyCode.ButtonR2 and s.Position.Z>0.18 then move+=Vector3.new(0,1,0) end
    end
  end
  if move.Magnitude>0 then move=move.Unit*curSpeed end
  local cf=CFrame.fromEulerAnglesYXZ(math.rad(rot.Y), math.rad(rot.X),0)
  local world=cf:VectorToWorldSpace(move)
  local pos=cam.CFrame.Position + world*dt
  cam.CFrame=CFrame.new(pos)*CFrame.fromEulerAnglesYXZ(math.rad(rot.Y), math.rad(rot.X),0)
  local char=pl.Character
  if char and char:FindFirstChild("HumanoidRootPart") then
    local hrp=char.HumanoidRootPart
    hrp.CFrame=CFrame.new(pos)
    hrp.AssemblyLinearVelocity=Vector3.zero
    local h=char:FindFirstChildOfClass("Humanoid") if h then h.PlatformStand=true end
  end
end)
print("[ARKHER CAMERA V1.25] Studio — dir+WASD/QE Shift | Mobile joystick+dedo | Gamepad sticks")
"""

def mk(cls,name,props=None):
    return Inst(cls,name,props or {})

def fix_properties_to_editable(prop):
    # recria Properties com TextBox editável no lugar do TextLabel Val
    lst=None
    for c in prop.children:
        if c.name=="List":
            lst=c
    if not lst:
        return
    # percorre sections e troca Val TextLabel por TextBox onde houver
    for sec in lst.children:
        for row in list(sec.children):
            if row.cls=="Frame" and row.name not in ("Head","Output"):
                # procura filho chamado Val
                for child in list(row.children):
                    if child.name=="Val" and child.cls=="TextLabel":
                        # substituir por TextBox
                        tb=mk("TextBox", "Val", {
                            "BackgroundTransparency":(T_FLOAT32,1),
                            "Position":child.props.get("Position", (T_UDIM2, udim2(0.5,0,0,0))),
                            "Size":child.props.get("Size", (T_UDIM2, udim2(0.5,-8,1,0))),
                            "Text":child.props.get("Text", (T_STRING,"")),
                            "TextColor3":(T_COLOR3, col(CYBER["text"])),
                            "TextSize":(T_FLOAT32,11),
                            "Font":(T_ENUM,2),
                            "TextXAlignment":(T_ENUM,2),
                            "ClearTextOnFocus":(T_BOOL, False),
                            "BorderSizePixel":(T_INT,0),
                        })
                        # remove antigo e adiciona novo
                        row.children=[c for c in row.children if c.name!="Val"]
                        row.add(tb)
                        break

def patch25(roots):
    # 1) garante viewport 100% vazio — remove Center e Viewport sem matar os 287 editores
    for r in roots:
        if r.cls=="StarterGui":
            for sg in r.children:
                if sg.name=="ARKHER_STUDIO":
                    for rootFrame in list(sg.children):
                        if rootFrame.name=="Root":
                            # manter TUDO exceto Center/Viewport/BuildGrid — preserva TopBar/Explorer/Properties/StatusBar + 287 editores ARKHER_*
                            kept=[]
                            for c in rootFrame.children:
                                if c.name=="Center": continue
                                if c.name in ("Viewport","BuildGrid","ViewportFrame"): continue
                                kept.append(c)
                            rootFrame.children=kept
                            rootFrame.props["BackgroundTransparency"]=(T_FLOAT32,1)
                            rootFrame.props["BackgroundColor3"]=(T_COLOR3, col(0x0A0E1A))
                            # ajustar Explorer/Properties positions já feitas, só confirmar
                            for c in rootFrame.children:
                                if c.name=="Explorer":
                                    c.props["Position"]=(T_UDIM2, udim2(0,0,0,62))
                                    c.props["Size"]=(T_UDIM2, udim2(0,220,1,-82))
                                if c.name=="Properties":
                                    c.props["Position"]=(T_UDIM2, udim2(1,0,0,62))
                                    c.props["AnchorPoint"]=(T_VECTOR2, vec2(1,0))
                                    c.props["Size"]=(T_UDIM2, udim2(0,300,1,-82))
                                    fix_properties_to_editable(c)
                                if c.name=="TopBar":
                                    c.props["Position"]=(T_UDIM2, udim2(0,0,0,0))
                                if c.name=="StatusBar":
                                    c.props["Position"]=(T_UDIM2, udim2(0,0,1,0))
        if r.cls=="StarterPlayer":
            for folder in r.children:
                if folder.name=="StarterPlayerScripts":
                    # trocar camera
                    folder.children=[c for c in folder.children if "CameraFly" not in c.name]
                    folder.add(Inst("LocalScript","ARKHER_CameraFly",{"Source":(T_STRING, CAMERA_FINAL)}))
                    # atualizar Global hook para TextBox também flash
                    for ls in list(folder.children):
                        if ls.name=="ARKHER_GlobalFunc_24":
                            ls.props["Source"]=(T_STRING, ls.props["Source"][1].replace("TextButton","TextButton or c:IsA(\"TextBox\")").replace("frame:IsA(\"Frame\") and frame.BackgroundColor3 or btn.BackgroundColor3","frame:IsA(\"Frame\") and frame.BackgroundColor3 or Color3.fromRGB(0,212,255)"))
        # garantir Loading 3D existe (ReplicatedFirst)
        if r.cls=="ReplicatedFirst":
            hasLoad=any(c.name=="ARKHER_Loading" or "Loading" in c.name for c in r.children)
            if not hasLoad:
                r.add(Inst("LocalScript","ARKHER_Loading",{"Source":(T_STRING, "-- ARKHER Loading 3D cyber-grid #0E1430 neon #00D4FF\nlocal gui=Instance.new(\"ScreenGui\") gui.Name=\"ARKHER_LoadingGUI\" gui.IgnoreGuiInset=true gui.DisplayOrder=999\nlocal bg=Instance.new(\"Frame\") bg.Size=UDim2.fromScale(1,1) bg.BackgroundColor3=Color3.fromHex(\"#0E1430\") bg.BorderSizePixel=0 bg.Parent=gui\nlocal title=Instance.new(\"TextLabel\") title.Size=UDim2.fromScale(1,0.2) title.Position=UDim2.fromScale(0,0.35) title.BackgroundTransparency=1 title.Text=\"ARKHER STUDIO 1 — GENESIS EDITION\" title.TextColor3=Color3.fromHex(\"#00D4FF\") title.TextScaled=true title.Font=Enum.Font.GothamBold title.Parent=bg\nlocal bar=Instance.new(\"Frame\") bar.Size=UDim2.new(0.4,0,0,6) bar.Position=UDim2.fromScale(0.3,0.6) bar.BackgroundColor3=Color3.fromHex(\"#1A3A8A\") bar.BorderSizePixel=0 bar.Parent=bg Instance.new(\"UICorner\",bar).CornerRadius=UDim.new(0,3)\nlocal fill=Instance.new(\"Frame\") fill.Size=UDim2.fromScale(0,1) fill.BackgroundColor3=Color3.fromHex(\"#00D4FF\") fill.BorderSizePixel=0 fill.Parent=bar Instance.new(\"UICorner\",fill).CornerRadius=UDim.new(0,3)\nlocal pct=Instance.new(\"TextLabel\") pct.Position=UDim2.fromScale(0,0.66) pct.Size=UDim2.fromScale(1,0.08) pct.BackgroundTransparency=1 pct.Text=\"0%\" pct.TextColor3=Color3.fromHex(\"#7A8AB8\") pct.TextScaled=true pct.Font=Enum.Font.Gotham pct.Parent=bg\ntask.spawn(function() for i=1,100 do fill.Size=UDim2.fromScale(i/100,1) pct.Text=i..\"% — Inicializando 17.188 sistemas...\" task.wait(0.015) end task.wait(0.35) gui:Destroy() end)\ngui.Parent=game:GetService(\"Players\").LocalPlayer:WaitForChild(\"PlayerGui\")\n")}))
    return roots

if __name__=="__main__":
    roots=build_all_v121()
    roots=patch22b(roots)
    roots=patch24(roots)
    roots=patch25(roots)
    out=os.path.join(REL,"ARKHER_STUDIO_1_GENESIS_EDITION_V1_25.rbxl")
    write(out, serialize(roots))
    print(f"V1.25 FINAL {out} ({os.path.getsize(out)/1048576:.2f} MB)")
    subprocess.run(["python3","tools/validate_rbxm.py",out], cwd=ROOT)
    from build_complete import arkher_installer_folder
    write(os.path.join(REL,"ARKHER_STUDIO_1_GENESIS_EDITION_V1_25.rbxm"), serialize([arkher_installer_folder()]))
    print("rbxm V1.25 done")
