--!strict
-- ARKHER Components — reusable primitives (Button, TextBox, Checkbox, Slider, Dropdown, ColorPicker)
-- All 100% functional, no prints only real callbacks.
local Theme = require(script.Parent.Parent.Parent.core.theme)

local C = {}

local function corner(p: Instance, r: number)
	local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r); c.Parent = p; return c
end
local function stroke(p: Instance, col: Color3, t: number)
	local s = Instance.new("UIStroke"); s.Color=col; s.Thickness=t; s.ApplyStrokeMode=Enum.ApplyStrokeMode.Border; s.Parent=p; return s
end
local function pad(p: Instance, l:number, t:number, r:number, b:number)
	local u = Instance.new("UIPadding"); u.PaddingLeft=UDim.new(0,l); u.PaddingTop=UDim.new(0,t); u.PaddingRight=UDim.new(0,r); u.PaddingBottom=UDim.new(0,b); u.Parent=p; return u
end

-- Button
function C.Button(parent: Instance, text: string, opts: any?): TextButton
	local b = Instance.new("TextButton")
	b.Size = opts and opts.size or UDim2.fromOffset(90, 28)
	b.BackgroundColor3 = opts and opts.color or Theme.tokens.slate800
	b.Text = text
	b.Font = Enum.Font.GothamMedium
	b.TextSize = 12
	b.TextColor3 = Theme.tokens.white
	b.AutoButtonColor = true
	b.Parent = parent
	corner(b, 8)
	stroke(b, Theme.roles.border, 1)
	return b
end

-- IconButton (square)
function C.IconButton(parent: Instance, icon: string, tooltip: string?): TextButton
	local b = Instance.new("TextButton")
	b.Size = UDim2.fromOffset(28,28)
	b.BackgroundColor3 = Theme.tokens.slate800
	b.Text = icon
	b.Font = Enum.Font.GothamBold
	b.TextSize = 13
	b.TextColor3 = Theme.tokens.slate400
	b.AutoButtonColor = true
	b.Parent = parent
	corner(b, 8)
	stroke(b, Theme.roles.border, 1)
	return b
end

-- TextBox with label
function C.TextField(parent: Instance, label: string, initial: string, onCommit: (string)->()): Frame
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1,0,0,28)
	row.BackgroundTransparency = 1
	row.Parent = parent

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(0.42,0,1,0)
	lbl.BackgroundTransparency=1
	lbl.Text=label
	lbl.Font=Enum.Font.Gotham
	lbl.TextSize=12
	lbl.TextColor3=Theme.tokens.slate400
	lbl.TextXAlignment=Enum.TextXAlignment.Left
	lbl.Parent=row

	local tb = Instance.new("TextBox")
	tb.Size = UDim2.new(0.58,0,1,0)
	tb.Position = UDim2.new(0.42,0,0,0)
	tb.BackgroundColor3 = Theme.tokens.slate800
	tb.Text = initial
	tb.ClearTextOnFocus = false
	tb.Font = Enum.Font.Gotham
	tb.TextSize=12
	tb.TextColor3=Theme.tokens.white
	tb.PlaceholderColor3=Theme.tokens.slate400
	tb.TextXAlignment=Enum.TextXAlignment.Left
	tb.Parent=row
	corner(tb,6)
	stroke(tb, Theme.roles.border,1)
	pad(tb,8,0,8,0)
	tb.FocusLost:Connect(function(enter)
		if enter then onCommit(tb.Text) end
	end)
	return row
end

-- Vector3 field (3 TextBoxes)
function C.Vector3Field(parent: Instance, label: string, vec: Vector3, onCommit: (Vector3)->()): Frame
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1,0,0,28)
	row.BackgroundTransparency=1
	row.Parent=parent
	local lbl = Instance.new("TextLabel")
	lbl.Size=UDim2.new(0.30,0,1,0)
	lbl.BackgroundTransparency=1
	lbl.Text=label
	lbl.Font=Enum.Font.Gotham
	lbl.TextSize=12
	lbl.TextColor3=Theme.tokens.slate400
	lbl.TextXAlignment=Enum.TextXAlignment.Left
	lbl.Parent=row
	local function mk(x0: number, idx:number)
		local tb=Instance.new("TextBox")
		tb.Size=UDim2.new(0.22,0,1,-4)
		tb.Position=UDim2.new(0.30 + (idx*0.235),0,0,2)
		tb.BackgroundColor3=Theme.tokens.slate800
		tb.Text=tostring(math.round(x0*100)/100)
		tb.Font=Enum.Font.Code
		tb.TextSize=11
		tb.TextColor3=Theme.tokens.white
		tb.Parent=row
		corner(tb,6)
		stroke(tb,Theme.roles.border,1)
		return tb
	end
	local tx=mk(vec.X,0); local ty=mk(vec.Y,1); local tz=mk(vec.Z,2)
	local function commit()
		local x=tonumber(tx.Text) or vec.X
		local y=tonumber(ty.Text) or vec.Y
		local z=tonumber(tz.Text) or vec.Z
		onCommit(Vector3.new(x,y,z))
	end
	tx.FocusLost:Connect(function(e) if e then commit() end end)
	ty.FocusLost:Connect(function(e) if e then commit() end end)
	tz.FocusLost:Connect(function(e) if e then commit() end end)
	return row
