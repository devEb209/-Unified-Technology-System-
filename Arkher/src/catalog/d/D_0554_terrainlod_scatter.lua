-- ARKHER SYSTEM D.0554 :: Terrain LOD Scatter Layer
-- Category D - TERRAIN
-- ARKHER Terrain Framework capability: sculpt, erode, paint, stream and mesh the ground itself.
-- Kit: scatter (blue-noise placement over the surface)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "D.0554"
	S.key = "arkher.terrain.terrainlod.scatter_layer"
	S.name = "Terrain LOD Scatter Layer"
	S.category = "D"
	S.family = "TERRAIN"
	S.area = "Terrain LOD"
	S.aspect = "Scatter Layer"
	S.kit = "scatter"
	S.version = "1.0.0"
	S.deps = { "arkher.terrain.terrainlod.spline_feature" }
	S.tags = { "d", "terrainlod", "scatter", "terrain" }
	S.description = "Terrain LOD Scatter Layer: blue-noise placement over the surface for the Terrain LOD subsystem."
	S.params = {
		backlogLimit = 20,
		baseRadius = 480,
		baseWeight = 0.52,
		bias = 0.12,
		biasWeight = 0.17,
		ceiling = 308,
		detailWeight = 0.52,
		failureTolerance = 2,
		horizon = 5,
		integrator = "euler",
		minConfidence = 0.52,
		minThrottle = 0.11,
		regressionSlope = 0.11,
		saturation = 0.72,
		scale = 1.2
	}
	S.features = { "addMask", "generate", "filterBySlope", "cluster", "minimumSpacing", "stats", "distribute", "spacing", "prune", "coverage", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("scatter", { id = "arkher.terrain.terrainlod.scatter_layer", seed = 30452, minDistance = 8, density = 0.92 })
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
				engine.bus:subscribe("arkher.terrain.terrainlod.*", function(payload) inst.lastSignal = payload end)
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
