-- ARKHER SYSTEM Q.0247 :: Map Screen Localization Registry
-- Category Q - UI / UX
-- ARKHER Interface Framework capability: responsive, themed, accessible interfaces on every device.
-- Kit: registry (catalogue of strings, plurals and locale metadata)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "Q.0247"
	S.key = "arkher.ui.mapscreen.localization_registry"
	S.name = "Map Screen Localization Registry"
	S.category = "Q"
	S.family = "UI / UX"
	S.area = "Map Screen"
	S.aspect = "Localization Registry"
	S.kit = "registry"
	S.version = "1.0.0"
	S.deps = { "arkher.ui.mapscreen.theme_composition" }
	S.tags = { "q", "mapscreen", "registry", "ui" }
	S.description = "Map Screen Localization Registry: catalogue of strings, plurals and locale metadata for the Map Screen subsystem."
	S.params = {
		backlogLimit = 18,
		baseRadius = 560,
		baseWeight = 0.8,
		bias = 0.1,
		biasWeight = 0.15,
		ceiling = 250,
		detailWeight = 0.3,
		failureTolerance = 0,
		horizon = 3,
		integrator = "euler",
		minConfidence = 0.5,
		minThrottle = 0.15,
		regressionSlope = 0.1,
		saturation = 0.75,
		scale = 2.0
	}
	S.features = { "define", "get", "has", "remove", "withTag", "query", "ids", "snapshot", "restore", "stats", "upsert", "bulkDefine", "tally", "export", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("registry", { id = "arkher.ui.mapscreen.localization_registry" })
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
				engine.bus:subscribe("arkher.ui.mapscreen.*", function(payload) inst.lastSignal = payload end)
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
