-- ARKHER KERNEL :: Dependency Graph + Resolver
-- Topological ordering, cycle detection, parallel wavefront scheduling.
--@arkher-module
return function(A)
	local Errors = A:import("arkher/kernel/errors")
	local DepGraph = {}
	DepGraph.__index = DepGraph

	function DepGraph.new()
		local self = setmetatable({}, DepGraph)
		self.nodes = {}
		self.edges = {}
		self.reverse = {}
		return self
	end

	function DepGraph:addNode(id, data)
		if self.nodes[id] then return false end
		self.nodes[id] = data or true
		self.edges[id] = {}
		self.reverse[id] = {}
		return true
	end

	function DepGraph:addEdge(from, to)
		if not self.nodes[from] then self:addNode(from) end
		if not self.nodes[to] then self:addNode(to) end
		for _, e in ipairs(self.edges[from]) do if e == to then return false end end
		self.edges[from][#self.edges[from] + 1] = to
		self.reverse[to][#self.reverse[to] + 1] = from
		return true
	end

	function DepGraph:dependenciesOf(id) return self.edges[id] or {} end
	function DepGraph:dependentsOf(id) return self.reverse[id] or {} end

	-- returns ordered list where dependencies come before dependents
	function DepGraph:topoSort()
		local indeg = {}
		local ids = {}
		for id in pairs(self.nodes) do indeg[id] = 0 ids[#ids + 1] = id end
		table.sort(ids)
		for _, id in ipairs(ids) do
			for _, dep in ipairs(self.edges[id]) do
				indeg[id] = indeg[id] + 0
			end
		end
		for _, id in ipairs(ids) do
			for _, dep in ipairs(self.edges[id]) do
				indeg[id] = indeg[id] + 1
			end
		end
		local ready = {}
		for _, id in ipairs(ids) do if indeg[id] == 0 then ready[#ready + 1] = id end end
		local order = {}
		while #ready > 0 do
			table.sort(ready)
			local id = table.remove(ready, 1)
			order[#order + 1] = id
			for _, dependent in ipairs(self.reverse[id]) do
				indeg[dependent] = indeg[dependent] - 1
				if indeg[dependent] == 0 then ready[#ready + 1] = dependent end
			end
		end
		if #order ~= #ids then
			local cyc = {}
			for _, id in ipairs(ids) do if indeg[id] > 0 then cyc[#cyc + 1] = id end end
			return nil, Errors.new(Errors.Codes.CYCLE, "dependency cycle detected", { nodes = cyc })
		end
		return order
	end

	-- wavefronts: lists of nodes that can execute in parallel
	function DepGraph:waves()
		local order, err = self:topoSort()
		if not order then return nil, err end
		local depth = {}
		local waves = {}
		for _, id in ipairs(order) do
			local d = 0
			for _, dep in ipairs(self.edges[id]) do
				local dd = (depth[dep] or 0) + 1
				if dd > d then d = dd end
			end
			depth[id] = d
			waves[d + 1] = waves[d + 1] or {}
			table.insert(waves[d + 1], id)
		end
		return waves
	end

	function DepGraph:hasCycle()
		local _, err = self:topoSort()
		return err ~= nil
	end

	function DepGraph:subgraph(rootId)
		local seen = {}
		local out = {}
		local stack = { rootId }
		while #stack > 0 do
			local id = table.remove(stack)
			if not seen[id] then
				seen[id] = true
				out[#out + 1] = id
				for _, d in ipairs(self.edges[id] or {}) do stack[#stack + 1] = d end
			end
		end
		return out
	end

	function DepGraph:size()
		local n = 0
		for _ in pairs(self.nodes) do n = n + 1 end
		return n
	end

	return DepGraph

end
