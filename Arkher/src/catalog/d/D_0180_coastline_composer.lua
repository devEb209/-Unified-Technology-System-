-- ARKHER SYSTEM D.0180 :: Coastline Material Composer
-- Category D - TERRAIN
-- ARKHER Terrain Framework capability: sculpt, erode, paint, stream and mesh the ground itself.
-- Kit: composer (weighted blending of terrain layers)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "D.0180"
	S.key = "arkher.terrain.coastline.material_composer"
	S.name = "Coastline Material Composer"
	S.category = "D"
	S.family = "TERRAIN"
	S.area = "Coastline"
	S.aspect = "Material Composer"
	S.kit = "composer"
	S.version = "1.0.0"
	S.deps = { "arkher.terrain.coastline.sculpt_commands" }
	S.tags = { "d", "coastline", "composer", "terrain" }
	S.description = "Coastline Material Composer: weighted blending of terrain layers for the Coastline subsystem."
	S.params = {
		backlogLimit = 11,
		baseRadius = 280,
		baseWeight = 0.53,
		bias = 0.03,
		biasWeight = 0.08,
		ceiling = 379,
		detailWeight = 0.23,
		failureTolerance = 3,
		horizon = 4,
		integrator = "verlet",
		minConfidence = 0.43,
		minThrottle = 0.115,
		regressionSlope = 0.065,
		saturation = 0.73,
		scale = 1.3
	}
	S.features = { "addLayer", "setWeight", "evaluate", "normalize", "layerNames", "stats", "installDefaults", "evaluateAt", "profileCurve", "dominantLayer", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("composer", { id = "arkher.terrain.coastline.material_composer", mode = "overlay" })
		inst.system = S
		inst.ctx = ctx

	function inst.installDefaults()
		inst.addLayer("base", S.params.baseWeight, function(x) return math.min(1, math.max(0, x)) end, inst.mode)
		inst.addLayer("detail", S.params.detailWeight, function(x) return math.min(1, math.max(0, x * 0.5)) end, inst.mode)
		inst.addLayer("bias", S.params.biasWeight, function() return S.params.bias end, inst.mode)
		return inst
	end
	function inst.evaluateAt(x) return inst.evaluate(x) end
	function inst.profileCurve(steps)
		local out = {}
		for i = 0, (steps or 8) do out[#out + 1] = inst.evaluate(i / (steps or 8)) end
		return out
	end
	function inst.dominantLayer()
		local best, bestW = nil, -1
		for _, l in ipairs(inst.layers) do if l.weight > bestW then best, bestW = l.name, l.weight end end
		return best
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
				engine.bus:subscribe("arkher.terrain.coastline.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		inst.installDefaults()
		local curve = inst.profileCurve(4)
		return #curve == 5 and type(inst.evaluateAt(0.5)) == "number" and inst.dominantLayer() ~= nil
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
