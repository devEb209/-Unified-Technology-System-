-- ARKHER SYSTEM K.0136 :: Hunger Drive Crowd Steering
-- Category K - NPC / NEURAL MIND NETWORK
-- ARKHER NMN capability: minds that perceive, remember, feel, plan, move and live together.
-- Kit: crowd (local avoidance, cohesion and arrival at scale)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "K.0136"
	S.key = "arkher.npc.hungerdrive.crowd_steering"
	S.name = "Hunger Drive Crowd Steering"
	S.category = "K"
	S.family = "NPC / NEURAL MIND NETWORK"
	S.area = "Hunger Drive"
	S.aspect = "Crowd Steering"
	S.kit = "crowd"
	S.version = "1.0.0"
	S.deps = { "arkher.npc.hungerdrive.navigation" }
	S.tags = { "k", "hungerdrive", "crowd", "npc" }
	S.description = "Hunger Drive Crowd Steering: local avoidance, cohesion and arrival at scale for the Hunger Drive subsystem."
	S.params = {
		backlogLimit = 16,
		baseRadius = 320,
		baseWeight = 0.88,
		bias = 0.08,
		biasWeight = 0.13,
		ceiling = 112,
		detailWeight = 0.48,
		failureTolerance = 3,
		horizon = 1,
		integrator = "euler",
		minConfidence = 0.48,
		minThrottle = 0.24,
		regressionSlope = 0.09,
		saturation = 0.83,
		scale = 3.8
	}
	S.features = { "add", "remove", "setTarget", "seek", "neighbors", "separation", "cohesion", "alignment", "step", "arrivedCount", "averageSpeed", "stats", "spawnRing", "simulate", "closestPair", "densityAt", "clearAgents", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("crowd", { id = "arkher.npc.hungerdrive.crowd_steering", radius = 0.80, maxSpeed = 5.80, cellSize = 10 })
		inst.system = S
		inst.ctx = ctx

		function inst.spawnRing(count, radius)
			local n = count or 6
			local r = radius or 6
			for i = 1, n do
				local angle = (i / n) * math.pi * 2
				inst.add("a" .. i, Vec.vec3(math.cos(angle) * r, 0, math.sin(angle) * r), {})
				inst.setTarget("a" .. i, Vec.vec3(-math.cos(angle) * r, 0, -math.sin(angle) * r))
			end
			return #inst.order
		end
		function inst.simulate(seconds, dt)
			local step = dt or 1 / 20
			local n = math.max(1, math.floor((seconds or 1) / step))
			for _ = 1, n do inst.step(step) end
			return inst.steps
		end
		function inst.closestPair()
			local best = math.huge
			for i = 1, #inst.order do
				for j = i + 1, #inst.order do
					local d = inst.agents[inst.order[i]].position:distance(
						inst.agents[inst.order[j]].position)
					if d < best then best = d end
				end
			end
			return best
		end
		function inst.densityAt(position, radius)
			local n = 0
			for _, id in ipairs(inst.order) do
				if inst.agents[id].position:distance(position) <= (radius or 5) then n = n + 1 end
			end
			return n
		end
		function inst.clearAgents()
			local ids = {}
			for i, id in ipairs(inst.order) do ids[i] = id end
			for _, id in ipairs(ids) do inst.remove(id) end
			return #inst.order
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
				engine.bus:subscribe("arkher.npc.hungerdrive.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		local ok = inst.spawnRing(6, 6) == 6
		inst.simulate(1.5, 1 / 20)
		ok = ok and inst.steps >= 30 and inst.closestPair() > 0.05
		ok = ok and inst.densityAt(Vec.vec3(), 40) == 6
		ok = ok and inst.averageSpeed() >= 0 and inst.arrivedCount() >= 0
		return ok and inst.clearAgents() == 0
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
