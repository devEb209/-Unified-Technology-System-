-- ARKHER SYSTEM E.0376 :: Terrain Splat Definition
-- Category E - MATERIALS
-- ARKHER Material Framework capability: how every surface in the world is defined, layered, worn and afforded.
-- Kit: material (layered PBR definition resolved into parameters)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "E.0376"
	S.key = "arkher.material.splat.definition"
	S.name = "Terrain Splat Definition"
	S.category = "E"
	S.family = "MATERIALS"
	S.area = "Terrain Splat"
	S.aspect = "Definition"
	S.kit = "material"
	S.version = "1.0.0"
	S.deps = {  }
	S.tags = { "e", "splat", "material", "material" }
	S.description = "Terrain Splat Definition: layered PBR definition resolved into parameters for the Terrain Splat subsystem."
	S.params = {
		backlogLimit = 21,
		baseRadius = 200,
		baseWeight = 0.53,
		bias = 0.13,
		biasWeight = 0.18,
		ceiling = 469,
		detailWeight = 0.33,
		failureTolerance = 3,
		horizon = 6,
		integrator = "verlet",
		minConfidence = 0.53,
		minThrottle = 0.165,
		regressionSlope = 0.115,
		saturation = 0.73,
		scale = 2.3
	}
	S.features = { "addLayer", "removeLayer", "setParam", "setEnabled", "resolve", "defineVariant", "applyVariant", "memoryBytes", "withinBudget", "lodParams", "checksum", "describe", "stats", "buildSurface", "surfaceAt", "wearVariant", "distanceParams", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("material", { id = "arkher.material.splat.definition", texelBudget = 1572864 })
		inst.system = S
		inst.ctx = ctx

		function inst.buildSurface()
			if inst.layers["base"] then return inst end
			inst.addLayer("base", { albedo = 0x808080, roughness = 0.5 + S.params.detailWeight * 0.4,
				metallic = (S.params.horizon % 2) * 0.5, weight = 1.0, texels = 65536 })
			inst.addLayer("detail", { albedo = 0x6A6A66, roughness = 0.9, weight = 0.4,
				texels = 16384, mask = function(ctx) return ctx.wear or 0 end })
			return inst
		end
		function inst.surfaceAt(ctx)
			inst.buildSurface()
			return inst.resolve(ctx)
		end
		function inst.wearVariant(amount)
			inst.buildSurface()
			inst.defineVariant("worn", { detail = { weight = amount or 0.9 } })
			inst.applyVariant("worn")
			return inst.resolve({ wear = 1 })
		end
		function inst.distanceParams(distance)
			inst.buildSurface()
			return inst.lodParams(distance or S.params.baseRadius)
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
				engine.bus:subscribe("arkher.material.splat.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		inst.buildSurface()
		local clean = inst.surfaceAt({ wear = 0 })
		local worn = inst.surfaceAt({ wear = 1 })
		local ok = clean.layers == 1 and worn.layers == 2
		ok = ok and worn.roughness >= clean.roughness - 0.001
		ok = ok and inst.memoryBytes() > 0
		ok = ok and inst.checksum() == inst.checksum()
		local lod = inst.distanceParams(900)
		ok = ok and lod.layers >= 1 and lod.level >= 0
		ok = ok and inst.wearVariant(0.9) ~= nil
		return ok and inst.describe().id ~= nil
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
