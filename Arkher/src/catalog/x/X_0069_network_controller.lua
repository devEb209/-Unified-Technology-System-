-- ARKHER SYSTEM X.0069 :: Network Validation Trust Controller
-- Category X - SECURITY / RELIABILITY
-- Security and reliability capability: nothing enters the engine unvalidated or ungoverned.
-- Kit: controller (adaptive trust scoring)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "X.0069"
	S.key = "arkher.security.network.trust_controller"
	S.name = "Network Validation Trust Controller"
	S.category = "X"
	S.family = "SECURITY / RELIABILITY"
	S.area = "Network Validation"
	S.aspect = "Trust Controller"
	S.kit = "controller"
	S.version = "1.0.0"
	S.deps = { "arkher.security.network.integrity_codec" }
	S.tags = { "x", "network", "controller", "security" }
	S.description = "Network Validation Trust Controller: adaptive trust scoring for the Network Validation subsystem."
	S.params = {
		backlogLimit = 44,
		baseRadius = 160,
		baseWeight = 0.66,
		bias = 0.36,
		biasWeight = 0.21,
		ceiling = 124,
		detailWeight = 0.56,
		failureTolerance = 1,
		horizon = 5,
		integrator = "euler",
		minConfidence = 0.76,
		minThrottle = 0.13,
		regressionSlope = 0.13,
		saturation = 0.86,
		scale = 1.6
	}
	S.features = { "setTarget", "submit", "step", "reset", "error", "settled", "stats", "regulate", "driveTo", "headroom", "qualityBand", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("controller", { id = "arkher.security.network.trust_controller", mode = "pid", target = 0.860, kp = 0.310, ki = 0.050, kd = 0.020, min = 0.05, max = 1.0, initial = 0.76, deadband = 0.01 })
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
				engine.bus:subscribe("arkher.security.network.*", function(payload) inst.lastSignal = payload end)
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
