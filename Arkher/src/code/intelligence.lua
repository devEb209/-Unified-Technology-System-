-- ARKHER CODE :: Code Intelligence Service
-- Project-wide indexing, diagnostics, completion, refactoring, dependency analysis and
-- documentation generation over ARKHER/Luau sources. Built on the `source` kit.
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local C = A:import("arkher/kernel/containers")
	local Hash = A:import("arkher/kernel/hash")
	local Intelligence = {}
	Intelligence.__index = Intelligence

	function Intelligence.new(opts)
		opts = opts or {}
		local self = setmetatable({}, Intelligence)
		self.files = {}
		self.symbolIndex = {}
		self.dependencies = {}
		self.diagnostics = {}
		self.rules = {}
		self.maxNesting = opts.maxNesting or 6
		self.stats = { indexed = 0, analyses = 0, completions = 0, refactors = 0 }
		self:installDefaultRules()
		return self
	end

	function Intelligence:installDefaultRules()
		self.rules["no-global-write"] = function(src)
			local issues = {}
			for i, tok in ipairs(src.tokens) do
				if tok.type == "identifier" and src.tokens[i + 1] and src.tokens[i + 1].value == "="
					and (i == 1 or (src.tokens[i - 1].type ~= "keyword" and src.tokens[i - 1].value ~= "."
						and src.tokens[i - 1].value ~= "," and src.tokens[i - 1].value ~= ":")) then
					local prev = src.tokens[i - 1]
					if not prev or (prev.value ~= "local" and prev.value ~= ")" and prev.value ~= "]" and prev.value ~= "end") then
						issues[#issues + 1] = { severity = "info", message = "possible global assignment '" .. tok.value .. "'", line = tok.line }
					end
				end
			end
			return issues
		end
		self.rules["long-function"] = function(src)
			local issues = {}
			local openLine = nil
			local depth = 0
			for _, tok in ipairs(src.tokens) do
				if tok.type == "keyword" then
					if tok.value == "function" then
						if depth == 0 then openLine = tok.line end
						depth = depth + 1
					elseif tok.value == "if" or tok.value == "for" or tok.value == "while" or tok.value == "do" then
						depth = depth + 1
					elseif tok.value == "end" then
						depth = depth - 1
						if depth == 0 and openLine and (tok.line - openLine) > 120 then
							issues[#issues + 1] = { severity = "warning",
								message = string.format("function spans %d lines", tok.line - openLine), line = openLine }
						end
					end
				end
			end
			return issues
		end
		self.rules["magic-number"] = function(src)
			local issues = {}
			local count = 0
			for _, tok in ipairs(src.tokens) do
				if tok.type == "number" and #tok.value > 4 then count = count + 1 end
			end
			if count > 30 then
				issues[#issues + 1] = { severity = "info", message = count .. " large numeric literals; consider a config table" }
			end
			return issues
		end
		return C.count(self.rules)
	end

	function Intelligence:index(path, text)
		local src = Kits.source({ text = text, maxNesting = self.maxNesting })
		src.tokenize()
		src.extractSymbols()
		for id, fn in pairs(self.rules) do src.addRule(id, fn) end
		self.files[path] = { source = src, hash = Hash.crc32(text), path = path }
		self.stats.indexed = self.stats.indexed + 1
		for _, sym in ipairs(src.symbols) do
			self.symbolIndex[sym.name] = self.symbolIndex[sym.name] or {}
			table.insert(self.symbolIndex[sym.name], { path = path, line = sym.line, kind = sym.kind })
		end
		-- dependency extraction: A:import("...") and A:import("...")
		local deps = {}
		for dep in string.gmatch(text, 'import%("([^"]+)"%)') do deps[#deps + 1] = dep end
		for dep in string.gmatch(text, 'require%("([^"]+)"%)') do deps[#deps + 1] = dep end
		self.dependencies[path] = deps
		return src
	end

	function Intelligence:analyze(path)
		self.stats.analyses = self.stats.analyses + 1
		local file = self.files[path]
		if not file then return nil, "not indexed" end
		local diags = file.source.analyze()
		self.diagnostics[path] = diags
		return diags
	end

	function Intelligence:analyzeAll()
		local total, errors, warnings, hints = 0, 0, 0, 0
		local worst = nil
		for path in pairs(self.files) do
			local diags = self:analyze(path)
			total = total + #diags
			for _, d in ipairs(diags) do
				if d.severity == "error" then errors = errors + 1
				elseif d.severity == "warning" then warnings = warnings + 1
				else hints = hints + 1 end
			end
			if not worst or #diags > worst.count then worst = { path = path, count = #diags } end
		end
		return { diagnostics = total, errors = errors, warnings = warnings, hints = hints,
			files = C.count(self.files), worst = worst }
	end

	function Intelligence:complete(path, prefix)
		self.stats.completions = self.stats.completions + 1
		local file = self.files[path]
		local out = file and file.source.complete(prefix) or {}
		for name, locations in pairs(self.symbolIndex) do
			if string.sub(name, 1, #prefix) == prefix and (not file or #out < 64) then
				out[#out + 1] = { label = name, kind = "project", detail = locations[1].path }
			end
		end
		table.sort(out, function(a, b) return a.label < b.label end)
		return out
	end

	function Intelligence:definitionOf(name)
		local hits = self.symbolIndex[name]
		if not hits or #hits == 0 then return nil end
		return hits[1]
	end

	function Intelligence:referencesOf(name)
		local out = {}
		for path, file in pairs(self.files) do
			for _, tok in ipairs(file.source.tokens) do
				if tok.type == "identifier" and tok.value == name then
					out[#out + 1] = { path = path, line = tok.line }
				end
			end
		end
		table.sort(out, function(a, b) return a.path == b.path and a.line < b.line or a.path < b.path end)
		return out
	end

	function Intelligence:rename(path, oldName, newName)
		self.stats.refactors = self.stats.refactors + 1
		local file = self.files[path]
		if not file then return 0 end
		local count, text = file.source.rename(oldName, newName)
		self:index(path, text)
		return count, text
	end

	function Intelligence:dependencyGraph()
		local nodes, edges = {}, 0
		for path, deps in pairs(self.dependencies) do
			nodes[path] = true
			edges = edges + #deps
			for _, d in ipairs(deps) do nodes[d] = true end
		end
		return { nodes = C.count(nodes), edges = edges, map = self.dependencies }
	end

	function Intelligence:unusedSymbols()
		local out = {}
		for name, locations in pairs(self.symbolIndex) do
			local refs = self:referencesOf(name)
			if #refs <= #locations then out[#out + 1] = { name = name, definedAt = locations[1] } end
		end
		table.sort(out, function(a, b) return a.name < b.name end)
		return out
	end

	function Intelligence:generateDocs(path)
		local file = self.files[path]
		if not file then return nil end
		local lines = { "# " .. path, "" }
		local m = file.source.metrics()
		lines[#lines + 1] = string.format("lines: %d · tokens: %d · complexity: %d · symbols: %d",
			m.lines, m.tokens, m.complexity, m.symbols)
		lines[#lines + 1] = ""
		lines[#lines + 1] = "## API"
		for _, sym in ipairs(file.source.symbols) do
			if sym.kind == "function" then lines[#lines + 1] = string.format("* `%s` (line %d)", sym.name, sym.line) end
		end
		return table.concat(lines, "\n")
	end

	function Intelligence:projectMetrics()
		local total = { lines = 0, tokens = 0, complexity = 0, symbols = 0, files = 0, comments = 0 }
		for _, file in pairs(self.files) do
			local m = file.source.metrics()
			total.lines = total.lines + m.lines
			total.tokens = total.tokens + m.tokens
			total.complexity = total.complexity + m.complexity
			total.symbols = total.symbols + m.symbols
			total.comments = total.comments + m.comments
			total.files = total.files + 1
		end
		total.commentRatio = total.comments / math.max(1, total.lines)
		total.averageComplexity = total.complexity / math.max(1, total.files)
		total.linesPerFile = total.lines / math.max(1, total.files)
		return total
	end

	function Intelligence:report()
		return { files = C.count(self.files), symbols = C.count(self.symbolIndex),
			rules = C.count(self.rules), metrics = self:projectMetrics(), stats = self.stats }
	end

	return Intelligence

end
