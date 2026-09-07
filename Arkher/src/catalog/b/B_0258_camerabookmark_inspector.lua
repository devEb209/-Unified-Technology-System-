-- ARKHER SYSTEM B.0258 :: Camera Bookmark Property Inspector
-- Category B - ARKHER STUDIO / IDE
-- ARKHER Studio capability: the authoring environment, its documents, panels, tools and history.
-- Kit: inspector (reflection-driven property editing)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "B.0258"
	S.key = "arkher.studio.camerabookmark.property_inspector"
	S.name = "Camera Bookmark Property Inspector"
	S.category = "B"
	S.family = "ARKHER STUDIO / IDE"
	S.area = "Camera Bookmark"
	S.aspect = "Property Inspector"
	S.kit = "inspector"
	S.version = "1.0.0"
	S.deps = { "arkher.studio.camerabookmark.widget_surface" }
	S.tags = { "b", "camerabookmark", "inspector", "studio" }
	S.description = "Camera Bookmark Property Inspector: reflection-driven property editing for the Camera Bookmark subsystem."
	S.params = {
		backlogLimit = 21,
		baseRadius = 200,
		baseWeight = 0.63,
		bias = 0.13,
		biasWeight = 0.18,
		ceiling = 141,
		detailWeight = 0.33,
		failureTolerance = 3,
		horizon = 6,
		integrator = "verlet",
		minConfidence = 0.53,
		minThrottle = 0.165,
		regressionSlope = 0.115,
		saturation = 0.83,
		scale = 2.3
	}
	S.features = { "attach", "fields", "layout", "edit", "apply", "revert", "multiSelect", "applyToAll", "stats", "ensureType", "attachDefault", "editMany", "pending", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("inspector", { id = "arkher.studio.camerabookmark.property_inspector" })
		inst.system = S
		inst.ctx = ctx

		function inst.ensureType()
			local Reflection = A:import("arkher/kernel/reflection")
			if not Reflection.getType(S.key) then
				Reflection.defineType(S.key, { fields = {
					intensity = { type = "number", default = S.params.baseWeight, min = 0, max = 1,
						editor = { group = "Tuning", order = 1 } },
					mode = { type = "string", default = "auto", editor = { group = "Tuning", order = 2 } },
					enabled = { type = "boolean", default = true, editor = { group = "General", order = 3 } } } })
			end
			return S.key
		end
		function inst.attachDefault(target)
			inst.ensureType()
			target = target or { intensity = S.params.baseWeight, mode = "auto", enabled = true }
			inst.attach(target, S.key)
			return target
		end
		function inst.editMany(patch)
			local applied, rejected = 0, 0
			for field, value in pairs(patch) do
				if inst.edit(field, value) then applied = applied + 1 else rejected = rejected + 1 end
			end
			return applied, rejected
		end
		function inst.pending()
			local out = {}
			for k, v in pairs(inst.edits) do out[#out + 1] = { field = k, value = v } end
			table.sort(out, function(a, b) return a.field < b.field end)
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
				engine.bus:subscribe("arkher.studio.camerabookmark.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		local target = inst.attachDefault({ intensity = 0.1, mode = "auto", enabled = true })
		local applied, rejected = inst.editMany({ intensity = 9.0, mode = "manual" })
		local ok = applied == 2 and rejected == 0 and #inst.pending() == 2
		ok = ok and inst.apply() == 2 and target.intensity == 1 and target.mode == "manual"
		ok = ok and #inst.fields() == 3
		local common = inst.multiSelect({ { intensity = 0.2 }, { intensity = 0.9 } })
		return ok and common.intensity == "<mixed>"
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
