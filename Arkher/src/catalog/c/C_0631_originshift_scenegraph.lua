-- ARKHER SYSTEM C.0631 :: World Origin Shift Scene Graph
-- Category C - SCENE / WORLD
-- World capability: what exists, where it is, who owns it, and how it keeps living.
-- Kit: scenegraph (hierarchical world state with lazy world transforms)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "C.0631"
	S.key = "arkher.world.originshift.scene_graph"
	S.name = "World Origin Shift Scene Graph"
	S.category = "C"
	S.family = "SCENE / WORLD"
	S.area = "World Origin Shift"
	S.aspect = "Scene Graph"
	S.kit = "scenegraph"
	S.version = "1.0.0"
	S.deps = {  }
	S.tags = { "c", "originshift", "scenegraph", "world" }
	S.description = "World Origin Shift Scene Graph: hierarchical world state with lazy world transforms for the World Origin Shift subsystem."
	S.params = {
		backlogLimit = 44,
		baseRadius = 320,
		baseWeight = 0.76,
		bias = 0.36,
		biasWeight = 0.21,
		ceiling = 180,
		detailWeight = 0.36,
		failureTolerance = 1,
		horizon = 5,
		integrator = "euler",
		minConfidence = 0.76,
		minThrottle = 0.18,
		regressionSlope = 0.13,
		saturation = 0.71,
		scale = 2.6
	}
	S.features = { "addNode", "get", "setParent", "markDirty", "setPosition", "setScale", "worldPosition", "worldScale", "traverse", "descendants", "withTag", "remove", "bounds", "visibleFrom", "depthOf", "stats", "buildSample", "attach", "flatten", "moveHub", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("scenegraph", { id = "arkher.world.originshift.scene_graph" })
		inst.system = S
		inst.ctx = ctx

		function inst.buildSample()
			if inst.get("root") then return inst.stats().nodes end
			inst.addNode("root", { position = Vec.vec3(0, 0, 0), tags = { S.area } })
			inst.addNode("hub", { position = Vec.vec3(S.params.baseRadius, 0, 0), tags = { "hub" } }, "root")
			for i = 1, 3 do
				inst.addNode("leaf" .. i, { position = Vec.vec3(i * 10, 0, 0),
					tags = { "leaf" }, radius = S.params.detailWeight * 10 }, "hub")
			end
			return inst.stats().nodes
		end
		function inst.attach(id, parent) return inst.setParent(id, parent) end
		function inst.flatten()
			local out = {}
			inst.traverse(function(node, depth) out[#out + 1] = { id = node.id, depth = depth } end)
			return out
		end
		function inst.moveHub(offset)
			inst.buildSample()
			inst.setPosition("hub", Vec.vec3(offset, 0, 0))
			return inst.worldPosition("leaf1")
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
				engine.bus:subscribe("arkher.world.originshift.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		inst.buildSample()
		local ok = inst.stats().nodes == 5
		ok = ok and inst.worldPosition("leaf1").x == S.params.baseRadius + 10
		ok = ok and inst.depthOf("leaf1") == 2
		ok = ok and #inst.withTag("leaf") == 3
		ok = ok and inst.moveHub(500).x == 510
		ok = ok and #inst.flatten() == 5
		ok = ok and inst.bounds() ~= nil
		ok = ok and inst.remove("hub") == 4
		return ok and inst.stats().nodes == 1
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
