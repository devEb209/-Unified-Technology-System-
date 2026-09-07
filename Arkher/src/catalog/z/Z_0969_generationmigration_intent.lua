-- ARKHER SYSTEM Z.0969 :: Generation Migration Intent Bridge
-- Category Z - ARKHER ORIGINAL TECHNOLOGIES
-- ARKHER original technology: the capabilities that exist in no other engine, built for a world that keeps living.
-- Kit: intent (natural language control surface for the technology)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "Z.0969"
	S.key = "arkher.origin.generationmigration.intent_bridge"
	S.name = "Generation Migration Intent Bridge"
	S.category = "Z"
	S.family = "ARKHER ORIGINAL TECHNOLOGIES"
	S.area = "Generation Migration"
	S.aspect = "Intent Bridge"
	S.kit = "intent"
	S.version = "1.0.0"
	S.deps = { "arkher.origin.generationmigration.semantic_graph" }
	S.tags = { "z", "generationmigration", "intent", "origin" }
	S.description = "Generation Migration Intent Bridge: natural language control surface for the technology for the Generation Migration subsystem."
	S.params = {
		backlogLimit = 27,
		baseRadius = 600,
		baseWeight = 0.79,
		bias = 0.19,
		biasWeight = 0.24,
		ceiling = 275,
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
	S.features = { "addVerb", "addTarget", "addQualifier", "addConstraint", "addPattern", "installDefaults", "tokenize", "numberIn", "parse", "explain", "vocabulary", "stats", "teach", "understand", "routeFor", "brief", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("intent", { id = "arkher.origin.generationmigration.intent_bridge", minConfidence = 0.44 })
		inst.system = S
		inst.ctx = ctx

		function inst.teach(word, action)
			return inst.addVerb(word, { word }, action or "create")
		end
		function inst.understand(text)
			local r = inst.parse(text)
			return r.understood, r
		end
		function inst.routeFor(text)
			local r = inst.parse(text)
			if not r.understood then return "clarify" end
			return (r.action or "unknown") .. ":" .. (r.target or "world")
		end
		function inst.brief(text)
			local r = inst.parse(text)
			return { action = r.action, target = r.target, quantity = r.quantity or 1,
				device = r.constraints.device or "any", confidence = r.confidence }
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
				engine.bus:subscribe("arkher.origin.generationmigration.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		inst.installDefaults()
		local ok, r = inst.understand("build a city with 20 buildings for phones")
		ok = ok and r.action == "create" and r.target == "city" and r.quantity == 20
		ok = ok and r.constraints.device == "mobile"
		ok = ok and inst.routeFor("build a city") == "create:city"
		local brief = inst.brief("optimize the map for weak phones")
		ok = ok and brief.action == "optimize" and brief.device == "mobile"
		ok = ok and inst.teach("erect", "create") ~= nil
		return ok and inst.stats().parsed >= 3
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
