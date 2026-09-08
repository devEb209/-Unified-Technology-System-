-- ARKHER SYSTEM VD.0044 :: Continuum Stream World Memory Stream
-- Category VD - CONTINUUM — SIMULATION
-- Continuum Simulation capability: ecology, economy, society and weather stepped through the continuum.
-- Kit: worldmemory (world memory continuum over epochs)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "VD.0044"
	S.key = "arkher.contsim.continuumstream.world_memory_stream"
	S.name = "Continuum Stream World Memory Stream"
	S.category = "VD"
	S.family = "CONTINUUM — SIMULATION"
	S.area = "Continuum Stream"
	S.aspect = "World Memory Stream"
	S.kit = "worldmemory"
	S.version = "1.0.0"
	S.deps = { "arkher.contsim.continuumstream.neural_field" }
	S.tags = { "vd", "continuumstream", "worldmemory", "contsim" }
	S.description = "Continuum Stream World Memory Stream: world memory continuum over epochs for the Continuum Stream subsystem."
	S.params = {
		backlogLimit = 19,
		baseRadius = 280,
		baseWeight = 0.91,
		bias = 0.11,
		biasWeight = 0.16,
		ceiling = 363,
		detailWeight = 0.71,
		failureTolerance = 1,
		horizon = 4,
		integrator = "verlet",
		minConfidence = 0.51,
		minThrottle = 0.205,
		regressionSlope = 0.105,
		saturation = 0.86,
		scale = 3.1
	}
	S.features = { "advanceEpoch", "remember", "advance", "recall", "historyOf", "compact", "summaryOf", "checksum", "checkpoint", "restore", "stats", "log", "story", "save", "load", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("worldmemory", { id = "arkher.contsim.continuumstream.world_memory_stream", capacity = 160 })
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
				engine.bus:subscribe("arkher.contsim.continuumstream.*", function(payload) inst.lastSignal = payload end)
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
