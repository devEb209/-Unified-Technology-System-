-- ARKHER SYSTEM P.0337 :: Cooldown Attributes
-- Category P - GAMEPLAY
-- ARKHER Gameplay Framework capability: attributes, items, objectives, combat and progression.
-- Kit: stats (base values, layered modifiers and derived statistics)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "P.0337"
	S.key = "arkher.play.cooldown.attributes"
	S.name = "Cooldown Attributes"
	S.category = "P"
	S.family = "GAMEPLAY"
	S.area = "Cooldown"
	S.aspect = "Attributes"
	S.kit = "stats"
	S.version = "1.0.0"
	S.deps = {  }
	S.tags = { "p", "cooldown", "stats", "play" }
	S.description = "Cooldown Attributes: base values, layered modifiers and derived statistics for the Cooldown subsystem."
	S.params = {
		backlogLimit = 14,
		baseRadius = 560,
		baseWeight = 0.86,
		bias = 0.06,
		biasWeight = 0.11,
		ceiling = 486,
		detailWeight = 0.66,
		failureTolerance = 1,
		horizon = 7,
		integrator = "euler",
		minConfidence = 0.46,
		minThrottle = 0.18,
		regressionSlope = 0.08,
		saturation = 0.81,
		scale = 2.6
	}
	S.features = { "define", "setBase", "addModifier", "removeModifier", "get", "defineDerived", "getDerived", "tick", "modifiersFor", "snapshot", "compare", "stats", "installProfile", "buff", "debuff", "power", "expire", "deltaFrom", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("stats", { id = "arkher.play.cooldown.attributes" })
		inst.system = S
		inst.ctx = ctx

		function inst.installProfile()
			if #inst.order > 0 then return #inst.order end
			inst.define("vitality", 10, { min = 0, max = 999 })
			inst.define("strength", 10, { min = 0, max = 999 })
			inst.define("agility", 10, { min = 0, max = 999 })
			inst.defineDerived("maxHealth", function(s) return 20 + s.get("vitality") * 8 end)
			inst.defineDerived("power", function(s) return s.get("strength") * 2 end)
			return #inst.order
		end
		function inst.buff(name, id, amount, duration)
			inst.installProfile()
			return inst.addModifier(name or "strength", id or "buff",
				{ flat = amount or 5, duration = duration })
		end
		function inst.debuff(name, id, percent, duration)
			inst.installProfile()
			return inst.addModifier(name or "agility", id or "debuff",
				{ percent = -(percent or 0.25), duration = duration })
		end
		function inst.power()
			inst.installProfile()
			return inst.getDerived("power")
		end
		function inst.expire(seconds)
			inst.installProfile()
			inst.tick(seconds or 1)
			return inst.stats().expired
		end
		function inst.deltaFrom(other)
			inst.installProfile()
			return inst.compare(other)
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
				engine.bus:subscribe("arkher.play.cooldown.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		local ok = inst.installProfile() == 3
		local base = inst.power()
		inst.buff("strength", "sword", 6)
		ok = ok and inst.power() > base
		inst.buff("strength", "rage", 4, 0.5)
		local peak = inst.power()
		inst.expire(1.0)
		ok = ok and inst.power() < peak and inst.power() > base
		ok = ok and inst.removeModifier("sword") == 1
		ok = ok and inst.getDerived("maxHealth") > 20
		ok = ok and #inst.modifiersFor("strength") == 0
		local snap = inst.snapshot()
		return ok and snap.vitality ~= nil and inst.stats().recomputes > 0
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
