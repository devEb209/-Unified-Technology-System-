-- ARKHER SYSTEM X.0174 :: State Recovery Audit Ledger
-- Category X - SECURITY / RELIABILITY
-- Security and reliability capability: nothing enters the engine unvalidated or ungoverned.
-- Kit: ledger (tamper-evident audit journal)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "X.0174"
	S.key = "arkher.security.staterecovery.audit_ledger"
	S.name = "State Recovery Audit Ledger"
	S.category = "X"
	S.family = "SECURITY / RELIABILITY"
	S.area = "State Recovery"
	S.aspect = "Audit Ledger"
	S.kit = "ledger"
	S.version = "1.0.0"
	S.deps = { "arkher.security.staterecovery.registry" }
	S.tags = { "x", "staterecovery", "ledger", "security" }
	S.description = "State Recovery Audit Ledger: tamper-evident audit journal for the State Recovery subsystem."
	S.params = {
		backlogLimit = 45,
		baseRadius = 360,
		baseWeight = 0.57,
		bias = 0.37,
		biasWeight = 0.22,
		ceiling = 429,
		detailWeight = 0.37,
		failureTolerance = 2,
		horizon = 6,
		integrator = "verlet",
		minConfidence = 0.77,
		minThrottle = 0.185,
		regressionSlope = 0.135,
		saturation = 0.77,
		scale = 2.7
	}
	S.features = { "write", "observe", "query", "seal", "verifySeal", "percentileBucket", "stats", "record", "timing", "digest", "recent", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("ledger", { id = "arkher.security.staterecovery.audit_ledger", capacity = 1005 })
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
				engine.bus:subscribe("arkher.security.staterecovery.*", function(payload) inst.lastSignal = payload end)
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
