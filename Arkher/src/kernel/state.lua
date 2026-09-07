-- ARKHER KERNEL :: State Machines (finite + hierarchical + pushdown)
--@arkher-module
return function(A)
	local Signal = A:import("arkher/kernel/signal")
	local State = {}
	State.__index = State

	function State.machine(opts)
		opts = opts or {}
		local self = setmetatable({}, State)
		self.states = {}
		self.current = nil
		self.previous = nil
		self.stack = {}
		self.transitions = {}
		self.onEnter = Signal.new("enter")
		self.onExit = Signal.new("exit")
		self.onTransition = Signal.new("transition")
		self.history = {}
		self.maxHistory = opts.maxHistory or 32
		self.timeInState = 0
		self.blocked = false
		return self
	end

	function State:add(name, def)
		def = def or {}
		self.states[name] = {
			name = name, enter = def.enter, exit = def.exit, update = def.update,
			can = def.can, tags = def.tags or {}, parent = def.parent,
		}
		return self
	end

	function State:allow(from, to, guard)
		self.transitions[from] = self.transitions[from] or {}
		self.transitions[from][to] = guard or true
		return self
	end

	function State:canTransition(to)
		if self.blocked then return false end
		if not self.states[to] then return false end
		if not self.current then return true end
		local t = self.transitions[self.current]
		if not t then return false end
		local guard = t[to] or (t["*"] ~= nil and t["*"])
		if guard == nil or guard == false then return false end
		if type(guard) == "function" then return guard(self) == true end
		return true
	end

	function State:goTo(to, payload)
		if not self:canTransition(to) then return false end
		local from = self.current
		if from and self.states[from].exit then self.states[from].exit(self, to, payload) end
		self.onExit:fire(from, to)
		self.previous = from
		self.current = to
		self.timeInState = 0
		self.history[#self.history + 1] = { from = from, to = to }
		if #self.history > self.maxHistory then table.remove(self.history, 1) end
		if self.states[to].enter then self.states[to].enter(self, from, payload) end
		self.onEnter:fire(to, from)
		self.onTransition:fire(from, to, payload)
		return true
	end

	function State:force(to, payload)
		local saved = self.transitions[self.current]
		self.transitions[self.current] = { [to] = true }
		local ok = self:goTo(to, payload)
		self.transitions[self.current == to and self.previous or self.current] = saved
		return ok
	end

	function State:push(to, payload)
		self.stack[#self.stack + 1] = self.current
		return self:force(to, payload)
	end

	function State:pop(payload)
		local prev = table.remove(self.stack)
		if not prev then return false end
		return self:force(prev, payload)
	end

	function State:update(dt)
		self.timeInState = self.timeInState + dt
		local s = self.states[self.current]
		if s and s.update then s.update(self, dt) end
		return self.current
	end

	function State:isIn(name)
		if self.current == name then return true end
		local s = self.states[self.current]
		while s and s.parent do
			if s.parent == name then return true end
			s = self.states[s.parent]
		end
		return false
	end

	function State:hasTag(tag)
		local s = self.states[self.current]
		if not s then return false end
		for _, t in ipairs(s.tags) do if t == tag then return true end end
		return false
	end

	function State:reset(to)
		self.current = to
		self.stack = {}
		self.history = {}
		self.timeInState = 0
	end

	return State

end
