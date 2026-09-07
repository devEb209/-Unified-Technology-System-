-- ARKHER SYSTEM L.0078 :: Cohort Economy
-- Category L - WORLD SIMULATION
-- ARKHER Living World capability: a world that keeps living, at the fidelity the observer deserves.
-- Kit: economy (stock, production, demand, price discovery and trade)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "L.0078"
	S.key = "arkher.sim.cohort.economy"
	S.name = "Cohort Economy"
	S.category = "L"
	S.family = "WORLD SIMULATION"
	S.area = "Cohort"
	S.aspect = "Economy"
	S.kit = "economy"
	S.version = "1.0.0"
	S.deps = { "arkher.sim.cohort.ecology" }
	S.tags = { "l", "cohort", "economy", "sim" }
	S.description = "Cohort Economy: stock, production, demand, price discovery and trade for the Cohort subsystem."
	S.params = {
		backlogLimit = 33,
		baseRadius = 520,
		baseWeight = 0.75,
		bias = 0.25,
		biasWeight = 0.1,
		ceiling = 369,
		detailWeight = 0.65,
		failureTolerance = 0,
		horizon = 2,
		integrator = "verlet",
		minConfidence = 0.65,
		minThrottle = 0.175,
		regressionSlope = 0.075,
		saturation = 0.7,
		scale = 2.5
	}
	S.features = { "defineGood", "addMarket", "setStock", "setProduction", "setDemand", "totalStock", "totalDemand", "updatePrices", "priceOf", "tick", "trade", "balance", "stats", "bootstrap", "runDays", "shipment", "scarcity", "wealthOf", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("economy", { id = "arkher.sim.cohort.economy", elasticity = 0.30 })
		inst.system = S
		inst.ctx = ctx

		function inst.bootstrap()
			if #inst.goodOrder > 0 then return #inst.goodOrder end
			inst.defineGood("food", { basePrice = 8 })
			inst.defineGood("ore", { basePrice = 14 })
			inst.addMarket("farm", { wealth = 400 })
			inst.addMarket("town", { wealth = 700 })
			inst.setStock("farm", "food", 200)
			inst.setStock("town", "ore", 120)
			inst.setProduction("farm", "food", 6)
			inst.setDemand("town", "food", 4)
			return #inst.goodOrder
		end
		function inst.runDays(days)
			inst.bootstrap()
			for _ = 1, (days or 4) do inst.tick(1) end
			return inst.ticks
		end
		function inst.shipment(good, amount)
			inst.bootstrap()
			return inst.trade("farm", "town", good or "food", amount or 20)
		end
		function inst.scarcity(good)
			local stock = inst.totalStock(good)
			if stock <= 0 then return 1 end
			return math.min(1, inst.totalDemand(good) / stock)
		end
		function inst.wealthOf(marketId)
			local m = inst.markets[marketId]
			if not m then return 0 end
			return m.wealth
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
				engine.bus:subscribe("arkher.sim.cohort.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		local ok = inst.bootstrap() == 2
		inst.runDays(4)
		ok = ok and inst.priceOf("food") > 0
		ok = ok and inst.shipment("food", 20) > 0
		ok = ok and inst.markets.town.stock.food > 0 and inst.wealthOf("town") < 700
		ok = ok and inst.scarcity("food") >= 0 and inst.balance() ~= nil
		return ok and inst.totalStock("food") > 0 and inst.stats().trades >= 1
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
