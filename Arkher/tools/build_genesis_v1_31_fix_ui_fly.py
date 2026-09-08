#!/usr/bin/env python3
"""GENESIS V1.31 FIX — UI tamanho PC legível, Properties/Explorer exatos da 1ª print, câmera fly EXATO código do usuário + rotação, remake D3"""
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
from build_genesis_v1_26_perfect import patch26, ICON_IDS
from build_genesis_v1_27_max_content import patch27
from build_genesis_v1_28_perfect_max import patch28
from build_genesis_v1_29_singularity_aaa import patch29
from build_genesis_v1_30_perfect_max2 import patch30

CYBER={"void":0x0A0E1A,"abyss":0x0E1430,"panel":0x0F1F3A,"panelAlt":0x13204A,"border":0x2A3A6A,"neon":0x00D4FF,"text":0xD0E4FF,"muted":0x7A8AB8,"sel":0x1A3A8A}

# FlyCameraController EXATO do usuário + rotação + VR + auto-enable sem toggle manual
FLYCAM_EXACT = """
-- FlyCameraController — LocalScript PC + Mobile + Console + VR — EXATO do usuário + rotação
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local VRService = game:GetService("VRService")
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local NORMAL_SPEED = 32
local FAST_SPEED = 96
local ACCELERATION = 10
local DECELERATION = 12
local MOUSE_SENSITIVITY = 0.0025
local GAMEPAD_SENSITIVITY = 2.5
local flying = true -- inicia voando (Studio-like) sem toggle manual
camera.CameraType = Enum.CameraType.Scriptable
local moveInput = Vector3.zero
local currentVelocity = Vector3.zero
local mouseLook = Vector2.zero
local gamepadLook = Vector2.zero
local shift = false
local rot = Vector2.new(0, -12)
local keys = {W=false,A=false,S=false,D=false,Q=false,E=false}
local function updateKeyboard()
 local x=0 local y=0 local z=0
 if keys.W then z-=1 end
 if keys.S then z+=1 end
 if keys.A then x-=1 end
 if keys.D then x+=1 end
 if keys.E then y+=1 end
 if keys.Q then y-=1 end
 local v=Vector3.new(x,y,z)
 if v.Magnitude>1 then v=v.Unit end
 moveInput=v
end
UserInputService.InputBegan:Connect(function(input, processed)
 if processed then return end
 local key=input.KeyCode
 if key==Enum.KeyCode.W then keys.W=true
 elseif key==Enum.KeyCode.A then keys.A=true
 elseif key==Enum.KeyCode.S then keys.S=true
 elseif key==Enum.KeyCode.D then keys.D=true
 elseif key==Enum.KeyCode.Q then keys.Q=true
 elseif key==Enum.KeyCode.E then keys.E=true
 elseif key==Enum.KeyCode.LeftShift then shift=true end
 updateKeyboard()
end)
UserInputService.InputEnded:Connect(function(input)
 local key=input.KeyCode
 if key==Enum.KeyCode.W then keys.W=false
 elseif key==Enum.KeyCode.A then keys.A=false
 elseif key==Enum.KeyCode.S then keys.S=false
 elseif key==Enum.KeyCode.D then keys.D=false
 elseif key==Enum.KeyCode.Q then keys.Q=false
 elseif key==Enum.KeyCode.E then keys.E=false
 elseif key==Enum.KeyCode.LeftShift then shift=false end
 updateKeyboard()
end)
-- Mouse + Gamepad look (só rotaciona quando voando)
UserInputService.InputChanged:Connect(function(input)
 if input.UserInputType==Enum.UserInputType.MouseMovement and flying then
  -- Studio: segura botão direito pra olhar — se não segura, ignora delta pra não girar sozinho
  if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
   mouseLook = input.Delta
  else
   mouseLook = Vector2.zero
  end
 elseif input.UserInputType==Enum.UserInputType.Gamepad1 then
  if input.KeyCode==Enum.KeyCode.Thumbstick2 then
   gamepadLook=input.Position
  end
 end
 -- Touch drag gira (mobile sem botão)
 if input.UserInputType==Enum.UserInputType.Touch and flying then
  -- distingue joystick (canto inferior esquerdo 220x140) de drag de câmera
  if input.Position.X>220 or input.Position.Y < camera.ViewportSize.Y - 140 then
   mouseLook = Vector2.new(input.Delta.X, input.Delta.Y)
  end
 end
end)
local function getMobileMovement()
 if not UserInputService.TouchEnabled then return Vector3.zero end
 local character=player.Character if not character then return Vector3.zero end
 local humanoid=character:FindFirstChildOfClass("Humanoid") if not humanoid then return Vector3.zero end
 local direction=humanoid.MoveDirection
 if direction.Magnitude<=0 then return Vector3.zero end
 local relative=camera.CFrame:VectorToObjectSpace(direction)
 return Vector3.new(relative.X,0,relative.Z)
end
local function getGamepadMovement()
 if not UserInputService.GamepadEnabled then return Vector3.zero end
 local state=UserInputService:GetGamepadState(Enum.UserInputType.Gamepad1)
 local leftStick=Vector2.zero
 for _,input in ipairs(state) do
  if input.KeyCode==Enum.KeyCode.Thumbstick1 then leftStick=input.Position break end
 end
 return Vector3.new(leftStick.X,0,-leftStick.Y)
end
local function calculateMovement()
 if UserInputService.KeyboardEnabled then return moveInput end
 if UserInputService.GamepadEnabled then return getGamepadMovement() end
 if UserInputService.TouchEnabled then return getMobileMovement() end
 return Vector3.zero
end
local function updateFly(dt)
 if not flying then return end
 -- Rotação (mouse + gamepad + touch)
 local look = mouseLook * 0.25 + gamepadLook * GAMEPAD_SENSITIVITY
 rot += Vector2.new(-look.X, -look.Y)
 rot = Vector2.new(rot.X, math.clamp(rot.Y, -85, 85))
 mouseLook = Vector2.zero
 -- gamepadLook zera se soltar
 if gamepadLook.Magnitude<0.08 then gamepadLook=Vector2.zero end
 local rotCF = CFrame.fromEulerAnglesYXZ(math.rad(rot.Y), math.rad(rot.X), 0)
 camera.CFrame = CFrame.new(camera.CFrame.Position) * rotCF
 local input=calculateMovement()
 local speed=shift and FAST_SPEED or NORMAL_SPEED
 local targetVelocity=Vector3.zero
 if input.Magnitude>0 then
  local forward=camera.CFrame.LookVector
  local right=camera.CFrame.RightVector
  local direction=right*input.X + forward*-input.Z
  if input.Y~=0 then direction+=Vector3.yAxis*input.Y end
  if direction.Magnitude>1 then direction=direction.Unit end
  targetVelocity=direction*speed
 end
 local acceleration = input.Magnitude>0 and ACCELERATION or DECELERATION
 currentVelocity=currentVelocity:Lerp(targetVelocity, math.clamp(acceleration*dt,0,1))
 camera.CFrame=camera.CFrame + currentVelocity*dt
 -- mantém personagem junto pra mobile joystick
 local char=player.Character
 if char and char:FindFirstChild("HumanoidRootPart") then
  char.HumanoidRootPart.CFrame=CFrame.new(camera.CFrame.Position)
  char.HumanoidRootPart.AssemblyLinearVelocity=Vector3.zero
  local h=char:FindFirstChildOfClass("Humanoid") if h then h.PlatformStand=true end
 end
end
local function updateVR()
 if not VRService.VREnabled then return end
end
RunService:BindToRenderStep("DsOS_FlyCamera", Enum.RenderPriority.Camera.Value+1, function(dt)
 if flying then updateFly(dt) updateVR() end
end)
local FlyCamera={}
function FlyCamera:Enable() flying=true camera.CameraType=Enum.CameraType.Scriptable currentVelocity=Vector3.zero end
function FlyCamera:Disable() flying=false currentVelocity=Vector3.zero camera.CameraType=Enum.CameraType.Custom end
function FlyCamera:Toggle() if flying then self:Disable() else self:Enable() end end
_G.FlyCamera=FlyCamera
print("[FlyCamera] PC direita+WASD/QE Shift | Mobile joystick padrão | Console thumbsticks | VR | sem toggle manual")
-- inicia posição igual print (vê grid e SunEmblemBlock)
task.wait(0.8)
camera.CFrame=CFrame.new(Vector3.new(22,18,22), Vector3.new(0,0,0))
rot=Vector2.new(45, -18)
"""

