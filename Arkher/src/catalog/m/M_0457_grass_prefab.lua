-- ARKHER SYSTEM M.0457 :: Grass Instancing
-- Category M - PROCEDURAL
-- Procedural capability: deterministic synthesis of worlds, cities, structures and detail from a seed.
-- Kit: prefab (template instancing of generated content)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "M.0457"
	S.key = "arkher.proc.grass.instancing"
	S.name = "Grass Instancing"
	S.category = "M"
	S.family = "PROCEDURAL"
	S.area = "Grass"
	S.aspect = "Instancing"
	S.kit = "prefab"
	S.version = "1.0.0"
	S.deps = { "arkher.proc.grass.rule_synthesizer" }
	S.tags = { "m", "grass", "prefab", "proc" }
	S.description = "Grass Instancing: template instancing of generated content for the Grass subsystem."
	S.params = {
		backlogLimit = 44,
		baseRadius = 480,
		baseWeight = 0.76,
		bias = 0.36,
		biasWeight = 0.21,
		ceiling = 132,
		detailWeight = 0.76,
		failureTolerance = 1,
		horizon = 5,
		integrator = "euler",
		minConfidence = 0.76,
		minThrottle = 0.23,
		regressionSlope = 0.13,
		saturation = 0.71,
		scale = 3.6
	}
	S.features = { "define", "instantiate", "override", "revert", "editTemplate", "instancesOf", "diff", "destroy", "stats", "ensureTemplate", "spawnMany", "retune", "overrideRate", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("prefab", { id = "arkher.proc.grass.instancing" })
		inst.system = S
		inst.ctx = ctx

		function inst.ensureTemplate()
			if inst.templates[S.area] then return S.area end
			inst.define(S.area, { props = { weight = S.params.baseWeight, detail = S.params.detailWeight,
				kind = S.key }, tags = { S.area } })
			return S.area
		end
		function inst.spawnMany(n)
			inst.ensureTemplate()
			local ids = {}
			for i = 1, (n or 4) do ids[#ids + 1] = inst.instantiate(S.area, i == 1 and { weight = 99 } or nil) end
			return ids
		end
		function inst.retune(key, value)
			inst.ensureTemplate()
			return inst.editTemplate(S.area, key, value)
		end
		function inst.overrideRate()
			local total, overridden = 0, 0
			for _, i in pairs(inst.instances) do
				total = total + 1
				for _ in pairs(i.overrides) do overridden = overridden + 1 break end
			end
			if total == 0 then return 0 end
			return overridden / total
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
				engine.bus:subscribe("arkher.proc.grass.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		local ids = inst.spawnMany(4)
		local ok = #ids == 4
		ok = ok and inst.instances[ids[1]].props.weight == 99
		ok = ok and inst.retune("weight", 7) == 3
		ok = ok and inst.instances[ids[2]].props.weight == 7
		ok = ok and inst.instances[ids[1]].props.weight == 99
		ok = ok and inst.overrideRate() == 0.25
		inst.revert(ids[1], "weight")
		ok = ok and inst.instances[ids[1]].props.weight == 7
		return ok and #inst.instancesOf(S.area) == 4
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
