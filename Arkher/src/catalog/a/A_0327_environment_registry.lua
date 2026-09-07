-- ARKHER SYSTEM A.0327 :: Environment Registry
-- Category A - UES / CORE
-- Kernel-level engine capability: the UES foundation every other ARKHER framework stands on.
-- Kit: registry (typed record storage, tagging and querying)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "A.0327"
	S.key = "arkher.core.environment.registry"
	S.name = "Environment Registry"
	S.category = "A"
	S.family = "UES / CORE"
	S.area = "Environment"
	S.aspect = "Registry"
	S.kit = "registry"
	S.version = "1.0.0"
	S.deps = { "arkher.core.environment.core_runtime" }
	S.tags = { "a", "environment", "registry", "core" }
	S.description = "Environment Registry: typed record storage, tagging and querying for the Environment subsystem."
	S.params = {
		backlogLimit = 35,
		baseRadius = 600,
		baseWeight = 0.57,
		bias = 0.27,
		biasWeight = 0.12,
		ceiling = 219,
		detailWeight = 0.67,
		failureTolerance = 2,
		horizon = 4,
		integrator = "verlet",
		minConfidence = 0.67,
		minThrottle = 0.185,
		regressionSlope = 0.085,
		saturation = 0.77,
		scale = 2.7
	}
	S.features = { "define", "get", "has", "remove", "withTag", "query", "ids", "snapshot", "restore", "stats", "upsert", "bulkDefine", "tally", "export", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("registry", { id = "arkher.core.environment.registry" })
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
				engine.bus:subscribe("arkher.core.environment.*", function(payload) inst.lastSignal = payload end)
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
