-- ARKHER SYSTEM N.0227 :: Magic Aura Effect Graph
-- Category N - VFX
-- ARKHER VFX Framework capability: emission, simulation, forces and trails inside one shared budget.
-- Kit: shadegraph (node graph describing how the effect is shaded)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "N.0227"
	S.key = "arkher.vfx.magicaura.effect_graph"
	S.name = "Magic Aura Effect Graph"
	S.category = "N"
	S.family = "VFX"
	S.area = "Magic Aura"
	S.aspect = "Effect Graph"
	S.kit = "shadegraph"
	S.version = "1.0.0"
	S.deps = { "arkher.vfx.magicaura.curve_authoring" }
	S.tags = { "n", "magicaura", "shadegraph", "vfx" }
	S.description = "Magic Aura Effect Graph: node graph describing how the effect is shaded for the Magic Aura subsystem."
	S.params = {
		backlogLimit = 13,
		baseRadius = 200,
		baseWeight = 0.95,
		bias = 0.05,
		biasWeight = 0.1,
		ceiling = 533,
		detailWeight = 0.45,
		failureTolerance = 0,
		horizon = 6,
		integrator = "verlet",
		minConfidence = 0.45,
		minThrottle = 0.225,
		regressionSlope = 0.075,
		saturation = 0.9,
		scale = 3.5
	}
	S.features = { "addNode", "connect", "hasCycle", "topoOrder", "evaluate", "fold", "compile", "stats", "buildGraph", "shade", "optimize", "source", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("shadegraph", { id = "arkher.vfx.magicaura.effect_graph" })
		inst.system = S
		inst.ctx = ctx

		function inst.buildGraph()
			if inst.nodes["out"] then return inst end
			inst.addNode("k", "constant", { value = S.params.detailWeight })
			inst.addNode("src", "input", { key = "value", default = 0.5 })
			inst.addNode("sum", "add")
			inst.addNode("sat", "saturate")
			inst.addNode("out", "output", { channel = "value" })
			inst.connect("k", "sum", 1)
			inst.connect("src", "sum", 2)
			inst.connect("sum", "sat", 1)
			inst.connect("sat", "out", 1)
			return inst
		end
		function inst.shade(value)
			inst.buildGraph()
			local out = inst.evaluate({ value = value or 0.5 })
			return out.value
		end
		function inst.optimize()
			inst.buildGraph()
			return inst.fold()
		end
		function inst.source()
			inst.buildGraph()
			return inst.compile()
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
				engine.bus:subscribe("arkher.vfx.magicaura.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		inst.buildGraph()
		local ok = inst.stats().nodes == 5
		local expected = math.min(1, S.params.detailWeight + 0.25)
		ok = ok and math.abs(inst.shade(0.25) - expected) < 1e-9
		ok = ok and inst.optimize() >= 0
		local src = inst.source()
		ok = ok and type(src) == "string" and #src > 40
		ok = ok and inst.hasCycle() == false
		return ok and inst.stats().evaluations > 0
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
