-- ARKHER SYSTEM K.0443 :: Local Avoidance Navigation
-- Category K - NPC / NEURAL MIND NETWORK
-- ARKHER NMN capability: minds that perceive, remember, feel, plan, move and live together.
-- Kit: navgraph (grid pathfinding, smoothing, line of sight and flow fields)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "K.0443"
	S.key = "arkher.npc.localavoidance.navigation"
	S.name = "Local Avoidance Navigation"
	S.category = "K"
	S.family = "NPC / NEURAL MIND NETWORK"
	S.area = "Local Avoidance"
	S.aspect = "Navigation"
	S.kit = "navgraph"
	S.version = "1.0.0"
	S.deps = { "arkher.npc.localavoidance.goal_planner" }
	S.tags = { "k", "localavoidance", "navgraph", "npc" }
	S.description = "Local Avoidance Navigation: grid pathfinding, smoothing, line of sight and flow fields for the Local Avoidance subsystem."
	S.params = {
		backlogLimit = 42,
		baseRadius = 400,
		baseWeight = 0.94,
		bias = 0.34,
		biasWeight = 0.19,
		ceiling = 170,
		detailWeight = 0.74,
		failureTolerance = 4,
		horizon = 3,
		integrator = "euler",
		minConfidence = 0.74,
		minThrottle = 0.22,
		regressionSlope = 0.12,
		saturation = 0.89,
		scale = 3.4
	}
	S.features = { "inBounds", "setCost", "block", "costAt", "walkable", "toWorld", "toCell", "blockRect", "findPath", "lineOfSight", "smooth", "worldPath", "pathLength", "flowField", "stats", "wall", "route", "reachable", "clearAll", "coverage", "steerFrom", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("navgraph", { id = "arkher.npc.localavoidance.navigation", width = 40, height = 40, cellSize = 4 })
		inst.system = S
		inst.ctx = ctx

		function inst.wall(x, z0, z1) return inst.blockRect(x, z0, x, z1) end
		function inst.route(sx, sz, tx, tz)
			local path = inst.findPath(sx, sz, tx, tz)
			if not path then return nil end
			return inst.worldPath(inst.smooth(path))
		end
		function inst.reachable(sx, sz, tx, tz) return inst.findPath(sx, sz, tx, tz) ~= nil end
		function inst.clearAll()
			inst.cells = {}
			return true
		end
		function inst.coverage()
			local blocked = 0
			for _, cost in pairs(inst.cells) do
				if cost < 0 then blocked = blocked + 1 end
			end
			return 1 - blocked / (inst.width * inst.height)
		end
		function inst.steerFrom(field, x, z) return field.direction(x, z) end

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
				engine.bus:subscribe("arkher.npc.localavoidance.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		local ok = inst.walkable(1, 1)
		inst.wall(4, 0, 6)
		ok = ok and not inst.walkable(4, 3)
		local route = inst.route(1, 1, 8, 1)
		ok = ok and route ~= nil and #route >= 2
		ok = ok and inst.reachable(1, 1, 8, 8) and inst.coverage() < 1
		ok = ok and not inst.lineOfSight(1, 3, 8, 3)
		local field = inst.flowField(8, 1)
		ok = ok and inst.steerFrom(field, 1, 1):length() > 0
		inst.clearAll()
		return ok and inst.walkable(4, 3)
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
