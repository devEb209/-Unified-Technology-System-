--!strict
-- BaseWindow — draggable + resizable panel with header, close, collapsible
-- No fake viewport; used for every editor window.
local Theme = require(script.Parent.Parent.Parent.core.theme)
local Config = require(script.Parent.Parent.Parent.core.config)

local BaseWindow = {}
BaseWindow.__index = BaseWindow

type Opts = {
	title: string,
	size: Vector2,
	pos: UDim2,
	icon: string?,
	noClose: boolean?,
	parent: Instance?,
	zIndex: number?,
}

local function corner(parent: Instance, r: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = parent
	return c
end

local function stroke(parent: Instance, col: Color3, t: number)
	local s = Instance.new("UIStroke")
	s.Color = col
	s.Thickness = t
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

function BaseWindow.new(opts: Opts)
	local self = setmetatable({}, BaseWindow)
	local T = Theme.tokens
	local R = Theme.roles

	local root = Instance.new("Frame")
	root.Name = opts.title:gsub("%s+","_")
	root.Size = UDim2.fromOffset(opts.size.X, opts.size.Y)
	root.Position = opts.pos or UDim2.fromOffset(120, 120)
	root.BackgroundColor3 = R.surface
	root.BorderSizePixel = 0
	root.ClipsDescendants = false
	root.ZIndex = opts.zIndex or 5
	root.Parent = opts.parent
	corner(root, Config.layout.corner)
	stroke(root, R.border, 1)
	self.Root = root

	-- Header
	local hdr = Instance.new("Frame")
	hdr.Name = "Header"
	hdr.Size = UDim2.new(1,0,0, Config.layout.windowHeaderH)
	hdr.BackgroundColor3 = T.slate800
	hdr.BorderSizePixel = 0
	hdr.ZIndex = root.ZIndex + 1
	hdr.Parent = root
	local hc = corner(hdr, Config.layout.corner)
	-- fix bottom corners flat so header merges
	local fix = Instance.new("Frame")
	fix.Size = UDim2.new(1,0,0,8)
	fix.Position = UDim2.new(0,0,1,-8)
	fix.BackgroundColor3 = T.slate800
	fix.BorderSizePixel = 0
	fix.ZIndex = hdr.ZIndex
	fix.Parent = hdr

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, -70, 1, 0)
	title.Position = UDim2.fromOffset(10, 0)
	title.BackgroundTransparency = 1
	title.Text = (opts.icon and (opts.icon.."  ") or "")..opts.title
	title.Font = Enum.Font.GothamBold
	title.TextSize = 13
	title.TextColor3 = T.white
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.ZIndex = hdr.ZIndex + 1
	title.Parent = hdr
	self.TitleLabel = title

	if not opts.noClose then
		local btn = Instance.new("TextButton")
		btn.Name = "Close"
		btn.Size = UDim2.fromOffset(28, 20)
		btn.Position = UDim2.new(1, -32, 0.5, -10)
		btn.AnchorPoint = Vector2.new(0,0)
		btn.BackgroundColor3 = Color3.fromRGB(42, 52, 96)
		btn.Text = "✕"
		btn.Font = Enum.Font.GothamBold
		btn.TextSize = 12
		btn.TextColor3 = T.slate400
		btn.AutoButtonColor = true
		btn.ZIndex = hdr.ZIndex + 2
		btn.Parent = hdr
		corner(btn, 6)
		self.CloseBtn = btn
		btn.MouseButton1Click:Connect(function()
			root.Visible = false
		end)
		btn.MouseEnter:Connect(function() btn.BackgroundColor3 = Theme.tokens.ember; btn.TextColor3 = Color3.new(1,1,1) end)
		btn.MouseLeave:Connect(function() btn.BackgroundColor3 = Color3.fromRGB(42,52,96); btn.TextColor3 = T.slate400 end)
	end

	-- Content area
	local content = Instance.new("Frame")
	content.Name = "Content"
	content.Size = UDim2.new(1, -2, 1, -Config.layout.windowHeaderH -2)
	content.Position = UDim2.fromOffset(1, Config.layout.windowHeaderH)
	content.BackgroundColor3 = R.surface
	content.BorderSizePixel = 0
	content.ClipsDescendants = true
	content.ZIndex = root.ZIndex
	content.Parent = root
	corner(content, Config.layout.corner)
	self.Content = content

	-- subtle glow border when focused
	local glow = Instance.new("UIStroke")
	glow.Color = T.arkherBlue
	glow.Thickness = 1
	glow.Transparency = 1 -- hidden until focus
	glow.Parent = root
	self.Glow = glow

	-- Drag logic (header)
	do
		local dragging = false
		local dragStart: Vector2
		local startPos: UDim2
		hdr.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				dragging = true
				dragStart = input.Position
				startPos = root.Position
				glow.Transparency = 0.3
				input.Changed:Connect(function()
					if input.UserInputState == Enum.UserInputState.End then
						dragging = false
						glow.Transparency = 1
					end
				end)
			end
		end)
		hdr.InputChanged:Connect(function(input)
			if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
				local delta = input.Position - dragStart
				root.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
			end
		end)
	end

	-- Resize handle (bottom-right)
	local handle = Instance.new("Frame")
	handle.Name = "Resize"
	handle.Size = UDim2.fromOffset(16,16)
	handle.Position = UDim2.new(1,-16,1,-16)
	handle.BackgroundTransparency = 1
	handle.ZIndex = root.ZIndex + 2
	handle.Parent = root
	local grip = Instance.new("TextLabel")
	grip.Size = UDim2.fromScale(1,1)
	grip.BackgroundTransparency = 1
	grip.Text = "◢"
	grip.TextColor3 = T.slate600
	grip.TextSize = 10
	grip.Font = Enum.Font.Gotham
	grip.Parent = handle
	do
		local resizing=false
		local start: Vector2
		local s0: Vector2
		handle.InputBegan:Connect(function(input)
			if input.UserInputType==Enum.UserInputType.MouseButton1 then
				resizing=true
				start=input.Position
				s0=Vector2.new(root.AbsoluteSize.X, root.AbsoluteSize.Y)
			end
		end)
		game:GetService("UserInputService").InputChanged:Connect(function(input)
			if resizing and input.UserInputType==Enum.UserInputType.MouseMovement then
				local d=input.Position-start
				local nx = math.clamp(s0.X + d.X, Config.layout.windowMin.X, 1200)
				local ny = math.clamp(s0.Y + d.Y, Config.layout.windowMin.Y, 900)
				root.Size = UDim2.fromOffset(nx, ny)
			end
		end)
		game:GetService("UserInputService").InputEnded:Connect(function(input)
			if input.UserInputType==Enum.UserInputType.MouseButton1 then resizing=false end
		end)
	end

	self.Handle = handle
	return self
end

function BaseWindow:Show()
	self.Root.Visible = true
	self.Root.ZIndex = 10
	self.Content.ZIndex = 10
end
function BaseWindow:Hide() self.Root.Visible=false end
function BaseWindow:Toggle() self.Root.Visible = not self.Root.Visible end
function BaseWindow:SetTitle(t: string) self.TitleLabel.Text = t end

return BaseWindow
