-- ARKHER SYSTEM U.0021 :: Parser Diagnostics Ledger
-- Category U - SCRIPTING / CODE INTELLIGENCE
-- Scripting capability: reading, understanding, transforming, generating and running ARKHER code.
-- Kit: ledger (append-only journal of code events)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "U.0021"
	S.key = "arkher.code.parser.diagnostics_ledger"
	S.name = "Parser Diagnostics Ledger"
	S.category = "U"
	S.family = "SCRIPTING / CODE INTELLIGENCE"
	S.area = "Parser"
	S.aspect = "Diagnostics Ledger"
	S.kit = "ledger"
	S.version = "1.0.0"
	S.deps = { "arkher.code.parser.compile_cache" }
	S.tags = { "u", "parser", "ledger", "code" }
	S.description = "Parser Diagnostics Ledger: append-only journal of code events for the Parser subsystem."
	S.params = {
		backlogLimit = 40,
		baseRadius = 480,
		baseWeight = 0.82,
		bias = 0.32,
		biasWeight = 0.17,
		ceiling = 408,
		detailWeight = 0.52,
		failureTolerance = 2,
		horizon = 1,
		integrator = "euler",
		minConfidence = 0.72,
		minThrottle = 0.11,
		regressionSlope = 0.11,
		saturation = 0.77,
		scale = 1.2
	}
	S.features = { "write", "observe", "query", "seal", "verifySeal", "percentileBucket", "stats", "record", "timing", "digest", "recent", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("ledger", { id = "arkher.code.parser.diagnostics_ledger", capacity = 984 })
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
				engine.bus:subscribe("arkher.code.parser.*", function(payload) inst.lastSignal = payload end)
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
