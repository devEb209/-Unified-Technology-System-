-- ARKHER :: engine + full catalog verification
local A = ARKHER
local TestKit = A:import("arkher/kernel/testkit")
local Engine = A:import("arkher/engine")
local Headless = A:import("arkher/platform/headless")
local t = TestKit.new()

local engine

t:describe("engine/boot", function(s)
	s:it("boots on the headless adapter", function(a)
		engine = Engine.boot(A, { headless = { device = { class = "phone", memoryMB = 2000, cores = 6,
			gpuTier = 1, screen = { width = 828, height = 1792 }, touch = true, os = "virtual" } } })
		a:equal(engine.platform, "headless")
		a:ok(engine.adapterValid, tostring(engine.adapterError))
		a:ok(engine.device.tier ~= nil)
		a:ok(engine.quality.renderScale > 0)
	end)
	s:it("loads the whole generated catalog", function(a)
		local loaded, failed = engine:loadCatalog()
		a:equal(failed, 0, "catalog modules must all load")
		a:gte(loaded, 9804)
		a:equal(#engine.systems, loaded)
	end)
	s:it("runs frames and adapts quality", function(a)
		local avg = engine:run(30, 1 / 60)
		a:gte(engine.frameCount, 30)
		a:ok(engine.quality.renderScale > 0)
		local findings, plan = engine:optimize()
		a:isType(findings, "table")
		a:isType(plan.steps, "table")
	end)
	s:it("reports category coverage", function(a)
		local r = engine:report()
		a:equal(r.byCategory.A, 520)
		a:equal(r.byCategory.S, 620)
		a:equal(r.byCategory.X, 410)
		a:equal(r.byCategory.B, 700)
		a:equal(r.byCategory.U, 600)
		a:equal(r.byCategory.Y, 400)
		a:equal(r.byCategory.C, 644)
		a:equal(r.byCategory.D, 640)
		a:equal(r.byCategory.M, 616)
		a:equal(r.byCategory.E, 600)
		a:equal(r.byCategory.F, 700)
		a:equal(r.byCategory.G, 504)
		a:equal(r.byCategory.H, 700)
		a:equal(r.byCategory.I, 520)
		a:equal(r.byCategory.J, 330)
		a:equal(r.byCategory.K, 700)
		a:equal(r.byCategory.L, 600)
		a:equal(r.systems, 9804)
	end)
end)

t:describe("catalog/self-verification", function(s)
	s:it("every system passes its own self-test", function(a)
		local result = engine:verify()
		if result.failed > 0 then
			local sample = {}
			for i = 1, math.min(5, #result.failures) do
				sample[#sample + 1] = result.failures[i].key .. " -> " .. result.failures[i].error
			end
			error(string.format("%d/%d systems failed self-test:\n%s", result.failed, result.total, table.concat(sample, "\n")))
		end
		a:equal(result.failed, 0)
		a:gte(result.passed, 9804)
	end)
	s:it("every system exposes a complete API surface", function(a)
		local minFeatures = math.huge
		local totalFeatures = 0
		for key, inst in pairs(engine.registry) do
			local n = 0
			for k, v in pairs(inst) do if type(v) == "function" then n = n + 1 end end
			totalFeatures = totalFeatures + n
			if n < minFeatures then minFeatures = n end
		end
		a:gte(minFeatures, 10)
		a:gte(totalFeatures, 155000)
		engine.totalCallableFeatures = totalFeatures
	end)
	s:it("systems integrate with the engine bus and registry", function(a)
		local sample = engine:findSystems("arkher.core.scheduler")
		a:gt(#sample, 5)
		local inst = sample[1].instance
		a:ok(inst.describe().key ~= nil)
		a:ok(inst.health().status ~= nil)
	end)
end)

local r = t:run()
local ok = t:report()
print(string.format("ARKHER CATALOG :: %d systems booted, %d callable features verified",
	#engine.systems, engine.totalCallableFeatures or 0))
if not ok then error("ARKHER engine tests failed") end
