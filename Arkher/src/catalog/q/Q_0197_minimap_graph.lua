-- ARKHER SYSTEM Q.0197 :: Minimap Navigation Graph
-- Category Q - UI / UX
-- ARKHER Interface Framework capability: responsive, themed, accessible interfaces on every device.
-- Kit: graph (screens, routes and shortest path between them)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "Q.0197"
	S.key = "arkher.ui.minimap.navigation_graph"
	S.name = "Minimap Navigation Graph"
	S.category = "Q"
	S.family = "UI / UX"
	S.area = "Minimap"
	S.aspect = "Navigation Graph"
	S.kit = "graph"
	S.version = "1.0.0"
	S.deps = { "arkher.ui.minimap.transition" }
	S.tags = { "q", "minimap", "graph", "ui" }
	S.description = "Minimap Navigation Graph: screens, routes and shortest path between them for the Minimap subsystem."
	S.params = {
		backlogLimit = 17,
		baseRadius = 200,
		baseWeight = 0.59,
		bias = 0.09,
		biasWeight = 0.14,
		ceiling = 97,
		detailWeight = 0.69,
		failureTolerance = 4,
		horizon = 2,
		integrator = "verlet",
		minConfidence = 0.49,
		minThrottle = 0.195,
		regressionSlope = 0.095,
		saturation = 0.79,
		scale = 2.9
	}
	S.features = { "addNode", "addEdge", "neighbors", "shortestPath", "components", "degree", "nodeCount", "edgeCount", "stats", "link", "buildFrom", "criticalPath", "hotNodes", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("graph", { id = "arkher.ui.minimap.navigation_graph", directed = false })
		inst.system = S
		inst.ctx = ctx

	function inst.link(a, b, cost) return inst.addEdge(a, b, cost or 1) end
	function inst.buildFrom(edges)
		for _, e in ipairs(edges) do inst.addEdge(e[1], e[2], e[3] or 1) end
		return inst.stats()
	end
	function inst.criticalPath(from, to)
		local path, cost = inst.shortestPath(from, to)
		return path, cost
	end
	function inst.hotNodes(limit)
		local list = {}
		for id in pairs(inst.nodes) do list[#list + 1] = { id = id, degree = inst.degree(id) } end
		table.sort(list, function(x, y) return x.degree > y.degree end)
		local out = {}
		for i = 1, math.min(limit or 5, #list) do out[i] = list[i] end
		return out
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
				engine.bus:subscribe("arkher.ui.minimap.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		inst.buildFrom({ { "probe.a", "probe.b", 1 }, { "probe.b", "probe.c", 1 }, { "probe.a", "probe.c", 4 } })
		local path, cost = inst.criticalPath("probe.a", "probe.c")
		return path ~= nil and cost == 2 and #inst.hotNodes(2) > 0
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
