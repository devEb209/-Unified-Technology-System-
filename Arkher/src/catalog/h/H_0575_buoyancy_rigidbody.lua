-- ARKHER SYSTEM H.0575 :: Buoyancy Body Dynamics
-- Category H - PHYSICS
-- ARKHER Physics Abstraction capability: mass, contact, constraint and motion, deterministic and budgeted.
-- Kit: rigidbody (integration, impulses, damping and sleeping of a body)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "H.0575"
	S.key = "arkher.physics.buoyancy.body_dynamics"
	S.name = "Buoyancy Body Dynamics"
	S.category = "H"
	S.family = "PHYSICS"
	S.area = "Buoyancy"
	S.aspect = "Body Dynamics"
	S.kit = "rigidbody"
	S.version = "1.0.0"
	S.deps = {  }
	S.tags = { "h", "buoyancy", "rigidbody", "physics" }
	S.description = "Buoyancy Body Dynamics: integration, impulses, damping and sleeping of a body for the Buoyancy subsystem."
	S.params = {
		backlogLimit = 19,
		baseRadius = 280,
		baseWeight = 0.81,
		bias = 0.11,
		biasWeight = 0.16,
		ceiling = 339,
		detailWeight = 0.71,
		failureTolerance = 1,
		horizon = 4,
		integrator = "verlet",
		minConfidence = 0.51,
		minThrottle = 0.205,
		regressionSlope = 0.105,
		saturation = 0.76,
		scale = 3.1
	}
	S.features = { "setMass", "addForce", "addTorque", "applyImpulse", "wake", "sleep", "integrateBody", "kineticEnergy", "momentum", "teleport", "stats", "integrateBody", "simulate", "launch", "restAt", "fallHeight", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("rigidbody", { id = "arkher.physics.buoyancy.body_dynamics", mass = 12.00, radius = 0.85, restitution = 0.51, friction = 0.61, gravityScale = 1 })
		inst.system = S
		inst.ctx = ctx

		local stepBody = inst.integrate
		function inst.integrateBody(dt, gravity) return stepBody(dt, gravity) end
		function inst.simulate(dt, steps, gravity)
			local g = gravity or Vec.vec3(0, -9.81, 0)
			for _ = 1, (steps or 8) do stepBody(dt or (1 / 60), g) end
			return inst.position
		end
		function inst.launch(direction, power)
			inst.wake()
			inst.applyImpulse(direction * (power or 10))
			return inst.velocity
		end
		function inst.restAt(position)
			inst.teleport(position or Vec.vec3())
			inst.velocity = Vec.vec3()
			inst.angularVelocity = Vec.vec3()
			return inst.position
		end
		function inst.fallHeight(seconds, gravity)
			local start = inst.position.y
			inst.simulate(1 / 60, math.floor((seconds or 1) * 60), gravity)
			return start - inst.position.y
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
				engine.bus:subscribe("arkher.physics.buoyancy.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		inst.restAt(Vec.vec3(0, 10, 0))
		local dropped = inst.fallHeight(0.2, Vec.vec3(0, -10, 0))
		local ok = dropped > 0 and inst.velocity.y < 0
		inst.launch(Vec.vec3(0, 1, 0), 100)
		ok = ok and inst.velocity.y > 0 and inst.kineticEnergy() > 0
		ok = ok and inst.momentum():length() > 0
		inst.restAt(Vec.vec3())
		return ok and inst.stats().steps > 0
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
