-- ARKHER SYSTEM N.0392 :: Footprint Particle Simulation
-- Category N - VFX
-- ARKHER VFX Framework capability: emission, simulation, forces and trails inside one shared budget.
-- Kit: particles (pooled integration of position, velocity, colour and life)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "N.0392"
	S.key = "arkher.vfx.footprint.particle_simulation"
	S.name = "Footprint Particle Simulation"
	S.category = "N"
	S.family = "VFX"
	S.area = "Footprint"
	S.aspect = "Particle Simulation"
	S.kit = "particles"
	S.version = "1.0.0"
	S.deps = { "arkher.vfx.footprint.emission" }
	S.tags = { "n", "footprint", "particles", "vfx" }
	S.description = "Footprint Particle Simulation: pooled integration of position, velocity, colour and life for the Footprint subsystem."
	S.params = {
		backlogLimit = 29,
		baseRadius = 520,
		baseWeight = 0.71,
		bias = 0.21,
		biasWeight = 0.06,
		ceiling = 205,
		detailWeight = 0.41,
		failureTolerance = 1,
		horizon = 6,
		integrator = "verlet",
		minConfidence = 0.61,
		minThrottle = 0.205,
		regressionSlope = 0.055,
		saturation = 0.91,
		scale = 3.1
	}
	S.features = { "spawn", "spawnMany", "kill", "killAll", "applyForce", "step", "aliveCount", "particleAt", "aliveList", "bounds", "occupancy", "applyQuality", "stats", "burstSpawn", "simulate", "centroid", "impulse", "pressure", "settle", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("particles", { id = "arkher.vfx.footprint.particle_simulation", capacity = 448, drag = 0.06, bounce = 0.21, groundY = 0 })
		inst.system = S
		inst.ctx = ctx

		function inst.burstSpawn(count)
			local n = 0
			for i = 1, (count or 8) do
				if inst.spawn({ position = Vec.vec3(0, 1, 0),
					velocity = Vec.vec3(0.4 * i, 3, 0), life = 0.4, size = 0.3 }) then
					n = n + 1
				end
			end
			return n
		end
		function inst.simulate(seconds, dt)
			local step = dt or 1 / 30
			local steps = math.max(1, math.floor((seconds or 0.3) / step))
			for _ = 1, steps do inst.step(step) end
			return inst.aliveCount()
		end
		function inst.centroid()
			local list = inst.aliveList()
			if #list == 0 then return Vec.vec3() end
			local sum = Vec.vec3()
			for _, p in ipairs(list) do sum = sum + p.position end
			return sum * (1 / #list)
		end
		function inst.impulse(force)
			return inst.applyForce(force or Vec.vec3(0, 12, 0), 1 / 30)
		end
		function inst.pressure()
			return inst.occupancy()
		end
		function inst.settle()
			inst.simulate(1.0, 1 / 30)
			return inst.aliveCount()
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
				engine.bus:subscribe("arkher.vfx.footprint.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		local spawned = inst.burstSpawn(6)
		local ok = spawned > 0 and inst.aliveCount() == spawned
		inst.impulse(Vec.vec3(0, 5, 0))
		inst.simulate(0.2, 1 / 30)
		ok = ok and inst.bounds() ~= nil and inst.pressure() > 0
		ok = ok and inst.centroid() ~= nil
		ok = ok and inst.settle() == 0
		inst.burstSpawn(3)
		inst.killAll()
		return ok and inst.aliveCount() == 0 and inst.stats().killed > 0
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
