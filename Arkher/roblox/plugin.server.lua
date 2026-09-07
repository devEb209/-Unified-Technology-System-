--!nolint
-- ARKHER V1 :: ARKHER STUDIO plugin host (Roblox Studio adapter)
--
-- IMPORTANT: ARKHER is NOT a Roblox Studio plugin. ARKHER is its own engine + IDE.
-- This file is only the ADAPTER that lets the real ARKHER Studio runtime
-- (src/studio/editor.lua, src/studio/viewport.lua, src/code/*, src/collab/*) drive a
-- Roblox Studio session. Every command below is executed by ARKHER itself; Studio is
-- used purely as a display surface and as a place-persistence backend.
--
-- Install: Releases/ARKHER_V1_STUDIO_PLUGIN.rbxmx -> right click in Explorer ->
-- "Save as Local Plugin...", or drop the file in your Plugins folder.

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local Selection = game:GetService("Selection")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--------------------------------------------------------------------- 1. loader
local ROOT = script:FindFirstChild("ARKHER")
if not ROOT then
	warn("[ARKHER] plugin payload missing (no ARKHER folder under the plugin script)")
	return
end

local factories = {}
local function walk(instance, prefix)
	for _, child in ipairs(instance:GetChildren()) do
		local path = prefix == "" and child.Name or (prefix .. "/" .. child.Name)
		if child:IsA("ModuleScript") then
			factories[path] = child
		elseif child:IsA("Folder") or child:IsA("Configuration") then
			walk(child, path)
		end
	end
end
walk(ROOT, "arkher")

local loaderModule = factories["arkher/kernel/loader"]
if not loaderModule then
	warn("[ARKHER] kernel loader missing from the plugin payload")
	return
end

local A = require(loaderModule)(nil).new({ timeFn = os.clock })
local registered = 0
for id, moduleScript in pairs(factories) do
	A:define(id, require(moduleScript))
	registered = registered + 1
end

--------------------------------------------------------------------- 2. runtime
local Engine = A:import("arkher/engine")
local Editor = A:import("arkher/studio/editor")
local Viewport = A:import("arkher/studio/viewport")
local Intelligence = A:import("arkher/code/intelligence")
local VisualScript = A:import("arkher/code/visualscript")
local Workspace_ = A:import("arkher/collab/workspace")
local BuildSvc = A:import("arkher/collab/build")
local Vec = A:import("arkher/kernel/vec")

local engine = Engine.boot(A, { logLevel = 30 })
local t0 = os.clock()
local loaded, failed = engine:loadCatalog()
local bootMs = (os.clock() - t0) * 1000

local editor = Editor.new({ projectName = game.Name })
local viewport = Viewport.new({ width = 1280, height = 720 })
local intelligence = Intelligence.new({})
local project = Workspace_.new({ initial = { objects = {} } })
local builder = BuildSvc.new({})
project:join("studio.user", "editor")

_G.ARKHER = engine
_G.ARKHER_STUDIO = { editor = editor, viewport = viewport, intelligence = intelligence,
	project = project, build = builder, loader = A }

--------------------------------------------------------------------- 3. ui shell
local toolbar = plugin:CreateToolbar("ARKHER")
local openButton = toolbar:CreateButton("ARKHER Studio",
	"Open the ARKHER Studio surface inside Roblox Studio", "rbxasset://textures/StudioToolbox/Explorer.png")
local verifyButton = toolbar:CreateButton("Verify",
	"Run every ARKHER system self-test", "rbxasset://textures/StudioToolbox/Search.png")
local installButton = toolbar:CreateButton("Install Runtime",
	"Copy the ARKHER runtime into ReplicatedStorage of this place", "rbxasset://textures/StudioToolbox/Insert.png")

local widget = plugin:CreateDockWidgetPluginGui("ARKHER_STUDIO_V1",
	DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Right, false, false, 420, 620, 320, 420))
widget.Title = "ARKHER V1"
widget.Name = "ARKHER_STUDIO_V1"

-- Colours below mirror arkher/ui/theme ("arkher-dark"), the single source of truth.
local BG = Color3.fromRGB(18, 20, 26)
local PANEL = Color3.fromRGB(26, 29, 38)
local ACCENT = Color3.fromRGB(96, 176, 255)
local TEXT = Color3.fromRGB(215, 225, 240)  -- theme.text
local MUTED = Color3.fromRGB(148, 163, 184)

local root = Instance.new("Frame")
root.Size = UDim2.fromScale(1, 1)
root.BackgroundColor3 = BG
root.BorderSizePixel = 0
root.Parent = widget

local function label(parent, text, size, pos, color, bold)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = size
	l.Position = pos
	l.Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
	l.TextSize = bold and 14 or 12
	l.TextColor3 = color or TEXT
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextYAlignment = Enum.TextYAlignment.Top
	l.RichText = true
	l.Text = text
	l.Parent = parent
	return l
end

local function button(parent, text, pos, size, fn)
	local b = Instance.new("TextButton")
	b.Size = size
	b.Position = pos
	b.BackgroundColor3 = PANEL
	b.BorderSizePixel = 0
	b.Font = Enum.Font.GothamMedium
	b.TextSize = 12
	b.TextColor3 = TEXT
	b.Text = text
	b.AutoButtonColor = true
	b.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = b
	b.MouseButton1Click:Connect(fn)
	return b
end

local header = label(root, "", UDim2.new(1, -20, 0, 58), UDim2.fromOffset(10, 8), TEXT, true)
local search = Instance.new("TextBox")
search.Size = UDim2.new(1, -20, 0, 26)
search.Position = UDim2.fromOffset(10, 70)
search.BackgroundColor3 = PANEL
search.BorderSizePixel = 0
search.Font = Enum.Font.Gotham
search.TextSize = 12
search.TextColor3 = TEXT
search.PlaceholderText = "filter systems (e.g. studio.viewport, do15, merge)"
search.Text = ""
search.ClearTextOnFocus = false
search.Parent = root
local searchCorner = Instance.new("UICorner")
searchCorner.CornerRadius = UDim.new(0, 6)
searchCorner.Parent = search

local list = Instance.new("ScrollingFrame")
list.Size = UDim2.new(1, -20, 1, -240)
list.Position = UDim2.fromOffset(10, 104)
list.BackgroundColor3 = PANEL
list.BorderSizePixel = 0
list.ScrollBarThickness = 6
list.CanvasSize = UDim2.new()
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.Parent = root
local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 2)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = list
local listPad = Instance.new("UIPadding")
listPad.PaddingTop = UDim.new(0, 4)
listPad.PaddingLeft = UDim.new(0, 6)
listPad.Parent = list

local output = label(root, "", UDim2.new(1, -20, 0, 96), UDim2.new(0, 10, 1, -128), MUTED)
output.TextWrapped = true

--------------------------------------------------------------------- 4. state
local report = engine:report()
local function refreshHeader(extra)
	header.Text = string.format(
		"<b>ARKHER %s</b>  %s\n%d systems online   B=%d U=%d Y=%d A=%d S=%d X=%d\n%s",
		report.version, report.generation, report.systems,
		report.byCategory.B or 0, report.byCategory.U or 0, report.byCategory.Y or 0,
		report.byCategory.A or 0, report.byCategory.S or 0, report.byCategory.X or 0,
		extra or string.format("%d modules registered - boot %.0f ms - %d load failures", registered, bootMs, failed))
end
refreshHeader()

local function log(text)
	output.Text = text
	print("[ARKHER] " .. text)
end

local rows = {}
local function renderList(filter)
	for _, r in ipairs(rows) do r:Destroy() end
	rows = {}
	local shown = 0
	for i, sys in ipairs(engine.systems) do
		local key = sys.key or ""
		if filter == "" or string.find(string.lower(key .. " " .. (sys.name or "")), string.lower(filter), 1, true) then
			shown = shown + 1
			if shown <= 200 then
				local row = Instance.new("TextButton")
				row.Size = UDim2.new(1, -12, 0, 20)
				row.BackgroundTransparency = 1
				row.Font = Enum.Font.Code
				row.TextSize = 11
				row.TextColor3 = shown % 2 == 0 and TEXT or MUTED
				row.TextXAlignment = Enum.TextXAlignment.Left
				row.Text = string.format("%s  %s", sys.id or "----", key)
				row.LayoutOrder = i
				row.Parent = list
				row.MouseButton1Click:Connect(function()
					local inst = engine.registry[key]
					if not inst then log("system not instantiated: " .. key) return end
					local ok, err = inst.selfTest()
					local health = inst.health()
					log(string.format("%s\nkit=%s  features=%d  status=%s  selfTest=%s%s",
						key, sys.kit or "?", #(sys.features or {}), health.status,
						ok and "PASS" or "FAIL", ok and "" or (" (" .. tostring(err) .. ")")))
				end)
				rows[#rows + 1] = row
			end
		end
	end
	return shown
end
renderList("")
search:GetPropertyChangedSignal("Text"):Connect(function()
	local shown = renderList(search.Text)
	refreshHeader(string.format("%d systems match \"%s\" (showing first 200)", shown, search.Text))
end)

--------------------------------------------------------------------- 5. commands
local function verifyAll()
	local start = os.clock()
	local result = engine:verify()
	local ms = (os.clock() - start) * 1000
	log(string.format("self-test: %d passed / %d failed of %d in %.0f ms",
		result.passed, result.failed, result.total, ms))
	for i = 1, math.min(5, #result.failures) do
		warn("[ARKHER] " .. result.failures[i].key .. " -> " .. tostring(result.failures[i].error))
	end
end

local function installRuntime()
	local existing = ReplicatedStorage:FindFirstChild("ARKHER")
	if existing then existing:Destroy() end
	local clone = ROOT:Clone()
	clone.Parent = ReplicatedStorage
	local boot = clone:FindFirstChild("ARKHER_Boot")
	if not boot then
		log("runtime copied to ReplicatedStorage.ARKHER (add ARKHER_Boot from the model release to auto-start)")
	else
		log("runtime installed: ReplicatedStorage.ARKHER (" .. registered .. " modules)")
	end
end

-- import the current Studio selection into the ARKHER document model
local function importSelection()
	local n = 0
	for _, obj in ipairs(Selection:Get()) do
		if obj:IsA("BasePart") then
			editor:run("object.create", {
				id = obj:GetFullName(),
				position = { obj.Position.X, obj.Position.Y, obj.Position.Z },
				size = { obj.Size.X, obj.Size.Y, obj.Size.Z },
			})
			project:edit("studio.user", "objects." .. obj.Name, { size = obj.Size.Magnitude })
			n = n + 1
		end
	end
	log(string.format("imported %d parts into the ARKHER document (%d objects, revision %d)",
		n, editor:objectCount(), editor.document.revision))
end

-- ARKHER Universal Transform Framework drives the Studio selection
local function snapSelection()
	local recording = ChangeHistoryService:TryBeginRecording("ARKHER Snap")
	local n = 0
	for _, obj in ipairs(Selection:Get()) do
		if obj:IsA("BasePart") then
			viewport.snap.translate = 1
			local snapped = viewport:applySnap(Vec.vec3(obj.Position.X, obj.Position.Y, obj.Position.Z), "translate")
			obj.Position = Vector3.new(snapped.x, snapped.y, snapped.z)
			n = n + 1
		end
	end
	if recording then ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit) end
	log(string.format("ARKHER Universal Transform Framework snapped %d parts to the %.1f stud grid",
		n, viewport.snap.translate))
end

-- ARKHER code intelligence over every Script in the place
local function analyzeScripts()
	local files = 0
	for _, obj in ipairs(game:GetDescendants()) do
		if obj:IsA("LuaSourceContainer") and not obj:IsDescendantOf(script) then
			local ok, source = pcall(function() return obj.Source end)
			if ok and source and #source > 0 then
				intelligence:index(obj:GetFullName(), source)
				files = files + 1
				if files >= 200 then break end
			end
		end
	end
	if files == 0 then log("no readable scripts found in this place") return end
	local result = intelligence:analyzeAll()
	local metrics = intelligence:projectMetrics()
	log(string.format("code intelligence: %d files, %d lines, %d symbols\n%d errors, %d warnings, %d hints - avg complexity %.1f",
		files, metrics.lines, metrics.symbols, result.errors, result.warnings,
		result.hints, metrics.averageComplexity))
end

-- D-O15 pass over the current place
local function optimizePlace()
	local findings, plan = engine:optimize()
	local lines = {}
	for i = 1, math.min(4, #plan.steps) do lines[#lines + 1] = "- " .. tostring(plan.steps[i]) end
	log(string.format("D-O15: %d findings, quality level %.2f\n%s",
		#findings, engine.do15.controller.level, table.concat(lines, "\n")))
end

-- production pipeline (collab/build) over the current project state
local function runPipeline()
	builder:standardPipeline({ name = game.Name, version = "1.0.0", assetCount = #game:GetDescendants(),
		fileCount = 0, testsPassed = 0, testsFailed = 0, assetBytes = 0, channel = "studio" })
	local r = builder:run()
	log(string.format("build pipeline: %d tasks executed, %d cache hits, error=%s",
		#r.executed, r.cacheHits or 0, tostring(r.error)))
end

local function commitProject()
	local id = project:commit("studio.user", "studio checkpoint")
	local rep = project:report()
	log(string.format("committed %s on branch %s (%d commits, %d branches)",
		tostring(id), rep.head, rep.commits, rep.branches))
end

--------------------------------------------------------------------- 6. wiring
local W = 0.5
button(root, "Verify all", UDim2.new(0, 10, 1, -226), UDim2.new(W, -14, 0, 24), verifyAll)
button(root, "Optimize (D-O15)", UDim2.new(W, 4, 1, -226), UDim2.new(W, -14, 0, 24), optimizePlace)
button(root, "Import selection", UDim2.new(0, 10, 1, -198), UDim2.new(W, -14, 0, 24), importSelection)
button(root, "Snap selection", UDim2.new(W, 4, 1, -198), UDim2.new(W, -14, 0, 24), snapSelection)
button(root, "Analyze scripts", UDim2.new(0, 10, 1, -170), UDim2.new(W, -14, 0, 24), analyzeScripts)
button(root, "Run pipeline", UDim2.new(W, 4, 1, -170), UDim2.new(W, -14, 0, 24), runPipeline)
button(root, "Commit project", UDim2.new(0, 10, 1, -142), UDim2.new(W, -14, 0, 24), commitProject)
button(root, "Install runtime", UDim2.new(W, 4, 1, -142), UDim2.new(W, -14, 0, 24), installRuntime)

openButton.Click:Connect(function() widget.Enabled = not widget.Enabled end)
verifyButton.Click:Connect(verifyAll)
installButton.Click:Connect(installRuntime)

log(string.format("ARKHER V1 ready: %d systems, %d modules, boot %.0f ms. Studio is an adapter - the engine is ARKHER.",
	report.systems, registered, bootMs))
