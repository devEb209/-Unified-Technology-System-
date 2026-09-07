-- ARKHER SYSTEM N.0484 :: Glow Force Field
-- Category N - VFX
-- ARKHER VFX Framework capability: emission, simulation, forces and trails inside one shared budget.
-- Kit: forcefield (wind, attraction, vortex, drag and curl turbulence)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "N.0484"
	S.key = "arkher.vfx.glow.force_field"
	S.name = "Glow Force Field"
	S.category = "N"
	S.family = "VFX"
	S.area = "Glow"
	S.aspect = "Force Field"
	S.kit = "forcefield"
	S.version = "1.0.0"
	S.deps = { "arkher.vfx.glow.particle_simulation" }
	S.tags = { "n", "glow", "forcefield", "vfx" }
	S.description = "Glow Force Field: wind, attraction, vortex, drag and curl turbulence for the Glow subsystem."
	S.params = {
		backlogLimit = 19,
		baseRadius = 280,
		baseWeight = 0.51,
		bias = 0.11,
		biasWeight = 0.16,
		ceiling = 251,
		detailWeight = 0.71,
		failureTolerance = 1,
		horizon = 4,
		integrator = "verlet",
		minConfidence = 0.51,
		minThrottle = 0.205,
		regressionSlope = 0.105,
		saturation = 0.71,
		scale = 3.1
	}
	S.features = { "addField", "removeField", "setEnabled", "fieldForce", "evaluate", "strengthAt", "applyTo", "dominant", "fieldCount", "stats", "installWeather", "netForce", "averageStrength", "attractTo", "disableAll", "enableAll", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("forcefield", { id = "arkher.vfx.glow.force_field", seed = 88251 })
		inst.system = S
		inst.ctx = ctx

		function inst.installWeather()
			if inst.fieldCount() > 0 then return inst.fieldCount() end
			inst.addField("wind", "wind", { direction = Vec.vec3(1, 0, 0.2), strength = 4 })
			inst.addField("gust", "turbulence", { strength = 2, frequency = 0.2 })
			inst.addField("drag", "drag", { strength = 0.8 })
			return inst.fieldCount()
		end
		function inst.netForce(position, velocity)
			inst.installWeather()
			return inst.evaluate(position or Vec.vec3(), velocity or Vec.vec3())
		end
		function inst.averageStrength(samples)
			inst.installWeather()
			local total, n = 0, samples or 4
			for i = 1, n do
				total = total + inst.strengthAt(Vec.vec3(i * 2, 0, i), Vec.vec3())
			end
			return total / n
		end
		function inst.attractTo(position, strength, radius)
			return inst.addField("attract", "radial",
				{ position = position or Vec.vec3(), strength = -(strength or 6),
					radius = radius or 20 })
		end
		function inst.disableAll()
			local n = 0
			for _, id in ipairs(inst.order) do
				if inst.setEnabled(id, false) ~= nil then n = n + 1 end
			end
			return n
		end
		function inst.enableAll()
			for _, id in ipairs(inst.order) do inst.setEnabled(id, true) end
			return inst.fieldCount()
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
				engine.bus:subscribe("arkher.vfx.glow.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		local ok = inst.installWeather() == 3
		local force = inst.netForce(Vec.vec3(1, 0, 1), Vec.vec3(0, 0, 1))
		ok = ok and force ~= nil and inst.averageStrength(3) >= 0
		ok = ok and inst.dominant(Vec.vec3(1, 0, 1)) ~= nil
		ok = ok and inst.attractTo(Vec.vec3(6, 0, 0), 5, 15) ~= nil
		ok = ok and inst.disableAll() == 4
		local quiet = inst.evaluate(Vec.vec3(), Vec.vec3())
		ok = ok and quiet:length() < 1e-6
		inst.enableAll()
		return ok and inst.stats().evaluations > 0 and inst.removeField("drag")
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
