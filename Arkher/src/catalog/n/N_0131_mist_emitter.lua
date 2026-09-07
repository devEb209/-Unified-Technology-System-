-- ARKHER SYSTEM N.0131 :: Waterfall Mist Emission
-- Category N - VFX
-- ARKHER VFX Framework capability: emission, simulation, forces and trails inside one shared budget.
-- Kit: emitter (shaped, rate and burst emission of new particles)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "N.0131"
	S.key = "arkher.vfx.mist.emission"
	S.name = "Waterfall Mist Emission"
	S.category = "N"
	S.family = "VFX"
	S.area = "Waterfall Mist"
	S.aspect = "Emission"
	S.kit = "emitter"
	S.version = "1.0.0"
	S.deps = {  }
	S.tags = { "n", "mist", "emitter", "vfx" }
	S.description = "Waterfall Mist Emission: shaped, rate and burst emission of new particles for the Waterfall Mist subsystem."
	S.params = {
		backlogLimit = 22,
		baseRadius = 240,
		baseWeight = 0.74,
		bias = 0.14,
		biasWeight = 0.19,
		ceiling = 206,
		detailWeight = 0.34,
		failureTolerance = 4,
		horizon = 7,
		integrator = "euler",
		minConfidence = 0.54,
		minThrottle = 0.17,
		regressionSlope = 0.12,
		saturation = 0.94,
		scale = 2.4
	}
	S.features = { "setRate", "setShape", "setBudget", "burst", "samplePosition", "sampleVelocity", "sampleSpec", "emit", "prewarm", "pause", "resume", "applyQuality", "stats", "configureShape", "emitFor", "burstNow", "dropRate", "headroom", "sampleCloud", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("emitter", { id = "arkher.vfx.mist.emission", shape = "box", rate = 34, speed = 4.40, life = 2.20, budget = 512, seed = 5774 })
		inst.system = S
		inst.ctx = ctx

		function inst.configureShape(kind)
			inst.setShape(kind or "cone", { radius = 2, angle = 0.5 })
			return inst.shape
		end
		function inst.emitFor(seconds, live)
			local total = 0
			local steps = math.max(1, math.floor((seconds or 0.2) / 0.05))
			for _ = 1, steps do total = total + #inst.emit(0.05, live or 0) end
			return total
		end
		function inst.burstNow(count)
			inst.burst(count or 8, 0)
			return #inst.emit(1 / 60, 0)
		end
		function inst.dropRate()
			local s = inst.stats()
			local total = s.emitted + s.dropped
			if total <= 0 then return 0 end
			return s.dropped / total
		end
		function inst.headroom(live)
			return math.max(0, inst.budget - (live or 0))
		end
		function inst.sampleCloud(count)
			local out = {}
			for i = 1, (count or 4) do out[i] = inst.sampleSpec() end
			return out
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
				engine.bus:subscribe("arkher.vfx.mist.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		inst.configureShape("sphere")
		local emitted = inst.emitFor(0.2, 0)
		local burst = inst.burstNow(6)
		local cloud = inst.sampleCloud(3)
		inst.emit(1, inst.budget)
		local ok = emitted >= 0 and burst >= 0 and #cloud == 3
		ok = ok and cloud[1].velocity ~= nil and cloud[1].life > 0
		ok = ok and inst.headroom(0) == inst.budget and inst.dropRate() >= 0
		inst.pause()
		ok = ok and #inst.emit(1, 0) == 0
		inst.resume()
		return ok and inst.stats().emitted >= emitted
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
