-- ARKHER NPC :: Agent Runtime
-- The body around a mind: navigation, steering, behaviour arbitration (behaviour tree +
-- utility + GOAP), daily schedule, and a strict simulation-tier budget so a town of NPCs
-- costs what a phone can pay.
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Mathx = A:import("arkher/kernel/mathx")
	local Vec = A:import("arkher/kernel/vec")
	local Signal = A:import("arkher/kernel/signal")
	local Mind = A:import("arkher/npc/mind")
	local v3 = Vec.vec3

	local Agents = {}
	Agents.__index = Agents

	-- Simulation tiers: how much of an NPC actually runs at this distance.
	Agents.TIERS = {
		{ name = "acting",     distance = 60,        mind = true,  steer = true,  rate = 1 },
		{ name = "behaving",   distance = 160,       mind = true,  steer = true,  rate = 3 },
		{ name = "scheduled",  distance = 420,       mind = false, steer = false, rate = 12 },
		{ name = "statistical",distance = math.huge, mind = false, steer = false, rate = 0 },
	}

	function Agents.new(opts)
		opts = opts or {}
		local self = setmetatable({}, Agents)
		self.agents = {}
		self.order = {}
		self.nav = Kits.create("navgraph", { id = "agents.nav",
			width = opts.navWidth or 48, height = opts.navHeight or 48,
			cellSize = opts.cellSize or 4 })
		self.crowd = Kits.create("crowd", { id = "agents.crowd",
			cellSize = opts.cellSize or 8, maxSpeed = opts.maxSpeed or 4 })
		self.society = Kits.create("society", { id = "agents.society" })
		self.pathCache = Kits.create("cache", { id = "agents.paths", policy = "lru",
			capacity = opts.pathCache or 128 })
		self.budget = opts.budget or 32
		self.frame = 0
		self.minded = 0
		self.skipped = 0
		self.pathRequests = 0
		self.pathHits = 0
		self.onArrive = Signal.new("agent.arrive")
		self.onActivity = Signal.new("agent.activity")
		return self
	end

	-- ------------------------------------------------------------------ spawning
	function Agents:spawn(id, opts)
		opts = opts or {}
		if self.agents[id] then return nil, "duplicate agent" end
		local agent = {
			id = id,
			position = opts.position or v3(),
			mind = Mind.new(id, { seed = opts.seed or 1, personality = opts.personality }),
			tree = Kits.create("behaviortree", { id = id .. ".bt" }),
			utility = Kits.create("utility", { id = id .. ".utility" }),
			planner = Kits.create("planner", { id = id .. ".goap" }),
			schedule = Kits.create("schedule", { id = id .. ".schedule",
				startHour = opts.startHour or 7 }),
			home = opts.home or (opts.position or v3()),
			work = opts.work or (opts.position or v3()),
			tier = 1, accumulator = 0, path = nil, pathIndex = 1,
			activity = "idle", faction = opts.faction, plan = nil, planStep = 1,
			arrivals = 0, replans = 0,
		}
		self:installDefaultBehaviour(agent)
		self:installDefaultSchedule(agent)
		self:installDefaultPlan(agent)
		self.crowd.add(id, agent.position, { maxSpeed = opts.maxSpeed or 4 })
		self.society.join(id, { faction = opts.faction })
		self.agents[id] = agent
		self.order[#self.order + 1] = id
		return agent
	end

	function Agents:despawn(id)
		if not self.agents[id] then return false end
		self.crowd.remove(id)
		self.society.leave(id)
		self.agents[id] = nil
		for i, k in ipairs(self.order) do
			if k == id then table.remove(self.order, i) break end
		end
		return true
	end

	function Agents:get(id) return self.agents[id] end

	-- ------------------------------------------------------------------ behaviour
	function Agents:installDefaultBehaviour(agent)
		local bt = agent.tree
		bt.addNode("root", "selector")
		bt.addNode("survive", "sequence")
		bt.addNode("threatened", "condition",
			{ condition = function(bb) return (bb.threat or 0) > 0.5 end })
		bt.addNode("flee", "action", { action = function(bb)
			bb.action = "flee"
			return "success"
		end })
		bt.addNode("routine", "sequence")
		bt.addNode("hasActivity", "condition",
			{ condition = function(bb) return bb.activity ~= nil end })
		bt.addNode("doActivity", "action", { action = function(bb)
			bb.action = bb.activity
			return "success"
		end })
		bt.addNode("idle", "action", { action = function(bb)
			bb.action = "wander"
			return "success"
		end })
		bt.attach("root", "survive")
		bt.attach("survive", "threatened")
		bt.attach("survive", "flee")
		bt.attach("root", "routine")
		bt.attach("routine", "hasActivity")
		bt.attach("routine", "doActivity")
		bt.attach("root", "idle")
		bt.setRoot("root")

		local u = agent.utility
		u.addOption("rest", { weight = 1 })
		u.addConsideration("rest", "tiredness",
			function(ctx) return 1 - (ctx.energy or 1) end, "quadratic")
		u.addOption("eat", { weight = 1 })
		u.addConsideration("eat", "hunger",
			function(ctx) return 1 - (ctx.food or 1) end, "quadratic")
		u.addOption("work", { weight = 0.9 })
		u.addConsideration("work", "purpose",
			function(ctx) return 1 - (ctx.purpose or 1) end, "linear")
		u.addConsideration("work", "daylight",
			function(ctx) return ctx.night and 0.1 or 1 end, "linear")
		u.addOption("socialize", { weight = 0.8 })
		u.addConsideration("socialize", "loneliness",
			function(ctx) return 1 - (ctx.social or 1) end, "logistic")
		return agent
	end

	function Agents:installDefaultSchedule(agent)
		local s = agent.schedule
		s.addSlot("sleep", 22, 6, { priority = 3, location = agent.home })
		s.addSlot("eat", 6, 8, { priority = 2, location = agent.home })
		s.addSlot("work", 8, 12, { priority = 2, location = agent.work })
		s.addSlot("eat", 12, 13, { priority = 2, location = agent.home })
		s.addSlot("work", 13, 18, { priority = 2, location = agent.work })
		s.addSlot("socialize", 18, 22, { priority = 1, location = agent.home })
		return agent
	end

	function Agents:installDefaultPlan(agent)
		local p = agent.planner
		p.addAction("goHome", { pre = { atHome = false }, effects = { atHome = true, atWork = false }, cost = 2 })
		p.addAction("goWork", { pre = { atWork = false }, effects = { atWork = true, atHome = false }, cost = 2 })
		p.addAction("sleep", { pre = { atHome = true, rested = false }, effects = { rested = true }, cost = 1 })
		p.addAction("eat", { pre = { atHome = true, fed = false }, effects = { fed = true }, cost = 1 })
		p.addAction("labour", { pre = { atWork = true, rested = true }, effects = { paid = true }, cost = 3 })
		return agent
	end

	-- ------------------------------------------------------------------ navigation
	function Agents:pathTo(id, target)
		local agent = self.agents[id]
		if not agent then return nil end
		self.pathRequests = self.pathRequests + 1
		local sx, sz = self.nav.toCell(agent.position)
		local tx, tz = self.nav.toCell(target)
		local key = sx .. ":" .. sz .. ">" .. tx .. ":" .. tz
		local cached = self.pathCache.get(key)
		if cached then
			self.pathHits = self.pathHits + 1
			agent.path = cached
			agent.pathIndex = 1
			return cached
		end
		local grid = self.nav.findPath(sx, sz, tx, tz)
		if not grid then return nil, "unreachable" end
		local smoothed = self.nav.smooth(grid)
		local world = self.nav.worldPath(smoothed)
		self.pathCache.set(key, world)
		agent.path = world
		agent.pathIndex = 1
		return world
	end

	function Agents:followPath(id, dt)
		local agent = self.agents[id]
		if not agent or not agent.path then return false end
		local waypoint = agent.path[agent.pathIndex]
		if not waypoint then
			agent.path = nil
			agent.arrivals = agent.arrivals + 1
			self.onArrive:fire({ id = id, position = agent.position })
			return true
		end
		self.crowd.setTarget(id, waypoint)
		if agent.position:distance(waypoint) < 2.0 then
			agent.pathIndex = agent.pathIndex + 1
		end
		return false
	end

	function Agents:goTo(id, target)
		local path = self:pathTo(id, target)
		if not path then
			self.crowd.setTarget(id, target)
			return false
		end
		return true
	end

	-- ------------------------------------------------------------------ decision
	function Agents:context(agent)
		local needs = agent.mind.needs
		return {
			energy = needs.needs.energy and needs.needs.energy.value or 1,
			food = needs.needs.food and needs.needs.food.value or 1,
			social = needs.needs.social and needs.needs.social.value or 1,
			purpose = needs.needs.purpose and needs.needs.purpose.value or 1,
			night = agent.schedule.isNight(),
			threat = agent.mind.threat or 0,
		}
	end

	function Agents:think(id, dt)
		local agent = self.agents[id]
		if not agent then return nil end
		local activity = agent.schedule.advance(dt / 3600 * 60) -- 1 real minute = 1 game hour
		local ctx = self:context(agent)
		agent.tree.set("threat", ctx.threat)
		agent.tree.set("activity", activity)
		agent.tree.tick(dt)
		local treeAction = agent.tree.get("action")
		local utilityAction = agent.utility.evaluate(ctx, dt)
		local mindAction = agent.mind:decide(dt)
		-- arbitration: survival first, then the strongest utility, then the mind's own idea
		local chosen = treeAction
		if chosen ~= "flee" then
			if utilityAction and agent.utility.options[utilityAction].score > 0.55 then
				chosen = utilityAction
			elseif mindAction then
				chosen = mindAction
			end
		end
		if chosen ~= agent.activity then
			self.onActivity:fire({ id = id, from = agent.activity, to = chosen })
			agent.activity = chosen
			local location = agent.schedule.locationFor(chosen)
			if location then self:goTo(id, location) end
		end
		agent.mind:act(chosen)
		return chosen, activity
	end

	function Agents:replan(id, goal)
		local agent = self.agents[id]
		if not agent then return nil end
		agent.replans = agent.replans + 1
		local state = {
			atHome = agent.position:distance(agent.home) < 6,
			atWork = agent.position:distance(agent.work) < 6,
			rested = (agent.mind.needs.needs.energy and agent.mind.needs.needs.energy.value or 1) > 0.6,
			fed = (agent.mind.needs.needs.food and agent.mind.needs.needs.food.value or 1) > 0.6,
			paid = false,
		}
		local plan = agent.planner.plan(state, goal or { paid = true })
		agent.plan = plan
		agent.planStep = 1
		return plan
	end

	-- ------------------------------------------------------------------ the frame
	function Agents:updateTier(id, observer)
		local agent = self.agents[id]
		if not agent then return nil end
		local distance = agent.position:distance(observer)
		for i, tier in ipairs(Agents.TIERS) do
			if distance <= tier.distance then
				agent.tier = i
				break
			end
		end
		return agent.tier, distance
	end

	function Agents:update(dt, observer)
		self.frame = self.frame + 1
		observer = observer or v3()
		local candidates = {}
		for _, id in ipairs(self.order) do
			local agent = self.agents[id]
			self:updateTier(id, observer)
			local tier = Agents.TIERS[agent.tier]
			if tier.rate > 0 then
				agent.accumulator = agent.accumulator + 1
				if agent.accumulator >= tier.rate then
					candidates[#candidates + 1] = { id = id,
						distance = agent.position:distance(observer) }
				end
			end
		end
		table.sort(candidates, function(a, b) return a.distance < b.distance end)
		local processed = 0
		for _, c in ipairs(candidates) do
			if processed >= self.budget then
				self.skipped = self.skipped + 1
			else
				local agent = self.agents[c.id]
				local tier = Agents.TIERS[agent.tier]
				local step = dt * agent.accumulator
				agent.accumulator = 0
				if tier.mind then
					agent.mind:place(agent.position)
					agent.mind.needs.tick(step)
					agent.mind.emotion.tick(step)
					agent.mind.memory.tick(step)
					self:think(c.id, step)
					self.minded = self.minded + 1
				else
					-- scheduled tier: the routine still advances, the brain does not run
					local activity = agent.schedule.advance(step / 60)
					if activity ~= agent.activity then
						agent.activity = activity
						local location = agent.schedule.locationFor(activity)
						if location then agent.position = location end
					end
				end
				if tier.steer then self:followPath(c.id, step) end
				processed = processed + 1
			end
		end
		self.crowd.step(dt)
		for _, id in ipairs(self.order) do
			local agent = self.agents[id]
			local body = self.crowd.agents[id]
			if body then agent.position = body.position end
		end
		return { processed = processed, candidates = #candidates, frame = self.frame }
	end

	function Agents:applyQuality(quality)
		quality = Mathx.clamp(quality or 1, 0, 1)
		self.budget = math.max(4, math.floor(4 + quality * 60))
		Agents.TIERS[1].distance = 20 + quality * 60
		Agents.TIERS[2].distance = 70 + quality * 140
		Agents.TIERS[3].distance = 200 + quality * 320
		for _, id in ipairs(self.order) do self.agents[id].mind:applyQuality(quality) end
		return { budget = self.budget, actingDistance = Agents.TIERS[1].distance }
	end

	function Agents:report()
		local byTier, byActivity = {}, {}
		for _, id in ipairs(self.order) do
			local agent = self.agents[id]
			local tier = Agents.TIERS[agent.tier].name
			byTier[tier] = (byTier[tier] or 0) + 1
			byActivity[agent.activity or "idle"] = (byActivity[agent.activity or "idle"] or 0) + 1
		end
		return { agents = #self.order, byTier = byTier, byActivity = byActivity,
			frame = self.frame, minded = self.minded, skipped = self.skipped,
			pathRequests = self.pathRequests, pathHits = self.pathHits,
			pathHitRate = self.pathRequests > 0 and (self.pathHits / self.pathRequests) or 0,
			crowd = self.crowd.stats(), nav = self.nav.stats(), society = self.society.stats() }
	end

	return Agents
end
