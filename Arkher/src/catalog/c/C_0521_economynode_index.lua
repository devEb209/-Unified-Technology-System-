-- ARKHER SYSTEM C.0521 :: Economy Node Spatial Index
-- Category C - SCENE / WORLD
-- World capability: what exists, where it is, who owns it, and how it keeps living.
-- Kit: index (spatial acceleration of world queries)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "C.0521"
	S.key = "arkher.world.economynode.spatial_index"
	S.name = "Economy Node Spatial Index"
	S.category = "C"
	S.family = "SCENE / WORLD"
	S.area = "Economy Node"
	S.aspect = "Spatial Index"
	S.kit = "index"
	S.version = "1.0.0"
	S.deps = { "arkher.world.economynode.instancing" }
	S.tags = { "c", "economynode", "index", "world" }
	S.description = "Economy Node Spatial Index: spatial acceleration of world queries for the Economy Node subsystem."
	S.params = {
		backlogLimit = 14,
		baseRadius = 240,
		baseWeight = 0.56,
		bias = 0.06,
		biasWeight = 0.11,
		ceiling = 478,
		detailWeight = 0.46,
		failureTolerance = 1,
		horizon = 7,
		integrator = "euler",
		minConfidence = 0.46,
		minThrottle = 0.23,
		regressionSlope = 0.08,
		saturation = 0.76,
		scale = 3.6
	}
	S.features = { "insert", "update", "remove", "queryRadius", "nearest", "count", "stats", "track", "moveTo", "around", "densityAt", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("index", { id = "arkher.world.economynode.spatial_index", mode = "hash", cellSize = 24 })
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
				engine.bus:subscribe("arkher.world.economynode.*", function(payload) inst.lastSignal = payload end)
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
