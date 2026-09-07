-- ARKHER SYSTEM R.0027 :: Handshake Prediction And Reconciliation
-- Category R - NETWORKING
-- ARKHER Networking Framework capability: authoritative replication, prediction and bandwidth discipline.
-- Kit: prediction (client simulation, correction and input replay)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "R.0027"
	S.key = "arkher.net.handshake.prediction_and_reconciliation"
	S.name = "Handshake Prediction And Reconciliation"
	S.category = "R"
	S.family = "NETWORKING"
	S.area = "Handshake"
	S.aspect = "Prediction And Reconciliation"
	S.kit = "prediction"
	S.version = "1.0.0"
	S.deps = { "arkher.net.handshake.time_sync" }
	S.tags = { "r", "handshake", "prediction", "net" }
	S.description = "Handshake Prediction And Reconciliation: client simulation, correction and input replay for the Handshake subsystem."
	S.params = {
		backlogLimit = 39,
		baseRadius = 280,
		baseWeight = 0.71,
		bias = 0.31,
		biasWeight = 0.16,
		ceiling = 511,
		detailWeight = 0.71,
		failureTolerance = 1,
		horizon = 8,
		integrator = "verlet",
		minConfidence = 0.71,
		minThrottle = 0.205,
		regressionSlope = 0.105,
		saturation = 0.91,
		scale = 3.1
	}
	S.features = { "simulate", "pushInput", "pending", "reconcile", "smooth", "predictionError", "reset", "applyQuality", "stats", "driveForward", "confirm", "correctTo", "errorNow", "renderPose", "rewind", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("prediction", { id = "arkher.net.handshake.prediction_and_reconciliation", errorThreshold = 0.035, smoothing = 9.0, maxInputs = 120 })
		inst.system = S
		inst.ctx = ctx

		function inst.driveForward(steps, dt)
			local input = { move = Vec.vec3(1, 0, 0), speed = 8 }
			local step = dt or 1 / 30
			for _ = 1, (steps or 6) do inst.pushInput(input, step) end
			return inst.sequence
		end
		function inst.confirm(sequence)
			return inst.reconcile({ position = inst.state.position,
				velocity = inst.state.velocity }, sequence or inst.sequence)
		end
		function inst.correctTo(position, sequence)
			return inst.reconcile({ position = position or Vec.vec3(),
				velocity = Vec.vec3() }, sequence or math.max(0, inst.sequence - 2))
		end
		function inst.errorNow()
			return inst.predictionError()
		end
		function inst.renderPose(dt)
			return inst.smooth({ position = inst.serverState.position,
				velocity = inst.serverState.velocity }, dt or 1 / 60)
		end
		function inst.rewind()
			inst.reset({ position = Vec.vec3(), velocity = Vec.vec3() })
			return inst.pending()
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
				engine.bus:subscribe("arkher.net.handshake.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		local ok = inst.driveForward(6, 1 / 30) == 6
		ok = ok and inst.state.position.x > 0 and inst.pending() == 6
		local corrected = inst.confirm(inst.sequence)
		ok = ok and not corrected and inst.pending() == 0
		inst.driveForward(4, 1 / 30)
		local far = Vec.vec3(inst.state.position.x - 5, 0, 0)
		local fixed, err = inst.correctTo(far)
		ok = ok and fixed and err > inst.errorThreshold
		ok = ok and inst.stats().replays > 0
		ok = ok and inst.errorNow() >= 0
		local pose = inst.renderPose(1 / 60)
		ok = ok and pose.position ~= nil
		return ok and inst.rewind() == 0 and inst.stats().mispredictions >= 1
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
