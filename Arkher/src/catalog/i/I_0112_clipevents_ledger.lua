-- ARKHER SYSTEM I.0112 :: Clip Events Event Ledger
-- Category I - ANIMATION
-- ARKHER Animation Framework capability: skeletons, clips, layers, IK and physical blending.
-- Kit: ledger (auditable journal of animation events fired)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "I.0112"
	S.key = "arkher.anim.clipevents.event_ledger"
	S.name = "Clip Events Event Ledger"
	S.category = "I"
	S.family = "ANIMATION"
	S.area = "Clip Events"
	S.aspect = "Event Ledger"
	S.kit = "ledger"
	S.version = "1.0.0"
	S.deps = { "arkher.anim.clipevents.compression_codec" }
	S.tags = { "i", "clipevents", "ledger", "anim" }
	S.description = "Clip Events Event Ledger: auditable journal of animation events fired for the Clip Events subsystem."
	S.params = {
		backlogLimit = 46,
		baseRadius = 240,
		baseWeight = 0.88,
		bias = 0.38,
		biasWeight = 0.23,
		ceiling = 94,
		detailWeight = 0.58,
		failureTolerance = 3,
		horizon = 7,
		integrator = "euler",
		minConfidence = 0.78,
		minThrottle = 0.14,
		regressionSlope = 0.14,
		saturation = 0.83,
		scale = 1.8
	}
	S.features = { "write", "observe", "query", "seal", "verifySeal", "percentileBucket", "stats", "record", "timing", "digest", "recent", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("ledger", { id = "arkher.anim.clipevents.event_ledger", capacity = 542 })
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
				engine.bus:subscribe("arkher.anim.clipevents.*", function(payload) inst.lastSignal = payload end)
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
