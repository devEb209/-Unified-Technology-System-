-- ARKHER SYSTEM H.0299 :: Capsule Collider Query
-- Category H - PHYSICS
-- ARKHER Physics Abstraction capability: mass, contact, constraint and motion, deterministic and budgeted.
-- Kit: raycaster (rays, sweeps and overlaps against the simulation)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "H.0299"
	S.key = "arkher.physics.capsulecollider.query"
	S.name = "Capsule Collider Query"
	S.category = "H"
	S.family = "PHYSICS"
	S.area = "Capsule Collider"
	S.aspect = "Query"
	S.kit = "raycaster"
	S.version = "1.0.0"
	S.deps = { "arkher.physics.capsulecollider.constraint_solver" }
	S.tags = { "h", "capsulecollider", "raycaster", "physics" }
	S.description = "Capsule Collider Query: rays, sweeps and overlaps against the simulation for the Capsule Collider subsystem."
	S.params = {
		backlogLimit = 37,
		baseRadius = 360,
		baseWeight = 0.89,
		bias = 0.29,
		biasWeight = 0.14,
		ceiling = 317,
		detailWeight = 0.49,
		failureTolerance = 4,
		horizon = 6,
		integrator = "verlet",
		minConfidence = 0.69,
		minThrottle = 0.245,
		regressionSlope = 0.095,
		saturation = 0.84,
		scale = 3.9
	}
	S.features = { "register", "unregister", "update", "raycast", "raycastAll", "spherecast", "overlapSphere", "nearby", "stats", "seedLine", "probeAlongX", "firstId", "clearAll", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("raycaster", { id = "arkher.physics.capsulecollider.query", cellSize = 48 })
		inst.system = S
		inst.ctx = ctx

		function inst.seedLine(count, spacing)
			for i = 1, (count or 4) do
				inst.register(Kits.create("collider", { id = S.key .. "." .. i, shape = "sphere",
					center = Vec.vec3(i * (spacing or 4), 0, 0), radius = 1 }))
			end
			return #inst.order
		end
		function inst.probeAlongX(originX)
			return inst.raycast(Vec.vec3(originX or -10, 0, 0), Vec.vec3(1, 0, 0), 500)
		end
		function inst.firstId(originX)
			local hit = inst.probeAlongX(originX)
			if not hit then return nil end
			return hit.id
		end
		function inst.clearAll()
			local removed = 0
			while #inst.order > 0 do
				if inst.unregister(inst.order[1]) then removed = removed + 1 else break end
			end
			return removed
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
				engine.bus:subscribe("arkher.physics.capsulecollider.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		inst.clearAll()
		local ok = inst.seedLine(4, 4) == 4
		local hit = inst.probeAlongX(-10)
		ok = ok and hit ~= nil and hit.distance > 0
		ok = ok and inst.firstId(-10) == S.key .. ".1"
		ok = ok and #inst.raycastAll(Vec.vec3(-10, 0, 0), Vec.vec3(1, 0, 0), 500) >= 4
		ok = ok and inst.spherecast(Vec.vec3(-10, 0, 0), Vec.vec3(1, 0, 0), 0.5, 500) ~= nil
		ok = ok and #inst.overlapSphere(Vec.vec3(4, 0, 0), 1.5) >= 1
		ok = ok and inst.raycast(Vec.vec3(-10, 80, 0), Vec.vec3(1, 0, 0), 500) == nil
		ok = ok and inst.clearAll() == 4
		return ok
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
