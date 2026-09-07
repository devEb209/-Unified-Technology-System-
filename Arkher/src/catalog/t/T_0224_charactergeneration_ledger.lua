-- ARKHER SYSTEM T.0224 :: Character Generation Decision Ledger
-- Category T - SINGULARITY AI
-- Singularity AI capability: understand, know, plan, act, judge - the intelligence that drives the whole engine.
-- Kit: ledger (auditable journal of every AI decision and its reason)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "T.0224"
	S.key = "arkher.ai.charactergeneration.decision_ledger"
	S.name = "Character Generation Decision Ledger"
	S.category = "T"
	S.family = "SINGULARITY AI"
	S.area = "Character Generation"
	S.aspect = "Decision Ledger"
	S.kit = "ledger"
	S.version = "1.0.0"
	S.deps = { "arkher.ai.charactergeneration.learning_analysis" }
	S.tags = { "t", "charactergeneration", "ledger", "ai" }
	S.description = "Character Generation Decision Ledger: auditable journal of every AI decision and its reason for the Character Generation subsystem."
	S.params = {
		backlogLimit = 11,
		baseRadius = 440,
		baseWeight = 0.63,
		bias = 0.03,
		biasWeight = 0.08,
		ceiling = 515,
		detailWeight = 0.63,
		failureTolerance = 3,
		horizon = 4,
		integrator = "verlet",
		minConfidence = 0.43,
		minThrottle = 0.165,
		regressionSlope = 0.065,
		saturation = 0.83,
		scale = 2.3
	}
	S.features = { "write", "observe", "query", "seal", "verifySeal", "percentileBucket", "stats", "record", "timing", "digest", "recent", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("ledger", { id = "arkher.ai.charactergeneration.decision_ledger", capacity = 579 })
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
				engine.bus:subscribe("arkher.ai.charactergeneration.*", function(payload) inst.lastSignal = payload end)
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
