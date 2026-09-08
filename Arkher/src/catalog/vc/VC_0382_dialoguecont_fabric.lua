-- ARKHER SYSTEM VC.0382 :: Dialogue Continuum Simulation Fabric
-- Category VC - CONTINUUM — NEURAL
-- Continuum Neural capability: neural fields, temporal upscaling and coherence over the continuum.
-- Kit: fabric (fabric stepping the continuum domains)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "VC.0382"
	S.key = "arkher.contneural.dialoguecont.simulation_fabric"
	S.name = "Dialogue Continuum Simulation Fabric"
	S.category = "VC"
	S.family = "CONTINUUM — NEURAL"
	S.area = "Dialogue Continuum"
	S.aspect = "Simulation Fabric"
	S.kit = "fabric"
	S.version = "1.0.0"
	S.deps = { "arkher.contneural.dialoguecont.complexity_budget" }
	S.tags = { "vc", "dialoguecont", "fabric", "contneural" }
	S.description = "Dialogue Continuum Simulation Fabric: fabric stepping the continuum domains for the Dialogue Continuum subsystem."
	S.params = {
		backlogLimit = 38,
		baseRadius = 240,
		baseWeight = 0.9,
		bias = 0.3,
		biasWeight = 0.15,
		ceiling = 510,
		detailWeight = 0.7,
		failureTolerance = 0,
		horizon = 7,
		integrator = "euler",
		minConfidence = 0.7,
		minThrottle = 0.2,
		regressionSlope = 0.1,
		saturation = 0.85,
		scale = 3.0
	}
	S.features = { "addDomain", "setRate", "setEnabled", "due", "tick", "run", "channel", "send", "receive", "load", "applyQuality", "stats", "installDomains", "simulate", "publish", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("fabric", { id = "arkher.contneural.dialoguecont.simulation_fabric", budgetMs = 2.5, starvationLimit = 10 })
		inst.system = S
		inst.ctx = ctx

		function inst.installDomains()
			inst.counters = { fast = 0, slow = 0 }
			local counters = inst.counters
			inst.addDomain("fast", { hz = 20, cost = 1, priority = 2,
				step = function() counters.fast = counters.fast + 1 end })
			inst.addDomain("slow", { hz = 2, cost = 1, priority = 1,
				step = function() counters.slow = counters.slow + 1 end })
			return #inst.order
		end
		function inst.simulate(seconds) return inst.run(seconds or 1, 1 / 30) end
		function inst.publish(topic, message)
			return inst.send(topic or "world", message or {})
		end

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
				engine.bus:subscribe("arkher.contneural.dialoguecont.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		local ok = inst.installDomains() == 2
		inst.simulate(1)
		ok = ok and inst.counters.fast > inst.counters.slow
		ok = ok and inst.publish("world", { tick = 1 }) == 1
		ok = ok and #inst.receive("world") == 1
		local before = inst.load()
		inst.applyQuality(0.2)
		return ok and inst.load() < before and inst.stats().steps > 0
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
