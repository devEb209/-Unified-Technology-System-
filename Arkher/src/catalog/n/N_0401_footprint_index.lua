-- ARKHER SYSTEM N.0401 :: Footprint Spatial Index
-- Category N - VFX
-- ARKHER VFX Framework capability: emission, simulation, forces and trails inside one shared budget.
-- Kit: index (spatial acceleration of effect queries and culling)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "N.0401"
	S.key = "arkher.vfx.footprint.spatial_index"
	S.name = "Footprint Spatial Index"
	S.category = "N"
	S.family = "VFX"
	S.area = "Footprint"
	S.aspect = "Spatial Index"
	S.kit = "index"
	S.version = "1.0.0"
	S.deps = { "arkher.vfx.footprint.quality_policy" }
	S.tags = { "n", "footprint", "index", "vfx" }
	S.description = "Footprint Spatial Index: spatial acceleration of effect queries and culling for the Footprint subsystem."
	S.params = {
		backlogLimit = 45,
		baseRadius = 200,
		baseWeight = 0.67,
		bias = 0.37,
		biasWeight = 0.22,
		ceiling = 485,
		detailWeight = 0.57,
		failureTolerance = 2,
		horizon = 6,
		integrator = "verlet",
		minConfidence = 0.77,
		minThrottle = 0.135,
		regressionSlope = 0.135,
		saturation = 0.87,
		scale = 1.7
	}
	S.features = { "insert", "update", "remove", "queryRadius", "nearest", "count", "stats", "track", "moveTo", "around", "densityAt", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("index", { id = "arkher.vfx.footprint.spatial_index", mode = "hash", cellSize = 16 })
		inst.system = S
		inst.ctx = ctx

	function inst.track(id, x, y, z, payload) return inst.insert(id, Vec.vec3(x, y, z), payload) end
	function inst.moveTo(id, x, y, z) return inst.update(id, Vec.vec3(x, y, z)) end
	function inst.around(x, y, z, radius) return inst.queryRadius(Vec.vec3(x, y, z), radius) end
	function inst.densityAt(x, y, z, radius)
		local hits = inst.around(x, y, z, radius)
		local volume = (4 / 3) * math.pi * radius ^ 3
		return #hits / math.max(volume, 1e-6)
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
				engine.bus:subscribe("arkher.vfx.footprint.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		inst.track("probe.1", 0, 0, 0, { kind = "probe" })
		inst.track("probe.2", 500, 0, 0, { kind = "probe" })
		local near = inst.around(0, 0, 0, 64)
		local ok = #near == 1 and near[1].id == "probe.1" and inst.densityAt(0, 0, 0, 64) > 0
		inst.remove("probe.1") inst.remove("probe.2")
		return ok
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
