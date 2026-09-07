-- ARKHER KERNEL :: Containers
-- Cache-friendly data structures used by every runtime system.
--@arkher-module
return function(A)
	local Bits = A:import("arkher/kernel/bits")
	local C = {}

	------------------------------------------------------------------ RingBuffer
	local Ring = {}
	Ring.__index = Ring
	function C.ring(capacity)
		return setmetatable({ cap = capacity, data = {}, head = 0, size = 0 }, Ring)
	end
	function Ring:push(v)
		self.head = self.head + 1
		self.data[(self.head - 1) % self.cap + 1] = v
		if self.size < self.cap then self.size = self.size + 1 end
		return self
	end
	function Ring:get(i)
		if i < 1 or i > self.size then return nil end
		local idx = self.head - self.size + i
		return self.data[(idx - 1) % self.cap + 1]
	end
	function Ring:last() return self:get(self.size) end
	function Ring:toTable()
		local out = {}
		for i = 1, self.size do out[i] = self:get(i) end
		return out
	end
	function Ring:clear() self.data = {} self.head = 0 self.size = 0 end
	function Ring:average()
		if self.size == 0 then return 0 end
		local s = 0
		for i = 1, self.size do s = s + (self:get(i) or 0) end
		return s / self.size
	end
	function Ring:max()
		local m = -math.huge
		for i = 1, self.size do local v = self:get(i) if v and v > m then m = v end end
		return m
	end
	C.Ring = Ring

	------------------------------------------------------------------ PriorityQueue (binary heap)
	local PQ = {}
	PQ.__index = PQ
	function C.priorityQueue(cmp)
		return setmetatable({ heap = {}, n = 0, cmp = cmp or function(a, b) return a.priority < b.priority end }, PQ)
	end
	function PQ:push(item)
		self.n = self.n + 1
		self.heap[self.n] = item
		local i = self.n
		while i > 1 do
			local p = i // 2
			if self.cmp(self.heap[i], self.heap[p]) then
				self.heap[i], self.heap[p] = self.heap[p], self.heap[i]
				i = p
			else break end
		end
		return self
	end
	function PQ:pop()
		if self.n == 0 then return nil end
		local top = self.heap[1]
		self.heap[1] = self.heap[self.n]
		self.heap[self.n] = nil
		self.n = self.n - 1
		local i = 1
		while true do
			local l, r = i * 2, i * 2 + 1
			local best = i
			if l <= self.n and self.cmp(self.heap[l], self.heap[best]) then best = l end
			if r <= self.n and self.cmp(self.heap[r], self.heap[best]) then best = r end
			if best == i then break end
			self.heap[i], self.heap[best] = self.heap[best], self.heap[i]
			i = best
		end
		return top
	end
	function PQ:peek() return self.heap[1] end
	function PQ:size() return self.n end
	function PQ:isEmpty() return self.n == 0 end
	C.PQ = PQ

	------------------------------------------------------------------ SparseSet (ECS friendly)
	local SparseSet = {}
	SparseSet.__index = SparseSet
	function C.sparseSet()
		return setmetatable({ dense = {}, sparse = {}, n = 0 }, SparseSet)
	end
	function SparseSet:add(id, value)
		if self.sparse[id] then self.dense[self.sparse[id]].value = value return false end
		self.n = self.n + 1
		self.dense[self.n] = { id = id, value = value }
		self.sparse[id] = self.n
		return true
	end
	function SparseSet:get(id)
		local i = self.sparse[id]
		if not i then return nil end
		return self.dense[i].value
	end
	function SparseSet:has(id) return self.sparse[id] ~= nil end
	function SparseSet:remove(id)
		local i = self.sparse[id]
		if not i then return false end
		local last = self.dense[self.n]
		self.dense[i] = last
		self.sparse[last.id] = i
		self.dense[self.n] = nil
		self.sparse[id] = nil
		self.n = self.n - 1
		return true
	end
	function SparseSet:iterate()
		local i = 0
		return function()
			i = i + 1
			local e = self.dense[i]
			if e then return e.id, e.value end
		end
	end
	function SparseSet:count() return self.n end
	C.SparseSet = SparseSet

	------------------------------------------------------------------ LRU cache
	local LRU = {}
	LRU.__index = LRU
	function C.lru(capacity)
		return setmetatable({ cap = capacity, map = {}, order = {}, n = 0, hits = 0, misses = 0 }, LRU)
	end
	function LRU:_touch(key)
		for i, k in ipairs(self.order) do
			if k == key then table.remove(self.order, i) break end
		end
		self.order[#self.order + 1] = key
	end
	function LRU:get(key)
		local v = self.map[key]
		if v == nil then self.misses = self.misses + 1 return nil end
		self.hits = self.hits + 1
		self:_touch(key)
		return v
	end
	function LRU:set(key, value)
		if self.map[key] == nil then self.n = self.n + 1 end
		self.map[key] = value
		self:_touch(key)
		while self.n > self.cap do
			local oldest = table.remove(self.order, 1)
			self.map[oldest] = nil
			self.n = self.n - 1
		end
		return self
	end
	function LRU:has(key) return self.map[key] ~= nil end
	function LRU:remove(key)
		if self.map[key] == nil then return false end
		self.map[key] = nil
		self.n = self.n - 1
		for i, k in ipairs(self.order) do if k == key then table.remove(self.order, i) break end end
		return true
	end
	function LRU:hitRate()
		local total = self.hits + self.misses
		if total == 0 then return 0 end
		return self.hits / total
	end
	function LRU:clear() self.map = {} self.order = {} self.n = 0 end
	C.LRU = LRU

	------------------------------------------------------------------ BitSet
	local BitSet = {}
	BitSet.__index = BitSet
	function C.bitset()
		return setmetatable({ words = {} }, BitSet)
	end
	function BitSet:set(i)
		local w = i // 32 + 1
		self.words[w] = Bits.setBit(self.words[w] or 0, i % 32)
		return self
	end
	function BitSet:clear(i)
		local w = i // 32 + 1
		if self.words[w] then self.words[w] = Bits.clearBit(self.words[w], i % 32) end
		return self
	end
	function BitSet:test(i)
		local w = self.words[i // 32 + 1]
		if not w then return false end
		return Bits.testBit(w, i % 32)
	end
	function BitSet:count()
		local n = 0
		for _, w in pairs(self.words) do
				n = n + Bits.popcount(w)
		end
		return n
	end
	function BitSet:union(other)
		local out = C.bitset()
		for k, v in pairs(self.words) do out.words[k] = v end
		for k, v in pairs(other.words) do out.words[k] = Bits.bor(out.words[k] or 0, v) end
		return out
	end
	function BitSet:intersect(other)
		local out = C.bitset()
		for k, v in pairs(self.words) do
			local o = other.words[k]
			if o then out.words[k] = Bits.band(v, o) end
		end
		return out
	end
	C.BitSet = BitSet

	------------------------------------------------------------------ Deque
	local Deque = {}
	Deque.__index = Deque
	function C.deque() return setmetatable({ first = 1, last = 0, items = {} }, Deque) end
	function Deque:pushBack(v) self.last = self.last + 1 self.items[self.last] = v end
	function Deque:pushFront(v) self.first = self.first - 1 self.items[self.first] = v end
	function Deque:popBack()
		if self.last < self.first then return nil end
		local v = self.items[self.last]
		self.items[self.last] = nil
		self.last = self.last - 1
		return v
	end
	function Deque:popFront()
		if self.last < self.first then return nil end
		local v = self.items[self.first]
		self.items[self.first] = nil
		self.first = self.first + 1
		return v
	end
	function Deque:size() return self.last - self.first + 1 end
	function Deque:isEmpty() return self:size() <= 0 end
	C.Deque = Deque

	------------------------------------------------------------------ helpers
	function C.slice(t, from, to)
		local out = {}
		for i = from, math.min(to, #t) do out[#out + 1] = t[i] end
		return out
	end
	function C.map(t, fn)
		local out = {}
		for i, v in ipairs(t) do out[i] = fn(v, i) end
		return out
	end
	function C.filter(t, fn)
		local out = {}
		for i, v in ipairs(t) do if fn(v, i) then out[#out + 1] = v end end
		return out
	end
	function C.reduce(t, fn, init)
		local acc = init
		for i, v in ipairs(t) do acc = fn(acc, v, i) end
		return acc
	end
	function C.find(t, fn)
		for i, v in ipairs(t) do if fn(v, i) then return v, i end end
		return nil
	end
	function C.keys(t)
		local out = {}
		for k in pairs(t) do out[#out + 1] = k end
		table.sort(out, function(a, b) return tostring(a) < tostring(b) end)
		return out
	end
	function C.count(t)
		local n = 0
		for _ in pairs(t) do n = n + 1 end
		return n
	end
	function C.deepCopy(t, seen)
		if type(t) ~= "table" then return t end
		seen = seen or {}
		if seen[t] then return seen[t] end
		local out = {}
		seen[t] = out
		for k, v in pairs(t) do out[C.deepCopy(k, seen)] = C.deepCopy(v, seen) end
		return setmetatable(out, getmetatable(t))
	end
	function C.deepEqual(a, b)
		if a == b then return true end
		if type(a) ~= "table" or type(b) ~= "table" then return false end
		for k, v in pairs(a) do if not C.deepEqual(v, b[k]) then return false end end
		for k in pairs(b) do if a[k] == nil then return false end end
		return true
	end
	function C.merge(a, b)
		local out = C.deepCopy(a)
		for k, v in pairs(b) do
			if type(v) == "table" and type(out[k]) == "table" then out[k] = C.merge(out[k], v)
			else out[k] = v end
		end
		return out
	end
	function C.freeze(t)
		return setmetatable({}, {
			__index = t,
			__newindex = function() error("ARKHER: attempt to modify frozen table", 2) end,
			__len = function() return #t end,
			__pairs = function() return pairs(t) end,
		})
	end

	return C

end
