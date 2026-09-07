-- ARKHER SYSTEM H.0450 :: Distance Joint Collision Shape
-- Category H - PHYSICS
-- ARKHER Physics Abstraction capability: mass, contact, constraint and motion, deterministic and budgeted.
-- Kit: collider (shape bounds, support mapping and closest points)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "H.0450"
	S.key = "arkher.physics.distancejoint.collision_shape"
	S.name = "Distance Joint Collision Shape"
	S.category = "H"
	S.family = "PHYSICS"
	S.area = "Distance Joint"
	S.aspect = "Collision Shape"
	S.kit = "collider"
	S.version = "1.0.0"
	S.deps = { "arkher.physics.distancejoint.body_dynamics" }
	S.tags = { "h", "distancejoint", "collider", "physics" }
	S.description = "Distance Joint Collision Shape: shape bounds, support mapping and closest points for the Distance Joint subsystem."
	S.params = {
		backlogLimit = 15,
		baseRadius = 600,
		baseWeight = 0.57,
		bias = 0.07,
		biasWeight = 0.12,
		ceiling = 535,
		detailWeight = 0.67,
		failureTolerance = 2,
		horizon = 8,
		integrator = "verlet",
		minConfidence = 0.47,
		minThrottle = 0.185,
		regressionSlope = 0.085,
		saturation = 0.77,
		scale = 2.7
	}
	S.features = { "setCenter", "aabb", "volume", "segment", "support", "closestPoint", "contains", "expandedBy", "expandedAABB", "stats", "placeAt", "boundsSize", "overlaps", "penetration", "widestAxis", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("collider", { id = "arkher.physics.distancejoint.collision_shape", shape = "capsule", radius = 2.70, height = 2.30, layer = "vehicle" })
		inst.system = S
		inst.ctx = ctx

		function inst.placeAt(x, y, z) return inst.setCenter(Vec.vec3(x, y, z)) end
		function inst.boundsSize()
			local box = inst.aabb()
			return box.max - box.min
		end
		function inst.overlaps(other)
			local _, distance = other.closestPoint(inst.center)
			return distance <= (inst.shape == "box" and inst.halfExtents:length() or inst.radius)
		end
		function inst.penetration(point)
			local _, distance = inst.closestPoint(point)
			return math.max(0, (inst.shape == "box" and inst.halfExtents:length() or inst.radius) - distance)
		end
		function inst.widestAxis()
			local size = inst.boundsSize()
			if size.x >= size.y and size.x >= size.z then return "x" end
			if size.y >= size.z then return "y" end
			return "z"
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
				engine.bus:subscribe("arkher.physics.distancejoint.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		inst.placeAt(0, 0, 0)
		local ok = inst.volume() > 0 and inst.boundsSize():length() > 0
		ok = ok and inst.contains(inst.center)
		local far = Vec.vec3(500, 500, 500)
		ok = ok and not inst.contains(far)
		local point, distance = inst.closestPoint(far)
		ok = ok and distance > 0 and point:length() > 0
		ok = ok and inst.support(Vec.vec3(1, 0, 0)):length() > 0
		ok = ok and inst.expandedBy(1).volume() > inst.volume()
		return ok and inst.widestAxis() ~= nil
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
