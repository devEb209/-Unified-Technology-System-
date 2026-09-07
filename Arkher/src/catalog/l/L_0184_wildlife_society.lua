-- ARKHER SYSTEM L.0184 :: Wildlife Society
-- Category L - WORLD SIMULATION
-- ARKHER Living World capability: a world that keeps living, at the fidelity the observer deserves.
-- Kit: society (relations, factions, reputation and cohesion of the region)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "L.0184"
	S.key = "arkher.sim.wildlife.society"
	S.name = "Wildlife Society"
	S.category = "L"
	S.family = "WORLD SIMULATION"
	S.area = "Wildlife"
	S.aspect = "Society"
	S.kit = "society"
	S.version = "1.0.0"
	S.deps = { "arkher.sim.wildlife.economy" }
	S.tags = { "l", "wildlife", "society", "sim" }
	S.description = "Wildlife Society: relations, factions, reputation and cohesion of the region for the Wildlife subsystem."
	S.params = {
		backlogLimit = 33,
		baseRadius = 520,
		baseWeight = 0.55,
		bias = 0.25,
		biasWeight = 0.1,
		ceiling = 513,
		detailWeight = 0.65,
		failureTolerance = 0,
		horizon = 2,
		integrator = "verlet",
		minConfidence = 0.65,
		minThrottle = 0.175,
		regressionSlope = 0.075,
		saturation = 0.75,
		scale = 2.5
	}
	S.features = { "join", "leave", "affinity", "interact", "setFactionStanding", "disposition", "gossip", "tick", "friendsOf", "cohesion", "stats", "populate", "bond", "feud", "circleOf", "standing", "factionOf", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("society", { id = "arkher.sim.wildlife.society", decayRate = 0.010, gossipReach = 3 })
		inst.system = S
		inst.ctx = ctx

		function inst.populate(names, faction)
			for _, name in ipairs(names) do inst.join(name, { faction = faction }) end
			return #inst.memberOrder
		end
		function inst.bond(a, b, times)
			for _ = 1, (times or 3) do inst.interact(a, b, 1, 0.4) end
			return inst.affinity(a, b)
		end
		function inst.feud(a, b, times)
			for _ = 1, (times or 3) do inst.interact(a, b, -1, 0.4) end
			return inst.affinity(a, b)
		end
		function inst.circleOf(id) return inst.friendsOf(id, 0.25) end
		function inst.standing(id)
			local m = inst.members[id]
			if not m then return 0 end
			return m.reputation
		end
		function inst.factionOf(id)
			local m = inst.members[id]
			if not m then return nil end
			return m.faction
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
				engine.bus:subscribe("arkher.sim.wildlife.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		local ok = inst.populate({ "ana", "bo", "cy" }, "village") == 3
		ok = ok and inst.bond("ana", "bo", 4) > 0.3
		ok = ok and inst.feud("ana", "cy", 4) < 0
		ok = ok and #inst.circleOf("ana") == 1
		ok = ok and inst.factionOf("bo") == "village"
		inst.gossip("ana", "cy", -1)
		ok = ok and inst.standing("cy") <= 0
		inst.tick(1)
		return ok and inst.cohesion() ~= nil and inst.disposition("ana", "bo") > 0
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
