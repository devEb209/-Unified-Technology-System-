-- ARKHER SYSTEM Z.0441 :: Player Absence Simulation Reality Layering
-- Category Z - ARKHER ORIGINAL TECHNOLOGIES
-- ARKHER original technology: the capabilities that exist in no other engine, built for a world that keeps living.
-- Kit: reality (stacked authored, simulated, proposed and player realities)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "Z.0441"
	S.key = "arkher.origin.playerabsence.reality_layering"
	S.name = "Player Absence Simulation Reality Layering"
	S.category = "Z"
	S.family = "ARKHER ORIGINAL TECHNOLOGIES"
	S.area = "Player Absence Simulation"
	S.aspect = "Reality Layering"
	S.kit = "reality"
	S.version = "1.0.0"
	S.deps = {  }
	S.tags = { "z", "playerabsence", "reality", "origin" }
	S.description = "Player Absence Simulation Reality Layering: stacked authored, simulated, proposed and player realities for the Player Absence Simulation subsystem."
	S.params = {
		backlogLimit = 28,
		baseRadius = 320,
		baseWeight = 0.9,
		bias = 0.2,
		biasWeight = 0.05,
		ceiling = 380,
		detailWeight = 0.6,
		failureTolerance = 0,
		horizon = 5,
		integrator = "euler",
		minConfidence = 0.6,
		minThrottle = 0.15,
		regressionSlope = 0.05,
		saturation = 0.85,
		scale = 2.0
	}
	S.features = { "addLayer", "installStack", "set", "get", "setEnabled", "setBlend", "commit", "discard", "keys", "snapshot", "divergence", "stats", "installLayers", "author", "simulate", "propose", "accept", "revert", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("reality", { id = "arkher.origin.playerabsence.reality_layering" })
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
				engine.bus:subscribe("arkher.origin.playerabsence.*", function(payload) inst.lastSignal = payload end)
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
