-- ARKHER SYSTEM VA.0203 :: Architect District Reality Continuum
-- Category VA - CONTINUUM — WORLD
-- Continuum World capability: infinite, seamless world built on continuum, sparse and multiscale.
-- Kit: reality (stacked reality layers of the continuum)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "VA.0203"
	S.key = "arkher.contworld.architectdistrict.reality_continuum"
	S.name = "Architect District Reality Continuum"
	S.category = "VA"
	S.family = "CONTINUUM — WORLD"
	S.area = "Architect District"
	S.aspect = "Reality Continuum"
	S.kit = "reality"
	S.version = "1.0.0"
	S.deps = { "arkher.contworld.architectdistrict.simulation_fabric" }
	S.tags = { "va", "architectdistrict", "reality", "contworld" }
	S.description = "Architect District Reality Continuum: stacked reality layers of the continuum for the Architect District subsystem."
	S.params = {
		backlogLimit = 43,
		baseRadius = 280,
		baseWeight = 0.55,
		bias = 0.35,
		biasWeight = 0.2,
		ceiling = 547,
		detailWeight = 0.35,
		failureTolerance = 0,
		horizon = 4,
		integrator = "verlet",
		minConfidence = 0.75,
		minThrottle = 0.175,
		regressionSlope = 0.125,
		saturation = 0.75,
		scale = 2.5
	}
	S.features = { "addLayer", "installStack", "set", "get", "setEnabled", "setBlend", "commit", "discard", "keys", "snapshot", "divergence", "stats", "installLayers", "author", "simulate", "propose", "accept", "revert", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("reality", { id = "arkher.contworld.architectdistrict.reality_continuum" })
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
				engine.bus:subscribe("arkher.contworld.architectdistrict.*", function(payload) inst.lastSignal = payload end)
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
