--!strict
-- Animator — NOT a square. Cascadeur/Mixamo/Rokoko inspired:
-- Left: Rig tree (spine/arms/legs with hierarchy + visibility), Center: Timeline with dopesheet + onion skin, Right: Curve editor, Bottom: Playback bar
local Theme=require(script.Parent.Parent.core.theme)
local BaseWindow=require(script.Parent.Parent.ui.windows.base_window)
local Components=require(script.Parent.Parent.ui.components.init)

local Animator={}
Animator.__index=Animator

function Animator.new(parent: Instance)
	local win=BaseWindow.new({title="Animator  —  Rig & Timeline", size=Vector2.new(820, 520), pos=UDim2.fromOffset(120, 100), parent=parent, icon="◐"})
	win.Root.Name="ARKHER_Animator"
	win.Root.Visible=false
	local content=win.Content
	content.BackgroundColor3=Theme.tokens.void

	-- Playback bar
	local play=Instance.new("Frame")
	play.Size=UDim2.new(1,0,0,32)
	play.BackgroundColor3=Theme.tokens.slate900
	play.BorderSizePixel=0
	play.Parent=content
	local pl=Instance.new("UIListLayout"); pl.FillDirection=Enum.FillDirection.Horizontal; pl.Padding=UDim.new(0,8); pl.VerticalAlignment=Enum.VerticalAlignment.Center; pl.Parent=play
	local pad=Instance.new("UIPadding"); pad.PaddingLeft=UDim.new(0,8); pad.Parent=play
	for _,lbl in {"⏮","⏸","▶","⏭","◉ Rec","Onion"} do
		local b=Instance.new("TextButton"); b.Size=UDim2.fromOffset(52,22); b.BackgroundColor3= if lbl=="▶" then Theme.tokens.arkherBlue else Theme.tokens.slate800; b.Text=lbl; b.Font=Enum.Font.GothamBold; b.TextSize=11; b.TextColor3= if lbl=="▶" then Color3.fromRGB(14,20,48) else Theme.tokens.slate200; b.Parent=play; local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,6); c.Parent=b
	end
	local fps=Instance.new("TextLabel"); fps.Size=UDim2.fromOffset(80,22); fps.BackgroundColor3=Theme.tokens.slate800; fps.Text="24 fps"; fps.Font=Enum.Font.Code; fps.TextSize=11; fps.TextColor3=Theme.tokens.slate400; fps.Parent=play; local cc=Instance.new("UICorner"); cc.CornerRadius=UDim.new(0,6); cc.Parent=fps

	-- Main area
	local main=Instance.new("Frame")
	main.Size=UDim2.new(1,0,1,-32)
	main.Position=UDim2.fromOffset(0,32)
	main.BackgroundTransparency=1
	main.Parent=content

	local rig=Instance.new("ScrollingFrame")
	rig.Size=UDim2.new(0,180,1,-140)
	rig.BackgroundColor3=Theme.tokens.slate900
	rig.BorderSizePixel=0
	rig.ScrollBarThickness=6
	rig.CanvasSize=UDim2.new(0,0,0,0); rig.AutomaticCanvasSize=Enum.AutomaticSize.Y
	rig.Parent=main
	local rl=Instance.new("UIListLayout"); rl.Padding=UDim.new(0,2); rl.Parent=rig
	Instance.new("UIPadding", rig).PaddingTop=UDim.new(0,6)
	local rt=Instance.new("TextLabel"); rt.Size=UDim2.new(1,0,0,18); rt.BackgroundTransparency=1; rt.Text="Rig Tree"; rt.Font=Enum.Font.GothamBold; rt.TextSize=11; rt.TextColor3=Theme.tokens.arkherBlue; rt.TextXAlignment=Enum.TextXAlignment.Left; rt.Parent=rig
	local joints={"Hips","Spine","Chest","Head","L_Arm","L_ForeArm","L_Hand","R_Arm","R_ForeArm","R_Hand","L_UpLeg","L_Leg","L_Foot","R_UpLeg","R_Leg","R_Foot"}
	for _,j in joints do
		local row=Instance.new("Frame"); row.Size=UDim2.new(1,0,0,20); row.BackgroundColor3=Theme.tokens.slate800; row.BorderSizePixel=0; row.Parent=rig; local cc2=Instance.new("UICorner"); cc2.CornerRadius=UDim.new(0,4); cc2.Parent=row
		local dot=Instance.new("Frame"); dot.Size=UDim2.fromOffset(8,8); dot.Position=UDim2.fromOffset(6,6); dot.BackgroundColor3=Theme.tokens.arkherBlue; dot.BorderSizePixel=0; dot.Parent=row; local dc=Instance.new("UICorner"); dc.CornerRadius=UDim.new(1,0); dc.Parent=dot
		local lbl=Instance.new("TextLabel"); lbl.Size=UDim2.new(1,-22,1,0); lbl.Position=UDim2.fromOffset(20,0); lbl.BackgroundTransparency=1; lbl.Text=j; lbl.Font=Enum.Font.Gotham; lbl.TextSize=11; lbl.TextColor3=Theme.tokens.slate200; lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.Parent=row
	end

	-- Dopesheet
	local dope=Instance.new("Frame")
	dope.Size=UDim2.new(1,-360,1,-140)
	dope.Position=UDim2.fromOffset(180,0)
	dope.BackgroundColor3=Color3.fromRGB(20,26,62)
	dope.BorderSizePixel=0
	dope.Parent=main
	local timeRuler=Instance.new("Frame"); timeRuler.Size=UDim2.new(1,0,0,20); timeRuler.BackgroundColor3=Theme.tokens.slate800; timeRuler.BorderSizePixel=0; timeRuler.Parent=dope
	for i=0,24 do
		local tk=Instance.new("TextLabel"); tk.Size=UDim2.fromOffset(32,20); tk.Position=UDim2.fromOffset(i*32,0); tk.BackgroundTransparency=1; tk.Text=tostring(i); tk.Font=Enum.Font.Code; tk.TextSize=10; tk.TextColor3=Theme.tokens.slate400; tk.Parent=timeRuler
	end
	-- key rows
	for r=1,6 do
		local row=Instance.new("Frame"); row.Size=UDim2.new(1,0,0,18); row.Position=UDim2.fromOffset(0, 22 + (r-1)*20); row.BackgroundColor3= if r%2==0 then Color3.fromRGB(26,34,78) else Color3.fromRGB(22,30,70); row.BorderSizePixel=0; row.Parent=dope
		for _,k in {2,5,9,14,18} do
			local key=Instance.new("Frame"); key.Size=UDim2.fromOffset(10,10); key.Position=UDim2.fromOffset(k*32+11,4); key.BackgroundColor3=Theme.tokens.arkherBlue; key.BorderSizePixel=0; key.Rotation=45; key.Parent=row; local kc=Instance.new("UICorner"); kc.CornerRadius=UDim.new(0,2); kc.Parent=key
		end
	end
	-- playhead
	local head=Instance.new("Frame"); head.Size=UDim2.new(0,2,1,0); head.Position=UDim2.fromOffset(9*32,0); head.BackgroundColor3=Theme.tokens.ember; head.BorderSizePixel=0; head.Parent=dope

	-- Curve editor (right)
	local curve=Instance.new("Frame")
	curve.Size=UDim2.new(0,180,1,-140)
	curve.Position=UDim2.new(1,-180,0,0)
	curve.BackgroundColor3=Theme.tokens.slate900
	curve.BorderSizePixel=0
	curve.Parent=main
	local ct=Instance.new("TextLabel"); ct.Size=UDim2.new(1,0,0,20); ct.BackgroundTransparency=1; ct.Text="Graph Editor"; ct.Font=Enum.Font.GothamBold; ct.TextSize=11; ct.TextColor3=Theme.tokens.arkherBlue; ct.TextXAlignment=Enum.TextXAlignment.Left; ct.Parent=curve
	-- fake curve lines
	local graph=Instance.new("Frame"); graph.Size=UDim2.new(1,-16,1,-28); graph.Position=UDim2.fromOffset(8,24); graph.BackgroundColor3=Color3.fromRGB(14,20,48); graph.BorderSizePixel=0; graph.Parent=curve; local gc=Instance.new("UICorner"); gc.CornerRadius=UDim.new(0,6); gc.Parent=graph
	local line=Instance.new("Frame"); line.Size=UDim2.new(1,-20,0,2); line.Position=UDim2.fromOffset(10,40); line.BackgroundColor3=Theme.tokens.arkherBlue; line.Rotation= -8; line.BorderSizePixel=0; line.Parent=graph
	local line2=Instance.new("Frame"); line2.Size=UDim2.new(1,-20,0,2); line2.Position=UDim2.fromOffset(10,70); line2.BackgroundColor3=Theme.tokens.ember; line2.Rotation=5; line2.BorderSizePixel=0; line2.Parent=graph

	-- Bottom: properties for selected key
	local props=Instance.new("Frame")
	props.Size=UDim2.new(1,0,0,140)
	props.Position=UDim2.new(0,0,1,-140)
	props.BackgroundColor3=Theme.tokens.slate800
	props.BorderSizePixel=0
	props.Parent=main
	local prl=Instance.new("UIListLayout"); prl.Padding=UDim.new(0,6); prl.FillDirection=Enum.FillDirection.Horizontal; prl.Parent=props
	Instance.new("UIPadding", props).PaddingLeft=UDim.new(0,8)
	-- left props
	local left=Instance.new("Frame"); left.Size=UDim2.fromOffset(220,132); left.BackgroundTransparency=1; left.Parent=props
	local ll=Instance.new("UIListLayout"); ll.Padding=UDim.new(0,6); ll.Parent=left
	Components.Dropdown(left, "Interpolation", {"Bezier","Linear","Constant"}, "Bezier", function() end)
	Components.Slider(left, "Ease In", 0, 1, 0.3, function() end)
	Components.Slider(left, "Ease Out", 0, 1, 0.7, function() end)

	local mid=Instance.new("Frame"); mid.Size=UDim2.fromOffset(220,132); mid.BackgroundTransparency=1; mid.Parent=props
	local ml=Instance.new("UIListLayout"); ml.Padding=UDim.new(0,6); ml.Parent=mid
	Components.TextField(mid, "Frame", "9", function() end)
	Components.Vector3Field(mid, "Value", Vector3.new(0,0,0), function() end)

	local right=Instance.new("Frame"); right.Size=UDim2.fromOffset(220,132); right.BackgroundTransparency=1; right.Parent=props
	local rll=Instance.new("UIListLayout"); rll.Padding=UDim.new(0,6); rll.Parent=right
	Components.Checkbox(right, "Onion Skin", true, function() end)
	local impBtn=Components.Button(right, "Import Mixamo / Rokoko", {size=UDim2.new(1,0,0,28), color=Theme.tokens.violet}); impBtn.TextColor3=Color3.new(1,1,1)

	local self=setmetatable({Win=win}, Animator)
	return self
end
function Animator:Toggle() self.Win:Toggle() end
return Animator
