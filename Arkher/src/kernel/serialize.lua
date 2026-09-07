-- ARKHER KERNEL :: Serialization
-- Deterministic JSON encoder/decoder plus a compact binary tagged format used for
-- project files, save games, network payloads and asset metadata.
--@arkher-module
return function(A)
	local Errors = A:import("arkher/kernel/errors")
	local Ser = {}

	------------------------------------------------------------------ JSON
	local function escape(s)
		s = string.gsub(s, "[\\\"]", "\\%0")
		s = string.gsub(s, "\n", "\\n")
		s = string.gsub(s, "\r", "\\r")
		s = string.gsub(s, "\t", "\\t")
		return s
	end

	local function isArray(t)
		local n = 0
		for k in pairs(t) do
			if type(k) ~= "number" then return false end
			n = n + 1
		end
		return n == #t
	end

	function Ser.encodeJSON(value, pretty, indent)
		indent = indent or ""
		local nl = pretty and "\n" or ""
		local pad = pretty and (indent .. "  ") or ""
		local t = type(value)
		if value == nil then return "null" end
		if t == "number" then
			if value ~= value or value == math.huge or value == -math.huge then return "null" end
			if value % 1 == 0 then return string.format("%d", value) end
			return string.format("%.10g", value)
		end
		if t == "boolean" then return tostring(value) end
		if t == "string" then return '"' .. escape(value) .. '"' end
		if t == "table" then
			if isArray(value) then
				if #value == 0 then return "[]" end
				local parts = {}
				for _, v in ipairs(value) do parts[#parts + 1] = pad .. Ser.encodeJSON(v, pretty, pad) end
				return "[" .. nl .. table.concat(parts, "," .. nl) .. nl .. indent .. "]"
			end
			local keys = {}
			for k in pairs(value) do keys[#keys + 1] = tostring(k) end
			table.sort(keys)
			if #keys == 0 then return "{}" end
			local parts = {}
			for _, k in ipairs(keys) do
				local v = value[k] ~= nil and value[k] or value[tonumber(k)]
				parts[#parts + 1] = pad .. '"' .. escape(k) .. '":' .. (pretty and " " or "") .. Ser.encodeJSON(v, pretty, pad)
			end
			return "{" .. nl .. table.concat(parts, "," .. nl) .. nl .. indent .. "}"
		end
		return "null"
	end

	function Ser.decodeJSON(str)
		local pos = 1
		local function skip()
			while pos <= #str do
				local c = string.sub(str, pos, pos)
				if c == " " or c == "\n" or c == "\t" or c == "\r" then pos = pos + 1 else break end
			end
		end
		local parseValue
		local function parseString()
			pos = pos + 1
			local buf = {}
			while pos <= #str do
				local c = string.sub(str, pos, pos)
				if c == '"' then pos = pos + 1 return table.concat(buf) end
				if c == "\\" then
					local n = string.sub(str, pos + 1, pos + 1)
					local map = { n = "\n", t = "\t", r = "\r", ['"'] = '"', ["\\"] = "\\", ["/"] = "/" }
					buf[#buf + 1] = map[n] or n
					pos = pos + 2
				else
					buf[#buf + 1] = c
					pos = pos + 1
				end
			end
			error(Errors.new(Errors.Codes.VALIDATION, "unterminated string in JSON"))
		end
		local function parseNumber()
			local s, e = string.find(str, "^-?%d+%.?%d*[eE]?[-+]?%d*", pos)
			local num = tonumber(string.sub(str, s, e))
			pos = e + 1
			return num
		end
		parseValue = function()
			skip()
			local c = string.sub(str, pos, pos)
			if c == "{" then
				pos = pos + 1
				local obj = {}
				skip()
				if string.sub(str, pos, pos) == "}" then pos = pos + 1 return obj end
				while true do
					skip()
					local k = parseString()
					skip()
					pos = pos + 1 -- ':'
					obj[k] = parseValue()
					skip()
					local ch = string.sub(str, pos, pos)
					pos = pos + 1
					if ch == "}" then return obj end
				end
			elseif c == "[" then
				pos = pos + 1
				local arr = {}
				skip()
				if string.sub(str, pos, pos) == "]" then pos = pos + 1 return arr end
				while true do
					arr[#arr + 1] = parseValue()
					skip()
					local ch = string.sub(str, pos, pos)
					pos = pos + 1
					if ch == "]" then return arr end
				end
			elseif c == '"' then return parseString()
			elseif string.sub(str, pos, pos + 3) == "true" then pos = pos + 4 return true
			elseif string.sub(str, pos, pos + 4) == "false" then pos = pos + 5 return false
			elseif string.sub(str, pos, pos + 3) == "null" then pos = pos + 4 return nil
			else return parseNumber() end
		end
		local ok, res = pcall(parseValue)
		if not ok then return nil, Errors.new(Errors.Codes.VALIDATION, "invalid JSON: " .. tostring(res)) end
		return res
	end

	------------------------------------------------------------------ Binary tagged format (ARKB)
	local TAG = { NIL = 0, FALSE = 1, TRUE = 2, INT = 3, FLOAT = 4, STR = 5, TABLE = 6, ARRAY = 7, END = 8 }

	local function writeVarint(buf, n)
		local v = math.floor(n)
		if v < 0 then v = v + 4294967296 end
		while true do
			local byte = v % 128
			v = v // 128
			if v > 0 then buf[#buf + 1] = string.char(byte + 128) else buf[#buf + 1] = string.char(byte) break end
		end
	end

	local function encodeValue(buf, v)
		local t = type(v)
		if v == nil then buf[#buf + 1] = string.char(TAG.NIL)
		elseif t == "boolean" then buf[#buf + 1] = string.char(v and TAG.TRUE or TAG.FALSE)
		elseif t == "number" then
			if v % 1 == 0 and math.abs(v) < 2 ^ 31 then
				buf[#buf + 1] = string.char(TAG.INT)
				writeVarint(buf, v)
			else
				buf[#buf + 1] = string.char(TAG.FLOAT)
				local s = string.format("%.17g", v)
				writeVarint(buf, #s)
				buf[#buf + 1] = s
			end
		elseif t == "string" then
			buf[#buf + 1] = string.char(TAG.STR)
			writeVarint(buf, #v)
			buf[#buf + 1] = v
		elseif t == "table" then
			local arr = isArray(v)
			buf[#buf + 1] = string.char(arr and TAG.ARRAY or TAG.TABLE)
			if arr then
				writeVarint(buf, #v)
				for _, item in ipairs(v) do encodeValue(buf, item) end
			else
				local keys = {}
				for k in pairs(v) do keys[#keys + 1] = k end
				table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
				writeVarint(buf, #keys)
				for _, k in ipairs(keys) do
					encodeValue(buf, k)
					encodeValue(buf, v[k])
				end
			end
		else
			buf[#buf + 1] = string.char(TAG.NIL)
		end
	end

	function Ser.encodeBinary(value)
		local buf = { "ARKB\1" }
		encodeValue(buf, value)
		return table.concat(buf)
	end

	function Ser.decodeBinary(data)
		if string.sub(data, 1, 4) ~= "ARKB" then return nil, Errors.new(Errors.Codes.VALIDATION, "not ARKB data") end
		local pos = 6
		local function readVarint()
			local result, shift = 0, 0
			while true do
				local b = string.byte(data, pos)
				pos = pos + 1
				result = result + ((b % 128) * (2 ^ shift))
				if b < 128 then break end
				shift = shift + 7
			end
			return result
		end
		local function readValue()
			local tag = string.byte(data, pos)
			pos = pos + 1
			if tag == TAG.NIL then return nil
			elseif tag == TAG.TRUE then return true
			elseif tag == TAG.FALSE then return false
			elseif tag == TAG.INT then
				local v = readVarint()
				if v >= 2 ^ 31 then v = v - 4294967296 end
				return v
			elseif tag == TAG.FLOAT then
				local n = readVarint()
				local s = string.sub(data, pos, pos + n - 1)
				pos = pos + n
				return tonumber(s)
			elseif tag == TAG.STR then
				local n = readVarint()
				local s = string.sub(data, pos, pos + n - 1)
				pos = pos + n
				return s
			elseif tag == TAG.ARRAY then
				local n = readVarint()
				local out = {}
				for i = 1, n do out[i] = readValue() end
				return out
			elseif tag == TAG.TABLE then
				local n = readVarint()
				local out = {}
				for _ = 1, n do
					local k = readValue()
					out[k] = readValue()
				end
				return out
			end
			return nil
		end
		local ok, res = pcall(readValue)
		if not ok then return nil, Errors.new(Errors.Codes.DATA_LOSS, tostring(res)) end
		return res
	end

	-- delta encoding for network/replication and undo stacks
	function Ser.diff(old, new)
		local d = { set = {}, del = {} }
		for k, v in pairs(new) do
			if type(v) == "table" and type(old[k]) == "table" then
				local sub = Ser.diff(old[k], v)
				if next(sub.set) or next(sub.del) then d.set[k] = sub end
			elseif old[k] ~= v then
				d.set[k] = v
			end
		end
		for k in pairs(old) do
			if new[k] == nil then d.del[#d.del + 1] = k end
		end
		return d
	end

	function Ser.applyDiff(target, d)
		for k, v in pairs(d.set or {}) do
			if type(v) == "table" and v.set ~= nil and v.del ~= nil then
				target[k] = target[k] or {}
				Ser.applyDiff(target[k], v)
			else
				target[k] = v
			end
		end
		for _, k in ipairs(d.del or {}) do target[k] = nil end
		return target
	end

	return Ser

end
