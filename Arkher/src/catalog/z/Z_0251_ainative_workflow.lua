-- ARKHER SYSTEM Z.0251 :: AI Native Engine Architecture Adaptive Workflow
-- Category Z - ARKHER ORIGINAL TECHNOLOGIES
-- ARKHER original technology: the capabilities that exist in no other engine, built for a world that keeps living.
-- Kit: workflow (verified, retryable, reversible execution plans)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "Z.0251"
	S.key = "arkher.origin.ainative.adaptive_workflow"
	S.name = "AI Native Engine Architecture Adaptive Workflow"
	S.category = "Z"
	S.family = "ARKHER ORIGINAL TECHNOLOGIES"
	S.area = "AI Native Engine Architecture"
	S.aspect = "Adaptive Workflow"
	S.kit = "workflow"
	S.version = "1.0.0"
	S.deps = { "arkher.origin.ainative.self_critique" }
	S.tags = { "z", "ainative", "workflow", "origin" }
	S.description = "AI Native Engine Architecture Adaptive Workflow: verified, retryable, reversible execution plans for the AI Native Engine Architecture subsystem."
	S.params = {
		backlogLimit = 38,
		baseRadius = 400,
		baseWeight = 0.9,
		bias = 0.3,
		biasWeight = 0.15,
		ceiling = 566,
		detailWeight = 0.5,
		failureTolerance = 0,
		horizon = 7,
		integrator = "euler",
		minConfidence = 0.7,
		minThrottle = 0.1,
		regressionSlope = 0.1,
		saturation = 0.85,
		scale = 1.0
	}
	S.features = { "addStep", "plan", "estimate", "criticalPath", "run", "rollback", "progress", "failedSteps", "reset", "stats", "installStages", "executeAll", "longest", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("workflow", { id = "arkher.origin.ainative.adaptive_workflow", maxRetries = 1, budget = 100 })
		inst.system = S
		inst.ctx = ctx

		function inst.installStages()
			local state = { prepared = false, built = 0, verified = false }
			inst.shared = state
			inst.addStep("prepare", { cost = 1,
				run = function() state.prepared = true return true end,
				verify = function() return state.prepared end,
				undo = function() state.prepared = false end })
			inst.addStep("build", { cost = 2, requires = { "prepare" },
				run = function() state.built = state.built + 4 return state.built end,
				verify = function() return state.built > 0 end,
				undo = function() state.built = 0 end })
			inst.addStep("verify", { cost = 1, requires = { "build" },
				run = function() state.verified = state.built > 0 return state.verified end,
				verify = function() return state.verified end })
			return #inst.order
		end
		function inst.executeAll()
			inst.reset()
			return inst.run(S)
		end
		function inst.longest()
			local path = inst.criticalPath()
			return path and #path or 0
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
				engine.bus:subscribe("arkher.origin.ainative.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		local ok = inst.installStages() == 3
		ok = ok and inst.executeAll()
		ok = ok and inst.shared.built == 4
		ok = ok and inst.progress() == 1
		ok = ok and inst.longest() >= 1
		ok = ok and #inst.failedSteps() == 0
		return ok and inst.stats().executed >= 3
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
