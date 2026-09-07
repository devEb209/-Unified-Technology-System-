-- ARKHER SYSTEM F.0579 :: Debug Visualization Lighting Rig
-- Category F - RENDERING
-- Rendering capability: the frame itself - declared, culled, lit, budgeted, resolved and paced.
-- Kit: lightrig (light clustering, importance and cascades)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "F.0579"
	S.key = "arkher.render.debugvis.lighting_rig"
	S.name = "Debug Visualization Lighting Rig"
	S.category = "F"
	S.family = "RENDERING"
	S.area = "Debug Visualization"
	S.aspect = "Lighting Rig"
	S.kit = "lightrig"
	S.version = "1.0.0"
	S.deps = { "arkher.render.debugvis.geometry_virtualization" }
	S.tags = { "f", "debugvis", "lightrig", "render" }
	S.description = "Debug Visualization Lighting Rig: light clustering, importance and cascades for the Debug Visualization subsystem."
	S.params = {
		backlogLimit = 21,
		baseRadius = 200,
		baseWeight = 0.73,
		bias = 0.13,
		biasWeight = 0.18,
		ceiling = 165,
		detailWeight = 0.33,
		failureTolerance = 3,
		horizon = 6,
		integrator = "verlet",
		minConfidence = 0.53,
		minThrottle = 0.165,
		regressionSlope = 0.115,
		saturation = 0.93,
		scale = 2.3
	}
	S.features = { "addLight", "remove", "cluster", "lightsAt", "importance", "cascadeSplits", "shadowCasters", "setSunAngle", "stats", "buildRig", "activeAt", "shadowPlan", "daylight", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("lightrig", { id = "arkher.render.debugvis.lighting_rig", maxActive = 5 })
		inst.system = S
		inst.ctx = ctx

		function inst.buildRig(count)
			if inst.lights["key"] then return inst end
			inst.addLight("key", { type = "directional", intensity = 2.5, shadows = true })
			for i = 1, (count or 4) do
				inst.addLight("fill" .. i, { position = Vec.vec3(i * 10, 3, 0),
					range = 10 + S.params.detailWeight * 20, intensity = 1 + i * 0.1 })
			end
			return inst
		end
		function inst.activeAt(point)
			inst.buildRig()
			return inst.importance(point or Vec.vec3(0, 0, 0))
		end
		function inst.shadowPlan(near, far)
			inst.buildRig()
			return inst.cascadeSplits(near or 1, far or 400, 3, 0.75)
		end
		function inst.daylight(elevation)
			inst.buildRig()
			return inst.setSunAngle(elevation or (math.pi / 3))
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
				engine.bus:subscribe("arkher.render.debugvis.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		inst.buildRig(4)
		local Spatial = A:import("arkher/kernel/spatial")
		local clusters = inst.cluster(Spatial.aabb(Vec.vec3(-20, -10, -20), Vec.vec3(80, 20, 20)), 3)
		local ok = clusters ~= nil and inst.stats().assignments > 0
		local active = inst.activeAt(Vec.vec3(10, 2, 0))
		ok = ok and #active >= 1 and #active <= inst.maxActive
		ok = ok and active[1].id == "key"
		local splits = inst.shadowPlan(1, 400)
		ok = ok and #splits == 3 and splits[1] < splits[3]
		local intensity, ambient = inst.daylight(math.pi / 2)
		ok = ok and intensity > 0 and ambient > 0
		ok = ok and #inst.shadowCasters(1) <= 1
		return ok and #inst.lightsAt(Vec.vec3(10, 2, 0)) >= 1
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
