-- ARKHER SYSTEM M.0036 :: Biome Map Rule Synthesizer
-- Category M - PROCEDURAL
-- Procedural capability: deterministic synthesis of worlds, cities, structures and detail from a seed.
-- Kit: synthesizer (rule expansion with constraints)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "M.0036"
	S.key = "arkher.proc.biomemap.rule_synthesizer"
	S.name = "Biome Map Rule Synthesizer"
	S.category = "M"
	S.family = "PROCEDURAL"
	S.area = "Biome Map"
	S.aspect = "Rule Synthesizer"
	S.kit = "synthesizer"
	S.version = "1.0.0"
	S.deps = { "arkher.proc.biomemap.noise_field" }
	S.tags = { "m", "biomemap", "synthesizer", "proc" }
	S.description = "Biome Map Rule Synthesizer: rule expansion with constraints for the Biome Map subsystem."
	S.params = {
		backlogLimit = 39,
		baseRadius = 280,
		baseWeight = 0.81,
		bias = 0.31,
		biasWeight = 0.16,
		ceiling = 327,
		detailWeight = 0.71,
		failureTolerance = 1,
		horizon = 8,
		integrator = "verlet",
		minConfidence = 0.71,
		minThrottle = 0.205,
		regressionSlope = 0.105,
		saturation = 0.76,
		scale = 3.1
	}
	S.features = { "addRule", "addConstraint", "expand", "generate", "reseed", "deterministicCheck", "stats", "installGrammar", "synthesize", "requireToken", "tokenCount", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("synthesizer", { id = "arkher.proc.biomemap.rule_synthesizer", seed = 45831 })
		inst.system = S
		inst.ctx = ctx

		function inst.installGrammar()
			if inst.stats().rules > 0 then return inst end
			inst.addRule("root", { { value = "block block", weight = 3 }, { value = "block", weight = 1 } })
			inst.addRule("block", { { value = "wall roof", weight = 2 }, { value = "wall", weight = 1 } })
			return inst
		end
		function inst.synthesize(attempts)
			inst.installGrammar()
			return inst.generate("root", attempts or 6)
		end
		function inst.requireToken(token)
			inst.installGrammar()
			inst.addConstraint("requires." .. token, function(result)
				return string.find(result, token, 1, true) ~= nil
			end)
			return inst
		end
		function inst.tokenCount(result)
			local n = 0
			for _ in string.gmatch(result or "", "%S+") do n = n + 1 end
			return n
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
				engine.bus:subscribe("arkher.proc.biomemap.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		inst.installGrammar()
		local ok = inst.stats().rules == 2
		local result, satisfied = inst.synthesize(6)
		ok = ok and type(result) == "string" and satisfied == true
		ok = ok and inst.tokenCount(result) >= 1
		inst.requireToken("roof")
		local guarded, met = inst.synthesize(12)
		ok = ok and (not met or string.find(guarded, "roof", 1, true) ~= nil)
		ok = ok and inst.deterministicCheck("root") == true
		return ok and inst.stats().generated > 0
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
