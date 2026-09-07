-- ARKHER SYSTEM U.0072 :: Type Inference Buffer Document
-- Category U - SCRIPTING / CODE INTELLIGENCE
-- Scripting capability: reading, understanding, transforming, generating and running ARKHER code.
-- Kit: document (transactional text and metadata buffer)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "U.0072"
	S.key = "arkher.code.typeinference.buffer_document"
	S.name = "Type Inference Buffer Document"
	S.category = "U"
	S.family = "SCRIPTING / CODE INTELLIGENCE"
	S.area = "Type Inference"
	S.aspect = "Buffer Document"
	S.kit = "document"
	S.version = "1.0.0"
	S.deps = { "arkher.code.typeinference.execution_orchestrator" }
	S.tags = { "u", "typeinference", "document", "code" }
	S.description = "Type Inference Buffer Document: transactional text and metadata buffer for the Type Inference subsystem."
	S.params = {
		backlogLimit = 17,
		baseRadius = 520,
		baseWeight = 0.99,
		bias = 0.09,
		biasWeight = 0.14,
		ceiling = 513,
		detailWeight = 0.29,
		failureTolerance = 4,
		horizon = 2,
		integrator = "verlet",
		minConfidence = 0.49,
		minThrottle = 0.145,
		regressionSlope = 0.095,
		saturation = 0.94,
		scale = 1.9
	}
	S.features = { "get", "set", "begin", "commit", "rollback", "validate", "isDirty", "markSaved", "serialize", "deserialize", "checksum", "stats", "transact", "applyPatch", "fieldNames", "transactionLabels", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("document", { id = "arkher.code.typeinference.buffer_document", initial = { profile = { quality = 0.99 }, meta = { revision = 0 } } })
		inst.system = S
		inst.ctx = ctx

		function inst.transact(label, fn)
			inst.begin(label)
			local ok, err = pcall(fn)
			if not ok then inst.rollback() return false, err end
			inst.commit()
			return true
		end
		function inst.applyPatch(patch)
			local n = 0
			for path, value in pairs(patch) do
				if inst.set(path, value) then n = n + 1 end
			end
			return n
		end
		function inst.fieldNames()
			local out = {}
			for k in pairs(inst.data) do out[#out + 1] = tostring(k) end
			table.sort(out)
			return out
		end
		function inst.transactionLabels()
			local out = {}
			for i, h in ipairs(inst.history) do out[i] = h.label end
			return out
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
				engine.bus:subscribe("arkher.code.typeinference.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		local ok = inst.transact("probe", function()
			inst.set("probe.alpha", 42)
			inst.set("probe.beta", "on")
		end)
		ok = ok and inst.get("probe.alpha") == 42 and inst.get("probe.beta") == "on"
		inst.begin("discard")
		inst.set("probe.alpha", 7)
		inst.rollback()
		ok = ok and inst.get("probe.alpha") == 42
		ok = ok and type(inst.checksum()) == "number" and #inst.fieldNames() >= 1
		inst.markSaved()
		return ok and inst.isDirty() == false
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
