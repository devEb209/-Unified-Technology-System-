-- ARKHER :: boot environment spec (the 1.0.1 boot-fix guard)
--
-- On the real Roblox runtime the host globals (game, Instance, task, bit32, os)
-- are NOT entries of _G: they resolve through the script environment metatable.
-- rawget(_G, "game") is nil inside Roblox, which is exactly how 1.0.0 broke:
-- the platform adapter declared the Roblox host unavailable, Engine.boot bound
-- the HEADLESS adapter instead - a zombie engine with a frozen clock, no services
-- and no real device profile - while the boot report still printed normally.
--
-- This spec simulates the Roblox environment faithfully (metatable on _G, host
-- globals reachable only through __index) and proves the engine now detects the
-- host, binds the Roblox adapter and boots the catalog there. It also proves the
-- bit32 backend is selected through the metatable and produces values identical
-- to the arithmetic backend used on plain Lua hosts.
local A = ARKHER
local TestKit = A:import("arkher/kernel/testkit")
local t = TestKit.new()

---------------------------------------------------------------- fake Roblox host
local fakeUIS = { TouchEnabled = true, KeyboardEnabled = false, GamepadEnabled = false,
	VREnabled = false, MouseEnabled = false }
local fakeCamera = { ViewportSize = { X = 812, Y = 375 } }
local fakeWorkspace = { CurrentCamera = fakeCamera }
local fakeStats = { GetTotalMemoryUsageMb = function() return 512 end }
local fakeRunService = { IsServer = function() return true end,
	IsClient = function() return false end, IsStudio = function() return false end,
	Heartbeat = { Connect = function() return {} end } }
local fakePlayers = { GetPlayers = function() return {} end,
	PlayerAdded = { Connect = function() return {} end } }
local fakeServices = {
	UserInputService = fakeUIS, Workspace = fakeWorkspace, Stats = fakeStats,
	RunService = fakeRunService, Players = fakePlayers,
}
local fakeGame = { GetService = function(_, name) return fakeServices[name] end }
local fakeInstance = { new = function(cls)
	return { ClassName = cls, Name = "", Parent = nil, Destroy = function() end }
end }
local fakeTask = { spawn = function(fn, ...) return fn(...) end, delay = function() end }

-- Plain Lua 5.3 has no bit32 library, so the shim is built from ARKHER's own
-- arithmetic backend: identical values, which is exactly what is asserted below.
local BitsArith = A:import("arkher/kernel/bits")
local bit32shim = {
	band = BitsArith.band, bor = BitsArith.bor, bxor = BitsArith.bxor,
	bnot = BitsArith.bnot, lshift = BitsArith.lshift, rshift = BitsArith.rshift,
	lrotate = BitsArith.rotl, rrotate = BitsArith.rotr,
}

-- the Roblox condition: host globals resolve, but rawget cannot see them
local robloxEnv = { game = fakeGame, Instance = fakeInstance, task = fakeTask,
	bit32 = bit32shim, os = os }

local savedMeta = getmetatable(_G)
setmetatable(_G, { __index = robloxEnv })

-- a FRESH loader so every factory re-executes under the simulated environment
local Loader = A:import("arkher/kernel/loader")
local B = Loader.new({ timeFn = os.clock })
for id, factory in pairs(ARKHER_FACTORIES) do B:define(id, factory) end

