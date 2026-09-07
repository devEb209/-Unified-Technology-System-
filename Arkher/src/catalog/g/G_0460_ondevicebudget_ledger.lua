-- ARKHER SYSTEM G.0460 :: On Device Budget Training Ledger
-- Category G - NEURAL / RECONSTRUCTION
-- ARKHER Reconstruction and Neural Intelligence capability: predict, reconstruct and verify instead of brute force.
-- Kit: ledger (auditable record of training and deployment)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "G.0460"
	S.key = "arkher.neural.ondevicebudget.training_ledger"
	S.name = "On Device Budget Training Ledger"
	S.category = "G"
	S.family = "NEURAL / RECONSTRUCTION"
	S.area = "On Device Budget"
	S.aspect = "Training Ledger"
	S.kit = "ledger"
	S.version = "1.0.0"
	S.deps = { "arkher.neural.ondevicebudget.error_analysis" }
	S.tags = { "g", "ondevicebudget", "ledger", "neural" }
	S.description = "On Device Budget Training Ledger: auditable record of training and deployment for the On Device Budget subsystem."
	S.params = {
		backlogLimit = 23,
		baseRadius = 600,
		baseWeight = 0.95,
		bias = 0.15,
		biasWeight = 0.2,
		ceiling = 343,
		detailWeight = 0.55,
		failureTolerance = 0,
		horizon = 8,
		integrator = "verlet",
		minConfidence = 0.55,
		minThrottle = 0.125,
		regressionSlope = 0.125,
		saturation = 0.9,
		scale = 1.5
	}
	S.features = { "write", "observe", "query", "seal", "verifySeal", "percentileBucket", "stats", "record", "timing", "digest", "recent", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("ledger", { id = "arkher.neural.ondevicebudget.training_ledger", capacity = 663 })
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
				engine.bus:subscribe("arkher.neural.ondevicebudget.*", function(payload) inst.lastSignal = payload end)
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
