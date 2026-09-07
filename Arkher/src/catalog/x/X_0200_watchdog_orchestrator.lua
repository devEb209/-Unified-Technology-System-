-- ARKHER SYSTEM X.0200 :: Watchdog Orchestrator
-- Category X - SECURITY / RELIABILITY
-- Security and reliability capability: nothing enters the engine unvalidated or ungoverned.
-- Kit: orchestrator (incident state machine)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "X.0200"
	S.key = "arkher.security.watchdog.orchestrator"
	S.name = "Watchdog Orchestrator"
	S.category = "X"
	S.family = "SECURITY / RELIABILITY"
	S.area = "Watchdog"
	S.aspect = "Orchestrator"
	S.kit = "orchestrator"
	S.version = "1.0.0"
	S.deps = { "arkher.security.watchdog.trust_controller" }
	S.tags = { "x", "watchdog", "orchestrator", "security" }
	S.description = "Watchdog Orchestrator: incident state machine for the Watchdog subsystem."
	S.params = {
		backlogLimit = 26,
		baseRadius = 240,
		baseWeight = 0.68,
		bias = 0.18,
		biasWeight = 0.23,
		ceiling = 498,
		detailWeight = 0.58,
		failureTolerance = 3,
		horizon = 3,
		integrator = "euler",
		minConfidence = 0.58,
		minThrottle = 0.14,
		regressionSlope = 0.14,
		saturation = 0.88,
		scale = 1.8
	}
	S.features = { "on", "canGo", "go", "step", "isIn", "reset", "stats", "begin", "activate", "degrade", "recover", "halt", "uptimeRatio", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("orchestrator", { id = "arkher.security.watchdog.orchestrator", states = { "idle", "warmup", "active", "degraded", "recovering", "halted" } })
		inst.system = S
		inst.ctx = ctx

	function inst.begin() return inst.go("warmup") end
	function inst.activate() return inst.go("active") end
	function inst.degrade(reason)
		inst.lastReason = reason
		return inst.go("degraded")
	end
	function inst.recover() return inst.go("recovering") and inst.go("active") end
	function inst.halt() return inst.go("halted") end
	function inst.uptimeRatio()
		local active = 0
		for _, entry in ipairs(inst.log) do if entry.to == "active" then active = active + 1 end end
		return active / math.max(1, #inst.log)
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
				engine.bus:subscribe("arkher.security.watchdog.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		inst.reset()
		inst.begin()
		inst.activate()
		inst.degrade("probe")
		local recovered = inst.recover()
		return recovered and inst.current == "active" and inst.stats().transitions >= 4
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
