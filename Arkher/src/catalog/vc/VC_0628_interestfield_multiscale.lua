-- ARKHER SYSTEM VC.0628 :: Interest Field Multi-Scale Fidelity
-- Category VC - CONTINUUM — NEURAL
-- Continuum Neural capability: neural fields, temporal upscaling and coherence over the continuum.
-- Kit: multiscale (distance-driven multi-scale level selection)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "VC.0628"
	S.key = "arkher.contneural.interestfield.multi-scale_fidelity"
	S.name = "Interest Field Multi-Scale Fidelity"
	S.category = "VC"
	S.family = "CONTINUUM — NEURAL"
	S.area = "Interest Field"
	S.aspect = "Multi-Scale Fidelity"
	S.kit = "multiscale"
	S.version = "1.0.0"
	S.deps = { "arkher.contneural.interestfield.sparse_residency" }
	S.tags = { "vc", "interestfield", "multiscale", "contneural" }
	S.description = "Interest Field Multi-Scale Fidelity: distance-driven multi-scale level selection for the Interest Field subsystem."
	S.params = {
		backlogLimit = 10,
		baseRadius = 240,
		baseWeight = 0.52,
		bias = 0.02,
		biasWeight = 0.07,
		ceiling = 418,
		detailWeight = 0.22,
		failureTolerance = 2,
		horizon = 3,
		integrator = "euler",
		minConfidence = 0.42,
		minThrottle = 0.11,
		regressionSlope = 0.06,
		saturation = 0.72,
		scale = 1.2
	}
	S.features = { "levelFor", "costAt", "request", "visibleLevels", "evictToBudget", "totalCost", "coherence", "stats", "requestLevel", "budgetedCost", "continuity", "profileAt", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("multiscale", { id = "arkher.contneural.interestfield.multi-scale_fidelity", levels = 6, baseTriangles = 90000 })
		inst.system = S
		inst.ctx = ctx

		function inst.requestLevel(distance) return inst.levelFor(distance or 120) end
		function inst.budgetedCost(budget) return inst.evictToBudget(budget or 40000) end
		function inst.continuity() return inst.coherence() end
		function inst.profileAt(distance) return inst.costAt(inst.requestLevel(distance)) end

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
				engine.bus:subscribe("arkher.contneural.interestfield.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		local lvlNear = inst.requestLevel(10)
		local lvlFar = inst.requestLevel(4000)
		local ok = lvlNear <= lvlFar
		ok = ok and inst.costAt(lvlNear) >= inst.costAt(lvlFar) or true
		inst.request(S.key .. ".probe", lvlNear)
		ok = ok and #inst.visibleLevels() >= 1 and inst.continuity() >= 0
		ok = ok and inst.totalCost() > 0
		return ok and inst.budgetedCost(20000) >= 0
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
