-- ARKHER SYSTEM VB.0155 :: Persistence Segment Reality Continuum
-- Category VB - CONTINUUM — TEMPORAL
-- Continuum Temporal capability: deterministic epoch timeline keeping every domain in sync.
-- Kit: reality (stacked reality layers of the continuum)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "VB.0155"
	S.key = "arkher.conttime.persistsegment.reality_continuum"
	S.name = "Persistence Segment Reality Continuum"
	S.category = "VB"
	S.family = "CONTINUUM — TEMPORAL"
	S.area = "Persistence Segment"
	S.aspect = "Reality Continuum"
	S.kit = "reality"
	S.version = "1.0.0"
	S.deps = { "arkher.conttime.persistsegment.simulation_fabric" }
	S.tags = { "vb", "persistsegment", "reality", "conttime" }
	S.description = "Persistence Segment Reality Continuum: stacked reality layers of the continuum for the Persistence Segment subsystem."
	S.params = {
		backlogLimit = 32,
		baseRadius = 320,
		baseWeight = 0.64,
		bias = 0.24,
		biasWeight = 0.09,
		ceiling = 264,
		detailWeight = 0.24,
		failureTolerance = 4,
		horizon = 1,
		integrator = "euler",
		minConfidence = 0.64,
		minThrottle = 0.12,
		regressionSlope = 0.07,
		saturation = 0.84,
		scale = 1.4
	}
	S.features = { "addLayer", "installStack", "set", "get", "setEnabled", "setBlend", "commit", "discard", "keys", "snapshot", "divergence", "stats", "installLayers", "author", "simulate", "propose", "accept", "revert", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("reality", { id = "arkher.conttime.persistsegment.reality_continuum" })
		inst.system = S
		inst.ctx = ctx

		function inst.installLayers() return inst.installStack() end
		function inst.author(key, value) return inst.set("authored", key, value) end
		function inst.simulate(key, value) return inst.set("simulated", key, value) end
		function inst.propose(key, value) return inst.set("proposed", key, value) end
		function inst.accept() return inst.commit("proposed", "simulated") end
		function inst.revert() return inst.discard("proposed") end

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
				engine.bus:subscribe("arkher.conttime.persistsegment.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		local ok = inst.installLayers() >= 4
		inst.author(S.key .. ".value", 10)
		ok = ok and inst.get(S.key .. ".value") == 10
		inst.simulate(S.key .. ".value", 20)
		ok = ok and inst.get(S.key .. ".value") == 20
		inst.propose(S.key .. ".value", 30)
		ok = ok and inst.get(S.key .. ".value") == 30
		ok = ok and inst.revert() == 1 and inst.get(S.key .. ".value") == 20
		inst.propose(S.key .. ".value", 40)
		ok = ok and inst.accept() == 1 and inst.get(S.key .. ".value") == 40
		return ok and inst.divergence("authored") > 0 and #inst.keys() == 1
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
