-- ARKHER SYSTEM A.0506 :: Spatial Kernel Audit Ledger
-- Category A - UES / CORE
-- Kernel-level engine capability: the UES foundation every other ARKHER framework stands on.
-- Kit: ledger (append-only journal with sealing and histograms)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "A.0506"
	S.key = "arkher.core.spatial.audit_ledger"
	S.name = "Spatial Kernel Audit Ledger"
	S.category = "A"
	S.family = "UES / CORE"
	S.area = "Spatial Kernel"
	S.aspect = "Audit Ledger"
	S.kit = "ledger"
	S.version = "1.0.0"
	S.deps = { "arkher.core.spatial.predictor" }
	S.tags = { "a", "spatial", "ledger", "core" }
	S.description = "Spatial Kernel Audit Ledger: append-only journal with sealing and histograms for the Spatial Kernel subsystem."
	S.params = {
		backlogLimit = 30,
		baseRadius = 400,
		baseWeight = 0.72,
		bias = 0.22,
		biasWeight = 0.07,
		ceiling = 102,
		detailWeight = 0.62,
		failureTolerance = 2,
		horizon = 7,
		integrator = "euler",
		minConfidence = 0.62,
		minThrottle = 0.16,
		regressionSlope = 0.06,
		saturation = 0.92,
		scale = 2.2
	}
	S.features = { "write", "observe", "query", "seal", "verifySeal", "percentileBucket", "stats", "record", "timing", "digest", "recent", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("ledger", { id = "arkher.core.spatial.audit_ledger", capacity = 422 })
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
				engine.bus:subscribe("arkher.core.spatial.*", function(payload) inst.lastSignal = payload end)
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
