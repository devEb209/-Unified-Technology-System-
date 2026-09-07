-- ARKHER SYSTEM H.0587 :: Buoyancy Determinism Ledger
-- Category H - PHYSICS
-- ARKHER Physics Abstraction capability: mass, contact, constraint and motion, deterministic and budgeted.
-- Kit: ledger (auditable journal proving reproducible simulation)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "H.0587"
	S.key = "arkher.physics.buoyancy.determinism_ledger"
	S.name = "Buoyancy Determinism Ledger"
	S.category = "H"
	S.family = "PHYSICS"
	S.area = "Buoyancy"
	S.aspect = "Determinism Ledger"
	S.kit = "ledger"
	S.version = "1.0.0"
	S.deps = { "arkher.physics.buoyancy.analysis" }
	S.tags = { "h", "buoyancy", "ledger", "physics" }
	S.description = "Buoyancy Determinism Ledger: auditable journal proving reproducible simulation for the Buoyancy subsystem."
	S.params = {
		backlogLimit = 46,
		baseRadius = 560,
		baseWeight = 0.98,
		bias = 0.38,
		biasWeight = 0.23,
		ceiling = 502,
		detailWeight = 0.78,
		failureTolerance = 3,
		horizon = 7,
		integrator = "euler",
		minConfidence = 0.78,
		minThrottle = 0.24,
		regressionSlope = 0.14,
		saturation = 0.93,
		scale = 3.8
	}
	S.features = { "write", "observe", "query", "seal", "verifySeal", "percentileBucket", "stats", "record", "timing", "digest", "recent", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("ledger", { id = "arkher.physics.buoyancy.determinism_ledger", capacity = 182 })
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
				engine.bus:subscribe("arkher.physics.buoyancy.*", function(payload) inst.lastSignal = payload end)
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
