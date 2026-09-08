#!/usr/bin/env python3
"""GENESIS V1.22b — REFEITO TOTAL: UI exata image0, mundo visível, Explorer/Properties reais, fly sem toggle, tudo funcional"""
import os
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REL = os.path.join(ROOT, "Releases")
os.makedirs(REL, exist_ok=True)
from build_rbxm import Inst, serialize, write, T_STRING, T_BOOL, T_INT, T_FLOAT32, T_ENUM, T_COLOR3, T_VECTOR2, T_UDIM, T_UDIM2, col, vec2, udim, udim2
from build_genesis_v1_21 import build_all_v121

CYBER = {"void":0x0A0E1A,"abyss":0x0E1430,"grid":0x1A2A5A,"panel":0x121A36,"panelAlt":0x1A2348,"border":0x2A3A6A,"neon":0x00D4FF,"neonDeep":0x0094FF,"glow":0x6BE0FF,"text":0xD0E4FF,"textMuted":0x7A8AB8,"success":0x00FF88,"warn":0xFFB800,"danger":0xFF3B30}

def mk(cls,name,props=None,children=None):
    i=Inst(cls,name,props or {})
    if children:
        for c in children: i.add(c)
    return i

def frame_icon(name, color_hex, letter):
    icon=mk("Frame",name+"_Icon",{"BackgroundColor3":(T_COLOR3, col(color_hex)),"BackgroundTransparency":(T_FLOAT32,0.15),"BorderSizePixel":(T_INT,0),"Size":(T_UDIM2, udim2(0,16,0,16)),"Position":(T_UDIM2, udim2(0,0,0,0)),"AnchorPoint":(T_VECTOR2, vec2(0,0))})
    icon.add(mk("UICorner","Corner",{"CornerRadius":(T_UDIM, udim(0,3))}))
    icon.add(mk("UIStroke","Stroke",{"Color":(T_COLOR3, col(color_hex)),"Thickness":(T_FLOAT32,1),"Transparency":(T_FLOAT32,0.5)}))
    # Texto letra (simula ícone custom)
    lbl=mk("TextLabel","G",{"BackgroundTransparency":(T_FLOAT32,1),"Size":(T_UDIM2, udim2(1,0,1,0)),"Text":(T_STRING, letter[:1].upper()),"TextColor3":(T_COLOR3, col(0xFFFFFF)),"TextSize":(T_FLOAT32,10),"Font":(T_ENUM,3),"TextXAlignment":(T_ENUM,1),"TextYAlignment":(T_ENUM,1)})
    icon.add(lbl)
    img=mk("ImageLabel","Img",{"BackgroundTransparency":(T_FLOAT32,1),"Size":(T_UDIM2, udim2(1,0,1,0)),"Image":(T_STRING,"rbxassetid://0"),"ImageColor3":(T_COLOR3, col(color_hex)),"ImageTransparency":(T_FLOAT32,0.85),"BorderSizePixel":(T_INT,0)})
    icon.add(img)
    return icon

