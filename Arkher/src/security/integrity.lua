-- ARKHER SECURITY :: Integrity, Recovery and Anti-Corruption
-- Checksums for project/asset data, transactional state snapshots, corruption
-- detection and automatic recovery to the last known-good state.
--@arkher-module
return function(A)
	local Hash = A:import("arkher/kernel/hash")
	local Ser = A:import("arkher/kernel/serialize")
	local C = A:import("arkher/kernel/containers")
	local Integrity = {}
	Integrity.__index = Integrity

	function Integrity.new(opts)
		opts = opts or {}
		local self = setmetatable({}, Integrity)
		self.checkpoints = {}
		self.maxCheckpoints = opts.maxCheckpoints or 16
		self.records = {}
		self.stats = { checks = 0, failures = 0, recoveries = 0, checkpoints = 0 }
		return self
	end

	function Integrity:sign(id, data)
		local payload = Ser.encodeBinary(data)
		local sig = { id = id, crc = Hash.crc32(payload), size = #payload, content = Hash.contentId(data) }
		self.records[id] = sig
		return sig
	end

	function Integrity:verify(id, data)
		self.stats.checks = self.stats.checks + 1
		local rec = self.records[id]
		if not rec then return false, "no signature recorded" end
		local payload = Ser.encodeBinary(data)
		local crc = Hash.crc32(payload)
		if crc ~= rec.crc then
			self.stats.failures = self.stats.failures + 1
			return false, string.format("checksum mismatch (expected %08x got %08x)", rec.crc, crc)
		end
		return true
	end

	function Integrity:checkpoint(label, state)
		local snap = { label = label, state = C.deepCopy(state), signature = self:sign("checkpoint:" .. label, state) }
		self.checkpoints[#self.checkpoints + 1] = snap
		self.stats.checkpoints = self.stats.checkpoints + 1
		if #self.checkpoints > self.maxCheckpoints then table.remove(self.checkpoints, 1) end
		return snap
	end

	function Integrity:lastGood()
		for i = #self.checkpoints, 1, -1 do
			local cp = self.checkpoints[i]
			local ok = self:verify("checkpoint:" .. cp.label, cp.state)
			if ok then return cp end
		end
		return nil
	end

	function Integrity:recover()
		local cp = self:lastGood()
		if not cp then return nil, "no valid checkpoint" end
		self.stats.recoveries = self.stats.recoveries + 1
		return C.deepCopy(cp.state), cp.label
	end

	-- transactional apply: mutate a copy, validate, then commit or roll back
	function Integrity:transaction(state, mutate, validate)
		local working = C.deepCopy(state)
		local ok, err = pcall(mutate, working)
		if not ok then return state, false, tostring(err) end
		if validate then
			local valid, reason = validate(working)
			if not valid then return state, false, reason or "validation failed" end
		end
		return working, true
	end

	function Integrity:scan(collection)
		local issues = {}
		for id, data in pairs(collection) do
			local ok, reason = self:verify(id, data)
			if not ok then issues[#issues + 1] = { id = id, reason = reason } end
		end
		return #issues == 0, issues
	end

	function Integrity:report() return { stats = self.stats, checkpoints = #self.checkpoints, signed = C.count(self.records) } end

	return Integrity

end
