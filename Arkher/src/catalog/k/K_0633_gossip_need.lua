-- ARKHER SYSTEM K.0633 :: Gossip Drive System
-- Category K - NPC / NEURAL MIND NETWORK
-- ARKHER NMN capability: minds that perceive, remember, feel, plan, move and live together.
-- Kit: need (drives that decay, turn urgent and get satisfied)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "K.0633"
	S.key = "arkher.npc.gossip.drive_system"
	S.name = "Gossip Drive System"
	S.category = "K"
	S.family = "NPC / NEURAL MIND NETWORK"
	S.area = "Gossip"
	S.aspect = "Drive System"
	S.kit = "need"
	S.version = "1.0.0"
	S.deps = { "arkher.npc.gossip.memory" }
	S.tags = { "k", "gossip", "need", "npc" }
	S.description = "Gossip Drive System: drives that decay, turn urgent and get satisfied for the Gossip subsystem."
	S.params = {
		backlogLimit = 46,
		baseRadius = 400,
		baseWeight = 0.88,
		bias = 0.38,
		biasWeight = 0.23,
		ceiling = 254,
		detailWeight = 0.38,
		failureTolerance = 3,
		horizon = 7,
		integrator = "euler",
		minConfidence = 0.78,
		minThrottle = 0.19,
		regressionSlope = 0.14,
		saturation = 0.83,
		scale = 2.8
	}
	S.features = { "define", "tick", "satisfy", "urgency", "mostUrgent", "vector", "wellbeing", "stats", "installDrives", "starve", "critical", "satisfyAll", "deficit", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("need", { id = "arkher.npc.gossip.drive_system" })
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
				engine.bus:subscribe("arkher.npc.gossip.*", function(payload) inst.lastSignal = payload end)
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
