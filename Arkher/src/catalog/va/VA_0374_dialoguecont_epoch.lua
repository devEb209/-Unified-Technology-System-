-- ARKHER SYSTEM VA.0374 :: Dialogue Continuum Epoch Clock
-- Category VA - CONTINUUM — WORLD
-- Continuum World capability: infinite, seamless world built on continuum, sparse and multiscale.
-- Kit: epoch (deterministic epoch timeline with catch-up)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "VA.0374"
	S.key = "arkher.contworld.dialoguecont.epoch_clock"
	S.name = "Dialogue Continuum Epoch Clock"
	S.category = "VA"
	S.family = "CONTINUUM — WORLD"
	S.area = "Dialogue Continuum"
	S.aspect = "Epoch Clock"
	S.kit = "epoch"
	S.version = "1.0.0"
	S.deps = { "arkher.contworld.dialoguecont.infinite_grid" }
	S.tags = { "va", "dialoguecont", "epoch", "contworld" }
	S.description = "Dialogue Continuum Epoch Clock: deterministic epoch timeline with catch-up for the Dialogue Continuum subsystem."
	S.params = {
		backlogLimit = 34,
		baseRadius = 240,
		baseWeight = 0.76,
		bias = 0.26,
		biasWeight = 0.11,
		ceiling = 410,
		detailWeight = 0.46,
		failureTolerance = 1,
		horizon = 3,
		integrator = "euler",
		minConfidence = 0.66,
		minThrottle = 0.23,
		regressionSlope = 0.08,
		saturation = 0.71,
		scale = 3.6
	}
	S.features = { "advance", "epochNow", "elapsedSince", "catchUp", "seek", "drift", "checkpoint", "restore", "setDilation", "stats", "tickFor", "rewindTo", "burstCatch", "health", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("epoch", { id = "arkher.contworld.dialoguecont.epoch_clock", tickRate = 30, budget = 6, capacity = 128 })
		inst.system = S
		inst.ctx = ctx

		function inst.tickFor(seconds)
			local ticks = 0
			for _ = 1, math.max(1, math.floor((seconds or 1) * inst.tickRate)) do ticks = ticks + inst.advance(1/inst.tickRate) end
			return ticks
		end
		function inst.rewindTo(epoch) return inst.seek(epoch or 0) end
		function inst.burstCatch(target) return inst.catchUp(target or inst.epoch + 4) end
		function inst.health() return 1 - math.min(1, inst.drift()) end

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
				engine.bus:subscribe("arkher.contworld.dialoguecont.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		local before = inst.epoch
		inst.advance(0.2)
		local ok = inst.epoch > before and inst.health() >= 0
		ok = ok and inst.elapsedSince(before) == inst.epoch - before
		local cp = inst.checkpoint()
		inst.seek(before)
		ok = ok and inst.epoch == before
		inst.restore(cp)
		ok = ok and inst.catchUp(inst.epoch + 2) == 2
		return ok and inst.stats().epoch == inst.epoch
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
