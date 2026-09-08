-- ARKHER SYSTEM VD.0321 :: Ecology Continuum Complexity Budget
-- Category VD - CONTINUUM — SIMULATION
-- Continuum Simulation capability: ecology, economy, society and weather stepped through the continuum.
-- Kit: complexity (complexity budgeting for the continuum)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "VD.0321"
	S.key = "arkher.contsim.ecologycont.complexity_budget"
	S.name = "Ecology Continuum Complexity Budget"
	S.category = "VD"
	S.family = "CONTINUUM — SIMULATION"
	S.area = "Ecology Continuum"
	S.aspect = "Complexity Budget"
	S.kit = "complexity"
	S.version = "1.0.0"
	S.deps = { "arkher.contsim.ecologycont.world_memory_stream" }
	S.tags = { "vd", "ecologycont", "complexity", "contsim" }
	S.description = "Ecology Continuum Complexity Budget: complexity budgeting for the continuum for the Ecology Continuum subsystem."
	S.params = {
		backlogLimit = 23,
		baseRadius = 280,
		baseWeight = 0.85,
		bias = 0.15,
		biasWeight = 0.2,
		ceiling = 215,
		detailWeight = 0.35,
		failureTolerance = 0,
		horizon = 8,
		integrator = "verlet",
		minConfidence = 0.55,
		minThrottle = 0.175,
		regressionSlope = 0.125,
		saturation = 0.8,
		scale = 2.5
	}
	S.features = { "addZone", "setCounts", "setImportance", "costOf", "totalCost", "pressure", "classify", "evaluate", "directiveFor", "heaviest", "setTarget", "stats", "installZones", "governFrame", "budgetFor", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("complexity", { id = "arkher.contsim.ecologycont.complexity_budget", targetMs = 14.0 })
		inst.system = S
		inst.ctx = ctx

		function inst.installZones()
			inst.addZone(S.key .. ".core", { objects = 400, agents = 30, lights = 20,
				effects = 6 })
			inst.addZone(S.key .. ".edge", { objects = 120, agents = 6, lights = 4,
				effects = 1 })
			inst.setImportance(S.key .. ".core", 3)
			return inst.totalCost()
		end
		function inst.governFrame(targetMs)
			inst.setTarget(targetMs or 16.6)
			return inst.evaluate()
		end
		function inst.budgetFor(zone) return inst.directiveFor(zone) end

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
				engine.bus:subscribe("arkher.contsim.ecologycont.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		local ok = inst.installZones() > 0
		local result = inst.governFrame(8)
		ok = ok and result.pressure > 1
		local core = inst.budgetFor(S.key .. ".core")
		local edge = inst.budgetFor(S.key .. ".edge")
		ok = ok and core.objects < 400 and edge.objects < 120
		ok = ok and core.quality >= edge.quality
		ok = ok and inst.heaviest() == S.key .. ".core"
		local relaxed = inst.governFrame(10000)
		return ok and relaxed.pressure < 1 and inst.stats().zones == 2
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