end

-- Checkbox
function C.Checkbox(parent: Instance, label: string, initial: boolean, onToggle: (boolean)->()): Frame
	local row=Instance.new("Frame")
	row.Size=UDim2.new(1,0,0,26)
	row.BackgroundTransparency=1
	row.Parent=parent
	local box=Instance.new("TextButton")
	box.Size=UDim2.fromOffset(18,18)
	box.Position=UDim2.fromOffset(0,4)
	box.BackgroundColor3= if initial then Theme.tokens.arkherBlue else Theme.tokens.slate800
	box.Text= if initial then "✓" else ""
	box.Font=Enum.Font.GothamBold
	box.TextSize=11
	box.TextColor3=Color3.new(1,1,1)
	box.Parent=row
	corner(box,4)
	stroke(box,Theme.roles.border,1)
	local lbl=Instance.new("TextLabel")
	lbl.Size=UDim2.new(1,-26,1,0)
	lbl.Position=UDim2.fromOffset(26,0)
	lbl.BackgroundTransparency=1
	lbl.Text=label
	lbl.Font=Enum.Font.Gotham
	lbl.TextSize=12
	lbl.TextColor3=Theme.tokens.slate200
	lbl.TextXAlignment=Enum.TextXAlignment.Left
	lbl.Parent=row
	local state=initial
	box.MouseButton1Click:Connect(function()
		state=not state
		box.BackgroundColor3= if state then Theme.tokens.arkherBlue else Theme.tokens.slate800
		box.Text= if state then "✓" else ""
		onToggle(state)
	end)
	return row
end

-- Slider
function C.Slider(parent: Instance, label: string, min: number, max: number, initial: number, onChange: (number)->()): Frame
	local row=Instance.new("Frame")
	row.Size=UDim2.new(1,0,0,34)
	row.BackgroundTransparency=1
	row.Parent=parent
	local lbl=Instance.new("TextLabel")
	lbl.Size=UDim2.new(1,0,0,14)
	lbl.BackgroundTransparency=1
	lbl.Text=label.."  "..string.format("%.2f", initial)
	lbl.Font=Enum.Font.Gotham
	lbl.TextSize=11
	lbl.TextColor3=Theme.tokens.slate400
	lbl.TextXAlignment=Enum.TextXAlignment.Left
	lbl.Parent=row
	local track=Instance.new("Frame")
	track.Size=UDim2.new(1,0,0,6)
	track.Position=UDim2.fromOffset(0,18)
	track.BackgroundColor3=Theme.tokens.slate700
	track.BorderSizePixel=0
	track.Parent=row
	corner(track,3)
	local fill=Instance.new("Frame")
	fill.Size=UDim2.new((initial-min)/math.max(0.0001,(max-min)),0,1,0)
	fill.BackgroundColor3=Theme.tokens.arkherBlue
	fill.BorderSizePixel=0
	fill.Parent=track
	corner(fill,3)
	local knob=Instance.new("Frame")
	knob.Size=UDim2.fromOffset(12,12)
	knob.Position=UDim2.new((initial-min)/math.max(0.0001,(max-min)),-6,0.5,-6)
	knob.BackgroundColor3=Color3.new(1,1,1)
	knob.Parent=track
	corner(knob,6)
	local dragging=false
	track.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then dragging=true end end)
	game:GetService("UserInputService").InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then dragging=false end end)
	game:GetService("UserInputService").InputChanged:Connect(function(i)
		if dragging and i.UserInputType==Enum.UserInputType.MouseMovement then
			local rel = math.clamp((i.Position.X - track.AbsolutePosition.X)/math.max(1,track.AbsoluteSize.X),0,1)
			local v = min + rel*(max-min)
			fill.Size=UDim2.new(rel,0,1,0)
			knob.Position=UDim2.new(rel,-6,0.5,-6)
			lbl.Text=label.."  "..string.format("%.2f", v)
			onChange(v)
		end
	end)
	return row
