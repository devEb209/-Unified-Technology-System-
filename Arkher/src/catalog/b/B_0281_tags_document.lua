-- ARKHER SYSTEM B.0281 :: Tag Manager Document Model
-- Category B - ARKHER STUDIO / IDE
-- ARKHER Studio capability: the authoring environment, its documents, panels, tools and history.
-- Kit: document (transactional editing state with dirty tracking and revisions)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "B.0281"
	S.key = "arkher.studio.tags.document_model"
	S.name = "Tag Manager Document Model"
	S.category = "B"
	S.family = "ARKHER STUDIO / IDE"
	S.area = "Tag Manager"
	S.aspect = "Document Model"
	S.kit = "document"
	S.version = "1.0.0"
	S.deps = {  }
	S.tags = { "b", "tags", "document", "studio" }
	S.description = "Tag Manager Document Model: transactional editing state with dirty tracking and revisions for the Tag Manager subsystem."
	S.params = {
		backlogLimit = 26,
		baseRadius = 560,
		baseWeight = 0.88,
		bias = 0.18,
		biasWeight = 0.23,
		ceiling = 306,
		detailWeight = 0.78,
		failureTolerance = 3,
		horizon = 3,
		integrator = "euler",
		minConfidence = 0.58,
		minThrottle = 0.24,
		regressionSlope = 0.14,
		saturation = 0.83,
		scale = 3.8
	}
	S.features = { "get", "set", "begin", "commit", "rollback", "validate", "isDirty", "markSaved", "serialize", "deserialize", "checksum", "stats", "transact", "applyPatch", "fieldNames", "transactionLabels", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("document", { id = "arkher.studio.tags.document_model", initial = { profile = { quality = 0.88 }, meta = { revision = 0 } } })
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
				engine.bus:subscribe("arkher.studio.tags.*", function(payload) inst.lastSignal = payload end)
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
