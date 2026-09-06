local function eq(a, b) assert(a == b, tostring(a) .. " ~= " .. tostring(b)) end
local function throws(callback) local ok = pcall(callback); assert(not ok, "expected failure") end
local function test(name, callback)
	local ok, err = pcall(callback)
	assert(ok, name .. ": " .. tostring(err))
	recordPass(name)
end

-- Small instance test double. This exercises logic, not Roblox's binary importer or engine APIs.
local methods, meta = {}, {}
function methods:IsA(class)
	if class == "Instance" or class == self._class then return true end
	if class == "BaseScript" then return self._class == "Script" or self._class == "LocalScript" end
	if class == "BasePart" then return self._class == "Part" or self._class == "MeshPart" end
	if class == "Light" then return self._class == "PointLight" or self._class == "SpotLight" end
	return false
end
function methods:GetChildren() return table.clone(self._children) end
function methods:FindFirstChild(name)
	for _, child in ipairs(self._children) do if child.Name == name then return child end end
	return nil
end
function methods:GetDescendants()
	local results = {}
	for _, child in ipairs(self._children) do
		table.insert(results, child)
		for _, descendant in ipairs(child:GetDescendants()) do table.insert(results, descendant) end
	end
	return results
end
function methods:IsDescendantOf(other)
	local current = self.Parent
	while current do if current == other then return true end; current = current.Parent end
	return false
end
meta.__index = function(self, key)
	if key == "Parent" then return rawget(self, "_parent") end
	if methods[key] then return methods[key] end
	return self._properties[key]
end
meta.__newindex = function(self, key, value)
	if key == "Parent" then
		if value and self._rejectParent == value then error("simulated parent write failure") end
		if value == self or (value and value:IsDescendantOf(self)) then error("cycle") end
		local old = rawget(self, "_parent")
		if old then
			for i, child in ipairs(old._children) do if child == self then table.remove(old._children, i); break end end
		end
		rawset(self, "_parent", value)
		if value then table.insert(value._children, self) end
	else self._properties[key] = value end
end
local function inst(class, name, parent)
	local item = setmetatable({ _class = class, _children = {}, _properties = { Name = name, Value = "", Disabled = false } }, meta)
	item.Parent = parent
	return item
end
local function services()
	local root = inst("DataModel", "game")
	return { ServerStorage = inst("ServerStorage", "ServerStorage", root),
		ReplicatedStorage = inst("ReplicatedStorage", "ReplicatedStorage", root), Workspace = inst("Workspace", "Workspace", root) }
end
local function marker(root, name, value) local item = inst("StringValue", name, root); item.Value = value; return item end
local function packageFor(s, kind, suffix)
	kind, suffix = kind or "UTS", suffix or ""
	local root = inst("Model", kind .. suffix .. "_IMPORT", s.Workspace)
	marker(root, "PackageKind", kind); marker(root, "PackageFormat", "uts-recovery/1")
	local payload = inst("Folder", "Payload", root)
	local storage = inst("Folder", "ServerStorage", payload)
	local shared = inst("Folder", "ReplicatedStorage", payload)
	local library = inst("Folder", kind .. "_Archive" .. suffix, storage)
	local runtime = inst("Folder", kind .. suffix, shared)
	return root, library, runtime, payload
end

