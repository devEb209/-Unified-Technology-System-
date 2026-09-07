-- ARKHER SYSTEM M.0477 :: Debris Grammar
-- Category M - PROCEDURAL
-- Procedural capability: deterministic synthesis of worlds, cities, structures and detail from a seed.
-- Kit: lsystem (rewriting grammar interpreted into geometry)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "M.0477"
	S.key = "arkher.proc.debris.grammar"
	S.name = "Debris Grammar"
	S.category = "M"
	S.family = "PROCEDURAL"
	S.area = "Debris"
	S.aspect = "Grammar"
	S.kit = "lsystem"
	S.version = "1.0.0"
	S.deps = {  }
	S.tags = { "m", "debris", "lsystem", "proc" }
	S.description = "Debris Grammar: rewriting grammar interpreted into geometry for the Debris subsystem."
	S.params = {
		backlogLimit = 28,
		baseRadius = 320,
		baseWeight = 0.7,
		bias = 0.2,
		biasWeight = 0.05,
		ceiling = 172,
		detailWeight = 0.6,
		failureTolerance = 0,
		horizon = 5,
		integrator = "euler",
		minConfidence = 0.6,
		minThrottle = 0.15,
		regressionSlope = 0.05,
		saturation = 0.9,
		scale = 2.0
	}
	S.features = { "addRule", "iterate", "reset", "interpret", "bounds", "totalLength", "stats", "installRules", "grow", "geometry", "complexity", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("lsystem", { id = "arkher.proc.debris.grammar", axiom = "F", angle = 38, step = 3.0 })
		inst.system = S
		inst.ctx = ctx

		function inst.installRules()
			if inst.rules["F"] then return inst end
			inst.addRule("F", "F[+F]F[-F]F")
			inst.addRule("X", "F[+X][-X]FX")
			return inst
		end
		function inst.grow(iterations)
			inst.installRules()
			return inst.iterate(iterations or 2)
		end
		function inst.geometry(origin)
			if not inst.current then inst.grow(2) end
			return inst.interpret(origin or Vec.vec3(0, 0, 0))
		end
		function inst.complexity()
			local segments = inst.geometry()
			return #segments, inst.totalLength()
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
				engine.bus:subscribe("arkher.proc.debris.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		local expanded = inst.grow(2)
		local ok = #expanded > 20
		local segments = inst.geometry(Vec.vec3(0, 0, 0))
		ok = ok and #segments > 5
		local count, length = inst.complexity()
		ok = ok and count == #segments and length > 0
		ok = ok and inst.bounds() ~= nil
		inst.reset()
		return ok and inst.stats().iterations == 0
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
