-- ARKHER SYSTEM W.0075 :: Dolly Colour Grade
-- Category W - CINEMATIC
-- ARKHER Cinematic Framework capability: shots, sequences, camera language, grading and playback.
-- Kit: grade (exposure, contrast, saturation, white balance and tone mapping)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "W.0075"
	S.key = "arkher.cine.dolly.colour_grade"
	S.name = "Dolly Colour Grade"
	S.category = "W"
	S.family = "CINEMATIC"
	S.area = "Dolly"
	S.aspect = "Colour Grade"
	S.kit = "grade"
	S.version = "1.0.0"
	S.deps = { "arkher.cine.dolly.camera_rig" }
	S.tags = { "w", "dolly", "grade", "cine" }
	S.description = "Dolly Colour Grade: exposure, contrast, saturation, white balance and tone mapping for the Dolly subsystem."
	S.params = {
		backlogLimit = 13,
		baseRadius = 360,
		baseWeight = 0.75,
		bias = 0.05,
		biasWeight = 0.1,
		ceiling = 309,
		detailWeight = 0.25,
		failureTolerance = 0,
		horizon = 6,
		integrator = "verlet",
		minConfidence = 0.45,
		minThrottle = 0.125,
		regressionSlope = 0.075,
		saturation = 0.7,
		scale = 1.5
	}
	S.features = { "setLook", "installLooks", "applyLook", "luma", "toneCurve", "apply", "applyMany", "averageLuma", "autoExpose", "reset", "stats", "look", "pixel", "expose", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("grade", { id = "arkher.cine.dolly.colour_grade", exposure = -0.10, contrast = 0.95, saturation = 1.10, toneMap = "reinhard" })
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
				engine.bus:subscribe("arkher.cine.dolly.*", function(payload) inst.lastSignal = payload end)
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