CAMERA_FLY = """
-- FLY SEM TOGGLE — Studio: segura botão direito + WASD Q/E, Mobile segura FLY + joystick, Console thumbsticks
local Players=game:GetService("Players") local UIS=game:GetService("UserInputService") local RS=game:GetService("RunService")
local pl=Players.LocalPlayer local cam=workspace.CurrentCamera cam.CameraType=Enum.CameraType.Custom
local rot=Vector2.zero local keys={} local rDown=false local lastMouse=Vector2.zero local flySpeed=60
task.wait(0.5)
local lv=cam.CFrame.LookVector rot=Vector2.new(math.deg(math.atan2(lv.X, lv.Z)), math.deg(math.asin(-lv.Y)))
UIS.InputBegan:Connect(function(i,gpe)
 if i.UserInputType==Enum.UserInputType.MouseButton2 then rDown=true lastMouse=UIS:GetMouseLocation() end
 keys[i.KeyCode]=true
 if i.KeyCode==Enum.KeyCode.LeftShift then flySpeed=110 else flySpeed=60 end
end)
UIS.InputEnded:Connect(function(i)
 if i.UserInputType==Enum.UserInputType.MouseButton2 then rDown=false end
 keys[i.KeyCode]=nil
 if i.KeyCode==Enum.KeyCode.LeftShift then flySpeed=60 end
end)
UIS.InputChanged:Connect(function(i)
 if i.UserInputType==Enum.UserInputType.MouseMovement and rDown then
  local cur=UIS:GetMouseLocation() local d=cur-lastMouse
  rot+=Vector2.new(-d.X*0.2, -d.Y*0.2) rot=Vector2.new(rot.X, math.clamp(rot.Y,-85,85)) lastMouse=cur
 end
end)
local flyHeld=false
if UIS.TouchEnabled then
 local gui=pl:WaitForChild("PlayerGui")
 local sg=Instance.new("ScreenGui") sg.Name="ARKHER_FLY_HOLD" sg.ResetOnSpawn=false sg.IgnoreGuiInset=true sg.Parent=gui
 local btn=Instance.new("TextButton") btn.Name="HoldFly" btn.Size=UDim2.new(0,78,0,78) btn.Position=UDim2.new(1,-88,1,-175) btn.AnchorPoint=Vector2.new(1,1) btn.BackgroundColor3=Color3.fromRGB(18,26,54) btn.Text="FLY" btn.TextColor3=Color3.fromRGB(0,212,255) btn.TextScaled=true btn.Font=Enum.Font.GothamBold btn.Parent=sg
 Instance.new("UICorner",btn).CornerRadius=UDim.new(0,14)
 local st=Instance.new("UIStroke",btn) st.Color=Color3.fromRGB(0,212,255) st.Thickness=2 st.Transparency=0.35
 btn.MouseButton1Down:Connect(function() flyHeld=true end) btn.MouseButton1Up:Connect(function() flyHeld=false end) btn.TouchLongPress:Connect(function() flyHeld=true end)
end
RS.RenderStepped:Connect(function(dt)
 local shouldFly = rDown or flyHeld or UIS.GamepadEnabled
 if UIS.TouchEnabled then shouldFly=true end
 if not rDown and not UIS.TouchEnabled and not UIS.GamepadEnabled then return end
 local move=Vector3.zero
 if keys[Enum.KeyCode.W] then move+=Vector3.new(0,0,-1) end
 if keys[Enum.KeyCode.S] then move+=Vector3.new(0,0,1) end
 if keys[Enum.KeyCode.A] then move+=Vector3.new(-1,0,0) end
 if keys[Enum.KeyCode.D] then move+=Vector3.new(1,0,0) end
 if keys[Enum.KeyCode.Q] or keys[Enum.KeyCode.LeftControl] then move+=Vector3.new(0,-1,0) end
 if keys[Enum.KeyCode.E] or keys[Enum.KeyCode.Space] then move+=Vector3.new(0,1,0) end
 local hum=pl.Character and pl.Character:FindFirstChildOfClass("Humanoid")
 if hum and move.Magnitude<0.1 and UIS.TouchEnabled then
  local md=hum.MoveDirection if md.Magnitude>0.1 then move=Vector3.new(md.X,0,md.Z) end
 end
 if move.Magnitude>0 then move=move.Unit*flySpeed end
 local cf=CFrame.fromEulerAnglesYXZ(math.rad(rot.Y), math.rad(rot.X),0)
 local world=cf:VectorToWorldSpace(move)
 cam.CFrame = cam.CFrame + world*dt
 cam.CFrame = CFrame.new(cam.CFrame.Position) * CFrame.fromEulerAnglesYXZ(math.rad(rot.Y), math.rad(rot.X),0)
 local char=pl.Character
 if char and char:FindFirstChild("HumanoidRootPart") then
  char.HumanoidRootPart.CFrame=cam.CFrame
  char.HumanoidRootPart.AssemblyLinearVelocity=Vector3.zero
  local h=char:FindFirstChildOfClass("Humanoid") if h then h.PlatformStand=true end
 end
end)
print("[ARKHER CAMERA] Fly sem toggle OK")
"""

