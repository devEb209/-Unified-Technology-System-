--!strict
local Theme=require(script.Parent.Parent.Parent.core.theme)
local BaseWindow=require(script.Parent.base_window)
local Output={}
Output.__index=Output
function Output.new(parent: Instance)
	local win=BaseWindow.new({title="Output", size=Vector2.new(520,160), pos=UDim2.new(0,320,1,-180), parent=parent, icon="◨"})
	win.Root.Name="ARKHER_Output"
	local content=win.Content
	local scroll=Instance.new("ScrollingFrame")
	scroll.Size=UDim2.new(1,-8,1,-8)
	scroll.Position=UDim2.fromOffset(4,4)
	scroll.BackgroundTransparency=1
	scroll.BorderSizePixel=0
	scroll.ScrollBarThickness=6
	scroll.ScrollBarImageColor3=Theme.tokens.slate600
	scroll.CanvasSize=UDim2.new(0,0,0,0)
	scroll.AutomaticCanvasSize=Enum.AutomaticSize.Y
	scroll.Parent=content
	local layout=Instance.new("UIListLayout"); layout.Padding=UDim.new(0,2); layout.Parent=scroll
	local pad=Instance.new("UIPadding"); pad.PaddingLeft=UDim.new(0,8); pad.PaddingRight=UDim.new(0,8); pad.PaddingTop=UDim.new(0,4); pad.Parent=scroll
	local self=setmetatable({Win=win, Scroll=scroll}, Output)
	function self:Log(text:string, color: Color3?)
		local lbl=Instance.new("TextLabel")
		lbl.Size=UDim2.new(1,0,0,16)
		lbl.AutomaticSize=Enum.AutomaticSize.Y
		lbl.BackgroundTransparency=1
		lbl.Text=text
		lbl.Font=Enum.Font.Code
		lbl.TextSize=11
		lbl.TextColor3=color or Theme.tokens.slate200
		lbl.TextXAlignment=Enum.TextXAlignment.Left
		lbl.TextWrapped=true
		lbl.Parent=scroll
	end
	self:Log("ARKHER Studio V2 — Output ready. Explorer/Properties functional, HistoryService active.", Theme.tokens.arkherGlow)
	return self
end
return Output
