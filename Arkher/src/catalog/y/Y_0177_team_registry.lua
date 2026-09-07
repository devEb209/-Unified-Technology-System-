-- ARKHER SYSTEM Y.0177 :: Team Directory Record Registry
-- Category Y - COLLABORATION / PRODUCTION
-- Collaboration capability: many creators, one project, with review, merge, release and audit.
-- Kit: registry (catalogued production records)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "Y.0177"
	S.key = "arkher.collab.team.record_registry"
	S.name = "Team Directory Record Registry"
	S.category = "Y"
	S.family = "COLLABORATION / PRODUCTION"
	S.area = "Team Directory"
	S.aspect = "Record Registry"
	S.kit = "registry"
	S.version = "1.0.0"
	S.deps = { "arkher.collab.team.permission_guard" }
	S.tags = { "y", "team", "registry", "collab" }
	S.description = "Team Directory Record Registry: catalogued production records for the Team Directory subsystem."
	S.params = {
		backlogLimit = 31,
		baseRadius = 440,
		baseWeight = 0.83,
		bias = 0.23,
		biasWeight = 0.08,
		ceiling = 71,
		detailWeight = 0.63,
		failureTolerance = 3,
		horizon = 8,
		integrator = "verlet",
		minConfidence = 0.63,
		minThrottle = 0.165,
		regressionSlope = 0.065,
		saturation = 0.78,
		scale = 2.3
	}
	S.features = { "define", "get", "has", "remove", "withTag", "query", "ids", "snapshot", "restore", "stats", "upsert", "bulkDefine", "tally", "export", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("registry", { id = "arkher.collab.team.record_registry" })
		inst.system = S
		inst.ctx = ctx

	function inst.upsert(id, data, tags) return inst.define(id, data, tags) end
	function inst.bulkDefine(list)
		local n = 0
		for _, rec in ipairs(list) do
			if inst.define(rec.id, rec.data, rec.tags) then n = n + 1 end
		end
		return n
	end
	function inst.tally()
		local out = {}
		for _, id in ipairs(inst.ids()) do
			for _, tag in ipairs(inst.records[id].tags) do out[tag] = (out[tag] or 0) + 1 end
		end
		return out
	end
	function inst.export() return { area = S.area, count = inst.stats().count, records = inst.snapshot() } end

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
				engine.bus:subscribe("arkher.collab.team.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		inst.define("probe.a", { weight = 1 }, { "probe" })
		inst.define("probe.b", { weight = 2 }, { "probe", "heavy" })
		local ok = inst.stats().count == 2 and #inst.withTag("probe") == 2 and inst.get("probe.b").weight == 2
		inst.remove("probe.a") inst.remove("probe.b")
		return ok
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
