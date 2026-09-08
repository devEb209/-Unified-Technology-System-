-- ARKHER SYSTEM VB.0345 :: Society Continuum Complexity Budget
-- Category VB - CONTINUUM — TEMPORAL
-- Continuum Temporal capability: deterministic epoch timeline keeping every domain in sync.
-- Kit: complexity (complexity budgeting for the continuum)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "VB.0345"
	S.key = "arkher.conttime.societycont.complexity_budget"
	S.name = "Society Continuum Complexity Budget"
	S.category = "VB"
	S.family = "CONTINUUM — TEMPORAL"
	S.area = "Society Continuum"
	S.aspect = "Complexity Budget"
	S.kit = "complexity"
	S.version = "1.0.0"
	S.deps = { "arkher.conttime.societycont.world_memory_stream" }
	S.tags = { "vb", "societycont", "complexity", "conttime" }
	S.description = "Society Continuum Complexity Budget: complexity budgeting for the continuum for the Society Continuum subsystem."
	S.params = {
		backlogLimit = 27,
		baseRadius = 440,
		baseWeight = 0.69,
		bias = 0.19,
		biasWeight = 0.24,
		ceiling = 347,
		detailWeight = 0.39,
		failureTolerance = 4,
		horizon = 4,
		integrator = "verlet",
		minConfidence = 0.59,
		minThrottle = 0.195,
		regressionSlope = 0.145,
		saturation = 0.89,
		scale = 2.9
	}
	S.features = { "addZone", "setCounts", "setImportance", "costOf", "totalCost", "pressure", "classify", "evaluate", "directiveFor", "heaviest", "setTarget", "stats", "installZones", "governFrame", "budgetFor", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("complexity", { id = "arkher.conttime.societycont.complexity_budget", targetMs = 18.0 })
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
				engine.bus:subscribe("arkher.conttime.societycont.*", function(payload) inst.lastSignal = payload end)
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
