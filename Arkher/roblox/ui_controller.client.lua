--!nolint
-- ARKHER CLIENT :: UI Controller (StarterPlayerScripts)
-- Liga os ScreenGuis de StarterGui (ARKHER_UI) aos eventos reais.
-- As UIs em si NÃO são código — são instâncias em StarterGui, aqui só o funcionamento.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Espera a UI real (instância) que foi distribuída pelo boot
local ui = playerGui:WaitForChild("ARKHER_UI", 10)
if not ui then
	warn("[ARKHER UI] ARKHER_UI não encontrado em StarterGui")
	return
end

local runtime = ReplicatedStorage:WaitForChild("ARKHER_RUNTIME", 10)
local remotes = ReplicatedStorage:FindFirstChild("ARKHER_REMOTES")

-- Exemplo: botões da UI
local mainBtn = ui:FindFirstChild("MainButton", true)
local flyBtn = ui:FindFirstChild("FlyButton", true)
local closeBtn = ui:FindFirstChild("CloseButton", true)
local panel = ui:FindFirstChild("MainPanel", true) or ui:FindFirstChild("Panel", true)

if mainBtn then
	mainBtn.Activated:Connect(function()
		if remotes and remotes:FindFirstChild("ARKHER_Request") then
			remotes.ARKHER_Request:FireServer("report", "MainButton clicked")
		end
	end)
end

if flyBtn then
	-- Encaminha pro camera_fly (que também escuta F)
	flyBtn.Activated:Connect(function()
		-- dispara toggle simulando F
	end)
end

if closeBtn and panel then
	closeBtn.Activated:Connect(function()
		panel.Visible = not panel.Visible
	end)
end

-- Atalho H esconde/mostra toda UI (útil pra screenshot)
UserInputService.InputBegan:Connect(function(input, gpe)
	if gpe then return end
	if input.KeyCode == Enum.KeyCode.H then
		ui.Enabled = not ui.Enabled
	end
end)

-- Animação de entrada (se tiver)
if panel then
	panel.BackgroundTransparency = 1
	game:GetService("TweenService"):Create(panel, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 0.15}):Play()
end

print("[ARKHER UI] controller ligado — UI em StarterGui, lógica em StarterPlayerScripts")
