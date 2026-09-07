-- ARKHER SYSTEM Q.0391 :: Accessibility Localization Registry
-- Category Q - UI / UX
-- ARKHER Interface Framework capability: responsive, themed, accessible interfaces on every device.
-- Kit: registry (catalogue of strings, plurals and locale metadata)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "Q.0391"
	S.key = "arkher.ui.uiaccessibility.localization_registry"
	S.name = "Accessibility Localization Registry"
	S.category = "Q"
	S.family = "UI / UX"
	S.area = "Accessibility"
	S.aspect = "Localization Registry"
	S.kit = "registry"
	S.version = "1.0.0"
	S.deps = { "arkher.ui.uiaccessibility.theme_composition" }
	S.tags = { "q", "uiaccessibility", "registry", "ui" }
	S.description = "Accessibility Localization Registry: catalogue of strings, plurals and locale metadata for the Accessibility subsystem."
	S.params = {
		backlogLimit = 9,
		baseRadius = 520,
		baseWeight = 0.81,
		bias = 0.01,
		biasWeight = 0.06,
		ceiling = 233,
		detailWeight = 0.41,
		failureTolerance = 1,
		horizon = 2,
		integrator = "verlet",
		minConfidence = 0.41,
		minThrottle = 0.205,
		regressionSlope = 0.055,
		saturation = 0.76,
		scale = 3.1
	}
	S.features = { "define", "get", "has", "remove", "withTag", "query", "ids", "snapshot", "restore", "stats", "upsert", "bulkDefine", "tally", "export", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("registry", { id = "arkher.ui.uiaccessibility.localization_registry" })
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
				engine.bus:subscribe("arkher.ui.uiaccessibility.*", function(payload) inst.lastSignal = payload end)
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
