-- ARKHER SYSTEM P.0184 :: Economy Combat Resolution
-- Category P - GAMEPLAY
-- ARKHER Gameplay Framework capability: attributes, items, objectives, combat and progression.
-- Kit: combat (accuracy, mitigation, criticals, statuses and death)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "P.0184"
	S.key = "arkher.play.playereconomy.combat_resolution"
	S.name = "Economy Combat Resolution"
	S.category = "P"
	S.family = "GAMEPLAY"
	S.area = "Economy"
	S.aspect = "Combat Resolution"
	S.kit = "combat"
	S.version = "1.0.0"
	S.deps = { "arkher.play.playereconomy.objectives" }
	S.tags = { "p", "playereconomy", "combat", "play" }
	S.description = "Economy Combat Resolution: accuracy, mitigation, criticals, statuses and death for the Economy subsystem."
	S.params = {
		backlogLimit = 12,
		baseRadius = 160,
		baseWeight = 0.84,
		bias = 0.04,
		biasWeight = 0.09,
		ceiling = 356,
		detailWeight = 0.44,
		failureTolerance = 4,
		horizon = 5,
		integrator = "euler",
		minConfidence = 0.44,
		minThrottle = 0.22,
		regressionSlope = 0.07,
		saturation = 0.79,
		scale = 3.4
	}
	S.features = { "addActor", "hitChance", "mitigate", "attack", "heal", "applyStatus", "hasStatus", "setCooldown", "ready", "tick", "teamAlive", "recent", "dps", "stats", "installDuel", "exchange", "resolveRounds", "burn", "survivors", "effectiveDamage", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("combat", { id = "arkher.play.playereconomy.combat_resolution", seed = 46884, armourK = 120, critMultiplier = 1.50 })
		inst.system = S
		inst.ctx = ctx

		function inst.installDuel()
			if #inst.order > 0 then return #inst.order end
			inst.addActor("champion", { health = 220, armour = 60, power = 26,
				accuracy = 0.95, critChance = 0.1, team = "player" })
			inst.addActor("challenger", { health = 180, armour = 30, power = 20,
				accuracy = 0.9, critChance = 0.05, team = "enemy",
				resistances = { fire = 0.25 } })
			return #inst.order
		end
		function inst.exchange()
			inst.installDuel()
			local a = inst.attack("champion", "challenger", {})
			local b = inst.attack("challenger", "champion", {})
			return a, b
		end
		function inst.resolveRounds(rounds)
			inst.installDuel()
			for _ = 1, (rounds or 3) do
				inst.exchange()
				inst.tick(0.5)
			end
			return inst.stats().attacks
		end
		function inst.burn(id, seconds, damage)
			inst.installDuel()
			return inst.applyStatus(id or "challenger", "burn",
				{ duration = seconds or 2, tickDamage = damage or 4 })
		end
		function inst.survivors()
			inst.installDuel()
			return inst.teamAlive("player"), inst.teamAlive("enemy")
		end
		function inst.effectiveDamage(power, armour)
			return inst.mitigate(power or 40, armour or 60, 0)
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
				engine.bus:subscribe("arkher.play.playereconomy.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		local ok = inst.installDuel() == 2
		local a = inst.exchange()
		ok = ok and (a == nil or a.damage >= 0)
		ok = ok and inst.resolveRounds(2) >= 4
		ok = ok and inst.burn("challenger", 1, 4)
		ok = ok and inst.hasStatus("challenger", "burn")
		inst.tick(1.5)
		ok = ok and not inst.hasStatus("challenger", "burn")
		inst.setCooldown("champion", "smash", 1)
		ok = ok and not inst.ready("champion", "smash")
		inst.tick(1.2)
		ok = ok and inst.ready("champion", "smash")
		local friends, foes = inst.survivors()
		ok = ok and friends >= 0 and foes >= 0
		ok = ok and inst.effectiveDamage(40, 60) < 40
		return ok and inst.hitChance("champion", "challenger") > 0
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
