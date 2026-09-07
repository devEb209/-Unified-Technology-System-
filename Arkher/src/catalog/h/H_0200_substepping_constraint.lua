-- ARKHER SYSTEM H.0200 :: Substepping Constraint Solver
-- Category H - PHYSICS
-- ARKHER Physics Abstraction capability: mass, contact, constraint and motion, deterministic and budgeted.
-- Kit: constraint (sequential impulses, friction, joints and warm starting)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "H.0200"
	S.key = "arkher.physics.substepping.constraint_solver"
	S.name = "Substepping Constraint Solver"
	S.category = "H"
	S.family = "PHYSICS"
	S.area = "Substepping"
	S.aspect = "Constraint Solver"
	S.kit = "constraint"
	S.version = "1.0.0"
	S.deps = { "arkher.physics.substepping.contact_generation" }
	S.tags = { "h", "substepping", "constraint", "physics" }
	S.description = "Substepping Constraint Solver: sequential impulses, friction, joints and warm starting for the Substepping subsystem."
	S.params = {
		backlogLimit = 35,
		baseRadius = 280,
		baseWeight = 0.77,
		bias = 0.27,
		biasWeight = 0.12,
		ceiling = 523,
		detailWeight = 0.47,
		failureTolerance = 2,
		horizon = 4,
		integrator = "verlet",
		minConfidence = 0.67,
		minThrottle = 0.235,
		regressionSlope = 0.085,
		saturation = 0.72,
		scale = 3.7
	}
	S.features = { "addJoint", "removeJoint", "solveContacts", "correctPositions", "solveJoints", "breakJoint", "clearCache", "stats", "testBodies", "link", "settle", "resolveHit", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("constraint", { id = "arkher.physics.substepping.constraint_solver", iterations = 11, baumgarte = 0.17, warmStart = true })
		inst.system = S
		inst.ctx = ctx

		function inst.testBodies(distance)
			return {
				anchor = Kits.create("rigidbody", { id = S.key .. ".anchor", mass = 0,
					position = Vec.vec3(0, 0, 0) }),
				load = Kits.create("rigidbody", { id = S.key .. ".load", mass = 1,
					position = Vec.vec3(0, distance or 3, 0) }),
			}
		end
		function inst.link(id, a, b, distance, stiffness)
			return inst.addJoint(id, { a = a, b = b, distance = distance, kind = "distance",
				stiffness = stiffness })
		end
		function inst.settle(bodies, steps, dt)
			for _ = 1, (steps or 8) do inst.solveJoints(bodies, dt or (1 / 60)) end
			return inst.stats().solves
		end
		function inst.resolveHit(bodies, depth)
			local manifolds = { { a = "anchor", b = "load", normal = Vec.vec3(0, 1, 0),
				depth = depth or 0.1, point = Vec.vec3(), restitution = 0.2, friction = 0.4 } }
			inst.solveContacts(manifolds, bodies, 1 / 60)
			inst.correctPositions(manifolds, bodies)
			return manifolds
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
		local bodies = inst.testBodies(3)
		bodies.load.velocity = Vec.vec3(0, -4, 0)
		inst.resolveHit(bodies, 0.2)
		local ok = bodies.load.velocity.y > -4
		ok = ok and inst.link("probe", "anchor", "load", 1) ~= nil
		inst.settle(bodies, 12)
		ok = ok and bodies.load.position.y < 3
		ok = ok and inst.removeJoint("probe")
		inst.clearCache()
		return ok and inst.stats().solves > 0
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
