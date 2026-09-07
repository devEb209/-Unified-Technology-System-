-- ARKHER SYSTEM F.0132 :: Global Illumination Probe Volume
-- Category F - RENDERING
-- Rendering capability: the frame itself - declared, culled, lit, budgeted, resolved and paced.
-- Kit: probe (irradiance probes encoded in spherical harmonics)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "F.0132"
	S.key = "arkher.render.gi.probe_volume"
	S.name = "Global Illumination Probe Volume"
	S.category = "F"
	S.family = "RENDERING"
	S.area = "Global Illumination"
	S.aspect = "Probe Volume"
	S.kit = "probe"
	S.version = "1.0.0"
	S.deps = { "arkher.render.gi.lighting_rig" }
	S.tags = { "f", "gi", "probe", "render" }
	S.description = "Global Illumination Probe Volume: irradiance probes encoded in spherical harmonics for the Global Illumination subsystem."
	S.params = {
		backlogLimit = 15,
		baseRadius = 600,
		baseWeight = 0.87,
		bias = 0.07,
		biasWeight = 0.12,
		ceiling = 535,
		detailWeight = 0.67,
		failureTolerance = 2,
		horizon = 8,
		integrator = "verlet",
		minConfidence = 0.47,
		minThrottle = 0.185,
		regressionSlope = 0.085,
		saturation = 0.82,
		scale = 2.7
	}
	S.features = { "place", "bake", "evalSH", "probeAt", "sampleAt", "invalidate", "dirtyCount", "rebake", "memoryBytes", "stats", "buildVolume", "irradiance", "refresh", "footprint", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("probe", { id = "arkher.render.gi.probe_volume", spacing = 24 })
		inst.system = S
		inst.ctx = ctx

		function inst.buildVolume()
			if #inst.probes > 0 then return #inst.probes end
			local Spatial = A:import("arkher/kernel/spatial")
			local span = inst.spacing
			inst.place(Spatial.aabb(Vec.vec3(0, 0, 0), Vec.vec3(span, span, span)), span)
			inst.bake(function(_, dir) return dir.y > 0 and 1.0 or 0.15 end, 8)
			return #inst.probes
		end
		function inst.irradiance(point, normal)
			inst.buildVolume()
			return inst.sampleAt(point or Vec.vec3(1, 1, 1), normal or Vec.vec3(0, 1, 0))
		end
		function inst.refresh(budget)
			inst.buildVolume()
			return inst.rebake(function() return 0.5 end, budget or 2)
		end
		function inst.footprint()
			inst.buildVolume()
			return inst.memoryBytes()
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
				engine.bus:subscribe("arkher.render.gi.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		local count = inst.buildVolume()
		local ok = count == 8
		local up = inst.irradiance(Vec.vec3(1, 1, 1), Vec.vec3(0, 1, 0))
		local down = inst.irradiance(Vec.vec3(1, 1, 1), Vec.vec3(0, -1, 0))
		ok = ok and up > down
		ok = ok and inst.footprint() > 0
		local Spatial = A:import("arkher/kernel/spatial")
		local dirty = inst.invalidate(Spatial.aabb(Vec.vec3(-1, -1, -1), Vec.vec3(1, 1, 1)))
		ok = ok and dirty > 0 and inst.dirtyCount() == dirty
		ok = ok and inst.refresh(1) == 1
		return ok and inst.stats().bakes > 0
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
