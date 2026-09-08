-- ARKHER SYSTEM VB.0499 :: Rendering Continuum Neural Field
-- Category VB - CONTINUUM — TEMPORAL
-- Continuum Temporal capability: deterministic epoch timeline keeping every domain in sync.
-- Kit: neuralfield (neural field encoding and reconstruction)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "VB.0499"
	S.key = "arkher.conttime.rendercont.neural_field"
	S.name = "Rendering Continuum Neural Field"
	S.category = "VB"
	S.family = "CONTINUUM — TEMPORAL"
	S.area = "Rendering Continuum"
	S.aspect = "Neural Field"
	S.kit = "neuralfield"
	S.version = "1.0.0"
	S.deps = { "arkher.conttime.rendercont.coherence_guard" }
	S.tags = { "vb", "rendercont", "neuralfield", "conttime" }
	S.description = "Rendering Continuum Neural Field: neural field encoding and reconstruction for the Rendering Continuum subsystem."
	S.params = {
		backlogLimit = 30,
		baseRadius = 560,
		baseWeight = 0.52,
		bias = 0.22,
		biasWeight = 0.07,
		ceiling = 550,
		detailWeight = 0.42,
		failureTolerance = 2,
		horizon = 7,
		integrator = "euler",
		minConfidence = 0.62,
		minThrottle = 0.21,
		regressionSlope = 0.06,
		saturation = 0.72,
		scale = 3.2
	}
	S.features = { "encode", "forward", "infer", "train", "quantize", "exportTable", "importTable", "memoryBytes", "stats", "encodeAt", "compressedSize", "roundTripError", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("neuralfield", { id = "arkher.conttime.rendercont.neural_field", dims = 20, hidden = 16, seed = 73702 })
		inst.system = S
		inst.ctx = ctx

		function inst.encodeAt(x, y)
			local sig = inst.encode(Vec.vec3(x or 0.2, y or 0.7, 0.4))
			return inst.forward(sig)[1]
		end
		function inst.compressedSize(bits) return inst.quantize(bits or 8).bytes end
		function inst.roundTripError()
			local before = inst.stats()
			local q = inst.quantize(8)
			inst.importTable(q.table)
			return math.abs(before.hidden - inst.stats().hidden) < 1
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
				engine.bus:subscribe("arkher.conttime.rendercont.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		local v1 = inst.encodeAt(0.2, 0.7)
		local ok = type(v1) == "number" and v1 > 0 and v1 < 1
		ok = ok and inst.infer(Vec.vec3(0.1,0.2,0.3)) ~= nil
		ok = ok and inst.train({{ input = Vec.vec3(0.1,0.2,0.3), target = {0.8}}}, 2, 0.1) >= 0
		ok = ok and inst.compressedSize(8) > 0
		ok = ok and inst.memoryBytes() > 0
		return ok and inst.roundTripError()
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
