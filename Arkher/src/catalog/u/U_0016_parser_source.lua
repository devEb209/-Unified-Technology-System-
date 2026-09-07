-- ARKHER SYSTEM U.0016 :: Parser Source Model
-- Category U - SCRIPTING / CODE INTELLIGENCE
-- Scripting capability: reading, understanding, transforming, generating and running ARKHER code.
-- Kit: source (tokenizing, symbol extraction and diagnostics)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "U.0016"
	S.key = "arkher.code.parser.source_model"
	S.name = "Parser Source Model"
	S.category = "U"
	S.family = "SCRIPTING / CODE INTELLIGENCE"
	S.area = "Parser"
	S.aspect = "Source Model"
	S.kit = "source"
	S.version = "1.0.0"
	S.deps = {  }
	S.tags = { "u", "parser", "source", "code" }
	S.description = "Parser Source Model: tokenizing, symbol extraction and diagnostics for the Parser subsystem."
	S.params = {
		backlogLimit = 16,
		baseRadius = 160,
		baseWeight = 0.98,
		bias = 0.08,
		biasWeight = 0.13,
		ceiling = 88,
		detailWeight = 0.68,
		failureTolerance = 3,
		horizon = 1,
		integrator = "euler",
		minConfidence = 0.48,
		minThrottle = 0.19,
		regressionSlope = 0.09,
		saturation = 0.93,
		scale = 2.8
	}
	S.features = { "setText", "tokenize", "extractSymbols", "addRule", "analyze", "complete", "metrics", "rename", "stats", "loadSample", "diagnose", "symbolNames", "quality", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("source", { id = "arkher.code.parser.source_model", text = "" })
		inst.system = S
		inst.ctx = ctx

		function inst.loadSample()
			inst.setText(table.concat({
				"-- " .. S.name,
				"local " .. S.tags[2] .. "Unit = {}",
				"function " .. S.tags[2] .. "Unit.process(value)",
				"\tlocal scale = " .. string.format("%.3f", S.params.scale),
				"\tif value == nil then return 0 end",
				"\treturn value * scale",
				"end",
				"return " .. S.tags[2] .. "Unit",
			}, "\n"))
			return #inst.text
		end
		function inst.diagnose()
			if #inst.text == 0 then inst.loadSample() end
			return inst.analyze()
		end
		function inst.symbolNames()
			if #inst.symbols == 0 then inst.extractSymbols() end
			local out = {}
			for _, sym in ipairs(inst.symbols) do out[#out + 1] = sym.name end
			table.sort(out)
			return out
		end
		function inst.quality()
			local m = inst.metrics()
			local score = 1.0 - math.min(0.5, #inst.diagnostics * 0.05)
			score = score - math.min(0.3, math.max(0, m.complexity - 5) * 0.02)
			return math.max(0, score), m
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
				engine.bus:subscribe("arkher.code.parser.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		inst.loadSample()
		local ok = #inst.tokenize() > 10
		ok = ok and #inst.symbolNames() >= 2
		ok = ok and type(inst.diagnose()) == "table"
		local score, m = inst.quality()
		ok = ok and score > 0 and m.lines >= 6 and m.tokens > 10
		ok = ok and type(inst.complete("pro")) == "table"
		return ok
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
