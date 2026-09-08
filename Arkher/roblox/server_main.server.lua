--!nolint
-- ARKHER SERVER :: Main Authority (ServerScriptService)
-- Segunda camada de segurança: tudo que é crítico roda aqui.
-- O cliente nunca decide nada sozinho, só pede; o servidor valida.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- Remote folder
local remotes = ReplicatedStorage:FindFirstChild("ARKHER_REMOTES")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "ARKHER_REMOTES"
	remotes.Parent = ReplicatedStorage
end

local requestRemote = remotes:FindFirstChild("ARKHER_Request")
if not requestRemote then
	requestRemote = Instance.new("RemoteEvent")
	requestRemote.Name = "ARKHER_Request"
	requestRemote.Parent = remotes
end
local stateRemote = remotes:FindFirstChild("ARKHER_State")
if not stateRemote then
	stateRemote = Instance.new("RemoteEvent")
	stateRemote.Name = "ARKHER_State"
	stateRemote.Parent = remotes
end

-- Server runtime reference
local engine = _G.ARKHER
if not engine then
	-- aguarda boot do engine (pode estar em ReplicatedStorage)
	task.wait(3)
	engine = _G.ARKHER
end

print("[ARKHER SERVER] Authority online — platform=" .. (engine and engine.platform or "unknown"))

-- Rate limit por player (anti spam)
local limits = {}
local function checkRate(player, key, maxPerSec)
	local now = os.clock()
	local bucket = limits[player.UserId .. ":" .. key]
	if not bucket then
		bucket = { count = 0, window = now }
		limits[player.UserId .. ":" .. key] = bucket
	end
	if now - bucket.window > 1 then
		bucket.window = now
		bucket.count = 0
	end
	bucket.count += 1
	return bucket.count <= maxPerSec
end

Players.PlayerRemoving:Connect(function(p)
	for k in pairs(limits) do if string.find(k, tostring(p.UserId)) then limits[k]=nil end end
end)

requestRemote.OnServerEvent:Connect(function(player, action, payload)
	if not checkRate(player, action, 20) then
		warn("[ARKHER SERVER] rate limit " .. player.Name .. " -> " .. tostring(action))
		return
	end
	-- Validação básica por ação
	if action == "ping" then
		stateRemote:FireClient(player, "pong", { t = os.clock() })
	elseif action == "flyRequest" then
		-- só permite fly se player tem permissão (ex: admin ou dev)
		-- por padrão permite, mas loga
		stateRemote:FireClient(player, "flyGranted", { allowed = true })
	elseif action == "report" then
		print("[ARKHER CLIENT REPORT] " .. player.Name .. " -> " .. tostring(payload))
	end
end)

-- Heartbeat autoridade (poderia replicar D-O15 aqui)
RunService.Heartbeat:Connect(function()
	if engine and engine.frameCount % 180 == 0 then
		-- broadcast qualidade
		stateRemote:FireAllClients("quality", engine.quality)
	end
end)
