-- ARKHER SYSTEM L.0227 :: Weather Ecology
-- Category L - WORLD SIMULATION
-- ARKHER Living World capability: a world that keeps living, at the fidelity the observer deserves.
-- Kit: ecology (populations, predation, harvesting and carrying capacity)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "L.0227"
	S.key = "arkher.sim.weather.ecology"
	S.name = "Weather Ecology"
	S.category = "L"
	S.family = "WORLD SIMULATION"
	S.area = "Weather"
	S.aspect = "Ecology"
	S.kit = "ecology"
	S.version = "1.0.0"
	S.deps = { "arkher.sim.weather.simulation_core" }
	S.tags = { "l", "weather", "ecology", "sim" }
	S.description = "Weather Ecology: populations, predation, harvesting and carrying capacity for the Weather subsystem."
	S.params = {
		backlogLimit = 33,
		baseRadius = 520,
		baseWeight = 0.85,
		bias = 0.25,
		biasWeight = 0.1,
		ceiling = 81,
		detailWeight = 0.65,
		failureTolerance = 0,
		horizon = 2,
		integrator = "verlet",
		minConfidence = 0.65,
		minThrottle = 0.175,
		regressionSlope = 0.075,
		saturation = 0.8,
		scale = 2.5
	}
	S.features = { "addSpecies", "link", "populationOf", "step", "harvest", "seed", "biomass", "stable", "stats", "buildFoodChain", "advanceSeasons", "dominant", "pressureOn", "cull", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("ecology", { id = "arkher.sim.weather.ecology" })
		inst.system = S
		inst.ctx = ctx

		function inst.buildFoodChain()
			if #inst.order > 0 then return #inst.order end
			inst.addSpecies("grass", { population = 800, growth = 0.5, capacity = 2000 })
			inst.addSpecies("deer", { population = 180, growth = 0.25, capacity = 700 })
			inst.addSpecies("wolf", { population = 18, growth = -0.12, capacity = 80 })
			inst.link("deer", "grass", { predation = 0.0004, efficiency = 0.3 })
			inst.link("wolf", "deer", { predation = 0.0009, efficiency = 0.35 })
			return #inst.order
		end
		function inst.advanceSeasons(steps, dt)
			inst.buildFoodChain()
			for _ = 1, (steps or 20) do inst.step(dt or 0.5) end
			return inst.ticks
		end
		function inst.dominant()
			local best, bestPop = nil, -1
			for _, name in ipairs(inst.order) do
				local pop = inst.populationOf(name)
				if pop > bestPop then bestPop = pop best = name end
			end
			return best, bestPop
		end
		function inst.pressureOn(name)
			local total = 0
			for _, link in ipairs(inst.links) do
				if link.prey == name then
					total = total + link.predation * inst.populationOf(link.predator)
				end
			end
			return total
		end
		function inst.cull(name, fraction)
			return inst.harvest(name, inst.populationOf(name) * (fraction or 0.1))
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
				engine.bus:subscribe("arkher.sim.weather.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		local ok = inst.buildFoodChain() == 3
		inst.advanceSeasons(24, 0.5)
		ok = ok and inst.biomass() > 100 and inst.dominant() == "grass"
		ok = ok and inst.pressureOn("deer") > 0 and inst.cull("deer", 0.1) > 0
		inst.seed("deer", 10)
		return ok and inst.populationOf("deer") > 0 and inst.stats().ticks >= 24
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
