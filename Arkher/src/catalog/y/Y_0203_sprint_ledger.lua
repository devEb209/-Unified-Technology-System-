-- ARKHER SYSTEM Y.0203 :: Sprint Change Ledger
-- Category Y - COLLABORATION / PRODUCTION
-- Collaboration capability: many creators, one project, with review, merge, release and audit.
-- Kit: ledger (auditable journal of production changes)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "Y.0203"
	S.key = "arkher.collab.sprint.change_ledger"
	S.name = "Sprint Change Ledger"
	S.category = "Y"
	S.family = "COLLABORATION / PRODUCTION"
	S.area = "Sprint"
	S.aspect = "Change Ledger"
	S.kit = "ledger"
	S.version = "1.0.0"
	S.deps = { "arkher.collab.sprint.merge_engine" }
	S.tags = { "y", "sprint", "ledger", "collab" }
	S.description = "Sprint Change Ledger: auditable journal of production changes for the Sprint subsystem."
	S.params = {
		backlogLimit = 10,
		baseRadius = 400,
		baseWeight = 0.72,
		bias = 0.02,
		biasWeight = 0.07,
		ceiling = 274,
		detailWeight = 0.62,
		failureTolerance = 2,
		horizon = 3,
		integrator = "euler",
		minConfidence = 0.42,
		minThrottle = 0.16,
		regressionSlope = 0.06,
		saturation = 0.92,
		scale = 2.2
	}
	S.features = { "write", "observe", "query", "seal", "verifySeal", "percentileBucket", "stats", "record", "timing", "digest", "recent", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("ledger", { id = "arkher.collab.sprint.change_ledger", capacity = 338 })
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
				engine.bus:subscribe("arkher.collab.sprint.*", function(payload) inst.lastSignal = payload end)
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
