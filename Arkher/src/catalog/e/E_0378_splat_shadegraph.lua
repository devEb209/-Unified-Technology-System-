-- ARKHER SYSTEM E.0378 :: Terrain Splat Shading Graph
-- Category E - MATERIALS
-- ARKHER Material Framework capability: how every surface in the world is defined, layered, worn and afforded.
-- Kit: shadegraph (node graph evaluated and compiled to Luau)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "E.0378"
	S.key = "arkher.material.splat.shading_graph"
	S.name = "Terrain Splat Shading Graph"
	S.category = "E"
	S.family = "MATERIALS"
	S.area = "Terrain Splat"
	S.aspect = "Shading Graph"
	S.kit = "shadegraph"
	S.version = "1.0.0"
	S.deps = { "arkher.material.splat.layer_composition" }
	S.tags = { "e", "splat", "shadegraph", "material" }
	S.description = "Terrain Splat Shading Graph: node graph evaluated and compiled to Luau for the Terrain Splat subsystem."
	S.params = {
		backlogLimit = 12,
		baseRadius = 480,
		baseWeight = 0.64,
		bias = 0.04,
		biasWeight = 0.09,
		ceiling = 380,
		detailWeight = 0.64,
		failureTolerance = 4,
		horizon = 5,
		integrator = "euler",
		minConfidence = 0.44,
		minThrottle = 0.17,
		regressionSlope = 0.07,
		saturation = 0.84,
		scale = 2.4
	}
	S.features = { "addNode", "connect", "hasCycle", "topoOrder", "evaluate", "fold", "compile", "stats", "buildGraph", "shade", "optimize", "source", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("shadegraph", { id = "arkher.material.splat.shading_graph" })
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
				engine.bus:subscribe("arkher.material.splat.*", function(payload) inst.lastSignal = payload end)
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
