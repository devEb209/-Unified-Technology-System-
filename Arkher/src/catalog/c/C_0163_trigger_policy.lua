-- ARKHER SYSTEM C.0163 :: Trigger Volume LOD Policy
-- Category C - SCENE / WORLD
-- World capability: what exists, where it is, who owns it, and how it keeps living.
-- Kit: policy (fidelity band scheduling for world content)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "C.0163"
	S.key = "arkher.world.trigger.lod_policy"
	S.name = "Trigger Volume LOD Policy"
	S.category = "C"
	S.family = "SCENE / WORLD"
	S.area = "Trigger Volume"
	S.aspect = "LOD Policy"
	S.kit = "policy"
	S.version = "1.0.0"
	S.deps = { "arkher.world.trigger.query_cache" }
	S.tags = { "c", "trigger", "policy", "world" }
	S.description = "Trigger Volume LOD Policy: fidelity band scheduling for world content for the Trigger Volume subsystem."
	S.params = {
		backlogLimit = 42,
		baseRadius = 560,
		baseWeight = 0.74,
		bias = 0.34,
		biasWeight = 0.19,
		ceiling = 274,
		detailWeight = 0.54,
		failureTolerance = 4,
		horizon = 3,
		integrator = "euler",
		minConfidence = 0.74,
		minThrottle = 0.12,
		regressionSlope = 0.12,
		saturation = 0.94,
		scale = 1.4
	}
	S.features = { "submit", "next", "starved", "pending", "stats", "enqueue", "dispatch", "fairnessIndex", "backlogged", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("policy", { id = "arkher.world.trigger.lod_policy", algorithm = "wfq", starvationGuard = 50 })
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
				engine.bus:subscribe("arkher.world.trigger.*", function(payload) inst.lastSignal = payload end)
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
