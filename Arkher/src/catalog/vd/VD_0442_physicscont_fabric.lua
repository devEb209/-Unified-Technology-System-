-- ARKHER SYSTEM VD.0442 :: Physics Continuum Simulation Fabric
-- Category VD - CONTINUUM — SIMULATION
-- Continuum Simulation capability: ecology, economy, society and weather stepped through the continuum.
-- Kit: fabric (fabric stepping the continuum domains)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "VD.0442"
	S.key = "arkher.contsim.physicscont.simulation_fabric"
	S.name = "Physics Continuum Simulation Fabric"
	S.category = "VD"
	S.family = "CONTINUUM — SIMULATION"
	S.area = "Physics Continuum"
	S.aspect = "Simulation Fabric"
	S.kit = "fabric"
	S.version = "1.0.0"
	S.deps = { "arkher.contsim.physicscont.complexity_budget" }
	S.tags = { "vd", "physicscont", "fabric", "contsim" }
	S.description = "Physics Continuum Simulation Fabric: fabric stepping the continuum domains for the Physics Continuum subsystem."
	S.params = {
		backlogLimit = 41,
		baseRadius = 360,
		baseWeight = 0.63,
		bias = 0.33,
		biasWeight = 0.18,
		ceiling = 289,
		detailWeight = 0.73,
		failureTolerance = 3,
		horizon = 2,
		integrator = "verlet",
		minConfidence = 0.73,
		minThrottle = 0.215,
		regressionSlope = 0.115,
		saturation = 0.83,
		scale = 3.3
	}
	S.features = { "addDomain", "setRate", "setEnabled", "due", "tick", "run", "channel", "send", "receive", "load", "applyQuality", "stats", "installDomains", "simulate", "publish", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("fabric", { id = "arkher.contsim.physicscont.simulation_fabric", budgetMs = 4.0, starvationLimit = 5 })
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
				engine.bus:subscribe("arkher.contsim.physicscont.*", function(payload) inst.lastSignal = payload end)
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
