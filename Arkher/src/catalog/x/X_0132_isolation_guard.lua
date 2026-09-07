-- ARKHER SYSTEM X.0132 :: Process Isolation Guard
-- Category X - SECURITY / RELIABILITY
-- Security and reliability capability: nothing enters the engine unvalidated or ungoverned.
-- Kit: guard (capability enforcement and rate limiting)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "X.0132"
	S.key = "arkher.security.isolation.guard"
	S.name = "Process Isolation Guard"
	S.category = "X"
	S.family = "SECURITY / RELIABILITY"
	S.area = "Process Isolation"
	S.aspect = "Guard"
	S.kit = "guard"
	S.version = "1.0.0"
	S.deps = { "arkher.security.isolation.validator" }
	S.tags = { "x", "isolation", "guard", "security" }
	S.description = "Process Isolation Guard: capability enforcement and rate limiting for the Process Isolation subsystem."
	S.params = {
		backlogLimit = 14,
		baseRadius = 400,
		baseWeight = 0.56,
		bias = 0.06,
		biasWeight = 0.11,
		ceiling = 534,
		detailWeight = 0.26,
		failureTolerance = 1,
		horizon = 7,
		integrator = "euler",
		minConfidence = 0.46,
		minThrottle = 0.13,
		regressionSlope = 0.08,
		saturation = 0.76,
		scale = 1.6
	}
	S.features = { "tick", "allow", "check", "reset", "utilization", "stats", "attempt", "burstCapacity", "cooldownFor", "saturated", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("guard", { id = "arkher.security.isolation.guard", algorithm = "token", capacity = 26, refillPerSec = 11, windowSec = 1 })
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
				engine.bus:subscribe("arkher.security.isolation.*", function(payload) inst.lastSignal = payload end)
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
