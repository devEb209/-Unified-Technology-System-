-- ARKHER SYSTEM Z.0564 :: Collective Behaviour Autonomous Pipeline
-- Category Z - ARKHER ORIGINAL TECHNOLOGIES
-- ARKHER original technology: the capabilities that exist in no other engine, built for a world that keeps living.
-- Kit: autopipeline (the project analysing and repairing itself, with measured gain)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "Z.0564"
	S.key = "arkher.origin.collectivebehaviour.autonomous_pipeline"
	S.name = "Collective Behaviour Autonomous Pipeline"
	S.category = "Z"
	S.family = "ARKHER ORIGINAL TECHNOLOGIES"
	S.area = "Collective Behaviour"
	S.aspect = "Autonomous Pipeline"
	S.kit = "autopipeline"
	S.version = "1.0.0"
	S.deps = { "arkher.origin.collectivebehaviour.simulation_fabric" }
	S.tags = { "z", "collectivebehaviour", "autopipeline", "origin" }
	S.description = "Collective Behaviour Autonomous Pipeline: the project analysing and repairing itself, with measured gain for the Collective Behaviour subsystem."
	S.params = {
		backlogLimit = 18,
		baseRadius = 400,
		baseWeight = 0.5,
		bias = 0.1,
		biasWeight = 0.15,
		ceiling = 362,
		detailWeight = 0.5,
		failureTolerance = 0,
		horizon = 3,
		integrator = "euler",
		minConfidence = 0.5,
		minThrottle = 0.1,
		regressionSlope = 0.1,
		saturation = 0.7,
		scale = 1.0
	}
	S.features = { "addRule", "installDefaults", "analyze", "projectHealth", "applyFix", "improve", "report", "stats", "sampleProject", "audit", "repair", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("autopipeline", { id = "arkher.origin.collectivebehaviour.autonomous_pipeline", maxIterations = 6 })
		inst.system = S
		inst.ctx = ctx

		function inst.sampleProject()
			return { frameMs = 40, targetMs = 16.6, drawCalls = 2400, maxDrawCalls = 900,
				failingTests = 2, orphanAssets = 4, memoryMb = 800, memoryCeilingMb = 512,
				quality = 1 }
		end
		function inst.audit(project) return inst.analyze(project or inst.sampleProject()) end
		function inst.repair(project, rounds) return inst.improve(project, rounds or 24) end

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
				engine.bus:subscribe("arkher.origin.collectivebehaviour.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		inst.installDefaults()
		local project = inst.sampleProject()
		local findings = inst.audit(project)
		local ok = #findings == 5 and findings[1].severity == 3
		local before = inst.projectHealth(project)
		local record = inst.repair(project, 24)
		ok = ok and record.gain > 0 and record.after > before
		ok = ok and project.orphanAssets == 0 and project.drawCalls < 2400
		ok = ok and inst.report().open >= 0
		return ok and inst.stats().applied > 0
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
