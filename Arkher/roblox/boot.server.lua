--!nolint
-- ARKHER V1 :: Roblox Boot Script (server)
-- Drop the ARKHER model anywhere (ReplicatedStorage is recommended) and this script
-- boots the entire engine: kernel, platform adapter, D-O15 and the system catalog.
-- Nothing here is a demo shim - it is the real ARKHER runtime entry point.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local ARKHER_ROOT = script.Parent
if ARKHER_ROOT.Name ~= "ARKHER" then
	local found = ReplicatedStorage:FindFirstChild("ARKHER")
	if found then ARKHER_ROOT = found end
end

-- 1. index every ModuleScript into ARKHER module ids ("arkher/kernel/eventbus")
local factories = {}
local function walk(instance, prefix)
	for _, child in ipairs(instance:GetChildren()) do
		local path = prefix == "" and child.Name or (prefix .. "/" .. child.Name)
		if child:IsA("ModuleScript") then
			factories[path] = child
		elseif child:IsA("Folder") or child:IsA("Configuration") then
			walk(child, path)
		end
	end
end
walk(ARKHER_ROOT, "arkher")

local loaderModule = factories["arkher/kernel/loader"]
if not loaderModule then
	warn("[ARKHER] loader module missing - is the model complete?")
	return
end

-- 2. build the loader and register every factory
local Loader = require(loaderModule)(nil)
local A = Loader.new({ timeFn = os.clock })
local registered = 0
for id, moduleScript in pairs(factories) do
	A:define(id, require(moduleScript))
	registered = registered + 1
end

-- 3. boot the engine on the Roblox adapter
local Engine = A:import("arkher/engine")
local engine = Engine.boot(A, { logLevel = 30 })

-- Boot guard: if the platform adapter ever fails to recognize the Roblox host, the
-- engine silently binds the headless adapter instead (frozen clock, no services,
-- no real device profile) - exactly the V1.0.0 boot bug. A zombie boot must die
-- loudly, never quietly.
if engine.platform ~= "roblox" then
	warn("[ARKHER] BOOT REFUSED: inside Roblox the engine bound the '"
		.. tostring(engine.platform) .. "' adapter instead of the Roblox one.")
	error("ARKHER boot: Roblox host not detected by the platform adapter", 0)
end

local t0 = os.clock()
local loaded, failed = engine:loadCatalog()
local bootMs = (os.clock() - t0) * 1000

-- 4. verify the catalog with every system's own self-test
local verification = engine:verify()
local report = engine:report()

print(string.rep("=", 68))
print(string.format("ARKHER %s  (%s)  platform=%s", report.version, report.generation, report.platform))
print(string.format("  modules registered : %d", registered))
print(string.format("  systems online     : %d  (A=%d  S=%d  X=%d)", report.systems,
	report.byCategory.A or 0, report.byCategory.S or 0, report.byCategory.X or 0))
print(string.format("  self-test          : %d passed / %d failed", verification.passed, verification.failed))
print(string.format("  boot time          : %.1f ms   load failures: %d", bootMs, failed))
print(string.format("  device             : %s (tier %s, score %d)", report.device.class, report.device.tier, math.floor(report.device.score)))
print(string.format("  D-O15 budgets      : frame %.1fms, draws %d, parts %d, mem %dMB",
	report.device.budgets.frameMs, report.device.budgets.drawCalls, report.device.budgets.parts, report.device.budgets.memoryMB))
print(string.format("  quality preset     : renderScale=%.2f lodBias=%.2f vfx=%.2f npcTick=%d",
	report.quality.renderScale, report.quality.lodBias, report.quality.vfxDensity, report.quality.npcTickRate))
for _, f in ipairs(verification.failures) do warn("[ARKHER] self-test failed: " .. f.key .. " -> " .. tostring(f.error)) end
print(string.rep("=", 68))

-- 5. publish the live engine so game code and the ARKHER HUD can use it
local shared_ = ReplicatedStorage:FindFirstChild("ARKHER_RUNTIME")
if not shared_ then
	shared_ = Instance.new("Folder")
	shared_.Name = "ARKHER_RUNTIME"
	shared_.Parent = ReplicatedStorage
end
local status = Instance.new("StringValue")
status.Name = "Status"
status.Value = string.format("ARKHER %s online | %d systems | %d/%d self-tests passed | %s tier",
	report.version, report.systems, verification.passed, verification.total, report.device.tier)
status.Parent = shared_

local systemsValue = Instance.new("IntValue")
systemsValue.Name = "SystemCount"
systemsValue.Value = report.systems
systemsValue.Parent = shared_

local qualityValue = Instance.new("NumberValue")
qualityValue.Name = "QualityLevel"
qualityValue.Value = engine.do15.controller.level
qualityValue.Parent = shared_

local fpsValue = Instance.new("NumberValue")
fpsValue.Name = "FrameMs"
fpsValue.Value = 0
fpsValue.Parent = shared_

_G.ARKHER = engine
_G.ARKHER_LOADER = A

-- 6. drive the engine frame loop; D-O15 keeps the frame inside the device budget
RunService.Heartbeat:Connect(function(dt)
	local frameMs = engine:step(dt)
	fpsValue.Value = frameMs or 0
	qualityValue.Value = engine.do15.controller.level
end)

-- 7. ship the mobile-first HUD to every player
local hudTemplate = ARKHER_ROOT:FindFirstChild("ARKHER_HUD", true)
if hudTemplate then
	local function give(player)
		local clone = hudTemplate:Clone()
		clone.Parent = player:WaitForChild("PlayerGui")
	end
	Players.PlayerAdded:Connect(give)
	for _, p in ipairs(Players:GetPlayers()) do task.spawn(give, p) end
end
