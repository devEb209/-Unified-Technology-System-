-- ARKHER SYSTEM P.0338 :: Cooldown Inventory
-- Category P - GAMEPLAY
-- ARKHER Gameplay Framework capability: attributes, items, objectives, combat and progression.
-- Kit: inventory (slots, stacking, weight, equipment and crafting)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "P.0338"
	S.key = "arkher.play.cooldown.inventory"
	S.name = "Cooldown Inventory"
	S.category = "P"
	S.family = "GAMEPLAY"
	S.area = "Cooldown"
	S.aspect = "Inventory"
	S.kit = "inventory"
	S.version = "1.0.0"
	S.deps = { "arkher.play.cooldown.attributes" }
	S.tags = { "p", "cooldown", "inventory", "play" }
	S.description = "Cooldown Inventory: slots, stacking, weight, equipment and crafting for the Cooldown subsystem."
	S.params = {
		backlogLimit = 13,
		baseRadius = 200,
		baseWeight = 0.95,
		bias = 0.05,
		biasWeight = 0.1,
		ceiling = 237,
		detailWeight = 0.45,
		failureTolerance = 0,
		horizon = 6,
		integrator = "verlet",
		minConfidence = 0.45,
		minThrottle = 0.225,
		regressionSlope = 0.075,
		saturation = 0.9,
		scale = 3.5
	}
	S.features = { "defineItem", "weight", "countOf", "freeSlots", "add", "remove", "has", "moveTo", "equip", "unequip", "addRecipe", "canCraft", "craft", "totalValue", "serialize", "deserialize", "stats", "installCatalog", "stock", "load", "forge", "gearUp", "roundTrip", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("inventory", { id = "arkher.play.cooldown.inventory", slots = 32, maxWeight = 50 })
		inst.system = S
		inst.ctx = ctx

		function inst.installCatalog()
			if inst.defs.fibre then return true end
			inst.defineItem("fibre", { stack = 20, weight = 0.2, value = 1 })
			inst.defineItem("ingot", { stack = 10, weight = 1.5, value = 8 })
			inst.defineItem("blade", { stack = 1, weight = 3, slot = "hand", value = 40 })
			inst.addRecipe("forgeBlade", { fibre = 4, ingot = 2 }, { blade = 1 })
			return true
		end
		function inst.stock(item, count)
			inst.installCatalog()
			return inst.add(item or "fibre", count or 5)
		end
		function inst.load()
			return inst.weight() / math.max(1e-6, inst.maxWeight)
		end
		function inst.forge()
			inst.installCatalog()
			if not inst.canCraft("forgeBlade") then return false end
			return inst.craft("forgeBlade")
		end
		function inst.gearUp()
			if inst.countOf("blade") < 1 then return false end
			return inst.equip("blade")
		end
		function inst.roundTrip()
			local blob = inst.serialize()
			local before = inst.totalValue()
			inst.deserialize(blob)
			return before == inst.totalValue()
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
				engine.bus:subscribe("arkher.play.cooldown.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		inst.installCatalog()
		local ok = inst.stock("fibre", 6) == 6 and inst.stock("ingot", 3) == 3
		ok = ok and inst.load() > 0 and inst.load() <= 1
		ok = ok and inst.forge() and inst.countOf("blade") == 1
		ok = ok and inst.gearUp() and inst.equipment.hand == "blade"
		ok = ok and inst.countOf("fibre") == 2 and inst.has("ingot", 1)
		ok = ok and inst.roundTrip()
		ok = ok and inst.remove("ingot", 1) >= 1
		return ok and inst.freeSlots() >= 0 and inst.stats().crafted == 1
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
