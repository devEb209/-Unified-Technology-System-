-- ARKHER SYSTEM H.0073 :: Center Of Mass Contact Generation
-- Category H - PHYSICS
-- ARKHER Physics Abstraction capability: mass, contact, constraint and motion, deterministic and budgeted.
-- Kit: contact (narrow-phase manifolds with normal, depth and point)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "H.0073"
	S.key = "arkher.physics.centerofmass.contact_generation"
	S.name = "Center Of Mass Contact Generation"
	S.category = "H"
	S.family = "PHYSICS"
	S.area = "Center Of Mass"
	S.aspect = "Contact Generation"
	S.kit = "contact"
	S.version = "1.0.0"
	S.deps = { "arkher.physics.centerofmass.collision_shape" }
	S.tags = { "h", "centerofmass", "contact", "physics" }
	S.description = "Center Of Mass Contact Generation: narrow-phase manifolds with normal, depth and point for the Center Of Mass subsystem."
	S.params = {
		backlogLimit = 32,
		baseRadius = 480,
		baseWeight = 0.64,
		bias = 0.24,
		biasWeight = 0.09,
		ceiling = 208,
		detailWeight = 0.64,
		failureTolerance = 4,
		horizon = 1,
		integrator = "euler",
		minConfidence = 0.64,
		minThrottle = 0.17,
		regressionSlope = 0.07,
		saturation = 0.84,
		scale = 2.4
	}
	S.features = { "test", "generate", "deepest", "triggers", "clear", "stats", "pair", "probe", "depthAt", "sweepRange", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("contact", { id = "arkher.physics.centerofmass.contact_generation", slop = 0.0090, maxManifolds = 400 })
		inst.system = S
		inst.ctx = ctx

		function inst.pair(distance)
			local a = Kits.create("collider", { id = S.key .. ".a", shape = "sphere",
				center = Vec.vec3(0, 0, 0), radius = 1 })
			local b = Kits.create("collider", { id = S.key .. ".b", shape = "sphere",
				center = Vec.vec3(distance or 1.5, 0, 0), radius = 1 })
			return a, b
		end
		function inst.probe(distance)
			local a, b = inst.pair(distance)
			return inst.test(a, b)
		end
		function inst.depthAt(distance)
			local manifold = inst.probe(distance)
			if not manifold then return 0 end
			return manifold.depth
		end
		function inst.sweepRange(from, to, steps)
			local hits = 0
			for i = 0, (steps or 4) do
				local d = from + (to - from) * (i / math.max(1, steps or 4))
				if inst.probe(d) then hits = hits + 1 end
			end
			return hits
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
				engine.bus:subscribe("arkher.physics.centerofmass.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		local manifold = inst.probe(1.5)
		local ok = manifold ~= nil and manifold.depth > 0.4 and manifold.depth < 0.6
		ok = ok and inst.probe(50) == nil
		ok = ok and inst.depthAt(1.0) > inst.depthAt(1.8)
		ok = ok and inst.sweepRange(0.5, 3.0, 4) >= 2
		inst.clear()
		return ok and inst.stats().tests > 0
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
