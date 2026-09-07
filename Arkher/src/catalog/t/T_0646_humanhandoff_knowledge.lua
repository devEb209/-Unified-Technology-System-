-- ARKHER SYSTEM T.0646 :: Human Handoff Semantic Knowledge
-- Category T - SINGULARITY AI
-- Singularity AI capability: understand, know, plan, act, judge - the intelligence that drives the whole engine.
-- Kit: knowledge (typed entities, weighted relations and inferred closure)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "T.0646"
	S.key = "arkher.ai.humanhandoff.semantic_knowledge"
	S.name = "Human Handoff Semantic Knowledge"
	S.category = "T"
	S.family = "SINGULARITY AI"
	S.area = "Human Handoff"
	S.aspect = "Semantic Knowledge"
	S.kit = "knowledge"
	S.version = "1.0.0"
	S.deps = { "arkher.ai.humanhandoff.intent_understanding" }
	S.tags = { "t", "humanhandoff", "knowledge", "ai" }
	S.description = "Human Handoff Semantic Knowledge: typed entities, weighted relations and inferred closure for the Human Handoff subsystem."
	S.params = {
		backlogLimit = 13,
		baseRadius = 360,
		baseWeight = 0.65,
		bias = 0.05,
		biasWeight = 0.1,
		ceiling = 221,
		detailWeight = 0.25,
		failureTolerance = 0,
		horizon = 6,
		integrator = "verlet",
		minConfidence = 0.45,
		minThrottle = 0.125,
		regressionSlope = 0.075,
		saturation = 0.85,
		scale = 1.5
	}
	S.features = { "addEntity", "setAttribute", "attributesOf", "relate", "relatedTo", "hasRelation", "addRule", "infer", "query", "path", "embed", "similarity", "nearest", "forget", "stats", "installDomain", "componentsOf", "closestTo", "routeBetween", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("knowledge", { id = "arkher.ai.humanhandoff.semantic_knowledge", dims = 16 })
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
				engine.bus:subscribe("arkher.ai.humanhandoff.*", function(payload) inst.lastSignal = payload end)
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
