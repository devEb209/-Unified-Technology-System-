-- ARKHER SYSTEM B.0305 :: Search And Filter Session Sync
-- Category B - ARKHER STUDIO / IDE
-- ARKHER Studio capability: the authoring environment, its documents, panels, tools and history.
-- Kit: session (multi-user editing of this editor surface)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "B.0305"
	S.key = "arkher.studio.search.session_sync"
	S.name = "Search And Filter Session Sync"
	S.category = "B"
	S.family = "ARKHER STUDIO / IDE"
	S.area = "Search And Filter"
	S.aspect = "Session Sync"
	S.kit = "session"
	S.version = "1.0.0"
	S.deps = { "arkher.studio.search.preview_cache" }
	S.tags = { "b", "search", "session", "studio" }
	S.description = "Search And Filter Session Sync: multi-user editing of this editor surface for the Search And Filter subsystem."
	S.params = {
		backlogLimit = 23,
		baseRadius = 280,
		baseWeight = 0.85,
		bias = 0.15,
		biasWeight = 0.2,
		ceiling = 327,
		detailWeight = 0.35,
		failureTolerance = 0,
		horizon = 8,
		integrator = "verlet",
		minConfidence = 0.55,
		minThrottle = 0.175,
		regressionSlope = 0.125,
		saturation = 0.8,
		scale = 2.5
	}
	S.features = { "join", "leave", "acquireLock", "releaseLock", "submit", "rebase", "since", "updatePresence", "activeUsers", "stats", "openWith", "editPath", "lockedEdit", "conflictRate", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("session", { id = "arkher.studio.search.session_sync", maxOps = 3847 })
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
				engine.bus:subscribe("arkher.studio.search.*", function(payload) inst.lastSignal = payload end)
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
