--!strict
-- Audio — DaVinci Fairlight + FMOD: mixer strips, buses, effects, waveform
local Theme=require(script.Parent.Parent.core.theme)
local BaseWindow=require(script.Parent.Parent.ui.windows.base_window)
local Components=require(script.Parent.Parent.ui.components.init)
local Audio={}
Audio.__index=Audio
function Audio.new(parent: Instance)
	local win=BaseWindow.new({title="Audio  —  Fairlight Mixer", size=Vector2.new(860,420), pos=UDim2.fromOffset(100,140), parent=parent, icon="♪"})
	win.Root.Name="ARKHER_Audio"; win.Root.Visible=false
	local content=win.Content; content.BackgroundColor3=Theme.tokens.void
	local mixer=Instance.new("Frame"); mixer.Size=UDim2.new(1,0,1,-36); mixer.BackgroundColor3=Theme.tokens.slate900; mixer.BorderSizePixel=0; mixer.Parent=content
	local ml=Instance.new("UIListLayout"); ml.FillDirection=Enum.FillDirection.Horizontal; ml.Padding=UDim.new(0,8); ml.Parent=mixer; Instance.new("UIPadding", mixer).PaddingLeft=UDim.new(0,8)
	for i=1,6 do
		local strip=Instance.new("Frame"); strip.Size=UDim2.new(0,120,1,-16); strip.Position=UDim2.fromOffset(0,8); strip.BackgroundColor3=Theme.tokens.slate800; strip.BorderSizePixel=0; strip.Parent=mixer; local sc=Instance.new("UICorner"); sc.CornerRadius=UDim.new(0,8); sc.Parent=strip
		local lbl=Instance.new("TextLabel"); lbl.Size=UDim2.new(1,0,0,18); lbl.BackgroundColor3=Theme.categoryColor("track"..i); lbl.Text="Track "..i; lbl.Font=Enum.Font.GothamBold; lbl.TextSize=10; lbl.TextColor3=Color3.new(1,1,1); lbl.Parent=strip; local lc=Instance.new("UICorner"); lc.CornerRadius=UDim.new(0,8); lc.Parent=lbl
		local meter=Instance.new("Frame"); meter.Size=UDim2.new(0,16,1,-40); meter.Position=UDim2.fromOffset(8,28); meter.BackgroundColor3=Theme.tokens.slate700; meter.BorderSizePixel=0; meter.Parent=strip; local mc=Instance.new("UICorner"); mc.CornerRadius=UDim.new(0,4); mc.Parent=meter
		local fill=Instance.new("Frame"); fill.Size=UDim2.new(1,0,0.6,0); fill.Position=UDim2.new(0,0,0.4,0); fill.BackgroundColor3=Theme.statusColor("ok"); fill.BorderSizePixel=0; fill.Parent=meter; local fc=Instance.new("UICorner"); fc.CornerRadius=UDim.new(0,4); fc.Parent=fill
		local fader=Instance.new("Frame"); fader.Size=UDim2.fromOffset(40,80); fader.Position=UDim2.new(1,-48,0,28); fader.BackgroundColor3=Theme.tokens.slate700; fader.BorderSizePixel=0; fader.Parent=strip; local fcc=Instance.new("UICorner"); fcc.CornerRadius=UDim.new(0,6); fcc.Parent=fader
		local knob=Instance.new("Frame"); knob.Size=UDim2.fromOffset(32,12); knob.Position=UDim2.fromOffset(4,34); knob.BackgroundColor3=Color3.new(1,1,1); knob.BorderSizePixel=0; knob.Parent=fader; local kc=Instance.new("UICorner"); kc.CornerRadius=UDim.new(0,4); kc.Parent=knob
	end
	local bottom=Instance.new("Frame"); bottom.Size=UDim2.new(1,0,0,36); bottom.Position=UDim2.new(0,0,1,-36); bottom.BackgroundColor3=Theme.tokens.slate800; bottom.BorderSizePixel=0; bottom.Parent=content
	local bl=Instance.new("UIListLayout"); bl.FillDirection=Enum.FillDirection.Horizontal; bl.Padding=UDim.new(0,8); bl.VerticalAlignment=Enum.VerticalAlignment.Center; bl.Parent=bottom; Instance.new("UIPadding", bottom).PaddingLeft=UDim.new(0,8)
	for _,lbl in {"Record","EQ","Comp","Reverb","Bus"} do local b=Instance.new("TextButton"); b.Size=UDim2.fromOffset(70,22); b.BackgroundColor3=Theme.tokens.slate700; b.Text=lbl; b.Font=Enum.Font.Gotham; b.TextSize=11; b.TextColor3=Theme.tokens.slate200; b.Parent=bottom; local bc=Instance.new("UICorner"); bc.CornerRadius=UDim.new(0,6); bc.Parent=b end
	return setmetatable({Win=win}, Audio)
end
function Audio:Toggle() self.Win:Toggle() end
return Audio
