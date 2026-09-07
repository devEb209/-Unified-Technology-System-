-- ARKHER SYSTEM W.0183 :: Dialogue Scene Colour Grade
-- Category W - CINEMATIC
-- ARKHER Cinematic Framework capability: shots, sequences, camera language, grading and playback.
-- Kit: grade (exposure, contrast, saturation, white balance and tone mapping)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "W.0183"
	S.key = "arkher.cine.dialoguescene.colour_grade"
	S.name = "Dialogue Scene Colour Grade"
	S.category = "W"
	S.family = "CINEMATIC"
	S.area = "Dialogue Scene"
	S.aspect = "Colour Grade"
	S.kit = "grade"
	S.version = "1.0.0"
	S.deps = { "arkher.cine.dialoguescene.camera_rig" }
	S.tags = { "w", "dialoguescene", "grade", "cine" }
	S.description = "Dialogue Scene Colour Grade: exposure, contrast, saturation, white balance and tone mapping for the Dialogue Scene subsystem."
	S.params = {
		backlogLimit = 40,
		baseRadius = 320,
		baseWeight = 0.72,
		bias = 0.32,
		biasWeight = 0.17,
		ceiling = 472,
		detailWeight = 0.72,
		failureTolerance = 2,
		horizon = 1,
		integrator = "euler",
		minConfidence = 0.72,
		minThrottle = 0.21,
		regressionSlope = 0.11,
		saturation = 0.92,
		scale = 3.2
	}
	S.features = { "setLook", "installLooks", "applyLook", "luma", "toneCurve", "apply", "applyMany", "averageLuma", "autoExpose", "reset", "stats", "look", "pixel", "expose", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("grade", { id = "arkher.cine.dialoguescene.colour_grade", exposure = 0.07, contrast = 1.12, saturation = 0.92, toneMap = "filmic" })
		inst.system = S
		inst.ctx = ctx

		function inst.look(name, weight)
			inst.installLooks()
			return inst.applyLook(name or "warmDay", weight or 1)
		end
		function inst.pixel(r, g, b)
			return inst.apply({ r or 0.5, g or 0.5, b or 0.5 })
		end
		function inst.expose(target)
			local sample = {}
			for i = 1, 4 do sample[i] = { 0.04 * i, 0.04 * i, 0.04 * i } end
			for _ = 1, 8 do inst.autoExpose(sample, target or 0.18) end
			return inst.exposure
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
				engine.bus:subscribe("arkher.cine.dialoguescene.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		local base = inst.pixel(0.5, 0.5, 0.5)
		local ok = base[1] >= 0 and base[1] <= 1
		ok = ok and inst.look("noir", 1)
		local noir = inst.pixel(0.8, 0.2, 0.2)
		ok = ok and math.abs(noir[1] - noir[3]) < 0.3
		inst.reset()
		ok = ok and inst.expose(0.18) ~= 0
		ok = ok and inst.luma({ 1, 1, 1 }) > 0.99
		return ok and inst.stats().applied >= 3
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
