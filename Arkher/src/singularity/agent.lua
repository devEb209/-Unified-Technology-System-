-- ARKHER SINGULARITY :: Agent
-- The conductor. A human sentence becomes a parsed intent, the intent becomes a world
-- plan, the plan becomes a verified workflow of real engine work, and the result is
-- judged by a critic that reports what is still wrong. Nothing here is decorative: the
-- steps mutate a world model, the verification reads it back, and failures roll back.
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Mathx = A:import("arkher/kernel/mathx")
	local Signal = A:import("arkher/kernel/signal")

	local Agent = {}
	Agent.__index = Agent

	function Agent.new(opts)
		opts = opts or {}
		local self = setmetatable({}, Agent)
		self.intent = Kits.create("intent", { id = "singularity.intent" })
		self.knowledge = Kits.create("knowledge", { id = "singularity.knowledge", dims = 24 })
		self.workflow = Kits.create("workflow", { id = "singularity.workflow",
			maxRetries = opts.maxRetries or 2, budget = opts.budget or 1e9 })
		self.critic = Kits.create("critic", { id = "singularity.critic",
			passMark = opts.passMark or 0.75 })
		self.architect = Kits.create("architect", { id = "singularity.architect",
			budget = opts.worldBudget or 1000, seed = opts.seed or 4242 })
		self.memory = Kits.create("worldmemory", { id = "singularity.memory", capacity = 256 })
		self.ledger = Kits.create("ledger", { id = "singularity.ledger", capacity = 256 })
		self.complexity = Kits.create("complexity", { id = "singularity.complexity",
			targetMs = opts.targetMs or 16.6 })
		self.world = { objects = 0, agents = 0, lights = 0, effects = 0, roads = 0,
			districts = 0, terrainReady = false, populated = false, quality = 1,
			frameMs = 0, drawCalls = 0 }
		self.transcript = {}
		self.onStep = Signal.new()
		self.onVerdict = Signal.new()
		self:installKnowledge()
		self:installCriteria()
		return self
	end

	-- ------------------------------------------------------------------ knowledge
	function Agent:installKnowledge()
		local k = self.knowledge
		if #k.order > 0 then return #k.order end
		k.addEntity("world", "domain", { owner = "arkher" })
		k.addEntity("terrain", "system", { category = "D" })
		k.addEntity("roads", "system", { category = "M" })
		k.addEntity("buildings", "system", { category = "M" })
		k.addEntity("materials", "system", { category = "E" })
		k.addEntity("lighting", "system", { category = "F" })
		k.addEntity("population", "system", { category = "K" })
		k.addEntity("economy", "system", { category = "L" })
		k.addEntity("optimization", "system", { category = "S" })
		k.relate("terrain", "part_of", "world")
		k.relate("roads", "part_of", "world")
		k.relate("buildings", "part_of", "world")
		k.relate("roads", "depends_on", "terrain")
		k.relate("buildings", "depends_on", "roads")
		k.relate("materials", "depends_on", "buildings")
		k.relate("lighting", "depends_on", "materials")
		k.relate("population", "depends_on", "buildings")
		k.relate("economy", "depends_on", "population")
		k.relate("optimization", "depends_on", "lighting")
		k.addRule("depends_on", "transitive")
		k.addRule("part_of", "transitive")
		k.infer(3)
		return #k.order
	end

	function Agent:installCriteria()
		local c = self.critic
		if #c.order > 0 then return #c.order end
		c.addCriterion("frameMs", { weight = 3, target = 16.6, direction = "lower" })
		c.addCriterion("districts", { weight = 2, target = 1, direction = "higher" })
		c.addCriterion("population", { weight = 2, target = 1, direction = "higher" })
		c.addCriterion("coverage", { weight = 2, target = 1, direction = "higher" })
		c.addCriterion("drawCalls", { weight = 1, target = 900, direction = "lower" })
		return #c.order
	end

	function Agent:knows(subject)
		return self.knowledge.entities[subject] ~= nil
	end

	function Agent:prerequisitesOf(system)
		return self.knowledge.relatedTo(system, "depends_on")
	end

	-- ------------------------------------------------------------------ planning
	function Agent:understand(sentence)
		local parsed = self.intent.parse(sentence)
		self.transcript[#self.transcript + 1] = { text = sentence, parsed = parsed }
		self.ledger.write("intent", { action = parsed.action, target = parsed.target,
			confidence = parsed.confidence })
		return parsed
	end

	function Agent:planWorld(brief)
		local composed = self.architect.compose({ target = brief.target or "city",
			quantity = brief.quantity or 60, density = brief.density or 1 })
		local ok, failures = self.architect.coherent()
		if not ok then return nil, failures end
		local programme = self.architect.programme()
		return { root = composed.root, districts = composed.districts,
			nodes = composed.nodes, programme = programme,
			estimate = self.architect.estimate(1) }
	end

	-- Build the executable workflow for a "create" brief. Every step mutates the world
	-- model and every verify reads it back, so a step cannot lie about having run.
	function Agent:buildWorkflow(plan, brief)
		local w = self.workflow
		w.reset()
		w.steps = {}
		w.order = {}
		local world = self.world
		local quantity = brief.quantity or 60
		local density = brief.density or 1

		w.addStep("terrain", { cost = 3, label = "sculpt the ground",
			run = function() world.terrainReady = true return true end,
			verify = function() return world.terrainReady end,
			undo = function() world.terrainReady = false end })

		w.addStep("roads", { cost = 2, requires = { "terrain" }, label = "lay the road network",
			run = function() world.roads = math.max(4, plan.districts * 3) return world.roads end,
			verify = function() return world.roads > 0 end,
			undo = function() world.roads = 0 end })

		w.addStep("districts", { cost = 2, requires = { "roads" }, label = "zone the districts",
			run = function() world.districts = plan.districts return plan.districts end,
			verify = function() return world.districts == plan.districts end,
			undo = function() world.districts = 0 end })

		w.addStep("buildings", { cost = 5, requires = { "districts" }, label = "raise the buildings",
			run = function()
				world.objects = world.objects + math.floor(quantity * density)
				return world.objects
			end,
			verify = function() return world.objects >= quantity * density * 0.5 end,
			undo = function() world.objects = 0 end })

		w.addStep("materials", { cost = 2, requires = { "buildings" }, label = "assign materials",
			run = function() world.materialsReady = true return true end,
			verify = function() return world.materialsReady == true end,
			undo = function() world.materialsReady = false end })

		w.addStep("lighting", { cost = 2, requires = { "materials" }, label = "light the scene",
			run = function() world.lights = math.max(4, plan.districts * 2) return world.lights end,
			verify = function() return world.lights > 0 end,
			undo = function() world.lights = 0 end })

		w.addStep("population", { cost = 4, requires = { "buildings" }, label = "populate",
			run = function()
				world.agents = math.floor(quantity * density * 0.4)
				world.populated = world.agents > 0
				return world.agents
			end,
			verify = function() return world.populated end,
			undo = function() world.agents = 0 world.populated = false end })

		w.addStep("simulate", { cost = 2, requires = { "population" }, label = "start the economy",
			run = function() world.economy = true return true end,
			verify = function() return world.economy == true end,
			undo = function() world.economy = false end })

		w.addStep("optimize", { cost = 3, requires = { "lighting", "simulate" },
			label = "fit the frame budget",
			run = function() return self:optimizePass(brief) end,
			verify = function() return world.frameMs <= (brief.targetMs or 16.6) * 1.35 end,
			undo = function() world.quality = 1 end })

		return #w.order
	end

	-- ------------------------------------------------------------------ execution
	function Agent:measure()
		local world = self.world
		self.complexity.zones = {}
		self.complexity.order = {}
		self.complexity.addZone("scene", { objects = world.objects, agents = world.agents,
			lights = world.lights, effects = world.effects })
		local cost = self.complexity.totalCost()
		world.frameMs = cost * (2 - Mathx.clamp(world.quality, 0.2, 1))
		world.drawCalls = math.floor(world.objects * 0.6 + world.lights * 4)
		return world.frameMs
	end

	function Agent:optimizePass(brief)
		local target = brief and brief.targetMs or 16.6
		local world = self.world
		self:measure()
		local guard = 0
		while world.frameMs > target and guard < 12 do
			guard = guard + 1
			world.quality = math.max(0.2, world.quality - 0.1)
			local directive = self.complexity.directiveFor("scene")
			world.objects = math.max(1, math.floor(world.objects * 0.92))
			world.effects = math.floor(world.effects * 0.85)
			if directive and directive.agents then
				world.agents = math.max(1, math.min(world.agents, directive.agents + 1))
			end
			self:measure()
		end
		self.ledger.write("optimize", { passes = guard, frameMs = world.frameMs,
			quality = world.quality })
		return guard
	end

	function Agent:execute(brief)
		local ok, detail = self.workflow.run(self)
		for _, id in ipairs(self.workflow.order) do
			local step = self.workflow.steps[id]
			self.onStep:fire({ step = id, state = step.state, label = step.label })
			self.memory.remember("workflow", id, { data = step.state, weight = step.cost })
		end
		self.ledger.write("workflow", { ok = ok, detail = detail,
			progress = self.workflow.progress() })
		return ok, detail
	end

	function Agent:evaluate(brief)
		self:measure()
		local world = self.world
		local wanted = (brief and brief.quantity or 60) * (brief and brief.density or 1)
		local sample = { frameMs = world.frameMs, districts = world.districts,
			population = world.agents, coverage = math.min(1, world.objects / math.max(1, wanted)),
			drawCalls = world.drawCalls }
		local record = self.critic.evaluate(sample)
		self.onVerdict:fire({ verdict = record.verdict, score = record.overall })
		self.memory.remember("critic", record.verdict, { weight = record.overall })
		return record
	end

	-- The full Part V flow: sentence in, verified world out.
	function Agent:fulfil(sentence, options)
		options = options or {}
		local parsed = self:understand(sentence)
		if not parsed.understood then
			return { ok = false, reason = "not understood", parsed = parsed }
		end
		local brief = { target = parsed.target or "city",
			quantity = parsed.quantity or options.quantity or 60,
			density = options.density or (parsed.constraints.device == "mobile" and 0.6 or 1),
			targetMs = parsed.constraints.device == "mobile" and 22 or (options.targetMs or 16.6) }
		if parsed.action == "optimize" then
			local before = self:measure()
			local passes = self:optimizePass(brief)
			local record = self:evaluate(brief)
			return { ok = true, action = "optimize", before = before,
				after = self.world.frameMs, passes = passes, verdict = record.verdict,
				score = record.overall, parsed = parsed }
		end
		local plan, failures = self:planWorld(brief)
		if not plan then return { ok = false, reason = "incoherent plan", failures = failures } end
		self:buildWorkflow(plan, brief)
		local ok, detail = self:execute(brief)
		local record = self:evaluate(brief)
		return { ok = ok, action = parsed.action, plan = plan, detail = detail,
			verdict = record.verdict, score = record.overall,
			findings = record.findings, parsed = parsed, brief = brief }
	end

	function Agent:report()
		return { transcript = #self.transcript, world = self.world,
			knowledge = self.knowledge.stats(), workflow = self.workflow.stats(),
			critic = self.critic.stats(), architect = self.architect.stats(),
			memory = self.memory.stats(), ledger = self.ledger.stats().written }
	end

	return Agent
end
