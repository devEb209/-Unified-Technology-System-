-- ARKHER SYSTEM B.0361 :: Localization Session Sync
-- Category B - ARKHER STUDIO / IDE
-- ARKHER Studio capability: the authoring environment, its documents, panels, tools and history.
-- Kit: session (multi-user editing of this editor surface)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "B.0361"
	S.key = "arkher.studio.localization.session_sync"
	S.name = "Localization Session Sync"
	S.category = "B"
	S.family = "ARKHER STUDIO / IDE"
	S.area = "Localization"
	S.aspect = "Session Sync"
	S.kit = "session"
	S.version = "1.0.0"
	S.deps = { "arkher.studio.localization.preview_cache" }
	S.tags = { "b", "localization", "session", "studio" }
	S.description = "Localization Session Sync: multi-user editing of this editor surface for the Localization subsystem."
	S.params = {
		backlogLimit = 25,
		baseRadius = 200,
		baseWeight = 0.97,
		bias = 0.17,
		biasWeight = 0.22,
		ceiling = 457,
		detailWeight = 0.57,
		failureTolerance = 2,
		horizon = 2,
		integrator = "verlet",
		minConfidence = 0.57,
		minThrottle = 0.135,
		regressionSlope = 0.135,
		saturation = 0.92,
		scale = 1.7
	}
	S.features = { "join", "leave", "acquireLock", "releaseLock", "submit", "rebase", "since", "updatePresence", "activeUsers", "stats", "openWith", "editPath", "lockedEdit", "conflictRate", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("session", { id = "arkher.studio.localization.session_sync", maxOps = 5513 })
		inst.system = S
		inst.ctx = ctx

		function inst.openWith(users)
			for _, u in ipairs(users) do inst.join(u.id or u, u.role or "editor") end
			return #inst.activeUsers()
		end
		function inst.editPath(userId, path, value)
			return inst.submit(userId, { kind = "set", path = path, value = value })
		end
		function inst.lockedEdit(userId, path, value)
			local ok, holder = inst.acquireLock(userId, path)
			if not ok then return false, holder end
			local applied = inst.editPath(userId, path, value)
			inst.releaseLock(userId, path)
			return applied
		end
		function inst.conflictRate()
			local st = inst.stats()
			return st.conflicts / math.max(1, st.ops + st.conflicts)
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
				engine.bus:subscribe("arkher.studio.localization.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		inst.openWith({ { id = "probe.a", role = "editor" }, { id = "probe.b", role = "editor" },
			{ id = "probe.v", role = "viewer" } })
		local ok = #inst.activeUsers() == 3
		ok = ok and inst.acquireLock("probe.a", "probe.path")
		ok = ok and inst.editPath("probe.a", "probe.path", 1)
		ok = ok and inst.editPath("probe.b", "probe.path", 2) == false
		ok = ok and inst.editPath("probe.v", "probe.other", 3) == false
		inst.releaseLock("probe.a", "probe.path")
		ok = ok and #inst.since(0) == 1
		local rebased = inst.rebase({ kind = "set", path = "probe.path", value = 9 }, 0)
		ok = ok and rebased ~= nil and rebased.conflict == true
		ok = ok and inst.lockedEdit("probe.b", "probe.other", 4)
		inst.leave("probe.a") inst.leave("probe.b") inst.leave("probe.v")
		return ok and #inst.activeUsers() == 0
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
