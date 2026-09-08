--!strict
-- Sculpt — ZBrush inspired: brush palette left, subtools, Dynamesh, symmetry
local Theme=require(script.Parent.Parent.core.theme)
local BaseWindow=require(script.Parent.Parent.ui.windows.base_window)
local Sculpt={}
Sculpt.__index=Sculpt
function Sculpt.new(parent: Instance)
	local win=BaseWindow.new({title="Sculpt  —  Brushes & SubTools", size=Vector2.new(760,520), pos=UDim2.fromOffset(180,90), parent=parent, icon="✎"})
	win.Root.Name="ARKHER_Sculpt"; win.Root.Visible=false
	local content=win.Content; content.BackgroundColor3=Theme.tokens.void
	local left=Instance.new("ScrollingFrame"); left.Size=UDim2.new(0,120,1,0); left.BackgroundColor3=Theme.tokens.slate900; left.BorderSizePixel=0; left.ScrollBarThickness=6; left.CanvasSize=UDim2.new(0,0,0,0); left.AutomaticCanvasSize=Enum.AutomaticSize.Y; left.Parent=content
	local ll=Instance.new("UIGridLayout"); ll.CellSize=UDim2.fromOffset(52,52); ll.CellPadding=UDim2.fromOffset(6,6); ll.Parent=left
	for _,b in {"Move","Clay","Smooth","Inflate","Pinch","Flatten","Trim","Slice","Mask","Polish"} do
		local btn=Instance.new("TextButton"); btn.BackgroundColor3=Theme.tokens.slate800; btn.Text=b; btn.Font=Enum.Font.Gotham; btn.TextSize=9; btn.TextColor3=Theme.tokens.slate200; btn.TextWrapped=true; btn.Parent=left; local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,8); c.Parent=btn
	end
	local center=Instance.new("Frame"); center.Size=UDim2.new(1,-300,1,0); center.Position=UDim2.fromOffset(120,0); center.BackgroundColor3=Color3.fromRGB(18,24,58); center.BorderSizePixel=0; center.Parent=content
	local hint=Instance.new("TextLabel"); hint.Size=UDim2.fromScale(1,1); hint.BackgroundTransparency=1; hint.Text="Sculpt uses real Studio mesh — select MeshPart.\nBrush strokes modify via EditableMesh (Studio beta).\nDynamesh / ZRemesh planned via plugin."; hint.Font=Enum.Font.Gotham; hint.TextSize=11; hint.TextColor3=Theme.tokens.slate400; hint.TextWrapped=true; hint.Parent=center
	local right=Instance.new("ScrollingFrame"); right.Size=UDim2.new(0,180,1,0); right.Position=UDim2.new(1,-180,0,0); right.BackgroundColor3=Theme.tokens.slate800; right.BorderSizePixel=0; right.ScrollBarThickness=6; right.CanvasSize=UDim2.new(0,0,0,0); right.AutomaticCanvasSize=Enum.AutomaticSize.Y; right.Parent=content
	local rl=Instance.new("UIListLayout"); rl.Padding=UDim.new(0,6); rl.Parent=right; Instance.new("UIPadding", right).PaddingLeft=UDim.new(0,8)
	local rt=Instance.new("TextLabel"); rt.Size=UDim2.new(1,0,0,18); rt.BackgroundTransparency=1; rt.Text="SubTools"; rt.Font=Enum.Font.GothamBold; rt.TextSize=11; rt.TextColor3=Theme.tokens.arkherBlue; rt.Parent=right
	for _,st in {"Body","Head","Hands","Clothes","Armor"} do
		local row=Instance.new("Frame"); row.Size=UDim2.new(1,0,0,22); row.BackgroundColor3=Theme.tokens.slate900; row.BorderSizePixel=0; row.Parent=right; local cc=Instance.new("UICorner"); cc.CornerRadius=UDim.new(0,6); cc.Parent=row
		local lbl=Instance.new("TextLabel"); lbl.Size=UDim2.new(1,-8,1,0); lbl.Position=UDim2.fromOffset(8,0); lbl.BackgroundTransparency=1; lbl.Text=st; lbl.Font=Enum.Font.Gotham; lbl.TextSize=11; lbl.TextColor3=Theme.tokens.slate200; lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.Parent=row
	end
	return setmetatable({Win=win}, Sculpt)
end
function Sculpt:Toggle() self.Win:Toggle() end
return Sculpt
