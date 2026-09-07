-- ARKHER SYSTEM G.0073 :: Disocclusion Handling Temporal History
-- Category G - NEURAL / RECONSTRUCTION
-- ARKHER Reconstruction and Neural Intelligence capability: predict, reconstruct and verify instead of brute force.
-- Kit: temporal (history buffers reused across frames)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "G.0073"
	S.key = "arkher.neural.disocclusion.temporal_history"
	S.name = "Disocclusion Handling Temporal History"
	S.category = "G"
	S.family = "NEURAL / RECONSTRUCTION"
	S.area = "Disocclusion Handling"
	S.aspect = "Temporal History"
	S.kit = "temporal"
	S.version = "1.0.0"
	S.deps = { "arkher.neural.disocclusion.feature_extraction" }
	S.tags = { "g", "disocclusion", "temporal", "neural" }
	S.description = "Disocclusion Handling Temporal History: history buffers reused across frames for the Disocclusion Handling subsystem."
	S.params = {
		backlogLimit = 46,
		baseRadius = 240,
		baseWeight = 0.88,
		bias = 0.38,
		biasWeight = 0.23,
		ceiling = 174,
		detailWeight = 0.58,
		failureTolerance = 3,
		horizon = 7,
		integrator = "euler",
		minConfidence = 0.78,
		minThrottle = 0.14,
		regressionSlope = 0.14,
		saturation = 0.83,
		scale = 1.8
	}
	S.features = { "jitter", "advance", "reproject", "clamp", "resolve", "accumulationOf", "effectiveSamples", "purge", "reset", "stats", "frameJitter", "accumulate", "stabilize", "samplesFor", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("temporal", { id = "arkher.neural.disocclusion.temporal_history", feedback = 0.88, phase = 8 })
		inst.system = S
		inst.ctx = ctx

		function inst.frameJitter(index)
			return inst.jitter(index or inst.frame)
		end
		function inst.accumulate(key, value, motion)
			inst.advance()
			return inst.resolve(key or S.key, value or 1, { motion = motion or 0 })
		end
		function inst.stabilize(value, neighbors)
			return inst.clamp(value, neighbors or { 0.2, 0.25, 0.3 })
		end
		function inst.samplesFor(key)
			return inst.effectiveSamples(key or S.key)
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
				engine.bus:subscribe("arkher.neural.disocclusion.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		local jx, jy = inst.frameJitter(1)
		local jx2 = inst.frameJitter(2)
		local ok = jx ~= jx2 and math.abs(jy) <= 0.5
		local first = inst.accumulate(S.key, 0, 0)
		ok = ok and first == 0
		local second = inst.accumulate(S.key, 1, 0)
		ok = ok and second > 0 and second < 1
		ok = ok and inst.accumulationOf(S.key) == 2
		ok = ok and inst.samplesFor(S.key) >= 1
		local clamped, wasClamped = inst.stabilize(9.0)
		ok = ok and wasClamped == true and clamped < 1
		local reset = inst.accumulate(S.key, 0.5, 9999)
		ok = ok and reset == 0.5
		inst.reset()
		return ok and inst.stats().tracked == 0
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
