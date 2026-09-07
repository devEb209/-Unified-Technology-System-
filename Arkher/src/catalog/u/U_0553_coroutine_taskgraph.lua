-- ARKHER SYSTEM U.0553 :: Coroutine Scheduler Build Tasks
-- Category U - SCRIPTING / CODE INTELLIGENCE
-- Scripting capability: reading, understanding, transforming, generating and running ARKHER code.
-- Kit: taskgraph (incremental compile and test tasks)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "U.0553"
	S.key = "arkher.code.coroutine.build_tasks"
	S.name = "Coroutine Scheduler Build Tasks"
	S.category = "U"
	S.family = "SCRIPTING / CODE INTELLIGENCE"
	S.area = "Coroutine Scheduler"
	S.aspect = "Build Tasks"
	S.kit = "taskgraph"
	S.version = "1.0.0"
	S.deps = { "arkher.code.coroutine.buffer_document" }
	S.tags = { "u", "coroutine", "taskgraph", "code" }
	S.description = "Coroutine Scheduler Build Tasks: incremental compile and test tasks for the Coroutine Scheduler subsystem."
	S.params = {
		backlogLimit = 41,
		baseRadius = 200,
		baseWeight = 0.93,
		bias = 0.33,
		biasWeight = 0.18,
		ceiling = 529,
		detailWeight = 0.33,
		failureTolerance = 3,
		horizon = 2,
		integrator = "verlet",
		minConfidence = 0.73,
		minThrottle = 0.165,
		regressionSlope = 0.115,
		saturation = 0.88,
		scale = 2.3
	}
	S.features = { "addTask", "resolveOrder", "inputHash", "run", "invalidate", "artifact", "stats", "installPipeline", "build", "rebuild", "cacheEfficiency", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("taskgraph", { id = "arkher.code.coroutine.build_tasks", incremental = true })
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
				engine.bus:subscribe("arkher.code.coroutine.*", function(payload) inst.lastSignal = payload end)
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
