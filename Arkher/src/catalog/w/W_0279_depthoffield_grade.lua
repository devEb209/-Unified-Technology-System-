-- ARKHER SYSTEM W.0279 :: Depth Of Field Colour Grade
-- Category W - CINEMATIC
-- ARKHER Cinematic Framework capability: shots, sequences, camera language, grading and playback.
-- Kit: grade (exposure, contrast, saturation, white balance and tone mapping)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "W.0279"
	S.key = "arkher.cine.depthoffield.colour_grade"
	S.name = "Depth Of Field Colour Grade"
	S.category = "W"
	S.family = "CINEMATIC"
	S.area = "Depth Of Field"
	S.aspect = "Colour Grade"
	S.kit = "grade"
	S.version = "1.0.0"
	S.deps = { "arkher.cine.depthoffield.camera_rig" }
	S.tags = { "w", "depthoffield", "grade", "cine" }
	S.description = "Depth Of Field Colour Grade: exposure, contrast, saturation, white balance and tone mapping for the Depth Of Field subsystem."
	S.params = {
		backlogLimit = 29,
		baseRadius = 200,
		baseWeight = 0.91,
		bias = 0.21,
		biasWeight = 0.06,
		ceiling = 77,
		detailWeight = 0.21,
		failureTolerance = 1,
		horizon = 6,
		integrator = "verlet",
		minConfidence = 0.61,
		minThrottle = 0.105,
		regressionSlope = 0.055,
		saturation = 0.86,
		scale = 1.1
	}
	S.features = { "setLook", "installLooks", "applyLook", "luma", "toneCurve", "apply", "applyMany", "averageLuma", "autoExpose", "reset", "stats", "look", "pixel", "expose", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("grade", { id = "arkher.cine.depthoffield.colour_grade", exposure = -0.14, contrast = 0.91, saturation = 1.16, toneMap = "reinhard" })
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
				engine.bus:subscribe("arkher.cine.depthoffield.*", function(payload) inst.lastSignal = payload end)
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
