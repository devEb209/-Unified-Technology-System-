-- ARKHER SYSTEM A.0116 :: Dependency Audit Ledger
-- Category A - UES / CORE
-- Kernel-level engine capability: the UES foundation every other ARKHER framework stands on.
-- Kit: ledger (append-only journal with sealing and histograms)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "A.0116"
	S.key = "arkher.core.dependency.audit_ledger"
	S.name = "Dependency Audit Ledger"
	S.category = "A"
	S.family = "UES / CORE"
	S.area = "Dependency"
	S.aspect = "Audit Ledger"
	S.kit = "ledger"
	S.version = "1.0.0"
	S.deps = { "arkher.core.dependency.predictor" }
	S.tags = { "a", "dependency", "ledger", "core" }
	S.description = "Dependency Audit Ledger: append-only journal with sealing and histograms for the Dependency subsystem."
	S.params = {
		backlogLimit = 28,
		baseRadius = 160,
		baseWeight = 0.9,
		bias = 0.2,
		biasWeight = 0.05,
		ceiling = 332,
		detailWeight = 0.2,
		failureTolerance = 0,
		horizon = 5,
		integrator = "euler",
		minConfidence = 0.6,
		minThrottle = 0.1,
		regressionSlope = 0.05,
		saturation = 0.85,
		scale = 1.0
	}
	S.features = { "write", "observe", "query", "seal", "verifySeal", "percentileBucket", "stats", "record", "timing", "digest", "recent", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("ledger", { id = "arkher.core.dependency.audit_ledger", capacity = 780 })
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
				engine.bus:subscribe("arkher.core.dependency.*", function(payload) inst.lastSignal = payload end)
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
