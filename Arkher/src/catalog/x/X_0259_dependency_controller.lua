-- ARKHER SYSTEM X.0259 :: Dependency Validation Trust Controller
-- Category X - SECURITY / RELIABILITY
-- Security and reliability capability: nothing enters the engine unvalidated or ungoverned.
-- Kit: controller (adaptive trust scoring)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "X.0259"
	S.key = "arkher.security.dependency.trust_controller"
	S.name = "Dependency Validation Trust Controller"
	S.category = "X"
	S.family = "SECURITY / RELIABILITY"
	S.area = "Dependency Validation"
	S.aspect = "Trust Controller"
	S.kit = "controller"
	S.version = "1.0.0"
	S.deps = { "arkher.security.dependency.integrity_codec" }
	S.tags = { "x", "dependency", "controller", "security" }
	S.description = "Dependency Validation Trust Controller: adaptive trust scoring for the Dependency Validation subsystem."
	S.params = {
		backlogLimit = 27,
		baseRadius = 440,
		baseWeight = 0.89,
		bias = 0.19,
		biasWeight = 0.24,
		ceiling = 555,
		detailWeight = 0.39,
		failureTolerance = 4,
		horizon = 4,
		integrator = "verlet",
		minConfidence = 0.59,
		minThrottle = 0.195,
		regressionSlope = 0.145,
		saturation = 0.84,
		scale = 2.9
	}
	S.features = { "setTarget", "submit", "step", "reset", "error", "settled", "stats", "regulate", "driveTo", "headroom", "qualityBand", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("controller", { id = "arkher.security.dependency.trust_controller", mode = "bangbang", target = 0.690, kp = 0.440, ki = 0.030, kd = 0.050, min = 0.05, max = 1.0, initial = 0.59, deadband = 0.01 })
		inst.system = S
		inst.ctx = ctx

	function inst.regulate(measured, dt)
		inst.submit(measured)
		return inst.step(dt or 1 / 60)
	end
	function inst.driveTo(target, samples, dt)
		inst.setTarget(target)
		for _ = 1, (samples or 20) do inst.regulate(inst.value, dt) end
		return inst.value
	end
	function inst.headroom() return math.max(0, inst.max - inst.value) end
	function inst.qualityBand()
		local v = (inst.value - inst.min) / math.max(1e-9, inst.max - inst.min)
		if v > 0.85 then return "ultra" elseif v > 0.6 then return "high"
		elseif v > 0.35 then return "medium" elseif v > 0.15 then return "low" end
		return "minimum"
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
				engine.bus:subscribe("arkher.security.dependency.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		inst.reset()
		local settled = inst.driveTo(0.7, 60, 0.05)
		local ok = type(settled) == "number" and settled >= inst.min and settled <= inst.max
		return ok and type(inst.qualityBand()) == "string" 
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
