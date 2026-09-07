-- ARKHER SYSTEM U.0070 :: Type Inference Sandbox Guard
-- Category U - SCRIPTING / CODE INTELLIGENCE
-- Scripting capability: reading, understanding, transforming, generating and running ARKHER code.
-- Kit: guard (capability limits on executed code)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "U.0070"
	S.key = "arkher.code.typeinference.sandbox_guard"
	S.name = "Type Inference Sandbox Guard"
	S.category = "U"
	S.family = "SCRIPTING / CODE INTELLIGENCE"
	S.area = "Type Inference"
	S.aspect = "Sandbox Guard"
	S.kit = "guard"
	S.version = "1.0.0"
	S.deps = { "arkher.code.typeinference.completion_predictor" }
	S.tags = { "u", "typeinference", "guard", "code" }
	S.description = "Type Inference Sandbox Guard: capability limits on executed code for the Type Inference subsystem."
	S.params = {
		backlogLimit = 37,
		baseRadius = 200,
		baseWeight = 0.89,
		bias = 0.29,
		biasWeight = 0.14,
		ceiling = 133,
		detailWeight = 0.69,
		failureTolerance = 4,
		horizon = 6,
		integrator = "verlet",
		minConfidence = 0.69,
		minThrottle = 0.195,
		regressionSlope = 0.095,
		saturation = 0.84,
		scale = 2.9
	}
	S.features = { "tick", "allow", "check", "reset", "utilization", "stats", "attempt", "burstCapacity", "cooldownFor", "saturated", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("guard", { id = "arkher.code.typeinference.sandbox_guard", algorithm = "sliding", capacity = 209, refillPerSec = 54, windowSec = 1 })
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
				engine.bus:subscribe("arkher.code.typeinference.*", function(payload) inst.lastSignal = payload end)
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
