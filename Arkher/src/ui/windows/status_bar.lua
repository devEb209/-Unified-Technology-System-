--!strict
local Theme=require(script.Parent.Parent.Parent.core.theme)
local StatusBar={}
StatusBar.__index=StatusBar
function StatusBar.new(parent: Instance)
	local bar=Instance.new("Frame")
	bar.Name="ARKHER_Status"
	bar.Size=UDim2.new(1,0,0,22)
	bar.Position=UDim2.new(0,0,1,-22)
	bar.BackgroundColor3=Theme.tokens.slate900
	bar.BorderSizePixel=0
	bar.ZIndex=20
	bar.Parent=parent
	local line=Instance.new("Frame"); line.Size=UDim2.new(1,0,0,1); line.BackgroundColor3=Theme.roles.border; line.BorderSizePixel=0; line.Parent=bar
	local lbl=Instance.new("TextLabel")
	lbl.Name="Label"
	lbl.Size=UDim2.new(1,-16,1,0)
	lbl.Position=UDim2.fromOffset(8,0)
	lbl.BackgroundTransparency=1
	lbl.Text="ARKHER V2  •  Ready  •  Explorer ↔ Properties live  •  Ctrl+Z undo  •  Fly: RMB+WASD"
	lbl.Font=Enum.Font.Gotham
	lbl.TextSize=11
	lbl.TextColor3=Theme.tokens.slate400
	lbl.TextXAlignment=Enum.TextXAlignment.Left
	lbl.Parent=bar
	return setmetatable({Root=bar, Label=lbl}, StatusBar)
end
function StatusBar:SetText(t:string) self.Label.Text=t end
return StatusBar
