-- ARKHER SYSTEM P.0279 :: Combat Objectives
-- Category P - GAMEPLAY
-- ARKHER Gameplay Framework capability: attributes, items, objectives, combat and progression.
-- Kit: quest (objectives, prerequisites, progress and rewards)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "P.0279"
	S.key = "arkher.play.combatsys.objectives"
	S.name = "Combat Objectives"
	S.category = "P"
	S.family = "GAMEPLAY"
	S.area = "Combat"
	S.aspect = "Objectives"
	S.kit = "quest"
	S.version = "1.0.0"
	S.deps = { "arkher.play.combatsys.inventory" }
	S.tags = { "p", "combatsys", "quest", "play" }
	S.description = "Combat Objectives: objectives, prerequisites, progress and rewards for the Combat subsystem."
	S.params = {
		backlogLimit = 45,
		baseRadius = 200,
		baseWeight = 0.77,
		bias = 0.37,
		biasWeight = 0.22,
		ceiling = 149,
		detailWeight = 0.57,
		failureTolerance = 2,
		horizon = 6,
		integrator = "verlet",
		minConfidence = 0.77,
		minThrottle = 0.135,
		regressionSlope = 0.135,
		saturation = 0.72,
		scale = 1.7
	}
	S.features = { "define", "addObjective", "start", "canStart", "unlockAvailable", "notify", "isComplete", "complete", "fail", "progress", "active", "stateOf", "recent", "stats", "installChain", "begin", "report", "completion", "openQuests", "abandon", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("quest", { id = "arkher.play.combatsys.objectives" })
		inst.system = S
		inst.ctx = ctx

		function inst.installChain()
			if #inst.order > 0 then return #inst.order end
			inst.define("scout", { rewards = { xp = 40 } })
			inst.addObjective("scout", "markers", { required = 2, event = "reach.marker" })
			inst.define("secure", { requires = { "scout" }, rewards = { xp = 90 } })
			inst.addObjective("secure", "threats", { required = 1, event = "clear.threat" })
			return #inst.order
		end
		function inst.begin(name)
			inst.installChain()
			return inst.start(name or "scout")
		end
		function inst.report(event, amount)
			inst.installChain()
			return inst.notify(event or "reach.marker", amount or 1)
		end
		function inst.completion()
			inst.installChain()
			local total = 0
			for _, name in ipairs(inst.order) do total = total + inst.progress(name) end
			return total / math.max(1, #inst.order)
		end
		function inst.openQuests()
			inst.installChain()
			local out = {}
			for _, name in ipairs(inst.order) do
				if inst.stateOf(name) == "available" then out[#out + 1] = name end
			end
			return out
		end
		function inst.abandon(name)
			inst.installChain()
			return inst.fail(name or "scout")
		end

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
				engine.bus:subscribe("arkher.play.combatsys.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		local ok = inst.installChain() == 2
		ok = ok and #inst.openQuests() == 1
		ok = ok and inst.begin("scout")
		inst.report("reach.marker", 1)
		ok = ok and inst.progress("scout") > 0 and inst.progress("scout") < 1
		inst.report("reach.marker", 1)
		ok = ok and inst.stateOf("scout") == "completed"
		ok = ok and inst.stateOf("secure") == "available"
		ok = ok and inst.begin("secure")
		inst.report("clear.threat", 1)
		ok = ok and inst.isComplete("secure")
		return ok and inst.completion() > 0.9 and inst.stats().completed == 2
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
