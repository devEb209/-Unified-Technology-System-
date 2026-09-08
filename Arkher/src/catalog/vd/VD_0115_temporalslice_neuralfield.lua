-- ARKHER SYSTEM VD.0115 :: Temporal Slice Neural Field
-- Category VD - CONTINUUM — SIMULATION
-- Continuum Simulation capability: ecology, economy, society and weather stepped through the continuum.
-- Kit: neuralfield (neural field encoding and reconstruction)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "VD.0115"
	S.key = "arkher.contsim.temporalslice.neural_field"
	S.name = "Temporal Slice Neural Field"
	S.category = "VD"
	S.family = "CONTINUUM — SIMULATION"
	S.area = "Temporal Slice"
	S.aspect = "Neural Field"
	S.kit = "neuralfield"
	S.version = "1.0.0"
	S.deps = { "arkher.contsim.temporalslice.coherence_guard" }
	S.tags = { "vd", "temporalslice", "neuralfield", "contsim" }
	S.description = "Temporal Slice Neural Field: neural field encoding and reconstruction for the Temporal Slice subsystem."
	S.params = {
		backlogLimit = 30,
		baseRadius = 240,
		baseWeight = 0.82,
		bias = 0.22,
		biasWeight = 0.07,
		ceiling = 102,
		detailWeight = 0.22,
		failureTolerance = 2,
		horizon = 7,
		integrator = "euler",
		minConfidence = 0.62,
		minThrottle = 0.11,
		regressionSlope = 0.06,
		saturation = 0.77,
		scale = 1.2
	}
	S.features = { "encode", "forward", "infer", "train", "quantize", "exportTable", "importTable", "memoryBytes", "stats", "encodeAt", "compressedSize", "roundTripError", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("neuralfield", { id = "arkher.contsim.temporalslice.neural_field", dims = 20, hidden = 16, seed = 44582 })
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
				engine.bus:subscribe("arkher.contsim.temporalslice.*", function(payload) inst.lastSignal = payload end)
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
