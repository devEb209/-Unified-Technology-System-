-- ARKHER SYSTEM U.0266 :: Template Codegen Execution Orchestrator
-- Category U - SCRIPTING / CODE INTELLIGENCE
-- Scripting capability: reading, understanding, transforming, generating and running ARKHER code.
-- Kit: orchestrator (state machine of the execution lifecycle)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "U.0266"
	S.key = "arkher.code.codegen.execution_orchestrator"
	S.name = "Template Codegen Execution Orchestrator"
	S.category = "U"
	S.family = "SCRIPTING / CODE INTELLIGENCE"
	S.area = "Template Codegen"
	S.aspect = "Execution Orchestrator"
	S.kit = "orchestrator"
	S.version = "1.0.0"
	S.deps = { "arkher.code.codegen.sandbox_guard" }
	S.tags = { "u", "codegen", "orchestrator", "code" }
	S.description = "Template Codegen Execution Orchestrator: state machine of the execution lifecycle for the Template Codegen subsystem."
	S.params = {
		backlogLimit = 29,
		baseRadius = 360,
		baseWeight = 0.71,
		bias = 0.21,
		biasWeight = 0.06,
		ceiling = 541,
		detailWeight = 0.61,
		failureTolerance = 1,
		horizon = 6,
		integrator = "verlet",
		minConfidence = 0.61,
		minThrottle = 0.155,
		regressionSlope = 0.055,
		saturation = 0.91,
		scale = 2.1
	}
	S.features = { "on", "canGo", "go", "step", "isIn", "reset", "stats", "begin", "activate", "degrade", "recover", "halt", "uptimeRatio", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("orchestrator", { id = "arkher.code.codegen.execution_orchestrator", states = { "idle", "warmup", "active", "degraded", "recovering", "halted" } })
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
				engine.bus:subscribe("arkher.code.codegen.*", function(payload) inst.lastSignal = payload end)
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
