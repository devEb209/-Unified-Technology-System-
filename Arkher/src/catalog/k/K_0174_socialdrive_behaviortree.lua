-- ARKHER SYSTEM K.0174 :: Social Drive Reactive Behaviour
-- Category K - NPC / NEURAL MIND NETWORK
-- ARKHER NMN capability: minds that perceive, remember, feel, plan, move and live together.
-- Kit: behaviortree (sequences, selectors, decorators and cooldowns)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "K.0174"
	S.key = "arkher.npc.socialdrive.reactive_behaviour"
	S.name = "Social Drive Reactive Behaviour"
	S.category = "K"
	S.family = "NPC / NEURAL MIND NETWORK"
	S.area = "Social Drive"
	S.aspect = "Reactive Behaviour"
	S.kit = "behaviortree"
	S.version = "1.0.0"
	S.deps = { "arkher.npc.socialdrive.perception" }
	S.tags = { "k", "socialdrive", "behaviortree", "npc" }
	S.description = "Social Drive Reactive Behaviour: sequences, selectors, decorators and cooldowns for the Social Drive subsystem."
	S.params = {
		backlogLimit = 23,
		baseRadius = 280,
		baseWeight = 0.55,
		bias = 0.15,
		biasWeight = 0.2,
		ceiling = 135,
		detailWeight = 0.35,
		failureTolerance = 0,
		horizon = 8,
		integrator = "verlet",
		minConfidence = 0.55,
		minThrottle = 0.175,
		regressionSlope = 0.125,
		saturation = 0.75,
		scale = 2.5
	}
	S.features = { "addNode", "attach", "setRoot", "set", "get", "tick", "depth", "reset", "stats", "buildRoutine", "runRoutine", "successRate", "nodeCount", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("behaviortree", { id = "arkher.npc.socialdrive.reactive_behaviour" })
		inst.system = S
		inst.ctx = ctx

		function inst.buildRoutine()
			if #inst.order > 0 then return #inst.order end
			inst.addNode("root", "selector")
			inst.addNode("threatSeq", "sequence")
			inst.addNode("isThreat", "condition",
				{ condition = function(bb) return bb.threat == true end })
			inst.addNode("flee", "action",
				{ action = function(bb) bb.doing = "flee" return "success" end })
			inst.addNode("work", "action",
				{ action = function(bb) bb.doing = "work" return "success" end })
			inst.attach("root", "threatSeq")
			inst.attach("threatSeq", "isThreat")
			inst.attach("threatSeq", "flee")
			inst.attach("root", "work")
			inst.setRoot("root")
			return #inst.order
		end
		function inst.runRoutine(dt, blackboard)
			inst.buildRoutine()
			if blackboard then
				for k, v in pairs(blackboard) do inst.set(k, v) end
			end
			inst.tick(dt or 0.1)
			return inst.get("doing")
		end
		function inst.successRate()
			local total = inst.successes + inst.failures
			if total == 0 then return 0 end
			return inst.successes / total
		end
		function inst.nodeCount()
			inst.buildRoutine()
			return #inst.order
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
				engine.bus:subscribe("arkher.npc.socialdrive.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		local ok = inst.buildRoutine() == 5
		ok = ok and inst.runRoutine(0.1, { threat = false }) == "work"
		ok = ok and inst.runRoutine(0.1, { threat = true }) == "flee"
		ok = ok and inst.depth() >= 2 and inst.nodeCount() == 5
		ok = ok and inst.successRate() > 0
		inst.reset()
		return ok and inst.stats().nodes == 5
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
