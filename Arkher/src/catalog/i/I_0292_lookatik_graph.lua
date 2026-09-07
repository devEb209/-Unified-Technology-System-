-- ARKHER SYSTEM I.0292 :: Look At IK Retarget Graph
-- Category I - ANIMATION
-- ARKHER Animation Framework capability: skeletons, clips, layers, IK and physical blending.
-- Kit: graph (bone mapping and retarget path resolution)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "I.0292"
	S.key = "arkher.anim.lookatik.retarget_graph"
	S.name = "Look At IK Retarget Graph"
	S.category = "I"
	S.family = "ANIMATION"
	S.area = "Look At IK"
	S.aspect = "Retarget Graph"
	S.kit = "graph"
	S.version = "1.0.0"
	S.deps = { "arkher.anim.lookatik.physical_blend" }
	S.tags = { "i", "lookatik", "graph", "anim" }
	S.description = "Look At IK Retarget Graph: bone mapping and retarget path resolution for the Look At IK subsystem."
	S.params = {
		backlogLimit = 40,
		baseRadius = 160,
		baseWeight = 0.72,
		bias = 0.32,
		biasWeight = 0.17,
		ceiling = 104,
		detailWeight = 0.32,
		failureTolerance = 2,
		horizon = 1,
		integrator = "euler",
		minConfidence = 0.72,
		minThrottle = 0.16,
		regressionSlope = 0.11,
		saturation = 0.92,
		scale = 2.2
	}
	S.features = { "addNode", "addEdge", "neighbors", "shortestPath", "components", "degree", "nodeCount", "edgeCount", "stats", "link", "buildFrom", "criticalPath", "hotNodes", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("graph", { id = "arkher.anim.lookatik.retarget_graph", directed = true })
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
				engine.bus:subscribe("arkher.anim.lookatik.*", function(payload) inst.lastSignal = payload end)
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
