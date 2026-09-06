-- Reads the recovered library as inert data. Never requires or executes archived code.
-- SHA-256 is checked by the offline build validator; this reader checks structure, not cryptographic integrity.
local Archive = {}
Archive.__index = Archive

local function value(parent, name)
	local child = parent:FindFirstChild(name)
	assert(child and child:IsA("StringValue"), "missing archive value: " .. name)
	return child.Value
end

function Archive.new(folder, options)
	options = options or {}
	local decode = options.decode or function(text)
		return game:GetService("HttpService"):JSONDecode(text)
	end
	local manifest = decode(value(folder, "Manifest"))
	assert(manifest.format == "uts-source-archive/1", "unsupported archive format")
	local indexFolder = folder:FindFirstChild("Index")
	local pages = folder:FindFirstChild("Pages")
	assert(indexFolder and pages, "incomplete archive")
	local self = setmetatable({
		manifest = manifest, pages = pages, decode = decode,
		index = {}, cache = {}, order = {}, decodedPages = 0,
		cacheLimit = options.cachePages or 2,
	}, Archive)
	assert(type(self.cacheLimit) == "number" and self.cacheLimit % 1 == 0
		and self.cacheLimit >= 1 and self.cacheLimit <= 16, "cachePages must be 1..16")
	local indexes = indexFolder:GetChildren()
	table.sort(indexes, function(a, b) return a.Name < b.Name end)
	for _, chunk in ipairs(indexes) do
		assert(chunk:IsA("StringValue"), "invalid index chunk")
		for _, entry in ipairs(decode(chunk.Value)) do table.insert(self.index, entry) end
	end
	assert(#self.index == manifest.pages, "page index count mismatch")
	for i, entry in ipairs(self.index) do
		assert(type(entry.first) == "string" and entry.first <= entry.last, "invalid page bounds")
		if i > 1 then assert(self.index[i - 1].last <= entry.first, "unsorted page index") end
	end
	return self
end

function Archive:_page(entry)
	local result = self.cache[entry.name]
	if result then
		for i, name in ipairs(self.order) do
			if name == entry.name then table.remove(self.order, i); break end
		end
	else
		result = self.decode(value(self.pages, entry.name))
		assert(#result == entry.records, "page record count mismatch")
		self.decodedPages += 1
		self.cache[entry.name] = result
	end
	table.insert(self.order, entry.name)
	while #self.order > self.cacheLimit do
		self.cache[table.remove(self.order, 1)] = nil
	end
	return result
end

function Archive:_firstPage(path)
	local low, high = 1, #self.index
	while low <= high do
		local mid = math.floor((low + high) / 2)
		if self.index[mid].last < path then low = mid + 1 else high = mid - 1 end
	end
	return low
end

function Archive:Get(path)
	assert(type(path) == "string" and #path > 0, "path must be a non-empty string")
	local pieces, info, found = {}, nil, 0
	for i = self:_firstPage(path), #self.index do
		local entry = self.index[i]
		if entry.first > path then break end
		for _, record in ipairs(self:_page(entry)) do
			if record.path == path then
				if not info then
					assert(record.parts >= 1 and record.parts % 1 == 0, "invalid fragment count")
					info = { path = path, encoding = record.encoding, bytes = record.bytes,
						sha256 = record.sha256, parts = record.parts }
				end
				assert(record.parts == info.parts and record.sha256 == info.sha256
					and record.encoding == info.encoding and record.bytes == info.bytes, "inconsistent fragments")
				assert(record.part >= 1 and record.part <= info.parts and record.part % 1 == 0
					and not pieces[record.part], "invalid or duplicate fragment")
				pieces[record.part] = record.content
				found += 1
			end
		end
	end
	if not info then return nil, "not found" end
	assert(found == info.parts, "missing archive fragments")
	return table.concat(pieces), info
end

-- Paginated, lexicographically ordered listing. Use last returned path as 'after'.
function Archive:List(prefix, limit, after)
	prefix, limit, after = prefix or "", limit or 100, after or ""
	assert(type(prefix) == "string" and type(after) == "string", "invalid listing cursor")
	assert(type(limit) == "number" and limit % 1 == 0 and limit >= 1 and limit <= 1000, "limit must be 1..1000")
	local results = {}
	local start = if after > prefix then after else prefix
	for i = self:_firstPage(start), #self.index do
		for _, record in ipairs(self:_page(self.index[i])) do
			local path = record.path
			if path > after and path >= prefix and record.part == 1 then
				if string.sub(path, 1, #prefix) ~= prefix then return results end
				table.insert(results, { path = path, bytes = record.bytes, encoding = record.encoding, sha256 = record.sha256 })
				if #results == limit then return results end
			end
		end
	end
	return results
end

function Archive:ClearCache()
	table.clear(self.cache)
	table.clear(self.order)
end

function Archive:Stats()
	return { files = self.manifest.files, bytes = self.manifest.bytes, pages = #self.index,
		cachedPages = #self.order, decodedPages = self.decodedPages }
end

return Archive
