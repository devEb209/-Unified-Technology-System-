-- ARKHER SYSTEM S.0355 :: NPC Throttle Guard
-- Category S - D-O15 OPTIMIZATION
-- D-O15 optimization capability: measure, budget, predict, degrade gracefully, restore.
-- Kit: guard (rate limiting of expensive operations)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "S.0355"
	S.key = "arkher.do15.npc.throttle_guard"
	S.name = "NPC Throttle Guard"
	S.category = "S"
	S.family = "D-O15 OPTIMIZATION"
	S.area = "NPC"
	S.aspect = "Throttle Guard"
	S.kit = "guard"
	S.version = "1.0.0"
	S.deps = { "arkher.do15.npc.compression_codec" }
	S.tags = { "s", "npc", "guard", "do15" }
	S.description = "NPC Throttle Guard: rate limiting of expensive operations for the NPC subsystem."
	S.params = {
		backlogLimit = 21,
		baseRadius = 520,
		baseWeight = 0.63,
		bias = 0.13,
		biasWeight = 0.18,
		ceiling = 149,
		detailWeight = 0.53,
		failureTolerance = 3,
		horizon = 6,
		integrator = "verlet",
		minConfidence = 0.53,
		minThrottle = 0.115,
		regressionSlope = 0.115,
		saturation = 0.83,
		scale = 1.3
	}
	S.features = { "tick", "allow", "check", "reset", "utilization", "stats", "attempt", "burstCapacity", "cooldownFor", "saturated", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("guard", { id = "arkher.do15.npc.throttle_guard", algorithm = "token", capacity = 33, refillPerSec = 38, windowSec = 1 })
		inst.system = S
		inst.ctx = ctx

	function inst.attempt(principal, sandbox, cost)
		if sandbox and not inst.check(principal, sandbox) then return false, "capability" end
		if not inst.allow(cost or 1) then return false, "ratelimit" end
		return true
	end
	function inst.burstCapacity() return inst.capacity end
	function inst.cooldownFor(cost)
		local missing = math.max(0, (cost or 1) - inst.tokens)
		return missing / math.max(1e-6, inst.refillPerSec)
	end
	function inst.saturated() return inst.utilization() > S.params.saturation end

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
				engine.bus:subscribe("arkher.do15.npc.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		inst.reset()
		local first = inst.allow(1)
		local drained = true
		for _ = 1, inst.capacity + 2 do drained = inst.allow(1) end
		inst.tick(10)
		local recovered = inst.allow(1)
		return first and (drained == false) and recovered
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
