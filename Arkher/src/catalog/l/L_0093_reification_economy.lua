-- ARKHER SYSTEM L.0093 :: Reification Economy
-- Category L - WORLD SIMULATION
-- ARKHER Living World capability: a world that keeps living, at the fidelity the observer deserves.
-- Kit: economy (stock, production, demand, price discovery and trade)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "L.0093"
	S.key = "arkher.sim.reification.economy"
	S.name = "Reification Economy"
	S.category = "L"
	S.family = "WORLD SIMULATION"
	S.area = "Reification"
	S.aspect = "Economy"
	S.kit = "economy"
	S.version = "1.0.0"
	S.deps = { "arkher.sim.reification.ecology" }
	S.tags = { "l", "reification", "economy", "sim" }
	S.description = "Reification Economy: stock, production, demand, price discovery and trade for the Reification subsystem."
	S.params = {
		backlogLimit = 35,
		baseRadius = 280,
		baseWeight = 0.77,
		bias = 0.27,
		biasWeight = 0.12,
		ceiling = 235,
		detailWeight = 0.47,
		failureTolerance = 2,
		horizon = 4,
		integrator = "verlet",
		minConfidence = 0.67,
		minThrottle = 0.235,
		regressionSlope = 0.085,
		saturation = 0.72,
		scale = 3.7
	}
	S.features = { "defineGood", "addMarket", "setStock", "setProduction", "setDemand", "totalStock", "totalDemand", "updatePrices", "priceOf", "tick", "trade", "balance", "stats", "bootstrap", "runDays", "shipment", "scarcity", "wealthOf", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("economy", { id = "arkher.sim.reification.economy", elasticity = 0.42 })
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
				engine.bus:subscribe("arkher.sim.reification.*", function(payload) inst.lastSignal = payload end)
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
