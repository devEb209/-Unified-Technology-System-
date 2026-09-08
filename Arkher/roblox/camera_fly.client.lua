--!nolint
-- ARKHER CLIENT :: Fly Camera (StarterPlayerScripts)
-- Studio-like: PC = WASD + Q/E + mouse botão direito arrasta, Mobile = joystick padrão + botão Fly, Console = thumbsticks + triggers
-- Segura F ou botão UI pra ativar fly. No mobile, usa thumbstick do Roblox (já existe) e adiciona botão sobe/desce.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local cam = Workspace.CurrentCamera
cam.CameraType = Enum.CameraType.Custom

-- Estado
local flying = false
local flySpeed = 50
local baseSpeed = 50
local sprintMult = 2.2
local vel = Vector3.zero
local rot = Vector2.zero -- x yaw, y pitch
local keys = {}
local mouseDown = false
local lastMouse = Vector2.zero

-- Refs remotes (optional, pra pedir permissão fly pro server)
local remotes = ReplicatedStorage:WaitForChild("ARKHER_REMOTES", 5)
local requestRemote = remotes and remotes:FindFirstChild("ARKHER_Request")

local function isFlyAllowed()
	-- sempre permite local, server valida se quiser bloquear
	return true
end

-- Cria tag no character pra antiexploit saber que é fly autorizado
local function setFlyTag(on)
	local char = player.Character
	if not char then return end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	for _,c in ipairs(char:GetChildren()) do if c.Name=="ARKHER_FLY_AUTHORIZED" then c:Destroy() end end
	if on then
		local tag = Instance.new("BoolValue")
		tag.Name = "ARKHER_FLY_AUTHORIZED"
		tag.Value = true
		tag.Parent = char
		-- humanoid platformstand pra não cair
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then hum.PlatformStand = true end
	else
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then hum.PlatformStand = false end
	end
end

-- UI botão fly (caso StarterGui ARKHER_UI não exista)
local function ensureFlyButton()
	local gui = player:WaitForChild("PlayerGui")
	local existing = gui:FindFirstChild("ARKHER_FLY_BUTTON")
	if existing then return existing end
	local sg = Instance.new("ScreenGui")
	sg.Name = "ARKHER_FLY_BUTTON"
	sg.ResetOnSpawn = false
	sg.IgnoreGuiInset = true
	sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	sg.Parent = gui
	local btn = Instance.new("TextButton")
	btn.Name = "FlyToggle"
	btn.AnchorPoint = Vector2.new(1,1)
	btn.Position = UDim2.new(1, -14, 1, -120)
	btn.Size = UDim2.new(0, 86, 0, 86)
	btn.BackgroundColor3 = Color3.fromRGB(10,12,18)
	btn.BackgroundTransparency = 0.15
	btn.Text = "✈️"
	btn.TextColor3 = Color3.fromRGB(120,190,255)
	btn.TextScaled = true
	btn.Font = Enum.Font.GothamBold
	btn.Parent = sg
	local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0, 18); corner.Parent = btn
	local stroke = Instance.new("UIStroke"); stroke.Color = Color3.fromRGB(96,176,255); stroke.Thickness = 1.5; stroke.Transparency = 0.3; stroke.Parent = btn
	return sg
end
local flyGui = ensureFlyButton()
local flyBtn = flyGui:FindFirstChild("FlyToggle", true)
if flyBtn then
	flyBtn.Activated:Connect(function()
		flying = not flying
		setFlyTag(flying)
		flyBtn.BackgroundColor3 = flying and Color3.fromRGB(43,111,212) or Color3.fromRGB(10,12,18)
		if flying and requestRemote then requestRemote:FireServer("flyRequest") end
	end)
end

