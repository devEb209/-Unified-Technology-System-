--!nolint
-- ARKHER V1 :: Engine HUD (client)
-- Mobile-first status panel: shows the live ARKHER runtime, D-O15 quality level and
-- frame budget. Built entirely from ARKHER UI primitives (no external assets).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local runtime = ReplicatedStorage:WaitForChild("ARKHER_RUNTIME", 30)
if not runtime then return end

local player = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "ARKHER_HUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

local touch = UserInputService.TouchEnabled
local scale = touch and 1.15 or 1.0

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0, 0)
panel.Position = UDim2.new(0, 12, 0, 12)
panel.Size = UDim2.new(0, math.floor(300 * scale), 0, math.floor(120 * scale))
panel.BackgroundColor3 = Color3.fromRGB(10, 12, 18)
panel.BackgroundTransparency = 0.15
panel.BorderSizePixel = 0
panel.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = panel

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(96, 176, 255) -- theme.accent (arkher/ui/theme)
stroke.Thickness = 1.5
stroke.Transparency = 0.3
stroke.Parent = panel

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.new(0, 12, 0, 8)
title.Size = UDim2.new(1, -24, 0, 22 * scale)
title.Font = Enum.Font.GothamBold
title.TextSize = 15 * scale
title.TextColor3 = Color3.fromRGB(120, 190, 255)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "ARKHER V1 - UES ENGINE"
title.Parent = panel

local body = Instance.new("TextLabel")
body.Name = "Body"
body.BackgroundTransparency = 1
body.Position = UDim2.new(0, 12, 0, 32 * scale)
body.Size = UDim2.new(1, -24, 1, -40 * scale)
body.Font = Enum.Font.Code
body.TextSize = 12 * scale
body.TextColor3 = Color3.fromRGB(215, 225, 240)
body.TextXAlignment = Enum.TextXAlignment.Left
body.TextYAlignment = Enum.TextYAlignment.Top
body.RichText = false
body.Text = "booting..."
body.Parent = panel

local bar = Instance.new("Frame")
bar.Name = "QualityBar"
bar.Position = UDim2.new(0, 12, 1, -14 * scale)
bar.Size = UDim2.new(1, -24, 0, 5)
bar.BackgroundColor3 = Color3.fromRGB(40, 48, 62)
bar.BorderSizePixel = 0
bar.Parent = panel
local barFill = Instance.new("Frame")
barFill.Size = UDim2.new(1, 0, 1, 0)
barFill.BackgroundColor3 = Color3.fromRGB(80, 220, 140)
barFill.BorderSizePixel = 0
barFill.Parent = bar

-- tap/click to collapse (mobile friendly)
local collapsed = false
local button = Instance.new("TextButton")
button.BackgroundTransparency = 1
button.Size = UDim2.new(1, 0, 0, 30 * scale)
button.Text = ""
button.Parent = panel
button.Activated:Connect(function()
	collapsed = not collapsed
	panel.Size = collapsed and UDim2.new(0, math.floor(300 * scale), 0, 34 * scale)
		or UDim2.new(0, math.floor(300 * scale), 0, math.floor(120 * scale))
	body.Visible = not collapsed
	bar.Visible = not collapsed
end)

local status = runtime:WaitForChild("Status", 20)
local systemCount = runtime:WaitForChild("SystemCount", 20)
local quality = runtime:WaitForChild("QualityLevel", 20)
local frameMs = runtime:WaitForChild("FrameMs", 20)

local acc = 0
RunService.RenderStepped:Connect(function(dt)
	acc = acc + dt
	if acc < 0.25 then return end
	acc = 0
	local q = quality and quality.Value or 1
	local ms = frameMs and frameMs.Value or 0
	local fps = ms > 0 and (1000 / math.max(ms, 0.01)) or 0
	body.Text = string.format(
		"systems   : %d\nquality   : %.0f%%  (%s)\nengine ms : %.2f\nclient fps: %.0f\ndevice    : %s",
		systemCount and systemCount.Value or 0,
		q * 100,
		q > 0.8 and "ultra" or q > 0.6 and "high" or q > 0.4 and "medium" or "adaptive",
		ms, fps,
		touch and "touch / mobile" or "desktop")
	barFill.Size = UDim2.new(math.clamp(q, 0, 1), 0, 1, 0)
	barFill.BackgroundColor3 = q > 0.7 and Color3.fromRGB(80, 220, 140)
		or q > 0.4 and Color3.fromRGB(240, 200, 90)
		or Color3.fromRGB(240, 110, 110)
end)

if status then print("[ARKHER HUD] " .. status.Value) end
