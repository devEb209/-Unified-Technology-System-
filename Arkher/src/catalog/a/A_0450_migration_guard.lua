-- ARKHER SYSTEM A.0450 :: Migration Access Guard
-- Category A - UES / CORE
-- Kernel-level engine capability: the UES foundation every other ARKHER framework stands on.
-- Kit: guard (capability checks and rate limiting)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "A.0450"
	S.key = "arkher.core.migration.access_guard"
	S.name = "Migration Access Guard"
	S.category = "A"
	S.family = "UES / CORE"
	S.area = "Migration"
	S.aspect = "Access Guard"
	S.kit = "guard"
	S.version = "1.0.0"
	S.deps = { "arkher.core.migration.budget_governor" }
	S.tags = { "a", "migration", "guard", "core" }
	S.description = "Migration Access Guard: capability checks and rate limiting for the Migration subsystem."
	S.params = {
		backlogLimit = 31,
		baseRadius = 440,
		baseWeight = 0.73,
		bias = 0.23,
		biasWeight = 0.08,
		ceiling = 215,
		detailWeight = 0.63,
		failureTolerance = 3,
		horizon = 8,
		integrator = "verlet",
		minConfidence = 0.63,
		minThrottle = 0.165,
		regressionSlope = 0.065,
		saturation = 0.93,
		scale = 2.3
	}
	S.features = { "tick", "allow", "check", "reset", "utilization", "stats", "attempt", "burstCapacity", "cooldownFor", "saturated", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("guard", { id = "arkher.core.migration.access_guard", algorithm = "sliding", capacity = 43, refillPerSec = 48, windowSec = 1 })
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
				engine.bus:subscribe("arkher.core.migration.*", function(payload) inst.lastSignal = payload end)
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
