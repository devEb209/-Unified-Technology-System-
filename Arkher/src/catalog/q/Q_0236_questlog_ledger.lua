-- ARKHER SYSTEM Q.0236 :: Quest Log Interaction Ledger
-- Category Q - UI / UX
-- ARKHER Interface Framework capability: responsive, themed, accessible interfaces on every device.
-- Kit: ledger (auditable journal of what the player actually touched)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "Q.0236"
	S.key = "arkher.ui.questlog.interaction_ledger"
	S.name = "Quest Log Interaction Ledger"
	S.category = "Q"
	S.family = "UI / UX"
	S.area = "Quest Log"
	S.aspect = "Interaction Ledger"
	S.kit = "ledger"
	S.version = "1.0.0"
	S.deps = { "arkher.ui.questlog.localization_registry" }
	S.tags = { "q", "questlog", "ledger", "ui" }
	S.description = "Quest Log Interaction Ledger: auditable journal of what the player actually touched for the Quest Log subsystem."
	S.params = {
		backlogLimit = 16,
		baseRadius = 480,
		baseWeight = 0.68,
		bias = 0.08,
		biasWeight = 0.13,
		ceiling = 192,
		detailWeight = 0.28,
		failureTolerance = 3,
		horizon = 1,
		integrator = "euler",
		minConfidence = 0.48,
		minThrottle = 0.14,
		regressionSlope = 0.09,
		saturation = 0.88,
		scale = 1.8
	}
	S.features = { "write", "observe", "query", "seal", "verifySeal", "percentileBucket", "stats", "record", "timing", "digest", "recent", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("ledger", { id = "arkher.ui.questlog.interaction_ledger", capacity = 896 })
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
				engine.bus:subscribe("arkher.ui.questlog.*", function(payload) inst.lastSignal = payload end)
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