def mk(cls,name,props=None):
    return Inst(cls,name,props or {})

def icon_real(name, key):
    iid=ICON_IDS.get(key, "6031090996")
    f=mk("Frame",name,{"BackgroundColor3":(T_COLOR3, col(CYBER["panelAlt"])),"BackgroundTransparency":(T_FLOAT32,0.0),"Size":(T_UDIM2, udim2(0,26,0,26)),"BorderSizePixel":(T_INT,0)})
    f.add(mk("UICorner","C",{"CornerRadius":(T_UDIM, udim(0,4))}))
    f.add(mk("UIStroke","S",{"Color":(T_COLOR3, col(CYBER["border"])),"Thickness":(T_FLOAT32,1),"Transparency":(T_FLOAT32,0.75)}))
    img=mk("ImageLabel","Img",{"BackgroundTransparency":(T_FLOAT32,1),"Size":(T_UDIM2, udim2(1,0,1,0)),"Image":(T_STRING,f"rbxassetid://{iid}"),"BorderSizePixel":(T_INT,0)})
    f.add(img)
    return f

def rebuild_topbar_v31(top):
    top.children=[]
    top.props["BackgroundColor3"]=(T_COLOR3, col(0x0F1F3A))
    top.props["Size"]=(T_UDIM2, udim2(1,0,0,72))
    top.props["BorderSizePixel"]=(T_INT,0)
    top.add(mk("UIStroke","S",{"Color":(T_COLOR3, col(CYBER["border"])),"Thickness":(T_FLOAT32,1),"Transparency":(T_FLOAT32,0.6)}))
    # Title
    top.add(mk("TextLabel","Title",{"BackgroundTransparency":(T_FLOAT32,1),"Position":(T_UDIM2, udim2(0,8,0,3)),"Size":(T_UDIM2, udim2(0,160,0,14)),"Text":(T_STRING,"ARKHER STUDIO"),"TextColor3":(T_COLOR3, col(CYBER["neon"])),"TextSize":(T_FLOAT32,13),"Font":(T_ENUM,3),"TextXAlignment":(T_ENUM,0)}))
    # MenuRow
    menu=mk("Frame","MenuRow",{"BackgroundTransparency":(T_FLOAT32,1),"Position":(T_UDIM2, udim2(0,0,0,18)),"Size":(T_UDIM2, udim2(1,0,0,14))})
    top.add(menu)
    menu.add(mk("UIListLayout","L",{"FillDirection":(T_ENUM,0),"SortOrder":(T_ENUM,0),"Padding":(T_UDIM, udim(0,16)),"HorizontalAlignment":(T_ENUM,0)}))
    for n in ["FILE","EDIT","VIEW","INSERT","RUN","GAME"]:
        menu.add(mk("TextButton",n,{"BackgroundTransparency":(T_FLOAT32,1),"Size":(T_UDIM2, udim2(0,48,1,0)),"Text":(T_STRING,n),"TextColor3":(T_COLOR3, col(CYBER["text"])),"TextSize":(T_FLOAT32,11),"Font":(T_ENUM,3),"AutoButtonColor":(T_BOOL,True)}))
    # Right Collaborate
    collab=mk("Frame","CollaboratePill",{"BackgroundColor3":(T_COLOR3, col(0x1A7CFF)),"Size":(T_UDIM2, udim2(0,96,0,18)),"Position":(T_UDIM2, udim2(1,-210,0,4)),"BorderSizePixel":(T_INT,0)})
    top.add(collab)
    collab.add(mk("UICorner","C",{"CornerRadius":(T_UDIM, udim(0,4))}))
    collab.add(mk("TextLabel","T",{"BackgroundTransparency":(T_FLOAT32,1),"Size":(T_UDIM2, udim2(1,0,1,0)),"Text":(T_STRING,"Collaborate"),"TextColor3":(T_COLOR3, col(0xFFFFFF)),"TextSize":(T_FLOAT32,11),"Font":(T_ENUM,3)}))
    # ToolRow PC legível — 28px botão, texto 11px
    toolRow=mk("Frame","ToolRow",{"BackgroundTransparency":(T_FLOAT32,1),"Position":(T_UDIM2, udim2(0,6,0,34)),"Size":(T_UDIM2, udim2(1,-12,0,34))})
    top.add(toolRow)
    toolRow.add(mk("UIListLayout","L",{"FillDirection":(T_ENUM,0),"SortOrder":(T_ENUM,0),"Padding":(T_UDIM, udim(0,4)),"VerticalAlignment":(T_ENUM,1)}))
    groups=[
        ("File", ["Save","Open","Save","Save_to_Arkher"], ["Save","Open","Save","Arkher"]),
        ("Edit", ["Select","Move","Scale","Rotate","Transform"], ["Select","Move","Scale","Rotate","Transform"]),
        ("Insert", ["Model","Folder","Script","AA"], ["Model","Folder","Script","Arkher"]),
        ("Run", ["Play","Play"], ["Play","Stop"]),
        ("Game", ["Data","Localization","Settings","Toolbox","Collaboration","Changes"], ["DataStores","Localization","Settings","ToolBox","Collaborate","Changes"]),
        ("Arkher", ["Arkher","Plight"], ["CloudAssets","Settings"]),
    ]
    for gname, icons, keys in groups:
        grp=mk("Frame",gname,{"BackgroundTransparency":(T_FLOAT32,1),"Size":(T_UDIM2, udim2(0, len(icons)*52+8,1,0)),"BorderSizePixel":(T_INT,0)})
        grp.add(mk("UIListLayout","L",{"FillDirection":(T_ENUM,0),"SortOrder":(T_ENUM,0),"Padding":(T_UDIM, udim(0,4)),"HorizontalAlignment":(T_ENUM,1),"VerticalAlignment":(T_ENUM,1)}))
        for iname, k in zip(icons, keys):
            cell=mk("Frame",k,{"BackgroundColor3":(T_COLOR3, col(CYBER["panelAlt"])),"Size":(T_UDIM2, udim2(0,48,0,32)),"BorderSizePixel":(T_INT,0)})
            cell.add(mk("UICorner","C",{"CornerRadius":(T_UDIM, udim(0,6))}))
            cell.add(mk("UIStroke","S",{"Color":(T_COLOR3, col(CYBER["border"])),"Thickness":(T_FLOAT32,1),"Transparency":(T_FLOAT32,0.75)}))
            ic=icon_real(k+"_I", k)
            ic.props["Position"]=(T_UDIM2, udim2(0.5,0,0,4))
            ic.props["AnchorPoint"]=(T_VECTOR2, vec2(0.5,0))
            ic.props["Size"]=(T_UDIM2, udim2(0,22,0,22))
            cell.add(ic)
            cell.add(mk("TextLabel","Lbl",{"BackgroundTransparency":(T_FLOAT32,1),"Position":(T_UDIM2, udim2(0,0,1,-10)),"Size":(T_UDIM2, udim2(1,0,0,10)),"Text":(T_STRING,iname),"TextColor3":(T_COLOR3, col(CYBER["muted"])),"TextSize":(T_FLOAT32,8),"Font":(T_ENUM,2),"TextXAlignment":(T_ENUM,1)}))
            btn=mk("TextButton","Btn",{"BackgroundTransparency":(T_FLOAT32,1),"Size":(T_UDIM2, udim2(1,0,1,0)),"Text":(T_STRING,""),"AutoButtonColor":(T_BOOL,False),"ZIndex":(T_INT,5)})
            cell.add(btn)
            grp.add(cell)
        toolRow.add(grp)
        sep=mk("Frame","Sep",{"BackgroundColor3":(T_COLOR3, col(CYBER["border"])),"Size":(T_UDIM2, udim2(0,1,0,32)),"BorderSizePixel":(T_INT,0)})
        toolRow.add(sep)
    # CategoryRow 30 cats menor mas legível
    catRow=mk("Frame","CategoryRow",{"BackgroundTransparency":(T_FLOAT32,1),"Position":(T_UDIM2, udim2(0,0,1,-2)),"Size":(T_UDIM2, udim2(1,0,0,16)),"Visible":(T_BOOL, False)})
    top.add(catRow)

