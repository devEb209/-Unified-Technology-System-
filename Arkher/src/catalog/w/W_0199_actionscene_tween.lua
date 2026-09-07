-- ARKHER SYSTEM W.0199 :: Action Scene Motion Tween
-- Category W - CINEMATIC
-- ARKHER Cinematic Framework capability: shots, sequences, camera language, grading and playback.
-- Kit: tween (eased, delayed and sequenced motion of cinematic properties)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "W.0199"
	S.key = "arkher.cine.actionscene.motion_tween"
	S.name = "Action Scene Motion Tween"
	S.category = "W"
	S.family = "CINEMATIC"
	S.area = "Action Scene"
	S.aspect = "Motion Tween"
	S.kit = "tween"
	S.version = "1.0.0"
	S.deps = { "arkher.cine.actionscene.playback_orchestrator" }
	S.tags = { "w", "actionscene", "tween", "cine" }
	S.description = "Action Scene Motion Tween: eased, delayed and sequenced motion of cinematic properties for the Action Scene subsystem."
	S.params = {
		backlogLimit = 34,
		baseRadius = 240,
		baseWeight = 0.56,
		bias = 0.26,
		biasWeight = 0.11,
		ceiling = 218,
		detailWeight = 0.46,
		failureTolerance = 1,
		horizon = 3,
		integrator = "euler",
		minConfidence = 0.66,
		minThrottle = 0.23,
		regressionSlope = 0.08,
		saturation = 0.76,
		scale = 3.6
	}
	S.features = { "create", "remove", "pause", "resume", "valueOf", "ease", "update", "sequence", "activeCount", "clear", "stats", "installIntro", "advanceBy", "valuesOf", "curveSamples", "chain", "holdAll", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("tween", { id = "arkher.cine.actionscene.motion_tween", timeScale = 0.96 })
		inst.system = S
		inst.ctx = ctx

		function inst.installIntro()
			if #inst.order > 0 then return #inst.order end
			inst.create("fade", { from = 0, to = 1, duration = 0.3, easing = "quadOut" })
			inst.create("slide", { from = -40, to = 0, duration = 0.4, easing = "cubicOut" })
			return #inst.order
		end
		function inst.advanceBy(seconds, dt)
			local step = dt or 1 / 60
			local steps = math.max(1, math.floor((seconds or 0.5) / step))
			local finished = 0
			for _ = 1, steps do finished = finished + #inst.update(step) end
			return finished
		end
		function inst.valuesOf()
			local out = {}
			for _, id in ipairs(inst.order) do out[id] = inst.valueOf(id) end
			return out
		end
		function inst.curveSamples(name, count)
			local out = {}
			local n = count or 5
			for i = 0, n do out[#out + 1] = inst.ease(name or "quadOut", i / n) end
			return out
		end
		function inst.chain(prefix, steps)
			return inst.sequence(prefix or "chain", steps or {
				{ from = 0, to = 1, duration = 0.15 },
				{ from = 1, to = 0, duration = 0.15 } })
		end
		function inst.holdAll()
			for _, id in ipairs(inst.order) do inst.pause(id) end
			return #inst.order
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
				engine.bus:subscribe("arkher.cine.actionscene.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		local ok = inst.installIntro() == 2
		inst.advanceBy(0.15, 1 / 60)
		local mid = inst.valuesOf()
		ok = ok and mid.fade > 0 and mid.fade < 1
		local finished = inst.advanceBy(0.6, 1 / 60)
		ok = ok and finished >= 2 and inst.valueOf("fade") == 1
		local curve = inst.curveSamples("quadOut", 4)
		ok = ok and #curve == 5 and curve[1] <= curve[#curve]
		ok = ok and math.abs(inst.ease("linear", 0.5) - 0.5) < 1e-6
		local ids, total = inst.chain("intro")
		ok = ok and #ids == 2 and total > 0
		ok = ok and inst.holdAll() >= 2
		inst.clear()
		return ok and inst.activeCount() == 0 and inst.stats().completed >= 2
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
