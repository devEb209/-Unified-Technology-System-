-- ARKHER SYSTEM M.0597 :: Quest Graph Instancing
-- Category M - PROCEDURAL
-- Procedural capability: deterministic synthesis of worlds, cities, structures and detail from a seed.
-- Kit: prefab (template instancing of generated content)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "M.0597"
	S.key = "arkher.proc.questgraph.instancing"
	S.name = "Quest Graph Instancing"
	S.category = "M"
	S.family = "PROCEDURAL"
	S.area = "Quest Graph"
	S.aspect = "Instancing"
	S.kit = "prefab"
	S.version = "1.0.0"
	S.deps = { "arkher.proc.questgraph.rule_synthesizer" }
	S.tags = { "m", "questgraph", "prefab", "proc" }
	S.description = "Quest Graph Instancing: template instancing of generated content for the Quest Graph subsystem."
	S.params = {
		backlogLimit = 30,
		baseRadius = 400,
		baseWeight = 0.52,
		bias = 0.22,
		biasWeight = 0.07,
		ceiling = 470,
		detailWeight = 0.62,
		failureTolerance = 2,
		horizon = 7,
		integrator = "euler",
		minConfidence = 0.62,
		minThrottle = 0.16,
		regressionSlope = 0.06,
		saturation = 0.72,
		scale = 2.2
	}
	S.features = { "define", "instantiate", "override", "revert", "editTemplate", "instancesOf", "diff", "destroy", "stats", "ensureTemplate", "spawnMany", "retune", "overrideRate", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("prefab", { id = "arkher.proc.questgraph.instancing" })
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
				engine.bus:subscribe("arkher.proc.questgraph.*", function(payload) inst.lastSignal = payload end)
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