def rebuild_left_nav(parent):
    # Vertical nav strip 40px como na 1ª print
    nav=mk("Frame","NavStrip",{"BackgroundColor3":(T_COLOR3, col(0x0B122A)),"Size":(T_UDIM2, udim2(0,42,1,0)),"Position":(T_UDIM2, udim2(0,0,0,0)),"BorderSizePixel":(T_INT,0)})
    parent.add(nav)
    nav.add(mk("UIListLayout","L",{"FillDirection":(T_ENUM,1),"SortOrder":(T_ENUM,0),"Padding":(T_UDIM, udim(0,6)),"HorizontalAlignment":(T_ENUM,1)}))
    nav.add(mk("UIPadding","P",{"PaddingTop":(T_UDIM, udim(0,8))}))
    for name in ["Home","Toolbox","Quick\nAssets","Plugins","Nav\nTools"]:
        b=mk("Frame",name.replace("\n",""),{"BackgroundTransparency":(T_FLOAT32,1),"Size":(T_UDIM2, udim2(1,0,0,52)),"BorderSizePixel":(T_INT,0)})
        b.add(mk("TextLabel","I",{"BackgroundTransparency":(T_FLOAT32,1),"Size":(T_UDIM2, udim2(1,0,0,22)),"Text":(T_STRING,"◈"),"TextColor3":(T_COLOR3, col(CYBER["muted"])),"TextSize":(T_FLOAT32,16),"Font":(T_ENUM,3)}))
        b.add(mk("TextLabel","L",{"BackgroundTransparency":(T_FLOAT32,1),"Position":(T_UDIM2, udim2(0,0,0,22)),"Size":(T_UDIM2, udim2(1,0,0,28)),"Text":(T_STRING,name),"TextColor3":(T_COLOR3, col(CYBER["muted"])),"TextSize":(T_FLOAT32,8),"Font":(T_ENUM,2)}))
        nav.add(b)

