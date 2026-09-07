-- ARKHER SYSTEM P.0235 :: Quest Event Ledger
-- Category P - GAMEPLAY
-- ARKHER Gameplay Framework capability: attributes, items, objectives, combat and progression.
-- Kit: ledger (auditable journal of gameplay events)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "P.0235"
	S.key = "arkher.play.questsys.event_ledger"
	S.name = "Quest Event Ledger"
	S.category = "P"
	S.family = "GAMEPLAY"
	S.area = "Quest"
	S.aspect = "Event Ledger"
	S.kit = "ledger"
	S.version = "1.0.0"
	S.deps = { "arkher.play.questsys.rule_pipeline" }
	S.tags = { "p", "questsys", "ledger", "play" }
	S.description = "Quest Event Ledger: auditable journal of gameplay events for the Quest subsystem."
	S.params = {
		backlogLimit = 14,
		baseRadius = 400,
		baseWeight = 0.56,
		bias = 0.06,
		biasWeight = 0.11,
		ceiling = 478,
		detailWeight = 0.26,
		failureTolerance = 1,
		horizon = 7,
		integrator = "euler",
		minConfidence = 0.46,
		minThrottle = 0.13,
		regressionSlope = 0.08,
		saturation = 0.76,
		scale = 1.6
	}
	S.features = { "write", "observe", "query", "seal", "verifySeal", "percentileBucket", "stats", "record", "timing", "digest", "recent", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("ledger", { id = "arkher.play.questsys.event_ledger", capacity = 286 })
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
				engine.bus:subscribe("arkher.play.questsys.*", function(payload) inst.lastSignal = payload end)
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
