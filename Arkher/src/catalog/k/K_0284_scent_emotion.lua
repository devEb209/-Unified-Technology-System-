-- ARKHER SYSTEM K.0284 :: Scent Emotion
-- Category K - NPC / NEURAL MIND NETWORK
-- ARKHER NMN capability: minds that perceive, remember, feel, plan, move and live together.
-- Kit: emotion (appraisal of events into valence, arousal and mood)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "K.0284"
	S.key = "arkher.npc.scent.emotion"
	S.name = "Scent Emotion"
	S.category = "K"
	S.family = "NPC / NEURAL MIND NETWORK"
	S.area = "Scent"
	S.aspect = "Emotion"
	S.kit = "emotion"
	S.version = "1.0.0"
	S.deps = { "arkher.npc.scent.drive_system" }
	S.tags = { "k", "scent", "emotion", "npc" }
	S.description = "Scent Emotion: appraisal of events into valence, arousal and mood for the Scent subsystem."
	S.params = {
		backlogLimit = 31,
		baseRadius = 600,
		baseWeight = 0.63,
		bias = 0.23,
		biasWeight = 0.08,
		ceiling = 391,
		detailWeight = 0.43,
		failureTolerance = 3,
		horizon = 8,
		integrator = "verlet",
		minConfidence = 0.63,
		minThrottle = 0.215,
		regressionSlope = 0.065,
		saturation = 0.83,
		scale = 3.3
	}
	S.features = { "appraise", "tick", "label", "intensity", "mood", "influence", "reset", "stats", "good", "bad", "settle", "expression", "boldness", "isDistressed", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("emotion", { id = "arkher.npc.scent.emotion", inertia = 0.78, decayRate = 0.43, baselineArousal = 0.13 })
		inst.system = S
		inst.ctx = ctx

		function inst.good(intensity) return inst.appraise(0.8, intensity or 0.6) end
		function inst.bad(intensity) return inst.appraise(-0.8, intensity or 0.6) end
		function inst.settle(seconds, step)
			local dt = step or 0.5
			local n = math.max(1, math.floor((seconds or 4) / dt))
			for _ = 1, n do inst.tick(dt) end
			return inst.valence, inst.arousal
		end
		function inst.expression()
			local name, distance = inst.label()
			return { label = name, distance = distance,
				intensity = inst.intensity(), mood = inst.mood() }
		end
		function inst.boldness(base) return inst.influence(base or 1) end
		function inst.isDistressed() return inst.valence < -0.3 and inst.arousal > 0.3 end

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
				engine.bus:subscribe("arkher.npc.scent.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		inst.bad(1)
		local ok = inst.valence < 0 and inst.isDistressed()
		local e = inst.expression()
		ok = ok and e.label ~= nil and e.intensity > 0 and inst.boldness(1) < 1
		inst.settle(30, 0.5)
		ok = ok and math.abs(inst.valence - inst.baselineValence) < 0.2
		inst.good(1)
		return ok and inst.valence > 0 and inst.stats().appraisals == 2
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
