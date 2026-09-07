-- ARKHER SYSTEM K.0677 :: NPC LOD Perception
-- Category K - NPC / NEURAL MIND NETWORK
-- ARKHER NMN capability: minds that perceive, remember, feel, plan, move and live together.
-- Kit: perception (sight, hearing and bounded attention)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "K.0677"
	S.key = "arkher.npc.npclod.perception"
	S.name = "NPC LOD Perception"
	S.category = "K"
	S.family = "NPC / NEURAL MIND NETWORK"
	S.area = "NPC LOD"
	S.aspect = "Perception"
	S.kit = "perception"
	S.version = "1.0.0"
	S.deps = { "arkher.npc.npclod.emotion" }
	S.tags = { "k", "npclod", "perception", "npc" }
	S.description = "NPC LOD Perception: sight, hearing and bounded attention for the NPC LOD subsystem."
	S.params = {
		backlogLimit = 43,
		baseRadius = 440,
		baseWeight = 0.55,
		bias = 0.35,
		biasWeight = 0.2,
		ceiling = 203,
		detailWeight = 0.75,
		failureTolerance = 0,
		horizon = 4,
		integrator = "verlet",
		minConfidence = 0.75,
		minThrottle = 0.225,
		regressionSlope = 0.125,
		saturation = 0.75,
		scale = 3.5
	}
	S.features = { "place", "canSee", "canHear", "salience", "submit", "scan", "focus", "clear", "stats", "stand", "submitMany", "sweep", "threatLevel", "sees", "rangeOf", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("perception", { id = "arkher.npc.npclod.perception", sightRange = 40, hearingRange = 16, attentionSlots = 6, fov = 1.950 })
		inst.system = S
		inst.ctx = ctx

		function inst.stand(x, z)
			return inst.place(Vec.vec3(x or 0, 0, z or 0), Vec.vec3(0, 0, 1))
		end
		function inst.submitMany(list)
			for _, e in ipairs(list) do inst.submit(e.id, e.position, e.opts) end
			return #inst.stimuli
		end
		function inst.sweep() return inst.scan() end
		function inst.threatLevel()
			local worst = 0
			for _, e in ipairs(inst.attention) do
				if (e.threat or 0) > worst then worst = e.threat end
			end
			return worst
		end
		function inst.sees(id)
			for _, e in ipairs(inst.attention) do
				if e.id == id then return true end
			end
			return false
		end
		function inst.rangeOf(sense)
			if sense == "hearing" then return inst.hearingRange end
			return inst.sightRange
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
				engine.bus:subscribe("arkher.npc.npclod.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		inst.stand(0, 0)
		inst.submitMany({
			{ id = "close", position = Vec.vec3(0, 0, 3), opts = { threat = 0.9, intensity = 0.9 } },
			{ id = "far", position = Vec.vec3(0, 0, 12), opts = { intensity = 0.3 } },
			{ id = "behind", position = Vec.vec3(0, 0, -900) } })
		local attention = inst.sweep()
		local ok = #attention > 0 and inst.sees("close") and inst.threatLevel() > 0.5
		ok = ok and inst.canSee(Vec.vec3(0, 0, 5)) and not inst.canSee(Vec.vec3(0, 0, -5))
		ok = ok and inst.rangeOf("hearing") > 0 and inst.focus() ~= nil
		return ok and inst.clear() == 3
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
