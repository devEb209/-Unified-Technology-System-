-- ARKHER SYSTEM S.0490 :: Culling Telemetry
-- Category S - D-O15 OPTIMIZATION
-- D-O15 optimization capability: measure, budget, predict, degrade gracefully, restore.
-- Kit: ledger (counters, histograms and percentile export)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "S.0490"
	S.key = "arkher.do15.culling.telemetry"
	S.name = "Culling Telemetry"
	S.category = "S"
	S.family = "D-O15 OPTIMIZATION"
	S.area = "Culling"
	S.aspect = "Telemetry"
	S.kit = "ledger"
	S.version = "1.0.0"
	S.deps = { "arkher.do15.culling.streaming_governor" }
	S.tags = { "s", "culling", "ledger", "do15" }
	S.description = "Culling Telemetry: counters, histograms and percentile export for the Culling subsystem."
	S.params = {
		backlogLimit = 34,
		baseRadius = 560,
		baseWeight = 0.76,
		bias = 0.26,
		biasWeight = 0.11,
		ceiling = 346,
		detailWeight = 0.66,
		failureTolerance = 1,
		horizon = 3,
		integrator = "euler",
		minConfidence = 0.66,
		minThrottle = 0.18,
		regressionSlope = 0.08,
		saturation = 0.71,
		scale = 2.6
	}
	S.features = { "write", "observe", "query", "seal", "verifySeal", "percentileBucket", "stats", "record", "timing", "digest", "recent", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("ledger", { id = "arkher.do15.culling.telemetry", capacity = 794 })
		inst.system = S
		inst.ctx = ctx

	function inst.record(operation, payload) return inst.write(operation, payload) end
	function inst.timing(ms) return inst.observe(ms) end
	function inst.digest()
		return { seal = inst.seal(), written = inst.written, p95 = inst.percentileBucket(95) }
	end
	function inst.recent(kind, limit) return inst.query(kind, limit or 10) end

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
				engine.bus:subscribe("arkher.do15.culling.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		inst.record("probe", { v = 1 })
		inst.record("probe", { v = 2 })
		inst.timing(4) inst.timing(40)
		local d = inst.digest()
		return d.written == 2 and inst.verifySeal() and #inst.recent("probe") == 2
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
