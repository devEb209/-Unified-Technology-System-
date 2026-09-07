-- ARKHER SYSTEM C.0103 :: Prop Living Simulation
-- Category C - SCENE / WORLD
-- World capability: what exists, where it is, who owns it, and how it keeps living.
-- Kit: simulation (tiered simulation that keeps running unobserved)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "C.0103"
	S.key = "arkher.world.prop.living_simulation"
	S.name = "Prop Living Simulation"
	S.category = "C"
	S.family = "SCENE / WORLD"
	S.area = "Prop"
	S.aspect = "Living Simulation"
	S.kit = "simulation"
	S.version = "1.0.0"
	S.deps = { "arkher.world.prop.streaming" }
	S.tags = { "c", "prop", "simulation", "world" }
	S.description = "Prop Living Simulation: tiered simulation that keeps running unobserved for the Prop subsystem."
	S.params = {
		backlogLimit = 43,
		baseRadius = 280,
		baseWeight = 0.55,
		bias = 0.35,
		biasWeight = 0.2,
		ceiling = 299,
		detailWeight = 0.35,
		failureTolerance = 0,
		horizon = 4,
		integrator = "verlet",
		minConfidence = 0.75,
		minThrottle = 0.175,
		regressionSlope = 0.125,
		saturation = 0.75,
		scale = 2.5
	}
	S.features = { "spawn", "despawn", "setObserver", "classify", "tick", "catchUp", "query", "aggregateState", "stats", "populate", "observeAt", "run", "total", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("simulation", { id = "arkher.world.prop.living_simulation", fullRadius = 240, reducedRadius = 900, budget = 107 })
		inst.system = S
		inst.ctx = ctx

		function inst.populate(n)
			if inst.stats().entities > 0 then return inst.stats().entities end
			for i = 1, (n or 6) do
				inst.spawn(S.key .. "." .. i, {
					position = Vec.vec3(i * 100, 0, 0),
					state = { value = 10, ticks = 0 },
					update = function(st, dt) st.value = st.value + dt st.ticks = st.ticks + 1 end,
					aggregate = function(st, elapsed) st.value = st.value + elapsed * 0.25 end,
				})
			end
			return inst.stats().entities
		end
		function inst.observeAt(position)
			inst.populate()
			return inst.setObserver(position or Vec.vec3(0, 0, 0))
		end
		function inst.run(ticks, dt)
			inst.populate()
			local processed = 0
			for _ = 1, (ticks or 30) do processed = processed + inst.tick(dt or 1 / 30) end
			return processed
		end
		function inst.total() return inst.aggregateState("value") end

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
				engine.bus:subscribe("arkher.world.prop.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		inst.populate(6)
		local counts = inst.observeAt(Vec.vec3(0, 0, 0))
		local ok = counts.full + counts.reduced + counts.statistical == 6
		local before = inst.total()
		local processed = inst.run(30, 1 / 30)
		ok = ok and processed > 0
		ok = ok and inst.total() > before
		ok = ok and #inst.query(1e9) == 6
		ok = ok and inst.catchUp(S.key .. ".1", 10)
		return ok and inst.stats().ticks == 30
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
