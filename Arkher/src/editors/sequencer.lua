--!strict
-- Sequencer — DaVinci pages: Media / Cut / Edit / Fusion / Color / Fairlight / Deliver
local Theme=require(script.Parent.Parent.core.theme)
local BaseWindow=require(script.Parent.Parent.ui.windows.base_window)
local Sequencer={}
Sequencer.__index=Sequencer
function Sequencer.new(parent: Instance)
	local win=BaseWindow.new({title="Sequencer  —  Cinematic Timeline", size=Vector2.new(900,480), pos=UDim2.fromOffset(80,100), parent=parent, icon="🎬"})
	win.Root.Name="ARKHER_Sequencer"; win.Root.Visible=false
	local content=win.Content; content.BackgroundColor3=Theme.tokens.void
	local pages=Instance.new("Frame"); pages.Size=UDim2.new(1,0,0,28); pages.BackgroundColor3=Theme.tokens.slate900; pages.BorderSizePixel=0; pages.Parent=content
	local pl=Instance.new("UIListLayout"); pl.FillDirection=Enum.FillDirection.Horizontal; pl.Padding=UDim.new(0,4); pl.Parent=pages; Instance.new("UIPadding", pages).PaddingLeft=UDim.new(0,8)
	for _,pg in {"Media","Cut","Edit","Fusion","Color","Fairlight","Deliver"} do
		local b=Instance.new("TextButton"); b.Size=UDim2.fromOffset(84,20); b.BackgroundColor3= if pg=="Edit" then Theme.tokens.arkherBlue else Theme.tokens.slate800; b.Text=pg; b.Font=Enum.Font.GothamBold; b.TextSize=10; b.TextColor3= if pg=="Edit" then Color3.fromRGB(14,20,48) else Theme.tokens.slate400; b.Parent=pages; local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,6); c.Parent=b
	end
	local timeline=Instance.new("Frame"); timeline.Size=UDim2.new(1,0,1,-52); timeline.Position=UDim2.fromOffset(0,28); timeline.BackgroundColor3=Color3.fromRGB(16,22,52); timeline.BorderSizePixel=0; timeline.Parent=content
	-- tracks
	for i=1,4 do
		local track=Instance.new("Frame"); track.Size=UDim2.new(1,0,0,36); track.Position=UDim2.fromOffset(0, 20 + (i-1)*44); track.BackgroundColor3= if i%2==0 then Color3.fromRGB(26,34,78) else Color3.fromRGB(22,30,70); track.BorderSizePixel=0; track.Parent=timeline
		local label=Instance.new("TextLabel"); label.Size=UDim2.fromOffset(60,36); label.BackgroundColor3=Theme.categoryColor("track"..i); label.Text="V"..i; label.Font=Enum.Font.GothamBold; label.TextSize=10; label.TextColor3=Color3.new(1,1,1); label.Parent=track
		for _,clip in { {x=70,w=120,c=Theme.tokens.arkherBlue}, {x=200,w=80,c=Theme.tokens.aurora}, {x=300,w=140,c=Theme.tokens.violet} } do
			if i==1 or math.random()>0.5 then
				local c=Instance.new("Frame"); c.Size=UDim2.fromOffset(clip.w,28); c.Position=UDim2.fromOffset(clip.x,4); c.BackgroundColor3=clip.c; c.BorderSizePixel=0; c.Parent=track; local cc=Instance.new("UICorner"); cc.CornerRadius=UDim.new(0,4); cc.Parent=c
			end
		end
	end
	local bottom=Instance.new("Frame"); bottom.Size=UDim2.new(1,0,0,24); bottom.Position=UDim2.new(0,0,1,-24); bottom.BackgroundColor3=Theme.tokens.slate900; bottom.BorderSizePixel=0; bottom.Parent=content
	local bl=Instance.new("TextLabel"); bl.Size=UDim2.new(1,-16,1,0); bl.Position=UDim2.fromOffset(8,0); bl.BackgroundTransparency=1; bl.Text="24fps  •  3840×2160  •  Deliver: H.264 / ProRes  •  No fake viewport — uses real game camera"; bl.Font=Enum.Font.Gotham; bl.TextSize=10; bl.TextColor3=Theme.tokens.slate400; bl.TextXAlignment=Enum.TextXAlignment.Left; bl.Parent=bottom
	return setmetatable({Win=win}, Sequencer)
end
function Sequencer:Toggle() self.Win:Toggle() end
return Sequencer
