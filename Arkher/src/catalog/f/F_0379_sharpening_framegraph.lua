-- ARKHER SYSTEM F.0379 :: Sharpening Frame Graph
-- Category F - RENDERING
-- Rendering capability: the frame itself - declared, culled, lit, budgeted, resolved and paced.
-- Kit: framegraph (declared passes, culling, ordering and aliasing)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "F.0379"
	S.key = "arkher.render.sharpening.frame_graph"
	S.name = "Sharpening Frame Graph"
	S.category = "F"
	S.family = "RENDERING"
	S.area = "Sharpening"
	S.aspect = "Frame Graph"
	S.kit = "framegraph"
	S.version = "1.0.0"
	S.deps = {  }
	S.tags = { "f", "sharpening", "framegraph", "render" }
	S.description = "Sharpening Frame Graph: declared passes, culling, ordering and aliasing for the Sharpening subsystem."
	S.params = {
		backlogLimit = 25,
		baseRadius = 200,
		baseWeight = 0.67,
		bias = 0.17,
		biasWeight = 0.22,
		ceiling = 193,
		detailWeight = 0.57,
		failureTolerance = 2,
		horizon = 2,
		integrator = "verlet",
		minConfidence = 0.57,
		minThrottle = 0.135,
		regressionSlope = 0.135,
		saturation = 0.87,
		scale = 1.7
	}
	S.features = { "addResource", "addPass", "cull", "compile", "alias", "totalCost", "execute", "describe", "stats", "buildFrame", "frameOrder", "runFrame", "memoryPlan", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("framegraph", { id = "arkher.render.sharpening.frame_graph", budgetMs = 11.00 })
		inst.system = S
		inst.ctx = ctx

		function inst.buildFrame()
			if inst.passes["main"] then return inst end
			inst.addPass("prepare", { writes = { "buffer" }, cost = 1.0 })
			inst.addPass("extra", { reads = { "buffer" }, writes = { "aux" }, cost = 2.0,
				optional = true, priority = 2 })
			inst.addPass("main", { reads = { "buffer", "aux" }, writes = { "out" }, cost = 1.5,
				final = true })
			inst.addPass("orphan", { writes = { "unused" }, cost = 4.0 })
			return inst
		end
		function inst.frameOrder()
			inst.buildFrame()
			return inst.compile()
		end
		function inst.runFrame(budget)
			inst.buildFrame()
			return inst.execute({}, budget)
		end
		function inst.memoryPlan()
			inst.buildFrame()
			return inst.alias()
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
				engine.bus:subscribe("arkher.render.sharpening.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		local order = inst.frameOrder()
		local ok = #order == 3 and inst.culled == 1
		ok = ok and order[#order] == "main"
		local tight = inst.runFrame(2.0)
		ok = ok and #tight.skipped == 1
		local loose = inst.runFrame(50)
		ok = ok and #loose.skipped == 0
		local plan = inst.memoryPlan()
		ok = ok and plan.peakBytes > 0
		return ok and inst.totalCost() > 0
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
