--!strict
-- Modeler — inspired by 3ds Max Modifier Stack + Blender/Maya
-- Left: Modifier Stack (light-bulb eye, pin, reorder, collapse), Right: Parameters, Bottom: Tool shelf
local Theme=require(script.Parent.Parent.core.theme)
local Config=require(script.Parent.Parent.core.config)
local BaseWindow=require(script.Parent.Parent.ui.windows.base_window)
local Components=require(script.Parent.Parent.ui.components.init)

local Modeler={}
Modeler.__index=Modeler

function Modeler.new(parent: Instance)
	local win=BaseWindow.new({title="Modeler  —  Modifier Stack", size=Vector2.new(720, 480), pos=UDim2.fromOffset(180, 140), parent=parent, icon="⬢"})
	win.Root.Name="ARKHER_Modeler"
	win.Root.Visible=false
	local content=win.Content
	content.BackgroundColor3=Theme.tokens.void

	-- Top tool shelf (QWER + primitive)
	local shelf=Instance.new("Frame")
	shelf.Size=UDim2.new(1,0,0,32)
	shelf.BackgroundColor3=Theme.tokens.slate900
	shelf.BorderSizePixel=0
	shelf.Parent=content
	local sl=Instance.new("UIListLayout"); sl.FillDirection=Enum.FillDirection.Horizontal; sl.Padding=UDim.new(0,6); sl.VerticalAlignment=Enum.VerticalAlignment.Center; sl.Parent=shelf
	local pad=Instance.new("UIPadding"); pad.PaddingLeft=UDim.new(0,8); pad.Parent=shelf
	for _,lbl in {"Select","Move","Rotate","Scale","Extrude","Bevel","LoopCut"} do
		local b=Instance.new("TextButton"); b.Size=UDim2.fromOffset(78,22); b.BackgroundColor3=Theme.tokens.slate800; b.Text=lbl; b.Font=Enum.Font.Gotham; b.TextSize=11; b.TextColor3=Theme.tokens.slate200; b.Parent=shelf; local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,6); c.Parent=b
	end

	-- Three columns
	local cols=Instance.new("Frame")
	cols.Size=UDim2.new(1,0,1,-32)
	cols.Position=UDim2.fromOffset(0,32)
	cols.BackgroundTransparency=1
	cols.Parent=content

	local stack=Instance.new("ScrollingFrame")
	stack.Name="Stack"
	stack.Size=UDim2.new(0,200,1,0)
	stack.BackgroundColor3=Theme.tokens.slate900
	stack.BorderSizePixel=0
	stack.ScrollBarThickness=6
	stack.CanvasSize=UDim2.new(0,0,0,0); stack.AutomaticCanvasSize=Enum.AutomaticSize.Y
	stack.Parent=cols
	local pl=Instance.new("UIListLayout"); pl.Padding=UDim.new(0,2); pl.Parent=stack
	local pp=Instance.new("UIPadding"); pp.PaddingTop=UDim.new(0,6); pp.PaddingLeft=UDim.new(0,6); pp.PaddingRight=UDim.new(0,6); pp.Parent=stack
	local title=Instance.new("TextLabel"); title.Size=UDim2.new(1,0,0,18); title.BackgroundTransparency=1; title.Text="Modifier Stack"; title.Font=Enum.Font.GothamBold; title.TextSize=11; title.TextColor3=Theme.tokens.arkherBlue; title.TextXAlignment=Enum.TextXAlignment.Left; title.Parent=stack

	local mods={"Base Mesh","Mirror","Subdivision 2","Bevel 0.02","Solidify","Array X3","Bend 15°"}
	for i, name in mods do
		local row=Instance.new("Frame"); row.Size=UDim2.new(1,0,0,26); row.BackgroundColor3= if i==1 then Theme.tokens.slate800 else Color3.fromRGB(28,42,78); row.BorderSizePixel=0; row.Parent=stack; local cc=Instance.new("UICorner"); cc.CornerRadius=UDim.new(0,6); cc.Parent=row
		local eye=Instance.new("TextButton"); eye.Size=UDim2.fromOffset(22,18); eye.Position=UDim2.fromOffset(4,4); eye.BackgroundColor3=Theme.tokens.slate700; eye.Text="◉"; eye.Font=Enum.Font.Gotham; eye.TextSize=10; eye.TextColor3=Theme.tokens.arkherBlue; eye.Parent=row; local ec=Instance.new("UICorner"); ec.CornerRadius=UDim.new(0,4); ec.Parent=eye
		local lbl=Instance.new("TextLabel"); lbl.Size=UDim2.new(1,-60,1,0); lbl.Position=UDim2.fromOffset(30,0); lbl.BackgroundTransparency=1; lbl.Text=name; lbl.Font=Enum.Font.Gotham; lbl.TextSize=11; lbl.TextColor3=Theme.tokens.white; lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.Parent=row
		local pin=Instance.new("TextLabel"); pin.Size=UDim2.fromOffset(16,16); pin.Position=UDim2.new(1,-20,0.5,-8); pin.BackgroundTransparency=1; pin.Text="📌"; pin.TextSize=10; pin.Parent=row
	end
	local addBtn=Instance.new("TextButton"); addBtn.Size=UDim2.new(1,0,0,26); addBtn.BackgroundColor3=Theme.tokens.arkherBlue; addBtn.Text="+ Add Modifier  ▾"; addBtn.Font=Enum.Font.GothamBold; addBtn.TextSize=11; addBtn.TextColor3=Color3.fromRGB(14,20,48); addBtn.Parent=stack; local ac=Instance.new("UICorner"); ac.CornerRadius=UDim.new(0,6); ac.Parent=addBtn

	local center=Instance.new("Frame")
	center.Size=UDim2.new(1,-440,1,0)
	center.Position=UDim2.fromOffset(200,0)
	center.BackgroundColor3=Color3.fromRGB(16,22,52)
	center.BorderSizePixel=0
	center.Parent=cols
	local hint=Instance.new("TextLabel"); hint.Size=UDim2.fromScale(1,1); hint.BackgroundTransparency=1; hint.Text="Viewport is the real Studio viewport — no fake frame.\nGizmos + fly handle the 3D view. Stack edits the selected mesh."; hint.Font=Enum.Font.Gotham; hint.TextSize=11; hint.TextColor3=Theme.tokens.slate400; hint.TextWrapped=true; hint.Parent=center

	local params=Instance.new("ScrollingFrame")
	params.Size=UDim2.new(0,240,1,0)
	params.Position=UDim2.new(1,-240,0,0)
	params.BackgroundColor3=Theme.tokens.slate800
	params.BorderSizePixel=0
	params.ScrollBarThickness=6
	params.CanvasSize=UDim2.new(0,0,0,0); params.AutomaticCanvasSize=Enum.AutomaticSize.Y
	params.Parent=cols
	local prl=Instance.new("UIListLayout"); prl.Padding=UDim.new(0,8); prl.Parent=params
	local prp=Instance.new("UIPadding"); prp.PaddingLeft=UDim.new(0,8); prp.PaddingRight=UDim.new(0,8); prp.PaddingTop=UDim.new(0,8); prp.Parent=params
	local pt=Instance.new("TextLabel"); pt.Size=UDim2.new(1,0,0,18); pt.BackgroundTransparency=1; pt.Text="Bevel  —  Parameters"; pt.Font=Enum.Font.GothamBold; pt.TextSize=11; pt.TextColor3=Theme.tokens.white; pt.TextXAlignment=Enum.TextXAlignment.Left; pt.Parent=params
	-- functional sliders that affect selection via attribute
	Components.Slider(params, "Width", 0, 0.1, 0.02, function(v) 
		local sel=game:GetService("Selection"):Get()[1]
		if sel then sel:SetAttribute("ARKHER_BevelWidth", v) end
	end)
	Components.Slider(params, "Segments", 1, 6, 2, function(v) 
		local sel=game:GetService("Selection"):Get()[1]
		if sel then sel:SetAttribute("ARKHER_BevelSeg", math.floor(v)) end
	end)
	Components.Checkbox(params, "Clamp Overlap", true, function(v)
		local sel=game:GetService("Selection"):Get()[1]
		if sel then sel:SetAttribute("ARKHER_BevelClamp", v) end
	end)
	local apply=Components.Button(params, "Apply  (Collapse Stack)", {size=UDim2.new(1,0,0,28), color=Theme.tokens.arkherBlue})
	apply.TextColor3=Color3.fromRGB(14,20,48)

	local self=setmetatable({Win=win}, Modeler)
	return self
end
function Modeler:Toggle() self.Win:Toggle() end
return Modeler
