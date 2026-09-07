-- ARKHER SYSTEM M.0045 :: Continent Distribution
-- Category M - PROCEDURAL
-- Procedural capability: deterministic synthesis of worlds, cities, structures and detail from a seed.
-- Kit: scatter (blue-noise distribution with masks)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "M.0045"
	S.key = "arkher.proc.continent.distribution"
	S.name = "Continent Distribution"
	S.category = "M"
	S.family = "PROCEDURAL"
	S.area = "Continent"
	S.aspect = "Distribution"
	S.kit = "scatter"
	S.version = "1.0.0"
	S.deps = { "arkher.proc.continent.constraint_solver" }
	S.tags = { "m", "continent", "scatter", "proc" }
	S.description = "Continent Distribution: blue-noise distribution with masks for the Continent subsystem."
	S.params = {
		backlogLimit = 39,
		baseRadius = 440,
		baseWeight = 0.51,
		bias = 0.31,
		biasWeight = 0.16,
		ceiling = 407,
		detailWeight = 0.51,
		failureTolerance = 1,
		horizon = 8,
		integrator = "verlet",
		minConfidence = 0.71,
		minThrottle = 0.105,
		regressionSlope = 0.105,
		saturation = 0.71,
		scale = 1.1
	}
	S.features = { "addMask", "generate", "filterBySlope", "cluster", "minimumSpacing", "stats", "distribute", "spacing", "prune", "coverage", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("scatter", { id = "arkher.proc.continent.distribution", seed = 43351, minDistance = 13, density = 0.91 })
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
				engine.bus:subscribe("arkher.proc.continent.*", function(payload) inst.lastSignal = payload end)
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
