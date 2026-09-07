-- ARKHER SYSTEM V.0062 :: Shader Asset Bundling
-- Category V - ASSET PIPELINE
-- ARKHER Asset Pipeline capability: import, validate, cook, bundle and patch content within a device budget.
-- Kit: bundler (size-bounded packing, manifests and delta patches)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "V.0062"
	S.key = "arkher.asset.shaderasset.bundling"
	S.name = "Shader Asset Bundling"
	S.category = "V"
	S.family = "ASSET PIPELINE"
	S.area = "Shader Asset"
	S.aspect = "Bundling"
	S.kit = "bundler"
	S.version = "1.0.0"
	S.deps = { "arkher.asset.shaderasset.import" }
	S.tags = { "v", "shaderasset", "bundler", "asset" }
	S.description = "Shader Asset Bundling: size-bounded packing, manifests and delta patches for the Shader Asset subsystem."
	S.params = {
		backlogLimit = 21,
		baseRadius = 200,
		baseWeight = 0.53,
		bias = 0.13,
		biasWeight = 0.18,
		ceiling = 285,
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
	S.features = { "add", "compressedBytes", "pack", "bundleOf", "manifest", "delta", "loadPlan", "compressionRatio", "stats", "stage", "sizeOf", "residentPlan", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("bundler", { id = "arkher.asset.shaderasset.bundling", maxBundleBytes = 917504 })
		inst.system = S
		inst.ctx = ctx

		function inst.stage(count, bytes)
			for i = 1, (count or 4) do
				inst.add(S.key .. ".item" .. i, { bytes = bytes or 60000, type = "mesh",
					group = (i % 2 == 0) and "core" or "stream", priority = i })
			end
			return inst.pack()
		end
		function inst.sizeOf(group)
			local total = 0
			for _, bundle in ipairs(inst.bundles) do
				if bundle.group == group then total = total + bundle.bytes end
			end
			return total
		end
		function inst.residentPlan(groups)
			return inst.loadPlan(groups or { "core" })
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
				engine.bus:subscribe("arkher.asset.shaderasset.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		local packed = inst.stage(6, 60000)
		local ok = packed >= 1 and #inst.bundles == packed
		ok = ok and inst.bundleOf(S.key .. ".item1") ~= nil
		ok = ok and inst.sizeOf("core") > 0
		local manifest = inst.manifest()
		ok = ok and manifest.entries == 6 and manifest.totalBytes > 0
		local delta = inst.delta(manifest)
		ok = ok and #delta.added == 0 and #delta.removed == 0
		return ok and inst.compressionRatio() < 1 and #inst.residentPlan() >= 1
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
