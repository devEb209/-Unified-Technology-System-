-- ARKHER SYSTEM H.0570 :: Soft Body Simulation Policy
-- Category H - PHYSICS
-- ARKHER Physics Abstraction capability: mass, contact, constraint and motion, deterministic and budgeted.
-- Kit: policy (device tier rules for substeps, iterations and sleep)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "H.0570"
	S.key = "arkher.physics.softbody.simulation_policy"
	S.name = "Soft Body Simulation Policy"
	S.category = "H"
	S.family = "PHYSICS"
	S.area = "Soft Body"
	S.aspect = "Simulation Policy"
	S.kit = "policy"
	S.version = "1.0.0"
	S.deps = { "arkher.physics.softbody.budget_governor" }
	S.tags = { "h", "softbody", "policy", "physics" }
	S.description = "Soft Body Simulation Policy: device tier rules for substeps, iterations and sleep for the Soft Body subsystem."
	S.params = {
		backlogLimit = 15,
		baseRadius = 440,
		baseWeight = 0.57,
		bias = 0.07,
		biasWeight = 0.12,
		ceiling = 375,
		detailWeight = 0.27,
		failureTolerance = 2,
		horizon = 8,
		integrator = "verlet",
		minConfidence = 0.47,
		minThrottle = 0.135,
		regressionSlope = 0.085,
		saturation = 0.77,
		scale = 1.7
	}
	S.features = { "submit", "next", "starved", "pending", "stats", "enqueue", "dispatch", "fairnessIndex", "backlogged", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("policy", { id = "arkher.physics.softbody.simulation_policy", algorithm = "lottery", starvationGuard = 23 })
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
				engine.bus:subscribe("arkher.physics.softbody.*", function(payload) inst.lastSignal = payload end)
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