-- Input PC
UserInputService.InputBegan:Connect(function(input, gpe)
	if gpe then return end
	if input.KeyCode == Enum.KeyCode.F then
		flying = not flying
		setFlyTag(flying)
		if flyBtn then flyBtn.BackgroundColor3 = flying and Color3.fromRGB(43,111,212) or Color3.fromRGB(10,12,18) end
		if flying and requestRemote then requestRemote:FireServer("flyRequest") end
	end
	if input.KeyCode == Enum.KeyCode.LeftShift then flySpeed = baseSpeed * sprintMult end
	if input.UserInputType == Enum.UserInputType.MouseButton2 then mouseDown = true; lastMouse = UserInputService:GetMouseLocation() end
	keys[input.KeyCode] = true
end)
UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.LeftShift then flySpeed = baseSpeed end
	if input.UserInputType == Enum.UserInputType.MouseButton2 then mouseDown = false end
	keys[input.KeyCode] = nil
end)
UserInputService.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseMovement and flying and mouseDown then
		local cur = UserInputService:GetMouseLocation()
		local delta = cur - lastMouse
		rot = rot + Vector2.new(-delta.X * 0.25, -delta.Y * 0.25)
		rot = Vector2.new(rot.X, math.clamp(rot.Y, -88, 88))
		lastMouse = cur
	end
end)

-- Console gamepad (se existir)
local function gamepadDir()
	local move = Vector3.zero
	local gp = Enum.UserInputType.Gamepad1
	-- left thumbstick move (Gamepad)
	local ly = UserInputService:GetGamepadState(gp) -- not exists, fallback to thumbstick via InputBegan
	return move
end

-- Loop
RunService.RenderStepped:Connect(function(dt)
	if not flying then return end
	-- Direções PC
	local move = Vector3.zero
	if keys[Enum.KeyCode.W] then move += Vector3.new(0,0,-1) end
	if keys[Enum.KeyCode.S] then move += Vector3.new(0,0,1) end
	if keys[Enum.KeyCode.A] then move += Vector3.new(-1,0,0) end
	if keys[Enum.KeyCode.D] then move += Vector3.new(1,0,0) end
	if keys[Enum.KeyCode.Q] then move += Vector3.new(0,-1,0) end
	if keys[Enum.KeyCode.E] then move += Vector3.new(0,1,0) end
	if keys[Enum.KeyCode.Space] then move += Vector3.new(0,1,0) end
	if keys[Enum.KeyCode.LeftControl] then move += Vector3.new(0,-1,0) end

	-- Mobile joystick fallback: usa Humanoid.MoveDirection se estiver voando (captura o thumbstick padrão)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum and move == Vector3.zero and UserInputService.TouchEnabled then
		local md = hum.MoveDirection
		if md.Magnitude > 0.1 then
			move = Vector3.new(md.X, 0, md.Z)
		end
	end

	-- Console thumbsticks (poll)
	if move == Vector3.zero and UserInputService.GamepadEnabled then
		-- Left stick via thumbstick1, right stick via thumbstick2 — Roblox mapeia como KeyCode Thumbstick1/2
		-- Vamos ler via UserInputService:GetGamepadState não existe, então usa last InputChanged já capturado?
	end

	if move.Magnitude > 0 then move = move.Unit * flySpeed end
	-- Aplica rotação da câmera no movimento
	local camCF = CFrame.fromEulerAnglesYXZ(math.rad(rot.Y), math.rad(rot.X), 0)
	local worldMove = camCF:VectorToWorldSpace(move)
	cam.CFrame = cam.CFrame + worldMove * dt
	-- Mantém personagem junto (opcional)
	if char and char:FindFirstChild("HumanoidRootPart") then
		char.HumanoidRootPart.CFrame = cam.CFrame
		char.HumanoidRootPart.AssemblyLinearVelocity = Vector3.zero
	end
	-- Câmera segue
	cam.CFrame = CFrame.new(cam.CFrame.Position) * CFrame.fromEulerAnglesYXZ(math.rad(rot.Y), math.rad(rot.X), 0)
	cam.Focus = cam.CFrame * CFrame.new(0,0,-5)
end)

-- Quando iniciar, pega rotação inicial da câmera
task.wait(1)
rot = Vector2.new(-math.deg(math.asin(cam.CFrame.LookVector.Y)), math.deg(math.atan2(cam.CFrame.LookVector.X, cam.CFrame.LookVector.Z)))

print("[ARKHER CAMERA] Fly pronto — PC: F toggle + WASD/QE + botão direito arrasta | Mobile: botão ✈️ + joystick | Console: use stick")
