-- ARKHER SYSTEM L.0590 :: World Persistence Calendar
-- Category L - WORLD SIMULATION
-- ARKHER Living World capability: a world that keeps living, at the fidelity the observer deserves.
-- Kit: schedule (hours, days and seasons driving the region)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "L.0590"
	S.key = "arkher.sim.worldpersistence.calendar"
	S.name = "World Persistence Calendar"
	S.category = "L"
	S.family = "WORLD SIMULATION"
	S.area = "World Persistence"
	S.aspect = "Calendar"
	S.kit = "schedule"
	S.version = "1.0.0"
	S.deps = { "arkher.sim.worldpersistence.society" }
	S.tags = { "l", "worldpersistence", "schedule", "sim" }
	S.description = "World Persistence Calendar: hours, days and seasons driving the region for the World Persistence subsystem."
	S.params = {
		backlogLimit = 18,
		baseRadius = 240,
		baseWeight = 0.6,
		bias = 0.1,
		biasWeight = 0.15,
		ceiling = 82,
		detailWeight = 0.7,
		failureTolerance = 0,
		horizon = 3,
		integrator = "euler",
		minConfidence = 0.5,
		minThrottle = 0.2,
		regressionSlope = 0.1,
		saturation = 0.8,
		scale = 3.0
	}
	S.features = { "addSlot", "activeAt", "interrupt", "advance", "isNight", "nextActivity", "locationFor", "stats", "buildDay", "at", "fastForward", "emergency", "hourOfDay", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("schedule", { id = "arkher.sim.worldpersistence.calendar", startHour = 8 })
		inst.system = S
		inst.ctx = ctx

		function inst.buildDay()
			if #inst.slots > 0 then return #inst.slots end
			inst.addSlot("sleep", 22, 6, { priority = 3 })
			inst.addSlot("eat", 6, 8, { priority = 2 })
			inst.addSlot("work", 8, 18, { priority = 2, location = Vec.vec3(12, 0, 0) })
			inst.addSlot("social", 18, 22, { priority = 1 })
			return #inst.slots
		end
		function inst.at(hour)
			inst.buildDay()
			local slot = inst.activeAt(hour)
			if not slot then return nil end
			return slot.activity
		end
		function inst.fastForward(hours)
			inst.buildDay()
			return inst.advance(hours or 1)
		end
		function inst.emergency(activity, hours)
			inst.buildDay()
			inst.interrupt(activity or "flee", hours or 0.5, 9)
			return inst.advance(0.1)
		end
		function inst.hourOfDay() return inst.time end

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
				engine.bus:subscribe("arkher.sim.worldpersistence.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		local ok = inst.buildDay() == 4
		ok = ok and inst.at(9) == "work" and inst.at(23) == "sleep" and inst.at(3) == "sleep"
		inst.fastForward(2)
		ok = ok and inst.stats().current ~= nil
		ok = ok and inst.emergency("flee", 1) == "flee"
		inst.fastForward(2)
		ok = ok and inst.hourOfDay() >= 0 and inst.isNight() ~= nil
		return ok and inst.locationFor("work") ~= nil
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
