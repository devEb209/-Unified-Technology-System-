-- ARKHER SYSTEM S.0163 :: Audio Adaptive Controller
-- Category S - D-O15 OPTIMIZATION
-- D-O15 optimization capability: measure, budget, predict, degrade gracefully, restore.
-- Kit: controller (closed-loop quality regulation)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "S.0163"
	S.key = "arkher.do15.audio.adaptive_controller"
	S.name = "Audio Adaptive Controller"
	S.category = "S"
	S.family = "D-O15 OPTIMIZATION"
	S.area = "Audio"
	S.aspect = "Adaptive Controller"
	S.kit = "controller"
	S.version = "1.0.0"
	S.deps = { "arkher.do15.audio.budget_governor" }
	S.tags = { "s", "audio", "controller", "do15" }
	S.description = "Audio Adaptive Controller: closed-loop quality regulation for the Audio subsystem."
	S.params = {
		backlogLimit = 32,
		baseRadius = 160,
		baseWeight = 0.54,
		bias = 0.24,
		biasWeight = 0.09,
		ceiling = 464,
		detailWeight = 0.44,
		failureTolerance = 4,
		horizon = 1,
		integrator = "euler",
		minConfidence = 0.64,
		minThrottle = 0.22,
		regressionSlope = 0.07,
		saturation = 0.74,
		scale = 3.4
	}
	S.features = { "setTarget", "submit", "step", "reset", "error", "settled", "stats", "regulate", "driveTo", "headroom", "qualityBand", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("controller", { id = "arkher.do15.audio.adaptive_controller", mode = "pid", target = 0.740, kp = 0.490, ki = 0.080, kd = 0.050, min = 0.05, max = 1.0, initial = 0.64, deadband = 0.01 })
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
				engine.bus:subscribe("arkher.do15.audio.*", function(payload) inst.lastSignal = payload end)
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
