-- ARKHER SYSTEM Z.0266 :: Living Ecosystem Engine Emergence Detection
-- Category Z - ARKHER ORIGINAL TECHNOLOGIES
-- ARKHER original technology: the capabilities that exist in no other engine, built for a world that keeps living.
-- Kit: emergence (co-occurrence lift that names behaviour nobody scripted)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "Z.0266"
	S.key = "arkher.origin.livingecosystem.emergence_detection"
	S.name = "Living Ecosystem Engine Emergence Detection"
	S.category = "Z"
	S.family = "ARKHER ORIGINAL TECHNOLOGIES"
	S.area = "Living Ecosystem Engine"
	S.aspect = "Emergence Detection"
	S.kit = "emergence"
	S.version = "1.0.0"
	S.deps = { "arkher.origin.livingecosystem.world_memory" }
	S.tags = { "z", "livingecosystem", "emergence", "origin" }
	S.description = "Living Ecosystem Engine Emergence Detection: co-occurrence lift that names behaviour nobody scripted for the Living Ecosystem Engine subsystem."
	S.params = {
		backlogLimit = 19,
		baseRadius = 280,
		baseWeight = 0.61,
		bias = 0.11,
		biasWeight = 0.16,
		ceiling = 91,
		detailWeight = 0.71,
		failureTolerance = 1,
		horizon = 4,
		integrator = "verlet",
		minConfidence = 0.51,
		minThrottle = 0.205,
		regressionSlope = 0.105,
		saturation = 0.81,
		scale = 3.1
	}
	S.features = { "observe", "signal", "deviation", "lift", "detect", "novelty", "named", "forget", "stats", "watch", "trend", "detected", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("emergence", { id = "arkher.origin.livingecosystem.emergence_detection", windowSize = 7, threshold = 1.30, minCount = 3 })
		inst.system = S
		inst.ctx = ctx

		function inst.watch(event, weight) return inst.observe(event, weight) end
		function inst.trend(name, value) return inst.signal(name, value) end
		function inst.detected() return inst.detect() end

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
				engine.bus:subscribe("arkher.origin.livingecosystem.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		for i = 1, 6 do
			inst.watch("rain")
			inst.watch("flood")
			inst.watch("noise" .. i)
		end
		local found = inst.detected()
		local ok = #found > 0 and inst.lift("rain", "flood") > 1
		for _ = 1, 10 do inst.trend("level", 0.5) end
		ok = ok and math.abs(inst.deviation("level")) < 0.001
		inst.trend("level", 4)
		ok = ok and inst.deviation("level") > 1
		ok = ok and #inst.named() > 0
		return ok and inst.novelty("rain") < inst.novelty("unheard")
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
