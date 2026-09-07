-- ARKHER SYSTEM W.0285 :: Depth Of Field Event Ledger
-- Category W - CINEMATIC
-- ARKHER Cinematic Framework capability: shots, sequences, camera language, grading and playback.
-- Kit: ledger (auditable journal of every cue the sequence fired)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "W.0285"
	S.key = "arkher.cine.depthoffield.event_ledger"
	S.name = "Depth Of Field Event Ledger"
	S.category = "W"
	S.family = "CINEMATIC"
	S.area = "Depth Of Field"
	S.aspect = "Event Ledger"
	S.kit = "ledger"
	S.version = "1.0.0"
	S.deps = { "arkher.cine.depthoffield.cinematic_mix" }
	S.tags = { "w", "depthoffield", "ledger", "cine" }
	S.description = "Depth Of Field Event Ledger: auditable journal of every cue the sequence fired for the Depth Of Field subsystem."
	S.params = {
		backlogLimit = 31,
		baseRadius = 440,
		baseWeight = 0.63,
		bias = 0.23,
		biasWeight = 0.08,
		ceiling = 215,
		detailWeight = 0.63,
		failureTolerance = 3,
		horizon = 8,
		integrator = "verlet",
		minConfidence = 0.63,
		minThrottle = 0.165,
		regressionSlope = 0.065,
		saturation = 0.83,
		scale = 2.3
	}
	S.features = { "write", "observe", "query", "seal", "verifySeal", "percentileBucket", "stats", "record", "timing", "digest", "recent", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("ledger", { id = "arkher.cine.depthoffield.event_ledger", capacity = 407 })
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
				engine.bus:subscribe("arkher.cine.depthoffield.*", function(payload) inst.lastSignal = payload end)
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
