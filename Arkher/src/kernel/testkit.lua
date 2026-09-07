-- ARKHER KERNEL :: Test Kit
-- The test runner ARKHER uses in CI (headless) and inside Roblox Studio (plugin).
--@arkher-module
return function(A)
	local C = A:import("arkher/kernel/containers")
	local TestKit = {}
	TestKit.__index = TestKit

	function TestKit.new(opts)
		opts = opts or {}
		local self = setmetatable({}, TestKit)
		self.suites = {}
		self.current = nil
		self.results = { passed = 0, failed = 0, skipped = 0, assertions = 0, failures = {} }
		self.verbose = opts.verbose ~= false
		self.printer = opts.printer or print
		return self
	end

	function TestKit:describe(name, fn)
		local suite = { name = name, tests = {} }
		self.suites[#self.suites + 1] = suite
		self.current = suite
		fn(self)
		self.current = nil
		return self
	end

	function TestKit:it(name, fn)
		if not self.current then error("it() outside describe()") end
		self.current.tests[#self.current.tests + 1] = { name = name, fn = fn }
	end

	function TestKit:skip(name) 
		if self.current then self.current.tests[#self.current.tests + 1] = { name = name, skip = true } end
	end

	local A = {}
	A.__index = A
	function TestKit:assert()
		local kit = self
		return setmetatable({ kit = kit }, A)
	end
	function A:ok(cond, msg)
		self.kit.results.assertions = self.kit.results.assertions + 1
		if not cond then error("expected truthy: " .. tostring(msg or ""), 2) end
	end
	function A:equal(a, b, msg)
		self.kit.results.assertions = self.kit.results.assertions + 1
		if a ~= b then error(string.format("expected %s == %s %s", tostring(a), tostring(b), tostring(msg or "")), 2) end
	end
	function A:near(a, b, eps, msg)
		self.kit.results.assertions = self.kit.results.assertions + 1
		eps = eps or 1e-6
		if math.abs(a - b) > eps then error(string.format("expected %.8f ~= %.8f (eps %.8f) %s", a, b, eps, tostring(msg or "")), 2) end
	end
	function A:deepEqual(a, b, msg)
		self.kit.results.assertions = self.kit.results.assertions + 1
		if not C.deepEqual(a, b) then error("tables not deep-equal " .. tostring(msg or ""), 2) end
	end
	function A:isType(v, t, msg)
		self.kit.results.assertions = self.kit.results.assertions + 1
		if type(v) ~= t then error(string.format("expected type %s got %s %s", t, type(v), tostring(msg or "")), 2) end
	end
	function A:throws(fn, msg)
		self.kit.results.assertions = self.kit.results.assertions + 1
		local ok = pcall(fn)
		if ok then error("expected function to throw " .. tostring(msg or ""), 2) end
	end
	function A:gt(a, b, msg)
		self.kit.results.assertions = self.kit.results.assertions + 1
		if not (a > b) then error(string.format("expected %s > %s %s", tostring(a), tostring(b), tostring(msg or "")), 2) end
	end
	function A:gte(a, b, msg)
		self.kit.results.assertions = self.kit.results.assertions + 1
		if not (a >= b) then error(string.format("expected %s >= %s %s", tostring(a), tostring(b), tostring(msg or "")), 2) end
	end
	function A:lt(a, b, msg)
		self.kit.results.assertions = self.kit.results.assertions + 1
		if not (a < b) then error(string.format("expected %s < %s %s", tostring(a), tostring(b), tostring(msg or "")), 2) end
	end

	function TestKit:run()
		local t0 = os and os.clock and os.clock() or 0
		for _, suite in ipairs(self.suites) do
			local suiteFailed = 0
			for _, test in ipairs(suite.tests) do
				if test.skip then
					self.results.skipped = self.results.skipped + 1
				else
					local ok, err = pcall(test.fn, self:assert())
					if ok then
						self.results.passed = self.results.passed + 1
					else
						self.results.failed = self.results.failed + 1
						suiteFailed = suiteFailed + 1
						self.results.failures[#self.results.failures + 1] = { suite = suite.name, test = test.name, error = tostring(err) }
					end
				end
			end
			if self.verbose then
				local status = suiteFailed == 0 and "PASS" or "FAIL"
				self.printer(string.format("  [%s] %-52s %d tests", status, suite.name, #suite.tests))
			end
		end
		self.results.durationMs = ((os and os.clock and os.clock() or 0) - t0) * 1000
		return self.results
	end

	function TestKit:report()
		local r = self.results
		self.printer("")
		self.printer(string.format("ARKHER TESTS  passed=%d failed=%d skipped=%d assertions=%d  (%.1f ms)",
			r.passed, r.failed, r.skipped, r.assertions, r.durationMs or 0))
		for _, f in ipairs(r.failures) do
			self.printer(string.format("  FAIL %s :: %s\n       %s", f.suite, f.test, f.error))
		end
		return r.failed == 0
	end

	return TestKit

end
