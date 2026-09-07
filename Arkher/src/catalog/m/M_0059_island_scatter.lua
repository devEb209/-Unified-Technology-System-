-- ARKHER SYSTEM M.0059 :: Island Distribution
-- Category M - PROCEDURAL
-- Procedural capability: deterministic synthesis of worlds, cities, structures and detail from a seed.
-- Kit: scatter (blue-noise distribution with masks)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "M.0059"
	S.key = "arkher.proc.island.distribution"
	S.name = "Island Distribution"
	S.category = "M"
	S.family = "PROCEDURAL"
	S.area = "Island"
	S.aspect = "Distribution"
	S.kit = "scatter"
	S.version = "1.0.0"
	S.deps = { "arkher.proc.island.constraint_solver" }
	S.tags = { "m", "island", "scatter", "proc" }
	S.description = "Island Distribution: blue-noise distribution with masks for the Island subsystem."
	S.params = {
		backlogLimit = 33,
		baseRadius = 520,
		baseWeight = 0.65,
		bias = 0.25,
		biasWeight = 0.1,
		ceiling = 497,
		detailWeight = 0.65,
		failureTolerance = 0,
		horizon = 2,
		integrator = "verlet",
		minConfidence = 0.65,
		minThrottle = 0.175,
		regressionSlope = 0.075,
		saturation = 0.85,
		scale = 2.5
	}
	S.features = { "addMask", "generate", "filterBySlope", "cluster", "minimumSpacing", "stats", "distribute", "spacing", "prune", "coverage", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("scatter", { id = "arkher.proc.island.distribution", seed = 31665, minDistance = 17, density = 1.05 })
		inst.system = S
		inst.ctx = ctx

		function inst.distribute(bounds, attempts)
			local Spatial = A:import("arkher/kernel/spatial")
			local box = bounds or Spatial.aabb(Vec.vec3(0, 0, 0), Vec.vec3(200, 0, 200))
			return inst.generate(box, attempts or 200)
		end
		function inst.spacing()
			if #inst.points == 0 then inst.distribute() end
			return inst.minimumSpacing()
		end
		function inst.prune(predicate)
			local kept = {}
			for _, p in ipairs(inst.points) do
				if predicate(p) then kept[#kept + 1] = p end
			end
			local removed = #inst.points - #kept
			inst.points = kept
			return removed
		end
		function inst.coverage(area)
			if #inst.points == 0 then inst.distribute() end
			return #inst.points / math.max(1, area or 40000)
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
				engine.bus:subscribe("arkher.proc.island.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		local points = inst.distribute(nil, 200)
		local ok = #points > 0
		ok = ok and inst.spacing() >= (#points > 1 and inst.minDistance or 0)
		ok = ok and inst.stats().rejected >= 0
		local removed = inst.prune(function(p) return p.x <= 100 end)
		ok = ok and removed >= 0
		for _, p in ipairs(inst.points) do ok = ok and p.x <= 100 end
		ok = ok and inst.coverage(40000) >= 0
		return ok
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
