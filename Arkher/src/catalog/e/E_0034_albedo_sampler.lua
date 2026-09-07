-- ARKHER SYSTEM E.0034 :: Albedo Texture Sampling
-- Category E - MATERIALS
-- ARKHER Material Framework capability: how every surface in the world is defined, layered, worn and afforded.
-- Kit: sampler (atlas packing, mip chain and filtered sampling)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "E.0034"
	S.key = "arkher.material.albedo.texture_sampling"
	S.name = "Albedo Texture Sampling"
	S.category = "E"
	S.family = "MATERIALS"
	S.area = "Albedo"
	S.aspect = "Texture Sampling"
	S.kit = "sampler"
	S.version = "1.0.0"
	S.deps = { "arkher.material.albedo.shading_graph" }
	S.tags = { "e", "albedo", "sampler", "material" }
	S.description = "Albedo Texture Sampling: atlas packing, mip chain and filtered sampling for the Albedo subsystem."
	S.params = {
		backlogLimit = 14,
		baseRadius = 400,
		baseWeight = 0.66,
		bias = 0.06,
		biasWeight = 0.11,
		ceiling = 102,
		detailWeight = 0.26,
		failureTolerance = 1,
		horizon = 7,
		integrator = "euler",
		minConfidence = 0.46,
		minThrottle = 0.13,
		regressionSlope = 0.08,
		saturation = 0.86,
		scale = 1.6
	}
	S.features = { "defineTexture", "get", "pack", "packAll", "occupancy", "buildMips", "sample", "sampleLevel", "sampleLod", "lodFor", "evict", "residentBytes", "stats", "ensureTexture", "detail", "footprint", "lodForDistance", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("sampler", { id = "arkher.material.albedo.texture_sampling", atlasSize = 256, maxSide = 32 })
		inst.system = S
		inst.ctx = ctx

		function inst.ensureTexture()
			if inst.get(S.key) then return S.key end
			inst.defineTexture(S.key, 8, 8, function(u, v) return (u + v) * 0.5 end)
			inst.pack(S.key)
			return S.key
		end
		function inst.detail(u, v, lod)
			inst.ensureTexture()
			return inst.sampleLod(S.key, u, v, lod or 0)
		end
		function inst.footprint()
			inst.ensureTexture()
			return inst.residentBytes(), inst.occupancy()
		end
		function inst.lodForDistance(distance)
			inst.ensureTexture()
			return inst.lodFor(S.key, math.max(1, distance / 32))
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
				engine.bus:subscribe("arkher.material.albedo.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		inst.ensureTexture()
		local ok = inst.get(S.key) ~= nil
		ok = ok and math.abs(inst.sample(S.key, 0, 0) - 0) < 0.01
		ok = ok and math.abs(inst.sample(S.key, 1, 1) - 1) < 0.01
		ok = ok and inst.buildMips(S.key) == 4
		ok = ok and inst.detail(0.5, 0.5, 1) >= 0
		local bytes, occupancy = inst.footprint()
		ok = ok and bytes > 0 and occupancy > 0
		ok = ok and inst.lodForDistance(256) > 0
		return ok and inst.stats().samples > 0
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
