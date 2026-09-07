-- ARKHER SYSTEM K.0505 :: Flee Behaviour Mind Network
-- Category K - NPC / NEURAL MIND NETWORK
-- ARKHER NMN capability: minds that perceive, remember, feel, plan, move and live together.
-- Kit: mindnet (the learned policy that turns perception into a decision)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "K.0505"
	S.key = "arkher.npc.fleebehaviour.mind_network"
	S.name = "Flee Behaviour Mind Network"
	S.category = "K"
	S.family = "NPC / NEURAL MIND NETWORK"
	S.area = "Flee Behaviour"
	S.aspect = "Mind Network"
	S.kit = "mindnet"
	S.version = "1.0.0"
	S.deps = {  }
	S.tags = { "k", "fleebehaviour", "mindnet", "npc" }
	S.description = "Flee Behaviour Mind Network: the learned policy that turns perception into a decision for the Flee Behaviour subsystem."
	S.params = {
		backlogLimit = 27,
		baseRadius = 600,
		baseWeight = 0.79,
		bias = 0.19,
		biasWeight = 0.24,
		ceiling = 499,
		detailWeight = 0.79,
		failureTolerance = 4,
		horizon = 4,
		integrator = "verlet",
		minConfidence = 0.59,
		minThrottle = 0.245,
		regressionSlope = 0.145,
		saturation = 0.74,
		scale = 3.9
	}
	S.features = { "addAction", "build", "forward", "decide", "reinforce", "resetState", "parameters", "exportWeights", "importWeights", "memoryBytes", "stats", "installActions", "defaultActions", "observation", "think", "learn", "preference", "confidence", "brainBytes", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("mindnet", { id = "arkher.npc.fleebehaviour.mind_network", inputs = 9, hidden = 8, seed = 96179, learningRate = 0.095, exploration = 0.035 })
		inst.system = S
		inst.ctx = ctx

		function inst.installActions(list)
			local n = 0
			for _, name in ipairs(list) do
				if inst.addAction(name) then n = n + 1 end
			end
			return n
		end
		function inst.defaultActions()
			if #inst.actionOrder > 0 then return #inst.actionOrder end
			inst.installActions({ "observe", "approach", "avoid", "work" })
			return #inst.actionOrder
		end
		function inst.observation(values)
			local vec = {}
			for i = 1, inst.inputs do vec[i] = values[i] or 0 end
			return vec
		end
		function inst.think(values)
			inst.defaultActions()
			return inst.decide(inst.observation(values))
		end
		function inst.learn(values, reward)
			inst.think(values)
			return inst.reinforce(reward or 0)
		end
		function inst.preference(name)
			local a = inst.actions[name]
			if not a then return 0 end
			return a.value
		end
		function inst.confidence(values)
			inst.defaultActions()
			local scores = inst.forward(inst.observation(values))
			local best, second = -math.huge, -math.huge
			for _, v in pairs(scores) do
				if v > best then second = best best = v
				elseif v > second then second = v end
			end
			if second == -math.huge then return 1 end
			return math.min(1, math.abs(best - second))
		end
		function inst.brainBytes() return inst.memoryBytes() + inst.inputs * 8 end

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
				engine.bus:subscribe("arkher.npc.fleebehaviour.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		local obs = { 0.2, 0.7, 0.1, 0.4, 0.9, 0.3, 0.5, 0.6, 0.2, 0.1 }
		local action = inst.think(obs)
		local ok = action ~= nil and inst.parameters() > 10
		for _ = 1, 5 do inst.learn(obs, 1) end
		ok = ok and inst.preference(action) ~= nil and inst.confidence(obs) >= 0
		local w = inst.exportWeights()
		ok = ok and inst.importWeights(w) == #w
		inst.resetState()
		return ok and inst.brainBytes() > 0 and inst.stats().updates >= 5
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
