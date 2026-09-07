-- ARKHER D-O15 :: Budget Manager
-- Hard, measurable per-frame budgets. Every subsystem borrows from a pool and is
-- throttled the moment it overspends. This is what keeps phones at target FPS.
--@arkher-module
return function(A)
	local C = A:import("arkher/kernel/containers")
	local Budget = {}
	Budget.__index = Budget

	function Budget.new(totals)
		local self = setmetatable({}, Budget)
		self.totals = totals or {}
		self.spent = {}
		self.reservations = {}
		self.history = {}
		self.frame = 0
		self.overruns = {}
		self.policy = "proportional"
		return self
	end

	function Budget:setTotal(key, value) self.totals[key] = value end
	function Budget:total(key) return self.totals[key] or 0 end

	function Budget:reserve(consumer, key, amount, importance)
		self.reservations[key] = self.reservations[key] or {}
		self.reservations[key][consumer] = { amount = amount, importance = importance or 1.0 }
		return true
	end

	-- distribute a budget among reservations using importance weights
	function Budget:allocate(key)
		local total = self:total(key)
		local reservations = self.reservations[key] or {}
		local demand, weight = 0, 0
		for _, r in pairs(reservations) do
			demand = demand + r.amount
			weight = weight + r.importance
		end
		local out = {}
		if demand <= total or demand == 0 then
			for consumer, r in pairs(reservations) do out[consumer] = r.amount end
			return out, demand <= total
		end
		if self.policy == "priority" then
			local list = {}
			for consumer, r in pairs(reservations) do list[#list + 1] = { consumer = consumer, r = r } end
			table.sort(list, function(a, b) return a.r.importance > b.r.importance end)
			local left = total
			for _, item in ipairs(list) do
				local give = math.min(item.r.amount, left)
				out[item.consumer] = give
				left = left - give
			end
		else
			for consumer, r in pairs(reservations) do
				out[consumer] = total * (r.importance / weight) * (r.amount / demand) * (demand / math.max(demand, 1))
				out[consumer] = math.min(r.amount, total * (r.importance / weight))
			end
		end
		return out, false
	end

	function Budget:spend(key, amount)
		self.spent[key] = (self.spent[key] or 0) + amount
		if self.spent[key] > self:total(key) then
			self.overruns[key] = (self.overruns[key] or 0) + 1
			return false, self.spent[key] - self:total(key)
		end
		return true, self:total(key) - self.spent[key]
	end

	function Budget:remaining(key) return math.max(0, self:total(key) - (self.spent[key] or 0)) end
	function Budget:pressure(key)
		local t = self:total(key)
		if t <= 0 then return 0 end
		return (self.spent[key] or 0) / t
	end

	function Budget:beginFrame()
		self.frame = self.frame + 1
		local snapshot = {}
		for k, v in pairs(self.spent) do snapshot[k] = v end
		self.history[#self.history + 1] = snapshot
		if #self.history > 120 then table.remove(self.history, 1) end
		self.spent = {}
	end

	function Budget:averageSpend(key, frames)
		frames = math.min(frames or 30, #self.history)
		if frames == 0 then return 0 end
		local sum = 0
		for i = #self.history - frames + 1, #self.history do
			sum = sum + (self.history[i][key] or 0)
		end
		return sum / frames
	end

	function Budget:worstOffender()
		local worst, worstKey = 0, nil
		for key in pairs(self.totals) do
			local p = self:pressure(key)
			if p > worst then worst, worstKey = p, key end
		end
		return worstKey, worst
	end

	function Budget:report()
		local out = { frame = self.frame, keys = {} }
		for key, total in pairs(self.totals) do
			out.keys[#out.keys + 1] = { key = key, total = total, spent = self.spent[key] or 0,
				pressure = self:pressure(key), overruns = self.overruns[key] or 0, avg30 = self:averageSpend(key, 30) }
		end
		table.sort(out.keys, function(a, b) return a.pressure > b.pressure end)
		return out
	end

	return Budget

end
