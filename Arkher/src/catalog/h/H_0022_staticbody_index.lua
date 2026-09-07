-- ARKHER SYSTEM H.0022 :: Static Body Broadphase Index
-- Category H - PHYSICS
-- ARKHER Physics Abstraction capability: mass, contact, constraint and motion, deterministic and budgeted.
-- Kit: index (spatial acceleration of candidate pair finding)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "H.0022"
	S.key = "arkher.physics.staticbody.broadphase_index"
	S.name = "Static Body Broadphase Index"
	S.category = "H"
	S.family = "PHYSICS"
	S.area = "Static Body"
	S.aspect = "Broadphase Index"
	S.kit = "index"
	S.version = "1.0.0"
	S.deps = { "arkher.physics.staticbody.vehicle" }
	S.tags = { "h", "staticbody", "index", "physics" }
	S.description = "Static Body Broadphase Index: spatial acceleration of candidate pair finding for the Static Body subsystem."
	S.params = {
		backlogLimit = 10,
		baseRadius = 560,
		baseWeight = 0.92,
		bias = 0.02,
		biasWeight = 0.07,
		ceiling = 362,
		detailWeight = 0.42,
		failureTolerance = 2,
		horizon = 3,
		integrator = "euler",
		minConfidence = 0.42,
		minThrottle = 0.21,
		regressionSlope = 0.06,
		saturation = 0.87,
		scale = 3.2
	}
	S.features = { "insert", "update", "remove", "queryRadius", "nearest", "count", "stats", "track", "moveTo", "around", "densityAt", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("index", { id = "arkher.physics.staticbody.broadphase_index", mode = "hash", cellSize = 88 })
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
				engine.bus:subscribe("arkher.physics.staticbody.*", function(payload) inst.lastSignal = payload end)
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
