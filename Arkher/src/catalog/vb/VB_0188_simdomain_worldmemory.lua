-- ARKHER SYSTEM VB.0188 :: Simulation Domain World Memory Stream
-- Category VB - CONTINUUM — TEMPORAL
-- Continuum Temporal capability: deterministic epoch timeline keeping every domain in sync.
-- Kit: worldmemory (world memory continuum over epochs)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "VB.0188"
	S.key = "arkher.conttime.simdomain.world_memory_stream"
	S.name = "Simulation Domain World Memory Stream"
	S.category = "VB"
	S.family = "CONTINUUM — TEMPORAL"
	S.area = "Simulation Domain"
	S.aspect = "World Memory Stream"
	S.kit = "worldmemory"
	S.version = "1.0.0"
	S.deps = { "arkher.conttime.simdomain.neural_field" }
	S.tags = { "vb", "simdomain", "worldmemory", "conttime" }
	S.description = "Simulation Domain World Memory Stream: world memory continuum over epochs for the Simulation Domain subsystem."
	S.params = {
		backlogLimit = 12,
		baseRadius = 480,
		baseWeight = 0.84,
		bias = 0.04,
		biasWeight = 0.09,
		ceiling = 100,
		detailWeight = 0.64,
		failureTolerance = 4,
		horizon = 5,
		integrator = "euler",
		minConfidence = 0.44,
		minThrottle = 0.17,
		regressionSlope = 0.07,
		saturation = 0.79,
		scale = 2.4
	}
	S.features = { "advanceEpoch", "remember", "advance", "recall", "historyOf", "compact", "summaryOf", "checksum", "checkpoint", "restore", "stats", "log", "story", "save", "load", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("worldmemory", { id = "arkher.conttime.simdomain.world_memory_stream", capacity = 192 })
		inst.system = S
		inst.ctx = ctx

		function inst.log(subject, event, weight)
			return inst.remember(subject or S.key, event or "tick",
				{ weight = weight or 1, region = S.key })
		end
		function inst.story(subject) return inst.historyOf(subject or S.key, 8) end
		function inst.save() return inst.checkpoint(S.key) end
		function inst.load(checkpoint) return inst.restore(checkpoint) end

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
				engine.bus:subscribe("arkher.conttime.simdomain.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		inst.log(S.key, "born", 1)
		inst.advance(1)
		inst.log(S.key, "grew", 2)
		local ok = #inst.story(S.key) == 2
		ok = ok and #inst.recall({ region = S.key }) == 2
		local cp = inst.save()
		inst.log(S.key, "changed", 1)
		ok = ok and inst.checksum() ~= cp.checksum
		ok = ok and inst.load(cp)
		ok = ok and #inst.recall({ subject = S.key }) == 2
		ok = ok and inst.advanceEpoch("next") == 2
		return ok and inst.stats().written >= 3
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