def rebuild_properties_exact_left(prop):
    # Limpa e recria Properties ESQUERDA exato 1ª print — tamanho PC legível
    # Mantém NavStrip dentro
    prop.children=[]
    prop.props["BackgroundColor3"]=(T_COLOR3, col(0x0F1F3A))
    prop.props["Position"]=(T_UDIM2, udim2(0,0,0,72))
    prop.props["Size"]=(T_UDIM2, udim2(0,280,1,-92))
    prop.props["AnchorPoint"]=(T_VECTOR2, vec2(0,0))
    rebuild_left_nav(prop)
    # Header Properties Panel
    header=mk("Frame","Header",{"BackgroundColor3":(T_COLOR3, col(0x0B122A)),"Position":(T_UDIM2, udim2(0,42,0,0)),"Size":(T_UDIM2, udim2(1,-42,0,28)),"BorderSizePixel":(T_INT,0)})
    prop.add(header)
    header.add(mk("TextLabel","Title",{"BackgroundTransparency":(T_FLOAT32,1),"Position":(T_UDIM2, udim2(0,8,0,0)),"Size":(T_UDIM2, udim2(1,-24,1,0)),"Text":(T_STRING,"Properties Panel"),"TextColor3":(T_COLOR3, col(CYBER["text"])),"TextSize":(T_FLOAT32,12),"Font":(T_ENUM,3),"TextXAlignment":(T_ENUM,0)}))
    header.add(mk("TextLabel","Sub",{"BackgroundTransparency":(T_FLOAT32,1),"Position":(T_UDIM2, udim2(0,8,0,14)),"Size":(T_UDIM2, udim2(1,0,0,12)),"Text":(T_STRING,"SunEmblemBlock ×"),"TextColor3":(T_COLOR3, col(CYBER["muted"])),"TextSize":(T_FLOAT32,9),"Font":(T_ENUM,2),"TextXAlignment":(T_ENUM,0)}))
    # Search
    search=mk("TextBox","Search",{"BackgroundColor3":(T_COLOR3, col(CYBER["void"])),"Position":(T_UDIM2, udim2(0,50,0,32)),"Size":(T_UDIM2, udim2(1,-58,0,22)),"Text":(T_STRING,"Search Mastered ( Brt. N)"),"TextColor3":(T_COLOR3, col(CYBER["muted"])),"TextSize":(T_FLOAT32,11),"Font":(T_ENUM,2),"ClearTextOnFocus":(T_BOOL, False)})
    search.add(mk("UICorner","C",{"CornerRadius":(T_UDIM, udim(0,4))}))
    prop.add(search)
    # List
    lst=mk("ScrollingFrame","List",{"BackgroundTransparency":(T_FLOAT32,1),"Position":(T_UDIM2, udim2(0,42,0,60)),"Size":(T_UDIM2, udim2(1,-42,1,-80)),"CanvasSize":(T_UDIM2, udim2(0,0,0,1100)),"ScrollBarThickness":(T_INT,4),"BorderSizePixel":(T_INT,0)})
    prop.add(lst)
    lst.add(mk("UIListLayout","L",{"FillDirection":(T_ENUM,1),"SortOrder":(T_ENUM,0),"Padding":(T_UDIM, udim(0,6))}))
    def section(title, rows, expanded=True):
        h = 26 + (len(rows)*22 if expanded else 0)
        sec=mk("Frame",title,{"BackgroundColor3":(T_COLOR3, col(CYBER["panelAlt"])),"Size":(T_UDIM2, udim2(1,0,0,h)),"BorderSizePixel":(T_INT,0)})
        sec.add(mk("UICorner","C",{"CornerRadius":(T_UDIM, udim(0,6))}))
        sec.add(mk("UIStroke","S",{"Color":(T_COLOR3, col(CYBER["border"])),"Thickness":(T_FLOAT32,1),"Transparency":(T_FLOAT32,0.7)}))
        head=mk("Frame","Head",{"BackgroundTransparency":(T_FLOAT32,1),"Size":(T_UDIM2, udim2(1,0,0,26)),"BorderSizePixel":(T_INT,0)})
        sec.add(head)
        head.add(mk("TextLabel","Arrow",{"BackgroundTransparency":(T_FLOAT32,1),"Position":(T_UDIM2, udim2(0,8,0,0)),"Size":(T_UDIM2, udim2(0,12,1,0)),"Text":(T_STRING,"▾" if expanded else "▸"),"TextColor3":(T_COLOR3, col(CYBER["muted"])),"TextSize":(T_FLOAT32,12),"Font":(T_ENUM,2)}))
        head.add(mk("TextLabel","T",{"BackgroundTransparency":(T_FLOAT32,1),"Position":(T_UDIM2, udim2(0,22,0,0)),"Size":(T_UDIM2, udim2(1,-22,1,0)),"Text":(T_STRING,title),"TextColor3":(T_COLOR3, col(CYBER["neon"])),"TextSize":(T_FLOAT32,11),"Font":(T_ENUM,3),"TextXAlignment":(T_ENUM,0)}))
        if expanded:
            for i,(k,v) in enumerate(rows):
                r=mk("Frame",k,{"BackgroundTransparency":(T_FLOAT32,0.97 if i%2==0 else 1),"BackgroundColor3":(T_COLOR3, col(CYBER["void"])),"Size":(T_UDIM2, udim2(1,0,0,22)),"Position":(T_UDIM2, udim2(0,0,0,26+i*22)),"BorderSizePixel":(T_INT,0)})
                r.add(mk("TextLabel","Key",{"BackgroundTransparency":(T_FLOAT32,1),"Position":(T_UDIM2, udim2(0,10,0,0)),"Size":(T_UDIM2, udim2(0.55,0,1,0)),"Text":(T_STRING,k),"TextColor3":(T_COLOR3, col(CYBER["muted"])),"TextSize":(T_FLOAT32,11),"Font":(T_ENUM,2),"TextXAlignment":(T_ENUM,0)}))
                r.add(mk("TextBox","Val",{"BackgroundTransparency":(T_FLOAT32,1),"Position":(T_UDIM2, udim2(0.55,0,0,0)),"Size":(T_UDIM2, udim2(0.45,-10,1,0)),"Text":(T_STRING,v),"TextColor3":(T_COLOR3, col(CYBER["text"])),"TextSize":(T_FLOAT32,11),"Font":(T_ENUM,2),"TextXAlignment":(T_ENUM,2),"ClearTextOnFocus":(T_BOOL, False),"BorderSizePixel":(T_INT,0)}))
                sec.add(r)
        lst.add(sec)
    section("Core Properties", [("Position","X: 36, 43.3"),("Orientation","Y: 8, M: 0"),("Size","X: 25, 3, 3|"),("Transparency","X: 35, 2, 541|"),("Color","Color")], True)
    section("Data", [], False)
    section("Transform", [("Position","X: 36, 453"),("Position","Y: 8, M: 0"),("Orientation","X: 25, 2, 341"),("Color","Color")], True)
    section("Physics", [], False)
    section("Physics", [("Transparency",""),("ReplicatedFirst",""),("ReplicatedFirst","✓"),("TransformFull","✓"),("PhysicsPlayer",""),("PhysicsTotal...","☐")], True)
    section("Scripting", [("Scripting",""),("Advanced Data","")], True)
    # Status
    prop.add(mk("TextLabel","StatusBar",{"BackgroundTransparency":(T_FLOAT32,1),"Position":(T_UDIM2, udim2(0,42,1,-20)),"Size":(T_UDIM2, udim2(1,-42,0,20)),"Text":(T_STRING,"Command  Status Bar"),"TextColor3":(T_COLOR3, col(CYBER["muted"])),"TextSize":(T_FLOAT32,10),"Font":(T_ENUM,2),"TextXAlignment":(T_ENUM,0)}))

