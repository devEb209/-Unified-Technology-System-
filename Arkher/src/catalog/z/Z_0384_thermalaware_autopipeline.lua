-- ARKHER SYSTEM Z.0384 :: Thermal Aware Simulation Autonomous Pipeline
-- Category Z - ARKHER ORIGINAL TECHNOLOGIES
-- ARKHER original technology: the capabilities that exist in no other engine, built for a world that keeps living.
-- Kit: autopipeline (the project analysing and repairing itself, with measured gain)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "Z.0384"
	S.key = "arkher.origin.thermalaware.autonomous_pipeline"
	S.name = "Thermal Aware Simulation Autonomous Pipeline"
	S.category = "Z"
	S.family = "ARKHER ORIGINAL TECHNOLOGIES"
	S.area = "Thermal Aware Simulation"
	S.aspect = "Autonomous Pipeline"
	S.kit = "autopipeline"
	S.version = "1.0.0"
	S.deps = { "arkher.origin.thermalaware.simulation_fabric" }
	S.tags = { "z", "thermalaware", "autopipeline", "origin" }
	S.description = "Thermal Aware Simulation Autonomous Pipeline: the project analysing and repairing itself, with measured gain for the Thermal Aware Simulation subsystem."
	S.params = {
		backlogLimit = 15,
		baseRadius = 280,
		baseWeight = 0.77,
		bias = 0.07,
		biasWeight = 0.12,
		ceiling = 383,
		detailWeight = 0.47,
		failureTolerance = 2,
		horizon = 8,
		integrator = "verlet",
		minConfidence = 0.47,
		minThrottle = 0.235,
		regressionSlope = 0.085,
		saturation = 0.72,
		scale = 3.7
	}
	S.features = { "addRule", "installDefaults", "analyze", "projectHealth", "applyFix", "improve", "report", "stats", "sampleProject", "audit", "repair", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("autopipeline", { id = "arkher.origin.thermalaware.autonomous_pipeline", maxIterations = 11 })
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
				engine.bus:subscribe("arkher.origin.thermalaware.*", function(payload) inst.lastSignal = payload end)
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