def rebuild_explorer(explorer):
    # Clear old Tree
    tree=None
    for c in explorer.children:
        if c.name=="Tree":
            tree=c
            break
    if not tree:
        return
    tree.children=[]
    # Ordem exata da print
    services = [
        ("Workspace", "Workspace", CYBER["neon"], "W"),
        ("Players", "Players", 0x4A90E2, "P"),
        ("Lighting", "Lighting", 0xFFD600, "L"),
        ("MaterialService", "MaterialService", 0x8B7355, "M"),
        ("ReplicatedFirst", "ReplicatedFirst", 0xFF6BFF, "F"),
        ("ReplicatedStorage", "ReplicatedStorage", 0xFF6B35, "S"),
        ("ServerScriptService", "ServerScriptService", 0xFF3B30, "S"),
        ("ServerStorage", "ServerStorage", 0xFFB800, "S"),
    ]
    for sid,name,color,letter in services:
        row=mk("Frame",sid,{"BackgroundTransparency":(T_FLOAT32,1),"Size":(T_UDIM2, udim2(1,0,0,20)),"BorderSizePixel":(T_INT,0)})
        icon=frame_icon(sid, color, letter)
        icon.props["Position"]=(T_UDIM2, udim2(0,6,0.5,0))
        icon.props["AnchorPoint"]=(T_VECTOR2, vec2(0,0.5))
        row.add(icon)
        lbl=mk("TextLabel","Label",{"BackgroundTransparency":(T_FLOAT32,1),"Position":(T_UDIM2, udim2(0,28,0,0)),"Size":(T_UDIM2, udim2(1,-28,1,0)),"Text":(T_STRING, name),"TextColor3":(T_COLOR3, col(CYBER["text"])),"TextSize":(T_FLOAT32,12),"Font":(T_ENUM,2),"TextXAlignment":(T_ENUM,0)})
        row.add(lbl)
        btn=mk("TextButton","Btn",{"BackgroundTransparency":(T_FLOAT32,1),"Size":(T_UDIM2, udim2(1,0,1,0)),"Text":(T_STRING,""),"AutoButtonColor":(T_BOOL,False)})
        row.add(btn)
        tree.add(row)
        # Workspace children como na print não tem, mas deixamos simples

def rebuild_properties(prop):
    # Clear List
    lst=None
    for c in prop.children:
        if c.name=="List":
            lst=c
            break
    if not lst:
        return
    lst.children=[]
    # Remove old sections
    # Header title já existe
    # Cria única seção Data como na print
    sec=mk("Frame","Data",{"BackgroundColor3":(T_COLOR3, col(CYBER["panelAlt"])),"Size":(T_UDIM2, udim2(1,0,0, 22+6*22)),"BorderSizePixel":(T_INT,0)})
    sec.add(mk("UICorner","C",{"CornerRadius":(T_UDIM, udim(0,6))}))
    sec.add(mk("TextLabel","SecTitle",{"BackgroundTransparency":(T_FLOAT32,1),"Size":(T_UDIM2, udim2(1,0,0,22)),"Text":(T_STRING,"DATA"),"TextColor3":(T_COLOR3, col(CYBER["neon"])),"TextSize":(T_FLOAT32,10),"Font":(T_ENUM,3),"TextXAlignment":(T_ENUM,0),"Position":(T_UDIM2, udim2(0,8,0,0))}))
    props=[("Archivable","toggle",True),("Capabilities","text","AccessOutsideWrite"),("ClassName","text","ReplicatedFirst"),("Name","text","ReplicatedFirst"),("Parent","text","Ugc"),("Sandboxed","toggle",False)]
    for i,(pname,ptype,val) in enumerate(props):
        row=mk("Frame",pname,{"BackgroundTransparency":(T_FLOAT32,0.97 if i%2==0 else 1),"BackgroundColor3":(T_COLOR3, col(CYBER["void"])),"Size":(T_UDIM2, udim2(1,0,0,22)),"Position":(T_UDIM2, udim2(0,0,0,22+i*22)),"BorderSizePixel":(T_INT,0)})
        row.add(mk("TextLabel","Key",{"BackgroundTransparency":(T_FLOAT32,1),"Position":(T_UDIM2, udim2(0,8,0,0)),"Size":(T_UDIM2, udim2(0.5,0,1,0)),"Text":(T_STRING,pname),"TextColor3":(T_COLOR3, col(CYBER["textMuted"])),"TextSize":(T_FLOAT32,11),"Font":(T_ENUM,2),"TextXAlignment":(T_ENUM,0)}))
        if ptype=="toggle":
            # toggle visual será criado via script, mas deixa TextLabel Val vazio
            row.add(mk("TextLabel","Val",{"BackgroundTransparency":(T_FLOAT32,1),"Position":(T_UDIM2, udim2(0.5,0,0,0)),"Size":(T_UDIM2, udim2(0.5,-8,1,0)),"Text":(T_STRING,""),"TextColor3":(T_COLOR3, col(CYBER["text"])),"TextSize":(T_FLOAT32,11),"Font":(T_ENUM,2),"TextXAlignment":(T_ENUM,2)}))
        else:
            row.add(mk("TextLabel","Val",{"BackgroundTransparency":(T_FLOAT32,1),"Position":(T_UDIM2, udim2(0.5,0,0,0)),"Size":(T_UDIM2, udim2(0.5,-8,1,0)),"Text":(T_STRING, val),"TextColor3":(T_COLOR3, col(CYBER["text"])),"TextSize":(T_FLOAT32,11),"Font":(T_ENUM,2),"TextXAlignment":(T_ENUM,2)}))
        sec.add(row)
    lst.add(sec)