-- Scheduler
test("scheduler completes real callbacks", function()
	local queue, count = Scheduler.new(), 0
	queue:Add("work", function() count += 1; return true end)
	local report = queue:Step(); eq(count, 1); eq(report.completed, 1); eq(queue:Count(), 0)
end)
test("scheduler bounded capacity and cancellation", function()
	local queue = Scheduler.new({ capacity = 1 })
	queue:Add("one", function() return false end)
	throws(function() queue:Add("two", function() end) end)
	assert(queue:Cancel("one")); eq(queue:Count(), 0); assert(not queue:Cancel("missing"))
	for _ = 1, 2000 do queue:Add("one", function() end); queue:Cancel("one") end
	eq(#queue.queue, 0)
end)
test("scheduler rejects duplicate ids and nonfinite inputs", function()
	local queue = Scheduler.new(); queue:Add("a", function() end)
	throws(function() queue:Add("a", function() end) end)
	throws(function() Scheduler.new({ budgetSeconds = 0 / 0 }) end)
	throws(function() Scheduler.new({ budgetSeconds = math.huge }) end)
	throws(function() Scheduler.new({ capacity = 1.5 }) end)
end)
test("scheduler uses per-step budget and rotates work", function()
	local now, trace = 0, {}
	local queue = Scheduler.new({ clock = function() return now end, budgetSeconds = 0.002 })
	queue:Add("a", function() table.insert(trace, "a"); now += 0.003; return false end)
	queue:Add("b", function() table.insert(trace, "b"); return true end)
	eq(queue:Step().processed, 1); eq(trace[1], "a")
	queue:Step(); eq(trace[2], "b")
end)
test("scheduler contains callback failures", function()
	local queue = Scheduler.new(); queue:Add("bad", function() error("expected") end)
	local report = queue:Step(); eq(#report.errors, 1); eq(queue:Count(), 0)
end)
test("scheduler processes each repeating task at most once per step", function()
	local queue, count = Scheduler.new(), 0
	queue:Add("repeat", function() count += 1; return false end)
	queue:Step(); eq(count, 1); queue:Step(); eq(count, 2)
end)
test("scheduler enforces maximum callbacks and avoids recursive Step", function()
	local queue = Scheduler.new({ maxPerStep = 1 })
	queue:Add("a", function() throws(function() queue:Step() end); return true end)
	queue:Add("b", function() return true end)
	eq(queue:Step().processed, 1); eq(queue:Count(), 1)
end)
test("scheduler callback may cancel and replace itself safely", function()
	local queue, count = Scheduler.new(), 0
	queue:Add("a", function()
		queue:Cancel("a"); queue:Add("a", function() count += 1; return true end); return false
	end)
	queue:Step(); eq(queue:Count(), 1); queue:Step(); eq(count, 1); eq(queue:Count(), 0)
end)

-- Organizer
test("organizer preview is non-mutating", function()
	local s = services(); local root, lib, runtime = packageFor(s)
	local o = Organizer.new(s); local old = lib.Parent; local plan = o:Plan({ root })
	assert(plan.canApply); eq(plan.count, 2); eq(lib.Parent, old); eq(#s.ReplicatedStorage:GetChildren(), 0)
	throws(function() plan.count = 10 end)
end)
test("organizer requires explicit confirmation", function()
	local s = services(); local root, lib = packageFor(s); local old = lib.Parent
	local o = Organizer.new(s); assert(not o:Apply(o:Plan({ root }))); eq(lib.Parent, old)
end)
test("organizer routes library to ServerStorage and runtime to ReplicatedStorage", function()
	local s = services(); local root, lib, runtime = packageFor(s); local o = Organizer.new(s)
	local plan = o:Plan({ root }); local ok, receipt = o:Apply(plan, true)
	assert(ok); eq(receipt.count, 2); eq(lib.Parent, s.ServerStorage); eq(runtime.Parent, s.ReplicatedStorage)
	assert(not o:Apply(plan, true)); eq(o:Plan({ root }).count, 0)
end)
test("organizer undo restores exact original parents", function()
	local s = services(); local root, lib, runtime = packageFor(s)
	local fromA, fromB = lib.Parent, runtime.Parent; local o = Organizer.new(s)
	local ok, receipt = o:Apply(o:Plan({ root }), true); assert(ok)
	assert(o:Undo(receipt, true)); eq(lib.Parent, fromA); eq(runtime.Parent, fromB); assert(not o:Undo(receipt, true))
end)
test("organizer refuses existing destination names without overwrites", function()
	local s = services(); local root, lib = packageFor(s); local old = lib.Parent
	local existing = inst("Folder", "UTS", s.ReplicatedStorage)
	local o = Organizer.new(s); local plan = o:Plan({ root }); assert(not plan.canApply)
	assert(not o:Apply(plan, true)); eq(lib.Parent, old); eq(existing.Parent, s.ReplicatedStorage)
end)
test("organizer rejects conflicts between selected imports", function()
	local s = services(); local a = packageFor(s); local b = packageFor(s)
	local o = Organizer.new(s); assert(not o:Plan({ a, b }).canApply)
end)
test("organizer duplicate selection is idempotent", function()
	local s = services(); local root = packageFor(s); eq(Organizer.new(s):Plan({ root, root }).count, 2)
end)
test("organizer supports UTS and Arkhe in one transaction", function()
	local s = services(); local a = packageFor(s, "UTS"); local b = packageFor(s, "ARKHE")
	local o = Organizer.new(s); local plan = o:Plan({ a, b }); eq(plan.count, 4); assert(o:Apply(plan, true))
end)
test("organizer rejects unmarked imports and unknown services", function()
	local s = services(); local wrong = inst("Model", "other", s.Workspace)
	local o = Organizer.new(s); assert(not o:Plan({ wrong }).canApply)
	local root, _, _, payload = packageFor(s); inst("Folder", "Lighting", payload)
	assert(not o:Plan({ root }).canApply)
end)
test("organizer refuses active scripts", function()
	local s = services(); local root, _, runtime = packageFor(s); inst("Script", "Unexpected", runtime)
	assert(not Organizer.new(s):Plan({ root }).canApply)
end)
test("organizer rejects stale source names and new active scripts", function()
	local s = services(); local root, lib, runtime = packageFor(s); local o = Organizer.new(s)
	local plan = o:Plan({ root }); lib.Name = "changed"; assert(not o:Apply(plan, true))
	lib.Name = "UTS_Archive"; plan = o:Plan({ root }); inst("LocalScript", "late", runtime)
	assert(not o:Apply(plan, true))
end)
test("organizer preflights destination races before moving anything", function()
	local s = services(); local root, lib = packageFor(s); local original = lib.Parent; local o = Organizer.new(s)
	local plan = o:Plan({ root }); inst("Folder", "UTS", s.ReplicatedStorage)
	assert(not o:Apply(plan, true)); eq(lib.Parent, original)
end)
test("organizer rolls prior moves back after parent-write failure", function()
	local s = services(); local root, lib, runtime = packageFor(s)
	local originalA, originalB = lib.Parent, runtime.Parent; runtime._rejectParent = s.ReplicatedStorage
	local o = Organizer.new(s); local ok, message = o:Apply(o:Plan({ root }), true)
	assert(not ok); assert(string.find(message, "restored")); eq(lib.Parent, originalA); eq(runtime.Parent, originalB)
end)
test("organizer reports failed rollback rather than claiming success", function()
	local s = services(); local root, lib, runtime = packageFor(s)
	lib._rejectParent = lib.Parent; runtime._rejectParent = s.ReplicatedStorage
	local o = Organizer.new(s); local ok, message = o:Apply(o:Plan({ root }), true)
	assert(not ok); assert(string.find(message, "ROLLBACK FAILED"))
end)
test("organizer undo refuses externally edited installations", function()
	local s = services(); local root, lib = packageFor(s); local o = Organizer.new(s)
	local ok, receipt = o:Apply(o:Plan({ root }), true); assert(ok); lib.Name = "user-change"
	assert(not o:Undo(receipt, true)); eq(lib.Parent, s.ServerStorage)
end)
test("organizer rejects forged plans and receipts", function()
	local o = Organizer.new(services()); assert(not o:Apply({}, true)); assert(not o:Undo({}, true))
end)
test("organizer detects a destination container added after preview", function()
	local s = services(); local root, lib, _, payload = packageFor(s); local old = lib.Parent
	local o = Organizer.new(s); local plan = o:Plan({ root }); inst("Folder", "Lighting", payload)
	assert(not o:Apply(plan, true)); eq(lib.Parent, old)
end)
test("organizer retains installation when an undo write fails", function()
	local s = services(); local root, lib, runtime = packageFor(s); local from = lib.Parent
	local o = Organizer.new(s); local ok, receipt = o:Apply(o:Plan({ root }), true); assert(ok)
	lib._rejectParent = from; assert(not o:Undo(receipt, true))
	eq(lib.Parent, s.ServerStorage); eq(runtime.Parent, s.ReplicatedStorage)
	lib._rejectParent = nil; assert(o:Undo(receipt, true)); eq(lib.Parent, from)
end)

-- Packed source reader with injected JSON decoder. Real serialized JSON is validated independently by Python.
local function archiveFixture(cache)
	local root = inst("Folder", "Archive")
	local index = inst("Folder", "Index", root); local pages = inst("Folder", "Pages", root)
	marker(root, "Manifest", "manifest"); marker(index, "000001", "index")
	local function record(path, content, part, count, bytes)
		return { path = path, content = content, part = part, parts = count, bytes = bytes, sha256 = path, encoding = "utf-8" }
	end
	local data = {
		manifest = { format = "uts-source-archive/1", files = 2, bytes = 9, pages = 3 },
		index = { { name = "000001", first = "a.txt", last = "a.txt", records = 1 },
			{ name = "000002", first = "a.txt", last = "a.txt", records = 1 },
			{ name = "000003", first = "b.txt", last = "b.txt", records = 1 } },
		["000001"] = { record("a.txt", "hel", 1, 2, 5) },
		["000002"] = { record("a.txt", "lo", 2, 2, 5) },
		["000003"] = { record("b.txt", "beta", 1, 1, 4) },
	}
	for i = 1, 3 do local name = string.format("%06d", i); marker(pages, name, name) end
	local reader = Archive.new(root, { cachePages = cache or 1, decode = function(text) return data[text] end })
	return reader, data
end
test("archive is lazy and joins fragments exactly", function()
	local reader = archiveFixture(); eq(reader:Stats().decodedPages, 0)
	local content, info = reader:Get("a.txt"); eq(content, "hello"); eq(info.bytes, 5); eq(reader:Stats().cachedPages, 1)
end)
test("archive missing lookup and LRU cache are bounded", function()
	local reader = archiveFixture(); eq(reader:Get("zzz.txt"), nil); eq(reader:Stats().decodedPages, 0)
	reader:Get("b.txt"); local decoded = reader:Stats().decodedPages; reader:Get("b.txt")
	eq(reader:Stats().decodedPages, decoded); reader:ClearCache(); eq(reader:Stats().cachedPages, 0)
end)
test("archive pagination is ordered and has no duplicate fragments", function()
	local reader = archiveFixture(); local first = reader:List("", 1); eq(#first, 1); eq(first[1].path, "a.txt")
	local nextPage = reader:List("", 1, first[1].path); eq(nextPage[1].path, "b.txt")
	eq(#reader:List("a", 100), 1); eq(#reader:List("none", 100), 0)
end)
test("archive validates pagination limits", function()
	local reader = archiveFixture(); throws(function() reader:List("", 0) end); throws(function() reader:List("", 1001) end)
end)
test("archive rejects missing or duplicated fragments", function()
	local reader, data = archiveFixture(); data["000002"][1].part = 1
	throws(function() reader:Get("a.txt") end)
end)

-- Visual profile and scene inventory
local function lighting()
	local result = {}; for name, value in pairs(Profile.Describe().properties) do result[name] = if type(value) == "number" then value + 1 else not value end
	return result
end
test("visual profile requires opt-in and can restore", function()
	local light = lighting(); local old = table.clone(light)
	assert(not Profile.Apply(light)); assert(Profile.Apply(light, true)); eq(light.EnvironmentSpecularScale, 1)
	assert(not Profile.Apply(light, true)); assert(Profile.Restore(light, true))
	for name, value in pairs(old) do eq(light[name], value) end
end)
test("visual profile never writes engine-protected style settings", function()
	local config = Profile.Describe().properties
	eq(config.LightingStyle, nil); eq(config.PrioritizeLightingQuality, nil); eq(config.Technology, nil)
end)
test("visual profile refuses to overwrite external changes on restore", function()
	local light = lighting(); assert(Profile.Apply(light, true)); light.Brightness = 99
	assert(not Profile.Restore(light, true)); eq(light.Brightness, 99)
end)
test("scene audit counts actual instances without claiming physical systems", function()
	local root = inst("Model", "Scene"); local mesh = inst("MeshPart", "Mesh", root); mesh.Anchored = true
	inst("SurfaceAppearance", "PBR", mesh); local part = inst("Part", "Dynamic", root); part.Anchored = false
	local light = inst("PointLight", "Light", part); light.Enabled = true; light.Shadows = true
	local report = Audit.Inspect(root); eq(report.parts, 2); eq(report.unanchoredParts, 1)
	eq(report.meshParts, 1); eq(report.pbrSurfaces, 1); eq(report.shadowLights, 1); eq(report.instances, 5)
end)