def rebuild_explorer_exact_right(explorer):
    explorer.children=[]
    explorer.props["BackgroundColor3"]=(T_COLOR3, col(0x0F1F3A))
    explorer.props["Position"]=(T_UDIM2, udim2(1,0,0,72))
    explorer.props["AnchorPoint"]=(T_VECTOR2, vec2(1,0))
    explorer.props["Size"]=(T_UDIM2, udim2(0,280,1,-92))
    header=mk("Frame","Header",{"BackgroundColor3":(T_COLOR3, col(0x0B122A)),"Size":(T_UDIM2, udim2(1,0,0,28)),"BorderSizePixel":(T_INT,0)})
    explorer.add(header)
    header.add(mk("TextLabel","Title",{"BackgroundTransparency":(T_FLOAT32,1),"Position":(T_UDIM2, udim2(0,8,0,0)),"Size":(T_UDIM2, udim2(1,-20,0.5,0)),"Text":(T_STRING,"Explorer"),"TextColor3":(T_COLOR3, col(CYBER["text"])),"TextSize":(T_FLOAT32,12),"Font":(T_ENUM,3),"TextXAlignment":(T_ENUM,0)}))
    header.add(mk("TextBox","Filter",{"BackgroundColor3":(T_COLOR3, col(CYBER["void"])),"Position":(T_UDIM2, udim2(0,8,0,20)),"Size":(T_UDIM2, udim2(1,-16,0,16)),"Text":(T_STRING,"Filter Masters ( Br1: N)"),"TextColor3":(T_COLOR3, col(CYBER["muted"])),"TextSize":(T_FLOAT32,10),"Font":(T_ENUM,2),"ClearTextOnFocus":(T_BOOL, False)}))
    tree=mk("ScrollingFrame","Tree",{"BackgroundTransparency":(T_FLOAT32,1),"Position":(T_UDIM2, udim2(0,0,0,32)),"Size":(T_UDIM2, udim2(1,0,1,-60)),"CanvasSize":(T_UDIM2, udim2(0,0,0,800)),"ScrollBarThickness":(T_INT,4),"BorderSizePixel":(T_INT,0)})
    explorer.add(tree)
    tree.add(mk("UIListLayout","L",{"FillDirection":(T_ENUM,1),"SortOrder":(T_ENUM,0),"Padding":(T_UDIM, udim(0,1))}))
    def add_row(name, indent, selected=False, icon="6031090996"):
        row=mk("Frame",name,{"BackgroundTransparency":(T_FLOAT32, 0 if selected else 1),"BackgroundColor3":(T_COLOR3, col(CYBER["sel"] if selected else 0)),"Size":(T_UDIM2, udim2(1,0,0,22)),"BorderSizePixel":(T_INT,0)})
        if selected: row.add(mk("UICorner","C",{"CornerRadius":(T_UDIM, udim(0,4))}))
        arrow=mk("TextLabel","Arrow",{"BackgroundTransparency":(T_FLOAT32,1),"Position":(T_UDIM2, udim2(0, 4+indent*14,0,0)),"Size":(T_UDIM2, udim2(0,12,1,0)),"Text":(T_STRING,"▾" if name in ("Workspace","Assets","Game Objects") else "▸" if name=="Terrain" else ""),"TextColor3":(T_COLOR3, col(CYBER["muted"])),"TextSize":(T_FLOAT32,12),"Font":(T_ENUM,2)})
        row.add(arrow)
        ic=mk("ImageLabel","Icon",{"BackgroundTransparency":(T_FLOAT32,1),"Position":(T_UDIM2, udim2(0, 18+indent*14,0.5,0)),"AnchorPoint":(T_VECTOR2, vec2(0,0.5)),"Size":(T_UDIM2, udim2(0,16,0,16)),"Image":(T_STRING,f"rbxassetid://{icon}"),"BorderSizePixel":(T_INT,0)})
        row.add(ic)
        row.add(mk("TextLabel","Label",{"BackgroundTransparency":(T_FLOAT32,1),"Position":(T_UDIM2, udim2(0, 36+indent*14,0,0)),"Size":(T_UDIM2, udim2(1,-(36+indent*14),1,0)),"Text":(T_STRING,name),"TextColor3":(T_COLOR3, col(0xFFFFFF if selected else CYBER["text"])),"TextSize":(T_FLOAT32,11),"Font":(T_ENUM,2),"TextXAlignment":(T_ENUM,0)}))
        row.add(mk("TextButton","Btn",{"BackgroundTransparency":(T_FLOAT32,1),"Size":(T_UDIM2, udim2(1,0,1,0)),"Text":(T_STRING,""),"ZIndex":(T_INT,3)}))
        tree.add(row)
    add_row("Workspace",0, False, "6031091020")
    add_row("Assets",1, True, "6031091023")
    add_row("Terrain",1, False, "6031090999")
    add_row("Game Objects",1, False, "6031090997")
    add_row("SunEmblemBlock",2, False, "109251560")
    for sid, iid in [("Players","6031091024"),("Lighting","6031091025"),("MaterialService","6031091026"),("ReplicatedPost","6031091027"),("ReplicatedStorage","6031091028"),("ServerScriptService","6031091029"),("ServerStorage","6031091030"),("StarterGui","6031091031"),("StarterPack","6031091032"),("Starter Pack","6031091032"),("Starter Layer","6031091033"),("Starter Layer","6031091033"),("StarterChatService","6031091036"),("Starter Player","6031091033")]:
        add_row(sid,0, False, iid)
    for sid in ["ARKHER_Terrain","ARKHER_Animator","ARKHER_Material","ARKHER_Physics","ARKHER_Render"]:
        add_row(sid,0, False, "6031090999")
    chat=mk("Frame","Chat",{"BackgroundColor3":(T_COLOR3, col(0x0B122A)),"Position":(T_UDIM2, udim2(0,0,1,-28)),"Size":(T_UDIM2, udim2(1,0,0,28)),"BorderSizePixel":(T_INT,0)})
    explorer.add(chat)
    chat.add(mk("TextLabel","T",{"BackgroundTransparency":(T_FLOAT32,1),"Position":(T_UDIM2, udim2(0,8,0,0)),"Size":(T_UDIM2, udim2(1,-16,1,0)),"Text":(T_STRING,"Chat..."),"TextColor3":(T_COLOR3, col(CYBER["muted"])),"TextSize":(T_FLOAT32,11),"Font":(T_ENUM,2),"TextXAlignment":(T_ENUM,0)}))

