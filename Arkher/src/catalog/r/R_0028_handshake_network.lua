-- ARKHER SYSTEM R.0028 :: Handshake Transport Graph
-- Category R - NETWORKING
-- ARKHER Networking Framework capability: authoritative replication, prediction and bandwidth discipline.
-- Kit: network (topology, capacity and routing between endpoints)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "R.0028"
	S.key = "arkher.net.handshake.transport_graph"
	S.name = "Handshake Transport Graph"
	S.category = "R"
	S.family = "NETWORKING"
	S.area = "Handshake"
	S.aspect = "Transport Graph"
	S.kit = "network"
	S.version = "1.0.0"
	S.deps = { "arkher.net.handshake.prediction_and_reconciliation" }
	S.tags = { "r", "handshake", "network", "net" }
	S.description = "Handshake Transport Graph: topology, capacity and routing between endpoints for the Handshake subsystem."
	S.params = {
		backlogLimit = 35,
		baseRadius = 280,
		baseWeight = 0.77,
		bias = 0.27,
		biasWeight = 0.12,
		ceiling = 67,
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
	S.features = { "addNode", "addEdge", "route", "junctions", "deadEnds", "totalLength", "nearestNode", "connected", "stats", "buildGrid", "routeAcross", "topology", "snap", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("network", { id = "arkher.net.handshake.transport_graph" })
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
				engine.bus:subscribe("arkher.net.handshake.*", function(payload) inst.lastSignal = payload end)
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
