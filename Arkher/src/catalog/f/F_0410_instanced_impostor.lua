-- ARKHER SYSTEM F.0410 :: Instanced Draw Geometry Virtualization
-- Category F - RENDERING
-- Rendering capability: the frame itself - declared, culled, lit, budgeted, resolved and paced.
-- Kit: impostor (impostor and HLOD synthesis under a budget)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "F.0410"
	S.key = "arkher.render.instanced.geometry_virtualization"
	S.name = "Instanced Draw Geometry Virtualization"
	S.category = "F"
	S.family = "RENDERING"
	S.area = "Instanced Draw"
	S.aspect = "Geometry Virtualization"
	S.kit = "impostor"
	S.version = "1.0.0"
	S.deps = { "arkher.render.instanced.visibility_set" }
	S.tags = { "f", "instanced", "impostor", "render" }
	S.description = "Instanced Draw Geometry Virtualization: impostor and HLOD synthesis under a budget for the Instanced Draw subsystem."
	S.params = {
		backlogLimit = 34,
		baseRadius = 400,
		baseWeight = 0.66,
		bias = 0.26,
		biasWeight = 0.11,
		ceiling = 530,
		detailWeight = 0.26,
		failureTolerance = 1,
		horizon = 3,
		integrator = "euler",
		minConfidence = 0.66,
		minThrottle = 0.13,
		regressionSlope = 0.08,
		saturation = 0.86,
		scale = 1.6
	}
	S.features = { "register", "captureViews", "nearestView", "screenError", "select", "buildHLOD", "budgetPass", "stats", "ensureEntry", "representation", "pixelError", "spend", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("impostor", { id = "arkher.render.instanced.geometry_virtualization", atlasSlots = 32, viewCount = 8, errorThreshold = 1.60 })
		inst.system = S
		inst.ctx = ctx

		function inst.ensureEntry()
			if inst.entries[S.key] then return S.key end
			inst.register(S.key, { triangles = 2000 + S.params.horizon % 8000,
				radius = 2 + S.params.detailWeight * 8 })
			inst.captureViews(S.key, 8)
			return S.key
		end
		function inst.representation(distance)
			inst.ensureEntry()
			return inst.select(S.key, distance or 50, 720, 1.22)
		end
		function inst.pixelError(distance)
			inst.ensureEntry()
			return inst.screenError(S.key, distance or 50, 720, 1.22)
		end
		function inst.spend(budget)
			inst.ensureEntry()
			return inst.budgetPass({ { id = S.key, distance = 10 } }, budget or 4000)
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
				engine.bus:subscribe("arkher.render.instanced.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		inst.ensureEntry()
		local ok = inst.entries[S.key].views ~= nil
		local nearMode = inst.representation(5)
		local farMode = inst.representation(5000)
		ok = ok and nearMode == "mesh"
		ok = ok and (farMode == "impostor" or farMode == "culled")
		ok = ok and inst.pixelError(5) > inst.pixelError(500)
		local view = inst.nearestView(S.key, Vec.vec3(1, 0, 0))
		ok = ok and view ~= nil
		local spent = inst.spend(100000)
		ok = ok and spent.meshes == 1
		return ok and inst.stats().slots > 0
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
