-- ARKHER SYSTEM Y.0148 :: Annotation Working Set
-- Category Y - COLLABORATION / PRODUCTION
-- Collaboration capability: many creators, one project, with review, merge, release and audit.
-- Kit: selection (the set of items currently being worked on)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "Y.0148"
	S.key = "arkher.collab.annotation.working_set"
	S.name = "Annotation Working Set"
	S.category = "Y"
	S.family = "COLLABORATION / PRODUCTION"
	S.area = "Annotation"
	S.aspect = "Working Set"
	S.kit = "selection"
	S.version = "1.0.0"
	S.deps = { "arkher.collab.annotation.record_registry" }
	S.tags = { "y", "annotation", "selection", "collab" }
	S.description = "Annotation Working Set: the set of items currently being worked on for the Annotation subsystem."
	S.params = {
		backlogLimit = 8,
		baseRadius = 160,
		baseWeight = 0.9,
		bias = 0.0,
		biasWeight = 0.05,
		ceiling = 456,
		detailWeight = 0.2,
		failureTolerance = 0,
		horizon = 1,
		integrator = "euler",
		minConfidence = 0.4,
		minThrottle = 0.1,
		regressionSlope = 0.05,
		saturation = 0.85,
		scale = 1.0
	}
	S.features = { "contains", "add", "remove", "toggle", "set", "clear", "all", "count", "addFilter", "filtered", "stats", "selectWhere", "invert", "primaryOr", "summary", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("selection", { id = "arkher.collab.annotation.working_set", maxItems = 3976 })
		inst.system = S
		inst.ctx = ctx

		function inst.selectWhere(ids, predicate)
			inst.clear()
			local n = 0
			for _, id in ipairs(ids) do
				if predicate(id) and inst.add(id) then n = n + 1 end
			end
			return n
		end
		function inst.invert(universe)
			local current = {}
			for _, id in ipairs(inst.all()) do current[id] = true end
			inst.clear()
			for _, id in ipairs(universe) do
				if not current[id] then inst.add(id) end
			end
			return inst.count()
		end
		function inst.primaryOr(default) return inst.primary or default end
		function inst.summary()
			local filters = 0
			for _ in pairs(inst.filters) do filters = filters + 1 end
			return { count = inst.count(), primary = inst.primary, filters = filters, items = inst.all() }
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
				engine.bus:subscribe("arkher.collab.annotation.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		inst.clear()
		local universe = { "probe.a", "probe.b", "probe.c", "probe.d" }
		local n = inst.selectWhere(universe, function(id) return id ~= "probe.c" end)
		local ok = n == 3 and inst.contains("probe.a") and inst.contains("probe.c") == false
		ok = ok and inst.invert(universe) == 1 and inst.contains("probe.c")
		ok = ok and inst.summary().count == 1 and inst.primaryOr("none") ~= "none"
		inst.clear()
		return ok and inst.count() == 0
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