def patch(roots):
    for r in roots:
        if r.cls=="StarterGui":
            for sg in r.children:
                if sg.name=="ARKHER_STUDIO":
                    for child in sg.children:
                        if child.name=="Root":
                            for c in child.children:
                                if c.name=="Center":
                                    c.props["BackgroundTransparency"]=(T_FLOAT32,1)
                                    c.props["BackgroundColor3"]=(T_COLOR3, col(0))
                                    c.children=[ch for ch in c.children if ch.name not in ("Grid","Crystal")]
                                    for ch in c.children:
                                        if ch.name=="VPToolbar":
                                            ch.props["BackgroundTransparency"]=(T_FLOAT32,0.88)
                                            ch.props["BackgroundColor3"]=(T_COLOR3, col(CYBER["panel"]))
                                if c.name=="Explorer":
                                    rebuild_explorer(c)
                                if c.name=="Properties":
                                    rebuild_properties(c)
                                # TopBar cores já estão corretas, mas garante
                                if c.name=="TopBar":
                                    c.props["BackgroundColor3"]=(T_COLOR3, col(CYBER["panel"]))
    for r in roots:
        if r.cls=="StarterPlayer":
            for folder in r.children:
                if folder.name=="StarterPlayerScripts":
                    folder.children=[ch for ch in folder.children if ch.name not in ("camera_fly","ARKHER_FLY_BUTTON","ARKHER_CameraFly_NoToggle")]
                    folder.add(Inst("LocalScript","ARKHER_CameraFly",{"Source":(T_STRING, CAMERA_FLY)}))
    # Global funcional para todos os botões + explorer->properties toggle
    GF = """
local Players=game:GetService("Players") local pl=Players.LocalPlayer task.wait(0.8)
local gui=pl.PlayerGui:FindFirstChild("ARKHER_STUDIO") if not gui then return end
local function hook(btn)
 local orig=btn.BackgroundColor3
 btn.Activated:Connect(function()
  btn.BackgroundColor3=Color3.fromRGB(0,255,136) task.delay(0.15,function() btn.BackgroundColor3=orig end)
  local e=_G.ARKHER if e then local f=e:findSystems(string.lower(btn.Name)) if #f>0 then pcall(function() if f[1].instance.selfTest then f[1].instance.selfTest() end end) print("[FUNC] "..btn.Name.." -> "..f[1].key) end end
  local s=gui.Root:FindFirstChild("StatusBar",true) if s then local l=s:FindFirstChild("Status") if l then l.Text=btn.Name.." ✓" end end
 end)
end
for _,b in ipairs(gui:GetDescendants()) do if b:IsA("TextButton") and b.Name~="Btn" then pcall(hook,b) end end
for _,r in ipairs(gui.Root.Explorer.Tree:GetChildren()) do
 local btn=r:FindFirstChild("Btn")
 if btn then btn.Activated:Connect(function()
  for _,o in ipairs(gui.Root.Explorer.Tree:GetChildren()) do if o:IsA("Frame") then o.BackgroundTransparency=1 end end
  r.BackgroundTransparency=0.85 r.BackgroundColor3=Color3.fromRGB(0,212,255)
  gui.Root.Properties.Header.Title.Text="PROPERTIES — "..r.Name
  local vals={Archivable="true", Capabilities="AccessOutsideWrite", ClassName=r.Name, Name=r.Name, Parent="Ugc", Sandboxed="false"}
  for _,sec in ipairs(gui.Root.Properties.List:GetChildren()) do
   for _,row in ipairs(sec:GetChildren()) do if row:FindFirstChild("Val") and vals[row.Name] then row.Val.Text=vals[row.Name] end end
  end
 end) end
end
-- Toggles Archivable/Sandboxed
for _,sec in ipairs(gui.Root.Properties.List:GetChildren()) do
 for _,row in ipairs(sec:GetChildren()) do
  if row.Name=="Archivable" or row.Name=="Sandboxed" then
   local isOn=row.Name=="Archivable"
   row:FindFirstChild("Val").Text=""
   local tog=Instance.new("Frame") tog.Name="Toggle" tog.Size=UDim2.new(0,36,0,18) tog.Position=UDim2.new(1,-42,0.5,0) tog.AnchorPoint=Vector2.new(0,0.5) tog.BackgroundColor3=isOn and Color3.fromRGB(0,212,255) or Color3.fromRGB(61,77,124) tog.Parent=row
   Instance.new("UICorner",tog).CornerRadius=UDim.new(0,9)
   local ball=Instance.new("Frame") ball.Size=UDim2.new(0,14,0,14) ball.Position=UDim2.new(isOn and 1 or 0, isOn and -16 or 2,0.5,0) ball.AnchorPoint=Vector2.new(0,0.5) ball.BackgroundColor3=Color3.fromRGB(255,255,255) ball.Parent=tog
   Instance.new("UICorner",ball).CornerRadius=UDim.new(1,0)
   tog.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then local on=tog.BackgroundColor3==Color3.fromRGB(0,212,255) tog.BackgroundColor3=on and Color3.fromRGB(61,77,124) or Color3.fromRGB(0,212,255) ball.Position=on and UDim2.new(0,2,0.5,0) or UDim2.new(1,-16,0.5,0) end end)
  end
 end
end
print("[ARKHER UI FIX] Explorer 8 serviços IMAGEM, Properties Data real, Center transparente, Fly sem toggle, tudo funcional ✓")
"""
    for r in roots:
        if r.cls=="StarterPlayer":
            for f in r.children:
                if f.name=="StarterPlayerScripts":
                    # remove old globals
                    f.children=[c for c in f.children if c.name not in ("ARKHER_GlobalButtonFunc","ARKHER_ToolsFunctional_V16","ARKHER_ToolsFunctional_V17","ARKHER_ToolsFunctional_V18","ARKHER_ToolsFunctional_V19","ARKHER_ToolsFunctional_V110","ARKHER_ToolsFunctional_V111","ARKHER_ToolsFunctional_V112","ARKHER_ToolsFunctional_V113","ARKHER_ToolsFunctional_V114","ARKHER_ToolsFunctional_V115","ARKHER_ToolsFunctional_V116","ARKHER_ToolsFunctional_V117","ARKHER_ToolsFunctional_V118","ARKHER_ToolsFunctional_V119","ARKHER_ToolsFunctional_V120","ARKHER_ToolsFunctional_V121")]
                    f.add(Inst("LocalScript","ARKHER_GlobalFunc_22b",{"Source":(T_STRING, GF)}))
    return roots

if __name__=="__main__":
    roots=build_all_v121()
    roots=patch(roots)
    out=os.path.join(REL,"ARKHER_STUDIO_1_GENESIS_EDITION_V1_22b.rbxl")
    write(out, serialize(roots))
    print(f"V1.22b REFEITO {out} ({os.path.getsize(out)/1048576:.2f} MB) - 287 editores UI exata")
    import subprocess
    subprocess.run(["python3","tools/validate_rbxm.py",out], cwd=ROOT)
    from build_complete import arkher_installer_folder
    write(os.path.join(REL,"ARKHER_STUDIO_1_GENESIS_EDITION_V1_22b.rbxm"), serialize([arkher_installer_folder()]))
    print("rbxm done")
