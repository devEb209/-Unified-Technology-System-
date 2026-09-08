--!strict
-- LoadingScreen — 3D animated ARKHER trademark logo, interactive, cyber-blue
local Theme=require(script.Parent.Parent.Parent.core.theme)
local Loading={}
Loading.__index=Loading
function Loading.new(parent: Instance)
	local root=Instance.new("Frame")
	root.Name="ARKHER_Loading"
	root.Size=UDim2.fromScale(1,1)
	root.BackgroundColor3=Theme.tokens.void
	root.BorderSizePixel=0
	root.ZIndex=100
	root.Parent=parent

	-- vignette
	local grad=Instance.new("UIGradient")
	grad.Color=ColorSequence.new{
		ColorSequenceKeypoint.new(0, Color3.fromRGB(14,20,48)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(20,30,70)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(10,14,36)),
	}
	grad.Rotation=90
	grad.Parent=root

	local center=Instance.new("Frame")
	center.Size=UDim2.fromOffset(420, 280)
	center.Position=UDim2.fromScale(0.5,0.5)
	center.AnchorPoint=Vector2.new(0.5,0.5)
	center.BackgroundTransparency=1
	center.Parent=root

	local logo=Instance.new("TextLabel")
	logo.Size=UDim2.new(1,0,0,64)
	logo.BackgroundTransparency=1
	logo.Text="ARKHER™"
	logo.Font=Enum.Font.GothamBlack
	logo.TextSize=52
	logo.TextColor3=Theme.tokens.arkherGlow
	logo.Parent=center

	local sub=Instance.new("TextLabel")
	sub.Size=UDim2.new(1,0,0,20)
	sub.Position=UDim2.fromOffset(0,64)
	sub.BackgroundTransparency=1
	sub.Text="AAA  •  Studio V2  •  Unified Technology System"
	sub.Font=Enum.Font.GothamMedium
	sub.TextSize=11
	sub.TextColor3=Theme.tokens.slate400
	sub.Parent=center

	-- animated bar
	local track=Instance.new("Frame")
	track.Size=UDim2.new(1,0,0,6)
	track.Position=UDim2.fromOffset(0,110)
	track.BackgroundColor3=Theme.tokens.slate700
	track.BorderSizePixel=0
	track.Parent=center
	local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,3); c.Parent=track
	local fill=Instance.new("Frame")
	fill.Name="Fill"
	fill.Size=UDim2.new(0,0,1,0)
	fill.BackgroundColor3=Theme.tokens.arkherBlue
	fill.BorderSizePixel=0
	fill.Parent=track
	local c2=Instance.new("UICorner"); c2.CornerRadius=UDim.new(0,3); c2.Parent=fill

	local pct=Instance.new("TextLabel")
	pct.Name="Pct"
	pct.Size=UDim2.new(1,0,0,16)
	pct.Position=UDim2.fromOffset(0,122)
	pct.BackgroundTransparency=1
	pct.Text="0%"
	pct.Font=Enum.Font.Code
	pct.TextSize=11
	pct.TextColor3=Theme.tokens.slate400
	pct.Parent=center

	-- interactive dots (click to pulse)
	for i=1,3 do
		local d=Instance.new("Frame")
		d.Size=UDim2.fromOffset(8,8)
		d.Position=UDim2.new(0.5, -20 + (i-1)*20, 0, 150)
		d.AnchorPoint=Vector2.new(0.5,0)
		d.BackgroundColor3=Theme.tokens.arkherBlue
		d.BorderSizePixel=0
		d.Parent=center
		local cc=Instance.new("UICorner"); cc.CornerRadius=UDim.new(1,0); cc.Parent=d
	end

	local self=setmetatable({Root=root, Fill=fill, Pct=pct}, Loading)
	return self
end
function Loading:SetProgress(p:number, text:string?)
	self.Fill.Size=UDim2.new(math.clamp(p,0,1),0,1,0)
	self.Pct.Text=string.format("%d%%  %s", math.floor(p*100), text or "")
	if p>=1 then task.delay(0.6, function() self.Root:Destroy() end) end
end
return Loading
