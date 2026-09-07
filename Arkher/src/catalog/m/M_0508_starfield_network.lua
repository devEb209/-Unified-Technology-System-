-- ARKHER SYSTEM M.0508 :: Star Field Network Planner
-- Category M - PROCEDURAL
-- Procedural capability: deterministic synthesis of worlds, cities, structures and detail from a seed.
-- Kit: network (graph planning with A* routing)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "M.0508"
	S.key = "arkher.proc.starfield.network_planner"
	S.name = "Star Field Network Planner"
	S.category = "M"
	S.family = "PROCEDURAL"
	S.area = "Star Field"
	S.aspect = "Network Planner"
	S.kit = "network"
	S.version = "1.0.0"
	S.deps = { "arkher.proc.starfield.distribution" }
	S.tags = { "m", "starfield", "network", "proc" }
	S.description = "Star Field Network Planner: graph planning with A* routing for the Star Field subsystem."
	S.params = {
		backlogLimit = 40,
		baseRadius = 160,
		baseWeight = 0.82,
		bias = 0.32,
		biasWeight = 0.17,
		ceiling = 168,
		detailWeight = 0.32,
		failureTolerance = 2,
		horizon = 1,
		integrator = "euler",
		minConfidence = 0.72,
		minThrottle = 0.16,
		regressionSlope = 0.11,
		saturation = 0.77,
		scale = 2.2
	}
	S.features = { "addNode", "addEdge", "route", "junctions", "deadEnds", "totalLength", "nearestNode", "connected", "stats", "buildGrid", "routeAcross", "topology", "snap", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("network", { id = "arkher.proc.starfield.network_planner" })
		inst.system = S
		inst.ctx = ctx

		function inst.buildGrid(size, spacing)
			if inst.gridIds then return inst.gridIds end
			local n = size or 3
			local step = spacing or 100
			local ids = {}
			for r = 0, n - 1 do
				ids[r] = {}
				for c = 0, n - 1 do
					ids[r][c] = inst.addNode(Vec.vec3(c * step, 0, r * step), "junction")
				end
			end
			for r = 0, n - 1 do
				for c = 0, n - 1 do
					if c < n - 1 then inst.addEdge(ids[r][c], ids[r][c + 1], { class = "street" }) end
					if r < n - 1 then inst.addEdge(ids[r][c], ids[r + 1][c], { class = "street" }) end
				end
			end
			inst.gridIds = ids
			inst.gridSize = n
			inst.gridSpacing = step
			return ids
		end
		function inst.routeAcross()
			local ids = inst.buildGrid()
			local n = inst.gridSize
			return inst.route(ids[0][0], ids[n - 1][n - 1])
		end
		function inst.topology()
			inst.buildGrid()
			return { junctions = #inst.junctions(3), deadEnds = #inst.deadEnds(),
				connected = inst.connected(), length = inst.totalLength() }
		end
		function inst.snap(position)
			inst.buildGrid()
			return inst.nearestNode(position)
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
				engine.bus:subscribe("arkher.proc.starfield.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		inst.buildGrid(3, 100)
		local path, cost = inst.routeAcross()
		local ok = path ~= nil and #path == 5
		ok = ok and math.abs(cost - 400) < 0.001
		local topology = inst.topology()
		ok = ok and topology.connected == true and topology.deadEnds == 0
		ok = ok and math.abs(topology.length - 1200) < 0.001
		local nearest = inst.snap(Vec.vec3(95, 0, 5))
		return ok and nearest == inst.gridIds[0][1]
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
