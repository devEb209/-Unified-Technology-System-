-- ARKHER SYSTEM X.0276 :: Schema Enforcement Policy Engine
-- Category X - SECURITY / RELIABILITY
-- Security and reliability capability: nothing enters the engine unvalidated or ungoverned.
-- Kit: policy (ordered application of security policy)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "X.0276"
	S.key = "arkher.security.schema.policy_engine"
	S.name = "Schema Enforcement Policy Engine"
	S.category = "X"
	S.family = "SECURITY / RELIABILITY"
	S.area = "Schema Enforcement"
	S.aspect = "Policy Engine"
	S.kit = "policy"
	S.version = "1.0.0"
	S.deps = { "arkher.security.schema.recovery" }
	S.tags = { "x", "schema", "policy", "security" }
	S.description = "Schema Enforcement Policy Engine: ordered application of security policy for the Schema Enforcement subsystem."
	S.params = {
		backlogLimit = 31,
		baseRadius = 440,
		baseWeight = 0.73,
		bias = 0.23,
		biasWeight = 0.08,
		ceiling = 359,
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
	S.features = { "submit", "next", "starved", "pending", "stats", "enqueue", "dispatch", "fairnessIndex", "backlogged", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("policy", { id = "arkher.security.schema.policy_engine", algorithm = "lottery", starvationGuard = 23 })
		inst.system = S
		inst.ctx = ctx

	function inst.enqueue(id, weight, deadline) return inst.submit(id, weight, deadline) end
	function inst.dispatch(count)
		local out = {}
		for _ = 1, (count or 1) do
			local item = inst.next()
			if not item then break end
			out[#out + 1] = item.id
		end
		return out
	end
	function inst.fairnessIndex()
		local waited = {}
		for _, t in ipairs(inst.queue) do waited[#waited + 1] = t.waited end
		if #waited == 0 then return 1 end
		local sum, sumSq = 0, 0
		for _, w in ipairs(waited) do sum = sum + w sumSq = sumSq + w * w end
		if sumSq == 0 then return 1 end
		return (sum * sum) / (#waited * sumSq)
	end
	function inst.backlogged() return inst.pending() > S.params.backlogLimit end

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
				engine.bus:subscribe("arkher.security.schema.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		inst.enqueue("probe.late", 1, 100)
		inst.enqueue("probe.urgent", 2, 5)
		local dispatched = inst.dispatch(1)
		local ok = #dispatched == 1
		if inst.algorithm == "edf" then ok = ok and dispatched[1] == "probe.urgent" end
		inst.dispatch(4)
		return ok and type(inst.fairnessIndex()) == "number" 
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
