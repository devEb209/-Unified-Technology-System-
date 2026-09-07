-- ARKHER SYSTEM V.0193 :: Terrain Asset Import
-- Category V - ASSET PIPELINE
-- ARKHER Asset Pipeline capability: import, validate, cook, bundle and patch content within a device budget.
-- Kit: importer (validation, normalization, hashing and deduplication of incoming content)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "V.0193"
	S.key = "arkher.asset.terrainasset.import"
	S.name = "Terrain Asset Import"
	S.category = "V"
	S.family = "ASSET PIPELINE"
	S.area = "Terrain Asset"
	S.aspect = "Import"
	S.kit = "importer"
	S.version = "1.0.0"
	S.deps = {  }
	S.tags = { "v", "terrainasset", "importer", "asset" }
	S.description = "Terrain Asset Import: validation, normalization, hashing and deduplication of incoming content for the Terrain Asset subsystem."
	S.params = {
		backlogLimit = 36,
		baseRadius = 160,
		baseWeight = 0.68,
		bias = 0.28,
		biasWeight = 0.13,
		ceiling = 316,
		detailWeight = 0.68,
		failureTolerance = 3,
		horizon = 5,
		integrator = "euler",
		minConfidence = 0.68,
		minThrottle = 0.19,
		regressionSlope = 0.09,
		saturation = 0.88,
		scale = 2.8
	}
	S.features = { "defineType", "installDefaults", "validate", "normalize", "contentHash", "import", "get", "ofType", "missingDependencies", "totalBytes", "stats", "ingest", "ingestTexture", "catalogue", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("importer", { id = "arkher.asset.terrainasset.import", unitScale = 1.00 })
		inst.system = S
		inst.ctx = ctx

		function inst.ingest(name, bytes)
			return inst.import("mesh", { name = name, vertices = 300, triangles = 400,
				bytes = bytes or 4096, size = 2, extension = "obj" })
		end
		function inst.ingestTexture(name, size)
			return inst.import("texture", { name = name, width = size or 512,
				height = size or 512, bytes = (size or 512) * 64, extension = "png" })
		end
		function inst.catalogue()
			return { meshes = #inst.ofType("mesh"), textures = #inst.ofType("texture"),
				bytes = inst.totalBytes() }
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
				engine.bus:subscribe("arkher.asset.terrainasset.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		inst.installDefaults()
		local asset = inst.ingest(S.key .. ".mesh", 8192)
		local ok = asset ~= nil and asset.type == "mesh"
		local dup, _, note = inst.ingest(S.key .. ".mesh", 8192)
		ok = ok and note == "duplicate" and dup ~= nil
		ok = ok and inst.ingestTexture(S.key .. ".tex", 512) ~= nil
		local bad = inst.import("mesh", { name = "broken" })
		ok = ok and bad == nil
		local c = inst.catalogue()
		return ok and c.meshes == 1 and c.textures == 1 and c.bytes > 0
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
