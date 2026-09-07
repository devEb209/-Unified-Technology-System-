-- ARKHER SYSTEM S.0146 :: Animation Dynamic Scaler
-- Category S - D-O15 OPTIMIZATION
-- D-O15 optimization capability: measure, budget, predict, degrade gracefully, restore.
-- Kit: controller (runtime scaling of workload)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "S.0146"
	S.key = "arkher.do15.animation.dynamic_scaler"
	S.name = "Animation Dynamic Scaler"
	S.category = "S"
	S.family = "D-O15 OPTIMIZATION"
	S.area = "Animation"
	S.aspect = "Dynamic Scaler"
	S.kit = "controller"
	S.version = "1.0.0"
	S.deps = { "arkher.do15.animation.lod_policy" }
	S.tags = { "s", "animation", "controller", "do15" }
	S.description = "Animation Dynamic Scaler: runtime scaling of workload for the Animation subsystem."
	S.params = {
		backlogLimit = 23,
		baseRadius = 600,
		baseWeight = 0.55,
		bias = 0.15,
		biasWeight = 0.2,
		ceiling = 391,
		detailWeight = 0.55,
		failureTolerance = 0,
		horizon = 8,
		integrator = "verlet",
		minConfidence = 0.55,
		minThrottle = 0.125,
		regressionSlope = 0.125,
		saturation = 0.75,
		scale = 1.5
	}
	S.features = { "setTarget", "submit", "step", "reset", "error", "settled", "stats", "regulate", "driveTo", "headroom", "qualityBand", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("controller", { id = "arkher.do15.animation.dynamic_scaler", mode = "bangbang", target = 0.650, kp = 0.300, ki = 0.100, kd = 0.010, min = 0.05, max = 1.0, initial = 0.55, deadband = 0.01 })
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
				engine.bus:subscribe("arkher.do15.animation.*", function(payload) inst.lastSignal = payload end)
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