t:describe("boot fix :: Roblox environment is visible without rawget", function(s)
	s:it("host globals resolve through the environment metatable", function(a)
		a:ok(_G.game ~= nil, "_G.game must resolve through __index")
		a:ok(_G.Instance ~= nil, "_G.Instance must resolve through __index")
		a:equal(rawget(_G, "game"), nil, "rawget must NOT see host globals (the 1.0.0 trap)")
		a:equal(rawget(_G, "Instance"), nil, "rawget must NOT see host globals (the 1.0.0 trap)")
	end)

	s:it("bits.lua selects the bit32 backend through the metatable", function(a)
		local Bits = B:import("arkher/kernel/bits")
		a:equal(Bits.backend, "bit32", "inside Roblox the bit32 backend must be selected")
		a:equal(Bits.band(12, 10), BitsArith.band(12, 10))
		a:equal(Bits.bor(12, 10), BitsArith.bor(12, 10))
		a:equal(Bits.bxor(12, 10), BitsArith.bxor(12, 10))
		a:equal(Bits.lshift(7, 4), BitsArith.lshift(7, 4))
		a:equal(Bits.rotl(1, 31), BitsArith.rotl(1, 31))
	end)

	s:it("the platform adapter detects the Roblox host", function(a)
		local RobloxAdapter = B:import("arkher/platform/roblox")
		a:ok(RobloxAdapter.available(), "available() must be true when game resolves via __index")
		local adapter = RobloxAdapter.new()
		a:equal(adapter.kind, "roblox")
		a:ok(adapter.services.Players ~= nil, "Players service must bind")
		a:ok(adapter.services.RunService ~= nil, "RunService must bind")
		a:ok(adapter:isServer(), "the fake RunService reports server")
	end)

	s:it("the adapter clock advances (1.0.0 froze it at 0)", function(a)
		local RobloxAdapter = B:import("arkher/platform/roblox")
		local adapter = RobloxAdapter.new()
		local t1 = adapter:now()
		a:gt(t1, 0, "adapter:now() must use the host clock, not return 0")
		local t2 = adapter:now()
		a:gte(t2, t1, "the adapter clock must be monotonic")
	end)

	s:it("instance creation works through the metatable", function(a)
		local RobloxAdapter = B:import("arkher/platform/roblox")
		local adapter = RobloxAdapter.new()
		local id = adapter:createNode("Folder", "BootFixProbe")
		a:gte(id, 1)
		a:equal(adapter.nodes[id].ClassName, "Folder")
		a:equal(adapter.nodes[id].Name, "BootFixProbe")
	end)

	s:it("device profile comes from the host services", function(a)
		local RobloxAdapter = B:import("arkher/platform/roblox")
		local adapter = RobloxAdapter.new()
		local profile = adapter:deviceProfile()
		a:equal(profile.class, "phone", "touch + no keyboard + small screen = phone")
		a:equal(profile.gpuTier, 1)
		a:ok(profile.touch)
	end)
end)

t:describe("boot fix :: the engine boots on the Roblox adapter", function(s)
	s:it("Engine.boot binds the roblox platform, not headless", function(a)
		local Engine = B:import("arkher/engine")
		local engine = Engine.boot(B, { logLevel = 30 })
		a:equal(engine.platform, "roblox", "the 1.0.0 bug booted 'headless' inside Roblox")
		a:ok(engine.adapterValid, "the adapter must pass the interface spec")
		a:equal(engine.version.CURRENT, "1.0.1")
	end)

	s:it("the catalog loads and self-tests on the Roblox adapter", function(a)
		local Engine = B:import("arkher/engine")
		local engine = Engine.boot(B, { logLevel = 30 })
		local loaded, failed = engine:loadCatalog({ "A" })
		a:equal(failed, 0, "no catalog load failures")
		a:equal(loaded, 520, "category A must load completely")
		local verification = engine:verify()
		a:equal(verification.failed, 0, "no self-test failures")
		a:equal(verification.passed, 520)
	end)

	s:it("the frame loop steps and the report tells the truth", function(a)
		local Engine = B:import("arkher/engine")
		local engine = Engine.boot(B, { logLevel = 30 })
		engine:loadCatalog({ "A" })
		for _ = 1, 10 do
			local frameMs = engine:step(1 / 60)
			a:gte(frameMs, 0)
		end
		local report = engine:report()
		a:equal(report.platform, "roblox")
		a:equal(report.version, "1.0.1")
		a:gte(report.frames, 10)
	end)
end)

t:describe("boot fix :: plain hosts still boot headless", function(s)
	s:it("no game global means no Roblox adapter", function(a)
		-- negative control with the environment metatable removed
		setmetatable(_G, savedMeta)
		local ok, result = pcall(function()
			local FreshLoader = A:import("arkher/kernel/loader")
			local C = FreshLoader.new({ timeFn = os.clock })
			for id, factory in pairs(ARKHER_FACTORIES) do C:define(id, factory) end
			local RobloxAdapter = C:import("arkher/platform/roblox")
			return RobloxAdapter.available()
		end)
		setmetatable(_G, { __index = robloxEnv })
		a:ok(ok, "the negative control must not throw")
		a:equal(result, false, "without host globals the adapter must report unavailable")
	end)
end)

local okRun, runErr = pcall(function()
	local results = t:run()
	local okReport = t:report()
	if not okReport then error("ARKHER boot tests failed") end
end)
setmetatable(_G, savedMeta)
if not okRun then error(runErr) end
