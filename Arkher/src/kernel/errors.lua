-- ARKHER KERNEL :: Error System
-- Structured, coded, recoverable errors with context chains.
--@arkher-module
return function(A)
	local Errors = {}

	Errors.Codes = {
		OK = 0, UNKNOWN = 1, INVALID_ARGUMENT = 2, NOT_FOUND = 3, ALREADY_EXISTS = 4,
		PERMISSION_DENIED = 5, RESOURCE_EXHAUSTED = 6, FAILED_PRECONDITION = 7,
		ABORTED = 8, OUT_OF_RANGE = 9, UNIMPLEMENTED = 10, INTERNAL = 11,
		UNAVAILABLE = 12, DATA_LOSS = 13, TIMEOUT = 14, CYCLE = 15, VALIDATION = 16,
		BUDGET_EXCEEDED = 17, SANDBOX_VIOLATION = 18, VERSION_MISMATCH = 19, DEPENDENCY = 20,
	}

	local ErrorMT = {}
	ErrorMT.__index = ErrorMT
	ErrorMT.__tostring = function(e)
		local s = "[ARKHER:" .. tostring(e.codeName) .. "] " .. tostring(e.message)
		if e.source then s = s .. " (" .. tostring(e.source) .. ")" end
		if e.cause then s = s .. "\n  caused by: " .. tostring(e.cause) end
		return s
	end

	local codeNames = {}
	for name, v in pairs(Errors.Codes) do codeNames[v] = name end

	function Errors.new(code, message, ctx)
		local e = setmetatable({}, ErrorMT)
		e.__arkherError = true
		e.code = code or Errors.Codes.UNKNOWN
		e.codeName = codeNames[e.code] or "UNKNOWN"
		e.message = message or "unspecified error"
		e.context = ctx or {}
		e.source = ctx and ctx.source or nil
		e.time = ctx and ctx.time or 0
		e.recoverable = true
		return e
	end

	function Errors.is(v) return type(v) == "table" and v.__arkherError == true end

	function Errors.wrap(err, code, message, ctx)
		local e = Errors.new(code, message, ctx)
		e.cause = err
		return e
	end

	function Errors.fatal(code, message, ctx)
		local e = Errors.new(code, message, ctx)
		e.recoverable = false
		return e
	end

	-- protected call returning (ok, valueOrError) with structured errors
	function Errors.try(fn, ...)
		local results = table.pack(pcall(fn, ...))
		if results[1] then
			return true, table.unpack(results, 2, results.n)
		end
		local err = results[2]
		if Errors.is(err) then return false, err end
		return false, Errors.new(Errors.Codes.INTERNAL, tostring(err))
	end

	function Errors.assert(cond, code, message, ctx)
		if not cond then error(Errors.new(code, message, ctx), 2) end
		return cond
	end

	return Errors

end
