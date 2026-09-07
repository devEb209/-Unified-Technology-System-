-- ARKHER SYSTEM T.0205 :: City Generation Working Memory
-- Category T - SINGULARITY AI
-- Singularity AI capability: understand, know, plan, act, judge - the intelligence that drives the whole engine.
-- Kit: memory (decaying, consolidating recall of what the agent learned)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "T.0205"
	S.key = "arkher.ai.citygeneration.working_memory"
	S.name = "City Generation Working Memory"
	S.category = "T"
	S.family = "SINGULARITY AI"
	S.area = "City Generation"
	S.aspect = "Working Memory"
	S.kit = "memory"
	S.version = "1.0.0"
	S.deps = { "arkher.ai.citygeneration.outcome_prediction" }
	S.tags = { "t", "citygeneration", "memory", "ai" }
	S.description = "City Generation Working Memory: decaying, consolidating recall of what the agent learned for the City Generation subsystem."
	S.params = {
		backlogLimit = 41,
		baseRadius = 200,
		baseWeight = 0.83,
		bias = 0.33,
		biasWeight = 0.18,
		ceiling = 273,
		detailWeight = 0.33,
		failureTolerance = 3,
		horizon = 2,
		integrator = "verlet",
		minConfidence = 0.73,
		minThrottle = 0.165,
		regressionSlope = 0.115,
		saturation = 0.78,
		scale = 2.3
	}
	S.features = { "remember", "tick", "recall", "recallNear", "strongest", "consolidate", "knows", "factCount", "forget", "stats", "rememberBatch", "reinforceFact", "mostSalient", "pressure", "age", "summary", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("memory", { id = "arkher.ai.citygeneration.working_memory", capacity = 81, decayRate = 0.035, consolidateAt = 3 })
		inst.system = S
		inst.ctx = ctx

		function inst.rememberBatch(list)
			local n = 0
			for _, e in ipairs(list) do
				inst.remember(e.kind, e.payload or {}, e.salience or 0.5, e.position)
				n = n + 1
			end
			return n
		end
		function inst.reinforceFact(kind, times)
			for _ = 1, (times or inst.consolidateAt) do
				inst.remember(kind, { rehearsed = true }, 0.7)
			end
			return inst.consolidate()
		end
		function inst.mostSalient()
			local best = nil
			for _, e in ipairs(inst.episodes) do
				if not best or e.salience > best.salience then best = e end
			end
			return best
		end
		function inst.pressure() return #inst.episodes / math.max(1, inst.capacity) end
		function inst.age(seconds)
			inst.tick(seconds or 1)
			return inst.time
		end
		function inst.summary()
			local kinds = {}
			for _, e in ipairs(inst.episodes) do kinds[e.kind] = (kinds[e.kind] or 0) + 1 end
			return kinds
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
				engine.bus:subscribe("arkher.ai.citygeneration.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		local n = inst.rememberBatch({
			{ kind = "seen", salience = 0.8, position = Vec.vec3(1, 0, 0) },
			{ kind = "heard", salience = 0.3 } })
		local ok = n == 2 and #inst.recall("seen") == 1
		ok = ok and inst.mostSalient().kind == "seen"
		ok = ok and #inst.recallNear(Vec.vec3(1, 0, 0), 3) == 1
		inst.reinforceFact("seen", inst.consolidateAt + 1)
		ok = ok and inst.knows("seen") and inst.factCount() >= 1
		inst.age(2)
		return ok and inst.pressure() > 0 and inst.summary().seen ~= nil
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
