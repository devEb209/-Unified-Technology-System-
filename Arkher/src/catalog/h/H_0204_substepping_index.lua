-- ARKHER SYSTEM H.0204 :: Substepping Broadphase Index
-- Category H - PHYSICS
-- ARKHER Physics Abstraction capability: mass, contact, constraint and motion, deterministic and budgeted.
-- Kit: index (spatial acceleration of candidate pair finding)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "H.0204"
	S.key = "arkher.physics.substepping.broadphase_index"
	S.name = "Substepping Broadphase Index"
	S.category = "H"
	S.family = "PHYSICS"
	S.area = "Substepping"
	S.aspect = "Broadphase Index"
	S.kit = "index"
	S.version = "1.0.0"
	S.deps = { "arkher.physics.substepping.vehicle" }
	S.tags = { "h", "substepping", "index", "physics" }
	S.description = "Substepping Broadphase Index: spatial acceleration of candidate pair finding for the Substepping subsystem."
	S.params = {
		backlogLimit = 20,
		baseRadius = 160,
		baseWeight = 0.72,
		bias = 0.12,
		biasWeight = 0.17,
		ceiling = 444,
		detailWeight = 0.32,
		failureTolerance = 2,
		horizon = 5,
		integrator = "euler",
		minConfidence = 0.52,
		minThrottle = 0.16,
		regressionSlope = 0.11,
		saturation = 0.92,
		scale = 2.2
	}
	S.features = { "insert", "update", "remove", "queryRadius", "nearest", "count", "stats", "track", "moveTo", "around", "densityAt", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("index", { id = "arkher.physics.substepping.broadphase_index", mode = "hash", cellSize = 8 })
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
				engine.bus:subscribe("arkher.physics.substepping.*", function(payload) inst.lastSignal = payload end)
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
