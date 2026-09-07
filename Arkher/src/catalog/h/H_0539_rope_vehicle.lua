-- ARKHER SYSTEM H.0539 :: Rope Simulation Vehicle
-- Category H - PHYSICS
-- ARKHER Physics Abstraction capability: mass, contact, constraint and motion, deterministic and budgeted.
-- Kit: vehicle (suspension, drivetrain, steering and tire friction)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "H.0539"
	S.key = "arkher.physics.rope.vehicle"
	S.name = "Rope Simulation Vehicle"
	S.category = "H"
	S.family = "PHYSICS"
	S.area = "Rope Simulation"
	S.aspect = "Vehicle"
	S.kit = "vehicle"
	S.version = "1.0.0"
	S.deps = { "arkher.physics.rope.character_motion" }
	S.tags = { "h", "rope", "vehicle", "physics" }
	S.description = "Rope Simulation Vehicle: suspension, drivetrain, steering and tire friction for the Rope Simulation subsystem."
	S.params = {
		backlogLimit = 9,
		baseRadius = 520,
		baseWeight = 0.71,
		bias = 0.01,
		biasWeight = 0.06,
		ceiling = 449,
		detailWeight = 0.41,
		failureTolerance = 1,
		horizon = 2,
		integrator = "verlet",
		minConfidence = 0.41,
		minThrottle = 0.205,
		regressionSlope = 0.055,
		saturation = 0.91,
		scale = 3.1
	}
	S.features = { "addWheel", "standardChassis", "updateSuspension", "engineTorque", "gearRatio", "shiftUp", "shiftDown", "autoShift", "steerAngles", "tireForce", "step", "speedKmh", "stats", "ready", "drive", "brakeTo", "gripAt", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("vehicle", { id = "arkher.physics.rope.vehicle", mass = 1400, wheelbase = 3.10, track = 1.50, maxRpm = 6500 })
		inst.system = S
		inst.ctx = ctx

		function inst.ready()
			inst.standardChassis()
			inst.updateSuspension(function() return 0.25 end, 1 / 60)
			return #inst.wheels
		end
		function inst.drive(seconds, throttle, steer)
			inst.ready()
			local steps = math.max(1, math.floor((seconds or 1) * 60))
			for _ = 1, steps do
				inst.step(1 / 60, { throttle = throttle or 1, steer = steer or 0 })
			end
			return inst.speedKmh()
		end
		function inst.brakeTo(seconds)
			local steps = math.max(1, math.floor((seconds or 1) * 60))
			for _ = 1, steps do inst.step(1 / 60, { throttle = 0, brake = 1 }) end
			return inst.speedKmh()
		end
		function inst.gripAt(load, slip)
			inst.ready()
			local wheel = inst.wheels[1]
			wheel.load = load or 3000
			local fx, fy = inst.tireForce(wheel, slip or 0.1, 0.05, 1.1)
			return math.sqrt(fx * fx + fy * fy)
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
				engine.bus:subscribe("arkher.physics.rope.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		local ok = inst.ready() == 4
		local fast = inst.drive(1.5, 1, 0)
		ok = ok and fast > 1 and inst.rpm > inst.idleRpm
		local slow = inst.brakeTo(0.5)
		ok = ok and slow <= fast
		local inner, outer = inst.steerAngles(1)
		ok = ok and inner > 0 and math.abs(inner) >= math.abs(outer)
		ok = ok and inst.gripAt(3000, 0.2) > 0
		ok = ok and inst.gearRatio() > 0 and inst.engineTorque(3000) > 0
		return ok and inst.stats().wheels == 4
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
