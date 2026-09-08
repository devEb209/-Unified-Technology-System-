-- ARKHER SYSTEM VB.0394 :: Memory Continuum Simulation Fabric
-- Category VB - CONTINUUM — TEMPORAL
-- Continuum Temporal capability: deterministic epoch timeline keeping every domain in sync.
-- Kit: fabric (fabric stepping the continuum domains)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "VB.0394"
	S.key = "arkher.conttime.memorycont.simulation_fabric"
	S.name = "Memory Continuum Simulation Fabric"
	S.category = "VB"
	S.family = "CONTINUUM — TEMPORAL"
	S.area = "Memory Continuum"
	S.aspect = "Simulation Fabric"
	S.kit = "fabric"
	S.version = "1.0.0"
	S.deps = { "arkher.conttime.memorycont.complexity_budget" }
	S.tags = { "vb", "memorycont", "fabric", "conttime" }
	S.description = "Memory Continuum Simulation Fabric: fabric stepping the continuum domains for the Memory Continuum subsystem."
	S.params = {
		backlogLimit = 10,
		baseRadius = 240,
		baseWeight = 0.92,
		bias = 0.02,
		biasWeight = 0.07,
		ceiling = 178,
		detailWeight = 0.22,
		failureTolerance = 2,
		horizon = 3,
		integrator = "euler",
		minConfidence = 0.42,
		minThrottle = 0.11,
		regressionSlope = 0.06,
		saturation = 0.87,
		scale = 1.2
	}
	S.features = { "addDomain", "setRate", "setEnabled", "due", "tick", "run", "channel", "send", "receive", "load", "applyQuality", "stats", "installDomains", "simulate", "publish", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("fabric", { id = "arkher.conttime.memorycont.simulation_fabric", budgetMs = 2.5, starvationLimit = 6 })
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
				engine.bus:subscribe("arkher.conttime.memorycont.*", function(payload) inst.lastSignal = payload end)
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
