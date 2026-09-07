-- ARKHER SYSTEM K.0451 :: Crowd Flow Drive System
-- Category K - NPC / NEURAL MIND NETWORK
-- ARKHER NMN capability: minds that perceive, remember, feel, plan, move and live together.
-- Kit: need (drives that decay, turn urgent and get satisfied)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "K.0451"
	S.key = "arkher.npc.crowdflow.drive_system"
	S.name = "Crowd Flow Drive System"
	S.category = "K"
	S.family = "NPC / NEURAL MIND NETWORK"
	S.area = "Crowd Flow"
	S.aspect = "Drive System"
	S.kit = "need"
	S.version = "1.0.0"
	S.deps = { "arkher.npc.crowdflow.memory" }
	S.tags = { "k", "crowdflow", "need", "npc" }
	S.description = "Crowd Flow Drive System: drives that decay, turn urgent and get satisfied for the Crowd Flow subsystem."
	S.params = {
		backlogLimit = 37,
		baseRadius = 520,
		baseWeight = 0.99,
		bias = 0.29,
		biasWeight = 0.14,
		ceiling = 253,
		detailWeight = 0.29,
		failureTolerance = 4,
		horizon = 6,
		integrator = "verlet",
		minConfidence = 0.69,
		minThrottle = 0.145,
		regressionSlope = 0.095,
		saturation = 0.94,
		scale = 1.9
	}
	S.features = { "define", "tick", "satisfy", "urgency", "mostUrgent", "vector", "wellbeing", "stats", "installDrives", "starve", "critical", "satisfyAll", "deficit", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("need", { id = "arkher.npc.crowdflow.drive_system" })
		inst.system = S
		inst.ctx = ctx

		function inst.installDrives()
			if #inst.order > 0 then return #inst.order end
			inst.define("food", { value = 0.7, decay = 0.02, threshold = 0.35 })
			inst.define("rest", { value = 0.8, decay = 0.015, threshold = 0.3 })
			inst.define("safety", { value = 0.9, decay = 0.005, threshold = 0.5 })
			inst.define("social", { value = 0.6, decay = 0.01, threshold = 0.25 })
			return #inst.order
		end
		function inst.starve(name, seconds)
			inst.installDrives()
			inst.tick(seconds or 60)
			return inst.urgency(name)
		end
		function inst.critical(threshold)
			local out = {}
			for _, name in ipairs(inst.order) do
				if inst.urgency(name) > (threshold or 0.5) then out[#out + 1] = name end
			end
			return out
		end
		function inst.satisfyAll(amount)
			for _, name in ipairs(inst.order) do inst.satisfy(name, amount or 1) end
			return inst.wellbeing()
		end
		function inst.deficit() return 1 - inst.wellbeing() end

		function inst.describe()
			return { id = S.id, key = S.key, name = S.name, category = S.category, family = S.family,
				area = S.area, aspect = S.aspect, kit = S.kit, features = S.features,
				params = S.params, stats = inst.stats() }
		end

		function inst.health()
			local st = inst.stats()
			local status = "ok"
			for k, v in pairs(st) do
				if k == "failures" and type(v) == "number" and v > 0 then status = "degraded" end
				if k == "blocked" and type(v) == "number" and v > 0 and status == "ok" then status = "throttled" end
			end
			return { system = S.key, status = status, stats = st }
		end

		function inst.integrate(engine)
			if not engine then return false end
			inst.engine = engine
			if engine.bus then
				engine.bus:subscribe("arkher.npc.crowdflow.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		local ok = inst.installDrives() == 4
		ok = ok and inst.wellbeing() > 0.5
		ok = ok and inst.starve("food", 40) > 0
		ok = ok and #inst.critical(0) > 0
		ok = ok and inst.mostUrgent() ~= nil and #inst.vector() == 4
		return ok and inst.satisfyAll(1) > 0.9 and inst.deficit() < 0.1
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