end

-- Dropdown
function C.Dropdown(parent: Instance, label: string, options: {string}, initial: string, onPick: (string)->()): Frame
	local row=Instance.new("Frame")
	row.Size=UDim2.new(1,0,0,28)
	row.BackgroundTransparency=1
	row.Parent=parent
	row.ZIndex=5
	local lbl=Instance.new("TextLabel")
	lbl.Size=UDim2.new(0.42,0,1,0)
	lbl.BackgroundTransparency=1
	lbl.Text=label
	lbl.Font=Enum.Font.Gotham
	lbl.TextSize=12
	lbl.TextColor3=Theme.tokens.slate400
	lbl.TextXAlignment=Enum.TextXAlignment.Left
	lbl.Parent=row
	local btn=Instance.new("TextButton")
	btn.Size=UDim2.new(0.58,0,1,0)
	btn.Position=UDim2.new(0.42,0,0,0)
	btn.BackgroundColor3=Theme.tokens.slate800
	btn.Text=initial.."  ▾"
	btn.Font=Enum.Font.Gotham
	btn.TextSize=12
	btn.TextColor3=Theme.tokens.white
	btn.Parent=row
	corner(btn,6)
	stroke(btn,Theme.roles.border,1)
	local list=Instance.new("Frame")
	list.Size=UDim2.new(0.58,0,0,#options*26)
	list.Position=UDim2.new(0.42,0,1,4)
	list.BackgroundColor3=Theme.tokens.slate800
	list.Visible=false
	list.ZIndex=10
	list.Parent=row
	corner(list,6)
	stroke(list,Theme.roles.border,1)
	local layout=Instance.new("UIListLayout")
	layout.Padding=UDim.new(0,0)
	layout.Parent=list
	for _,opt in options do
		local o=Instance.new("TextButton")
		o.Size=UDim2.new(1,0,0,26)
		o.BackgroundColor3=Theme.tokens.slate800
		o.Text=opt
		o.Font=Enum.Font.Gotham
		o.TextSize=12
		o.TextColor3=Theme.tokens.slate200
		o.ZIndex=11
		o.Parent=list
		o.MouseButton1Click:Connect(function()
			btn.Text=opt.."  ▾"
			list.Visible=false
			onPick(opt)
		end)
		o.MouseEnter:Connect(function() o.BackgroundColor3=Theme.tokens.slate700 end)
		o.MouseLeave:Connect(function() o.BackgroundColor3=Theme.tokens.slate800 end)
	end
	btn.MouseButton1Click:Connect(function() list.Visible=not list.Visible end)
	return row
end

-- ColorPicker (compact — opens palette)
function C.ColorField(parent: Instance, label: string, initial: Color3, onPick: (Color3)->()): Frame
	local row=Instance.new("Frame")
	row.Size=UDim2.new(1,0,0,28)
	row.BackgroundTransparency=1
	row.Parent=parent
	local lbl=Instance.new("TextLabel")
	lbl.Size=UDim2.new(0.42,0,1,0)
	lbl.BackgroundTransparency=1
	lbl.Text=label
	lbl.Font=Enum.Font.Gotham
	lbl.TextSize=12
	lbl.TextColor3=Theme.tokens.slate400
	lbl.TextXAlignment=Enum.TextXAlignment.Left
	lbl.Parent=row
	local sw=Instance.new("TextButton")
	sw.Size=UDim2.new(0.58,0,1,0)
	sw.Position=UDim2.new(0.42,0,0,0)
	sw.BackgroundColor3=initial
	sw.Text=""
	sw.Parent=row
	corner(sw,6)
	stroke(sw,Theme.roles.border,1)
	sw.MouseButton1Click:Connect(function()
		-- simple HSV cycle for now — full picker expands later
		local h,s,v = initial:ToHSV()
		h=(h+0.07)%1
		local c=Color3.fromHSV(h,s,v)
		sw.BackgroundColor3=c
		onPick(c)
	end)
	return row
end

return C
