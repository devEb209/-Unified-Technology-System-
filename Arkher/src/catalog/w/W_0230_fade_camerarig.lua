-- ARKHER SYSTEM W.0230 :: Fade Camera Rig
-- Category W - CINEMATIC
-- ARKHER Cinematic Framework capability: shots, sequences, camera language, grading and playback.
-- Kit: camerarig (dolly, orbit, crane and handheld camera with focus and shake)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "W.0230"
	S.key = "arkher.cine.fade.camera_rig"
	S.name = "Fade Camera Rig"
	S.category = "W"
	S.family = "CINEMATIC"
	S.area = "Fade"
	S.aspect = "Camera Rig"
	S.kit = "camerarig"
	S.version = "1.0.0"
	S.deps = { "arkher.cine.fade.sequence_timeline" }
	S.tags = { "w", "fade", "camerarig", "cine" }
	S.description = "Fade Camera Rig: dolly, orbit, crane and handheld camera with focus and shake for the Fade subsystem."
	S.params = {
		backlogLimit = 30,
		baseRadius = 240,
		baseWeight = 0.82,
		bias = 0.22,
		biasWeight = 0.07,
		ceiling = 86,
		detailWeight = 0.22,
		failureTolerance = 2,
		horizon = 7,
		integrator = "euler",
		minConfidence = 0.62,
		minThrottle = 0.11,
		regressionSlope = 0.06,
		saturation = 0.77,
		scale = 1.2
	}
	S.features = { "setMode", "addPathPoint", "pathAt", "lookAt", "forward", "shake", "focusOn", "circleOfConfusion", "frameSubject", "update", "state", "stats", "stage", "dollyThrough", "depthOfField", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("camerarig", { id = "arkher.cine.fade.camera_rig", fov = 0.92, focus = 12.0, aperture = 2.4, smoothing = 12.0, distance = 14, height = 4 })
		inst.system = S
		inst.ctx = ctx

		function inst.stage(subject)
			inst.setMode("orbit")
			for _ = 1, 12 do inst.update(1 / 30, subject or Vec.vec3()) end
			return inst.position
		end
		function inst.dollyThrough(a, b)
			inst.addPathPoint(a or Vec.vec3())
			inst.addPathPoint(b or Vec.vec3(10, 0, 0))
			inst.setMode("dolly")
			return inst.pathLength
		end
		function inst.depthOfField(distance)
			return inst.circleOfConfusion(distance or inst.focus)
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
				engine.bus:subscribe("arkher.cine.fade.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		local subject = Vec.vec3()
		local p = inst.stage(subject)
		local ok = p ~= nil and inst.focus > 0
		ok = ok and inst.depthOfField(inst.focus) < 0.001
		ok = ok and inst.depthOfField(inst.focus * 5) > 0
		ok = ok and inst.dollyThrough(Vec.vec3(), Vec.vec3(10, 0, 0)) > 9
		ok = ok and inst.pathAt(0.5).x > 0
		inst.shake(1)
		inst.update(0.2, subject)
		return ok and inst.shakeAmount < 1 and inst.stats().updates >= 13
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
