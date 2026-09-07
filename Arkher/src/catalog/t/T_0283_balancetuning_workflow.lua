-- ARKHER SYSTEM T.0283 :: Balance Tuning Plan Workflow
-- Category T - SINGULARITY AI
-- Singularity AI capability: understand, know, plan, act, judge - the intelligence that drives the whole engine.
-- Kit: workflow (dependency-ordered plans that verify, retry and roll back)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "T.0283"
	S.key = "arkher.ai.balancetuning.plan_workflow"
	S.name = "Balance Tuning Plan Workflow"
	S.category = "T"
	S.family = "SINGULARITY AI"
	S.area = "Balance Tuning"
	S.aspect = "Plan Workflow"
	S.kit = "workflow"
	S.version = "1.0.0"
	S.deps = { "arkher.ai.balancetuning.semantic_knowledge" }
	S.tags = { "t", "balancetuning", "workflow", "ai" }
	S.description = "Balance Tuning Plan Workflow: dependency-ordered plans that verify, retry and roll back for the Balance Tuning subsystem."
	S.params = {
		backlogLimit = 38,
		baseRadius = 240,
		baseWeight = 0.6,
		bias = 0.3,
		biasWeight = 0.15,
		ceiling = 94,
		detailWeight = 0.7,
		failureTolerance = 0,
		horizon = 7,
		integrator = "euler",
		minConfidence = 0.7,
		minThrottle = 0.2,
		regressionSlope = 0.1,
		saturation = 0.8,
		scale = 3.0
	}
	S.features = { "addStep", "plan", "estimate", "criticalPath", "run", "rollback", "progress", "failedSteps", "reset", "stats", "installStages", "executeAll", "longest", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("workflow", { id = "arkher.ai.balancetuning.plan_workflow", maxRetries = 3, budget = 60 })
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
				engine.bus:subscribe("arkher.ai.balancetuning.*", function(payload) inst.lastSignal = payload end)
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