def patch31(roots):
    for r in roots:
        if r.cls=="StarterGui":
            for sg in r.children:
                if sg.name=="ARKHER_STUDIO":
                    for child in list(sg.children):
                        if child.name=="Root":
                            child.children=[c for c in child.children if c.name not in ("Center","Viewport","BuildGrid")]
                            child.props["BackgroundTransparency"]=(T_FLOAT32,1)
                            for c in child.children:
                                if c.name=="TopBar":
                                    rebuild_topbar_v31(c)
                                if c.name=="Properties":
                                    rebuild_properties_exact_left(c)
                                if c.name=="Explorer":
                                    rebuild_explorer_exact_right(c)
                                if c.name=="StatusBar":
                                    c.props["Size"]=(T_UDIM2, udim2(1,0,0,20))
                                    c.props["Position"]=(T_UDIM2, udim2(0,0,1,0))
                            # Viewport grid central simulando 1ª print (céu + grid)
                            vp=mk("Frame","Viewport",{"BackgroundColor3":(T_COLOR3, col(0x87CEEB)),"Position":(T_UDIM2, udim2(0,280,0,72)),"Size":(T_UDIM2, udim2(1,-560,1,-92)),"BorderSizePixel":(T_INT,0)})
                            # grid chão
                            grid=mk("Frame","Grid",{"BackgroundColor3":(T_COLOR3, col(0x6A7A8A)),"Position":(T_UDIM2, udim2(0,0,0.6,0)),"Size":(T_UDIM2, udim2(1,0,0.4,0)),"BorderSizePixel":(T_INT,0)})
                            # linhas grid
                            for i in range(12):
                                line=mk("Frame",f"Line{i}",{"BackgroundColor3":(T_COLOR3, col(0x8A9AAA)),"Position":(T_UDIM2, udim2(0, i*0.08,0,0)),"Size":(T_UDIM2, udim2(0,1,1,0)),"BorderSizePixel":(T_INT,0)})
                                grid.add(line)
                            vp.add(grid)
                            # plate SunEmblemBlock
                            plate=mk("Frame","Plate",{"BackgroundColor3":(T_COLOR3, col(0xFFFFFF)),"Position":(T_UDIM2, udim2(0.5,0,0.5,0)),"AnchorPoint":(T_VECTOR2, vec2(0.5,0.5)),"Size":(T_UDIM2, udim2(0,120,0,120)),"Rotation":(T_FLOAT32,45),"BorderSizePixel":(T_INT,0)})
                            plate.add(mk("UICorner","C",{"CornerRadius":(T_UDIM, udim(0,4))}))
                            plate.add(mk("TextLabel","Star",{"BackgroundTransparency":(T_FLOAT32,1),"Size":(T_UDIM2, udim2(1,0,1,0)),"Text":(T_STRING,"✦"),"TextColor3":(T_COLOR3, col(0x0F1F3A)),"TextSize":(T_FLOAT32,48),"Font":(T_ENUM,3)}))
                            vp.add(plate)
                            child.add(vp)
        if r.cls=="StarterPlayer":
            for folder in r.children:
                if folder.name=="StarterPlayerScripts":
                    folder.children=[c for c in folder.children if "FlyCamera" not in c.name and "CameraFly" not in c.name]
                    folder.add(Inst("LocalScript","ARKHER_FlyCamera",{"Source":(T_STRING, FLYCAM_EXACT)}))
                    # remove globals antigos
                    folder.children=[c for c in folder.children if not c.name.startswith("ARKHER_Global")]
                    # global novo com botões maiores
                    GF="""
local P=game:GetService("Players") local pl=P.LocalPlayer task.wait(1)
local gui=pl.PlayerGui:FindFirstChild("ARKHER_STUDIO") if not gui then return end
local function hook(btn)
 if btn:GetAttribute("Hooked31") then return end btn:SetAttribute("Hooked31",true)
 local fr=btn.Parent
 local col=fr:IsA("Frame") and fr.BackgroundColor3 or Color3.fromRGB(15,31,58)
 btn.Activated:Connect(function()
  if fr:IsA("Frame") then fr.BackgroundColor3=Color3.fromRGB(0,212,255) task.delay(0.2,function() fr.BackgroundColor3=col end) end
  local e=_G.ARKHER if e then local f=e:findSystems(string.lower(fr.Name)) if #f>0 then pcall(function() if f[1].instance.selfTest then f[1].instance.selfTest() end end) print("[FUNC] "..fr.Name.." -> "..f[1].key) end end
  local s=gui.Root:FindFirstChild("StatusBar",true) if s then local l=s:FindFirstChild("Cmd") if l then l.Text=fr.Name.." ✓" end end
 end)
end
for _,b in ipairs(gui:GetDescendants()) do if b:IsA("TextButton") and b.Name=="Btn" then pcall(hook,b) end end
print("[V1.31] UI PC legível + Explorer/Properties exatos 1ª print + FlyCamera EXATO")
"""
                    folder.add(Inst("LocalScript","ARKHER_Global_31",{"Source":(T_STRING, GF)}))
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
    out=os.path.join(REL,"ARKHER_STUDIO_1_GENESIS_EDITION_V1_31.rbxl")
    write(out, serialize(roots))
    print(f"V1.31 FIX {out} ({os.path.getsize(out)/1048576:.2f} MB)")
    subprocess.run(["python3","tools/validate_rbxm.py",out], cwd=ROOT)
    from build_complete import arkher_installer_folder
    write(os.path.join(REL,"ARKHER_STUDIO_1_GENESIS_EDITION_V1_31.rbxm"), serialize([arkher_installer_folder()]))
    print("rbxm V1.31 done")
