-- ARKHER SYSTEM P.0369 :: Death And Respawn Difficulty Controller
-- Category P - GAMEPLAY
-- ARKHER Gameplay Framework capability: attributes, items, objectives, combat and progression.
-- Kit: controller (closed-loop tuning toward a target challenge)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "P.0369"
	S.key = "arkher.play.deathrespawn.difficulty_controller"
	S.name = "Death And Respawn Difficulty Controller"
	S.category = "P"
	S.family = "GAMEPLAY"
	S.area = "Death And Respawn"
	S.aspect = "Difficulty Controller"
	S.kit = "controller"
	S.version = "1.0.0"
	S.deps = { "arkher.play.deathrespawn.balance_analysis" }
	S.tags = { "p", "deathrespawn", "controller", "play" }
	S.description = "Death And Respawn Difficulty Controller: closed-loop tuning toward a target challenge for the Death And Respawn subsystem."
	S.params = {
		backlogLimit = 25,
		baseRadius = 520,
		baseWeight = 0.77,
		bias = 0.17,
		biasWeight = 0.22,
		ceiling = 113,
		detailWeight = 0.77,
		failureTolerance = 2,
		horizon = 2,
		integrator = "verlet",
		minConfidence = 0.57,
		minThrottle = 0.235,
		regressionSlope = 0.135,
		saturation = 0.72,
		scale = 3.7
	}
	S.features = { "setTarget", "submit", "step", "reset", "error", "settled", "stats", "regulate", "driveTo", "headroom", "qualityBand", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("controller", { id = "arkher.play.deathrespawn.difficulty_controller", mode = "hysteresis", target = 0.670, kp = 0.520, ki = 0.080, kd = 0.030, min = 0.05, max = 1.0, initial = 0.57, deadband = 0.01 })
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
				engine.bus:subscribe("arkher.play.deathrespawn.*", function(payload) inst.lastSignal = payload end)
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
