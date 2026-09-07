-- ARKHER COLLABORATION :: Workspace (multi-user + version control)
-- Real-time collaborative editing with locks and operational rebase, plus a project
-- version control abstraction: commits, branches, three-way merge and history.
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local C = A:import("arkher/kernel/containers")
	local Hash = A:import("arkher/kernel/hash")
	local Ser = A:import("arkher/kernel/serialize")
	local Workspace = {}
	Workspace.__index = Workspace

	function Workspace.new(opts)
		opts = opts or {}
		local self = setmetatable({}, Workspace)
		self.session = Kits.session({})
		self.merger = Kits.merge({ strategy = opts.mergeStrategy or "three-way" })
		self.commits = {}
		self.branches = { main = nil }
		self.head = "main"
		self.workingTree = opts.initial or {}
		self.comments = {}
		self.tasks = {}
		self.stats = { commits = 0, merges = 0, conflicts = 0, comments = 0 }
		return self
	end

	------------------------------------------------------------------ collaboration
	function Workspace:join(userId, role) return self.session.join(userId, role) end
	function Workspace:leave(userId) return self.session.leave(userId) end
	function Workspace:lock(userId, path) return self.session.acquireLock(userId, path) end
	function Workspace:unlock(userId, path) return self.session.releaseLock(userId, path) end

	function Workspace:edit(userId, path, value)
		local ok, err = self.session.submit(userId, { kind = "set", path = path, value = value })
		if not ok then
			self.stats.conflicts = self.stats.conflicts + 1
			return false, err
		end
		local parts = {}
		for part in string.gmatch(path, "[^%.]+") do parts[#parts + 1] = part end
		local node = self.workingTree
		for i = 1, #parts - 1 do
			node[parts[i]] = node[parts[i]] or {}
			node = node[parts[i]]
		end
		node[parts[#parts]] = value
		return true
	end

	function Workspace:sync(sinceSeq) return self.session.since(sinceSeq or 0) end
	function Workspace:presence(userId, path) return self.session.updatePresence(userId, path) end

	function Workspace:comment(userId, path, text)
		self.stats.comments = self.stats.comments + 1
		self.comments[#self.comments + 1] = { user = userId, path = path, text = text,
			seq = self.session.cursor, resolved = false }
		return #self.comments
	end

	function Workspace:resolveComment(index)
		local c = self.comments[index]
		if not c then return false end
		c.resolved = true
		return true
	end

	function Workspace:assignTask(userId, title, path)
		self.tasks[#self.tasks + 1] = { assignee = userId, title = title, path = path, state = "open" }
		return #self.tasks
	end

	function Workspace:completeTask(index)
		local t = self.tasks[index]
		if not t then return false end
		t.state = "done"
		return true
	end

	------------------------------------------------------------------ version control
	function Workspace:commit(author, message)
		local parent = self.branches[self.head]
		local snapshot = C.deepCopy(self.workingTree)
		local id = string.format("ark%08x", Hash.crc32(Ser.encodeBinary(snapshot) .. tostring(#self.commits) .. tostring(message)))
		local commit = { id = id, parent = parent, author = author, message = message,
			tree = snapshot, seq = #self.commits + 1, branch = self.head }
		self.commits[id] = commit
		self.branches[self.head] = id
		self.stats.commits = self.stats.commits + 1
		return id
	end

	function Workspace:branch(name, fromCommit)
		if self.branches[name] then return false, "branch exists" end
		self.branches[name] = fromCommit or self.branches[self.head]
		return true
	end

	function Workspace:checkout(name)
		local tip = self.branches[name]
		if tip == nil and name ~= "main" then return false, "unknown branch" end
		self.head = name
		if tip then self.workingTree = C.deepCopy(self.commits[tip].tree) end
		return true
	end

	function Workspace:history(branch, limit)
		local out = {}
		local id = self.branches[branch or self.head]
		while id and #out < (limit or 50) do
			local c = self.commits[id]
			if not c then break end
			out[#out + 1] = { id = c.id, author = c.author, message = c.message, seq = c.seq }
			id = c.parent
		end
		return out
	end

	function Workspace:diff(commitA, commitB)
		local a = self.commits[commitA]
		local b = commitB and self.commits[commitB] or { tree = self.workingTree }
		if not a then return nil, "unknown commit" end
		return self.merger.diff(a.tree, b.tree)
	end

	function Workspace:commonAncestor(branchA, branchB)
		local seen = {}
		local id = self.branches[branchA]
		while id do
			seen[id] = true
			id = self.commits[id] and self.commits[id].parent
		end
		id = self.branches[branchB]
		while id do
			if seen[id] then return id end
			id = self.commits[id] and self.commits[id].parent
		end
		return nil
	end

	function Workspace:merge(fromBranch, author)
		local baseId = self:commonAncestor(self.head, fromBranch)
		local ours = self.commits[self.branches[self.head]]
		local theirs = self.commits[self.branches[fromBranch]]
		if not theirs then return nil, "unknown branch" end
		local base = baseId and self.commits[baseId].tree or {}
		local merged, conflicts = self.merger.threeWay(base, ours and ours.tree or {}, theirs.tree)
		self.stats.merges = self.stats.merges + 1
		if #conflicts > 0 then
			self.stats.conflicts = self.stats.conflicts + #conflicts
			return nil, conflicts
		end
		self.workingTree = merged
		local id = self:commit(author or "merge", "merge " .. fromBranch .. " into " .. self.head)
		return id
	end

	function Workspace:resolveConflict(path, choice) return self.merger.resolve(path, choice) end

	function Workspace:revert(commitId)
		local c = self.commits[commitId]
		if not c then return false end
		self.workingTree = C.deepCopy(c.tree)
		return true
	end

	function Workspace:report()
		return { head = self.head, branches = C.count(self.branches), commits = self.stats.commits,
			session = self.session.stats(), merge = self.merger.stats(),
			comments = #self.comments, tasks = #self.tasks }
	end

	return Workspace

end
