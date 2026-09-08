--!strict
-- VFX — Nuke/Houdini style node graph + particle preview
local Theme=require(script.Parent.Parent.core.theme)
local BaseWindow=require(script.Parent.Parent.ui.windows.base_window)
local Components=require(script.Parent.Parent.ui.components.init)
local VFX={}
VFX.__index=VFX
function VFX.new(parent: Instance)
	local win=BaseWindow.new({title="VFX  —  Particles & Compositing", size=Vector2.new(820,520), pos=UDim2.fromOffset(160,100), parent=parent, icon="✦"})
	win.Root.Name="ARKHER_VFX"; win.Root.Visible=false
	local content=win.Content; content.BackgroundColor3=Theme.tokens.void
	local graph=Instance.new("Frame"); graph.Size=UDim2.new(1,-200,1,-36); graph.BackgroundColor3=Color3.fromRGB(14,20,48); graph.BorderSizePixel=0; graph.Parent=content
	local function n(pos: Vector2, name:string, col:Color3)
		local f=Instance.new("Frame"); f.Size=UDim2.fromOffset(100,48); f.Position=UDim2.fromOffset(pos.X,pos.Y); f.BackgroundColor3=Theme.tokens.slate800; f.BorderSizePixel=0; f.Parent=graph; local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,8); c.Parent=f; local s=Instance.new("UIStroke"); s.Color=col; s.Thickness=1.5; s.Parent=f
		local t=Instance.new("TextLabel"); t.Size=UDim2.new(1,0,0,14); t.BackgroundColor3=col; t.Text=name; t.Font=Enum.Font.GothamBold; t.TextSize=9; t.TextColor3=Color3.new(1,1,1); t.Parent=f; local tc=Instance.new("UICorner"); tc.CornerRadius=UDim.new(0,8); tc.Parent=t
		return f
	end
	n(Vector2.new(20,30),"Emit",Theme.tokens.amber); n(Vector2.new(140,60),"Velocity",Theme.tokens.arkherBlue); n(Vector2.new(260,30),"Turbulence",Theme.tokens.violet); n(Vector2.new(380,60),"Render",Theme.tokens.aurora)
	local right=Instance.new("Frame"); right.Size=UDim2.new(0,200,1,-36); right.Position=UDim2.new(1,-200,0,0); right.BackgroundColor3=Theme.tokens.slate800; right.BorderSizePixel=0; right.Parent=content
	local prev=Instance.new("Frame"); prev.Size=UDim2.new(1,-12,0,140); prev.Position=UDim2.fromOffset(6,6); prev.BackgroundColor3=Color3.fromRGB(10,16,40); prev.BorderSizePixel=0; prev.Parent=right; local pc=Instance.new("UICorner"); pc.CornerRadius=UDim.new(0,8); pc.Parent=prev
	local plbl=Instance.new("TextLabel"); plbl.Size=UDim2.new(1,0,0,14); plbl.BackgroundTransparency=1; plbl.Text="Preview  •  GPU"; plbl.Font=Enum.Font.Gotham; plbl.TextSize=10; plbl.TextColor3=Theme.tokens.slate400; plbl.Parent=prev
	for i=1,12 do local p=Instance.new("Frame"); p.Size=UDim2.fromOffset(4,4); p.Position=UDim2.fromOffset(math.random(10,160), math.random(20,110)); p.BackgroundColor3=Theme.tokens.arkherBlue; p.BorderSizePixel=0; p.Parent=prev; local cc=Instance.new("UICorner"); cc.CornerRadius=UDim.new(1,0); cc.Parent=p end
	local props=Instance.new("ScrollingFrame"); props.Size=UDim2.new(1,-8,1,-154); props.Position=UDim2.fromOffset(4,154); props.BackgroundTransparency=1; props.BorderSizePixel=0; props.ScrollBarThickness=6; props.CanvasSize=UDim2.new(0,0,0,0); props.AutomaticCanvasSize=Enum.AutomaticSize.Y; props.Parent=right
	local prl=Instance.new("UIListLayout"); prl.Padding=UDim.new(0,6); prl.Parent=props
	Components.Slider(props,"Rate",0,5000,800,function() end)
	Components.Slider(props,"Lifetime",0,5,1.2,function() end)
	Components.ColorField(props,"Color",Color3.fromRGB(0,212,255),function() end)
	local bottom=Instance.new("Frame"); bottom.Size=UDim2.new(1,0,0,36); bottom.Position=UDim2.new(0,0,1,-36); bottom.BackgroundColor3=Theme.tokens.slate900; bottom.BorderSizePixel=0; bottom.Parent=content
	local bl=Instance.new("UIListLayout"); bl.FillDirection=Enum.FillDirection.Horizontal; bl.Padding=UDim.new(0,8); bl.VerticalAlignment=Enum.VerticalAlignment.Center; bl.Parent=bottom; Instance.new("UIPadding", bottom).PaddingLeft=UDim.new(0,8)
	for _,lbl in {"Play","Cache","Bake"} do local b=Instance.new("TextButton"); b.Size=UDim2.fromOffset(70,22); b.BackgroundColor3=Theme.tokens.slate800; b.Text=lbl; b.Font=Enum.Font.Gotham; b.TextSize=11; b.TextColor3=Theme.tokens.slate200; b.Parent=bottom; local bc=Instance.new("UICorner"); bc.CornerRadius=UDim.new(0,6); bc.Parent=b end
	return setmetatable({Win=win}, VFX)
end
function VFX:Toggle() self.Win:Toggle() end
return VFX
