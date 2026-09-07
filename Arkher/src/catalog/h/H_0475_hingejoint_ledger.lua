-- ARKHER SYSTEM H.0475 :: Hinge Joint Determinism Ledger
-- Category H - PHYSICS
-- ARKHER Physics Abstraction capability: mass, contact, constraint and motion, deterministic and budgeted.
-- Kit: ledger (auditable journal proving reproducible simulation)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "H.0475"
	S.key = "arkher.physics.hingejoint.determinism_ledger"
	S.name = "Hinge Joint Determinism Ledger"
	S.category = "H"
	S.family = "PHYSICS"
	S.area = "Hinge Joint"
	S.aspect = "Determinism Ledger"
	S.kit = "ledger"
	S.version = "1.0.0"
	S.deps = { "arkher.physics.hingejoint.analysis" }
	S.tags = { "h", "hingejoint", "ledger", "physics" }
	S.description = "Hinge Joint Determinism Ledger: auditable journal proving reproducible simulation for the Hinge Joint subsystem."
	S.params = {
		backlogLimit = 31,
		baseRadius = 600,
		baseWeight = 0.73,
		bias = 0.23,
		biasWeight = 0.08,
		ceiling = 399,
		detailWeight = 0.43,
		failureTolerance = 3,
		horizon = 8,
		integrator = "verlet",
		minConfidence = 0.63,
		minThrottle = 0.215,
		regressionSlope = 0.065,
		saturation = 0.93,
		scale = 3.3
	}
	S.features = { "write", "observe", "query", "seal", "verifySeal", "percentileBucket", "stats", "record", "timing", "digest", "recent", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("ledger", { id = "arkher.physics.hingejoint.determinism_ledger", capacity = 975 })
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
				engine.bus:subscribe("arkher.physics.hingejoint.*", function(payload) inst.lastSignal = payload end)
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
