-- ARKHER SYSTEM A.0255 :: Worker Access Guard
-- Category A - UES / CORE
-- Kernel-level engine capability: the UES foundation every other ARKHER framework stands on.
-- Kit: guard (capability checks and rate limiting)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "A.0255"
	S.key = "arkher.core.worker.access_guard"
	S.name = "Worker Access Guard"
	S.category = "A"
	S.family = "UES / CORE"
	S.area = "Worker"
	S.aspect = "Access Guard"
	S.kit = "guard"
	S.version = "1.0.0"
	S.deps = { "arkher.core.worker.budget_governor" }
	S.tags = { "a", "worker", "guard", "core" }
	S.description = "Worker Access Guard: capability checks and rate limiting for the Worker subsystem."
	S.params = {
		backlogLimit = 25,
		baseRadius = 360,
		baseWeight = 0.87,
		bias = 0.17,
		biasWeight = 0.22,
		ceiling = 209,
		detailWeight = 0.37,
		failureTolerance = 2,
		horizon = 2,
		integrator = "verlet",
		minConfidence = 0.57,
		minThrottle = 0.185,
		regressionSlope = 0.135,
		saturation = 0.82,
		scale = 2.7
	}
	S.features = { "tick", "allow", "check", "reset", "utilization", "stats", "attempt", "burstCapacity", "cooldownFor", "saturated", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("guard", { id = "arkher.core.worker.access_guard", algorithm = "leaky", capacity = 157, refillPerSec = 22, windowSec = 1 })
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
				engine.bus:subscribe("arkher.core.worker.*", function(payload) inst.lastSignal = payload end)
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
