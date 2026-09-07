-- ARKHER SYSTEM Z.0688 :: Auto Test Synthesis Semantic Graph
-- Category Z - ARKHER ORIGINAL TECHNOLOGIES
-- ARKHER original technology: the capabilities that exist in no other engine, built for a world that keeps living.
-- Kit: knowledge (typed entities and inferred relations of the technology itself)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "Z.0688"
	S.key = "arkher.origin.autotest.semantic_graph"
	S.name = "Auto Test Synthesis Semantic Graph"
	S.category = "Z"
	S.family = "ARKHER ORIGINAL TECHNOLOGIES"
	S.area = "Auto Test Synthesis"
	S.aspect = "Semantic Graph"
	S.kit = "knowledge"
	S.version = "1.0.0"
	S.deps = { "arkher.origin.autotest.world_architect" }
	S.tags = { "z", "autotest", "knowledge", "origin" }
	S.description = "Auto Test Synthesis Semantic Graph: typed entities and inferred relations of the technology itself for the Auto Test Synthesis subsystem."
	S.params = {
		backlogLimit = 22,
		baseRadius = 400,
		baseWeight = 0.54,
		bias = 0.14,
		biasWeight = 0.19,
		ceiling = 334,
		detailWeight = 0.74,
		failureTolerance = 4,
		horizon = 7,
		integrator = "euler",
		minConfidence = 0.54,
		minThrottle = 0.22,
		regressionSlope = 0.12,
		saturation = 0.74,
		scale = 3.4
	}
	S.features = { "addEntity", "setAttribute", "attributesOf", "relate", "relatedTo", "hasRelation", "addRule", "infer", "query", "path", "embed", "similarity", "nearest", "forget", "stats", "installDomain", "componentsOf", "closestTo", "routeBetween", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("knowledge", { id = "arkher.origin.autotest.semantic_graph", dims = 48 })
		inst.system = S
		inst.ctx = ctx

		function inst.installDomain()
			inst.addEntity(S.key .. ".root", "domain", { area = S.name })
			inst.addEntity(S.key .. ".part", "component", { area = S.name })
			inst.addEntity(S.key .. ".detail", "component", { area = S.name })
			inst.relate(S.key .. ".part", "part_of", S.key .. ".root")
			inst.relate(S.key .. ".detail", "part_of", S.key .. ".part")
			inst.addRule("part_of", "transitive")
			return inst.infer(3)
		end
		function inst.componentsOf()
			return inst.query({ type = "component" })
		end
		function inst.closestTo(id)
			local near = inst.nearest(id, 1)
			return near[1] and near[1].id or nil
		end
		function inst.routeBetween(a, b)
			return inst.path(a, b, 6)
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
				engine.bus:subscribe("arkher.origin.autotest.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		local inferred = inst.installDomain()
		local ok = inferred >= 1
		ok = ok and inst.hasRelation(S.key .. ".detail", "part_of", S.key .. ".root")
		ok = ok and #inst.componentsOf() == 2
		local route = inst.routeBetween(S.key .. ".detail", S.key .. ".root")
		ok = ok and route ~= nil and #route >= 2
		ok = ok and inst.closestTo(S.key .. ".part") ~= nil
		return ok and inst.stats().entities == 3
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
