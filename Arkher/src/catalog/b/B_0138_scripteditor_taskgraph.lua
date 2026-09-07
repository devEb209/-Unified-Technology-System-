-- ARKHER SYSTEM B.0138 :: Script Editor Task Runner
-- Category B - ARKHER STUDIO / IDE
-- ARKHER Studio capability: the authoring environment, its documents, panels, tools and history.
-- Kit: taskgraph (incremental background work for the editor)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "B.0138"
	S.key = "arkher.studio.scripteditor.task_runner"
	S.name = "Script Editor Task Runner"
	S.category = "B"
	S.family = "ARKHER STUDIO / IDE"
	S.area = "Script Editor"
	S.aspect = "Task Runner"
	S.kit = "taskgraph"
	S.version = "1.0.0"
	S.deps = { "arkher.studio.scripteditor.session_sync" }
	S.tags = { "b", "scripteditor", "taskgraph", "studio" }
	S.description = "Script Editor Task Runner: incremental background work for the editor for the Script Editor subsystem."
	S.params = {
		backlogLimit = 28,
		baseRadius = 480,
		baseWeight = 0.5,
		bias = 0.2,
		biasWeight = 0.05,
		ceiling = 516,
		detailWeight = 0.4,
		failureTolerance = 0,
		horizon = 5,
		integrator = "euler",
		minConfidence = 0.6,
		minThrottle = 0.2,
		regressionSlope = 0.05,
		saturation = 0.7,
		scale = 3.0
	}
	S.features = { "addTask", "resolveOrder", "inputHash", "run", "invalidate", "artifact", "stats", "installPipeline", "build", "rebuild", "cacheEfficiency", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("taskgraph", { id = "arkher.studio.scripteditor.task_runner", incremental = true })
		inst.system = S
		inst.ctx = ctx

		function inst.installPipeline()
			if inst.pipeline then return inst.pipeline end
			local counters = { collect = 0, transform = 0, emit = 0 }
			inst.counters = counters
			inst.addTask("collect", { inputs = { S.key }, fn = function()
				counters.collect = counters.collect + 1
				return { items = 8 + (S.params.horizon or 1) }
			end })
			inst.addTask("transform", { deps = { "collect" }, inputs = { S.params.scale }, fn = function(artifacts)
				counters.transform = counters.transform + 1
				local items = artifacts["collect"].value.items
				return { items = items, weight = items * S.params.scale }
			end })
			inst.addTask("emit", { deps = { "transform" }, inputs = { S.params.ceiling }, fn = function(artifacts)
				counters.emit = counters.emit + 1
				return { payload = math.min(artifacts["transform"].value.weight, S.params.ceiling) }
			end })
			inst.pipeline = { "collect", "transform", "emit" }
			return inst.pipeline
		end
		function inst.build()
			inst.installPipeline()
			return inst.run()
		end
		function inst.rebuild(taskId)
			inst.installPipeline()
			inst.invalidate(taskId or "collect")
			return inst.run()
		end
		function inst.cacheEfficiency()
			local st = inst.stats()
			return st.cacheHits / math.max(1, st.cacheHits + st.artifacts)
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
				engine.bus:subscribe("arkher.studio.scripteditor.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		local first = inst.build()
		local ok = #first == 3 and inst.counters.collect == 1
		ok = ok and #inst.build() == 0
		local third = inst.rebuild("transform")
		ok = ok and #third == 2 and inst.counters.collect == 1 and inst.counters.transform == 2
		ok = ok and inst.artifact("emit") ~= nil and inst.cacheEfficiency() > 0
		return ok
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
