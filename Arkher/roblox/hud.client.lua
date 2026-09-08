--!strict
-- ARKHER Studio V2 HUD — real functional Studio (no fake viewport)
-- Mounts TopBar, Explorer, Properties, Output, Status, Singularity (single button), Gizmos, Fly, primitive inserts, maps, editors
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Selection = game:GetService("Selection")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Wait for ARKHER modules (rojo)
local ARKHER = ReplicatedStorage:WaitForChild("ARKHER")
local Theme = require(ARKHER.core.theme)
local Config = require(ARKHER.core.config)

local BaseWindow = require(ARKHER.ui.windows.base_window)
local TopBar = require(ARKHER.ui.windows.topbar)
local Explorer = require(ARKHER.ui.windows.explorer)
local Properties = require(ARKHER.ui.windows.properties)
local StatusBar = require(ARKHER.ui.windows.status_bar)
local OutputWin = require(ARKHER.ui.windows.output)
local SingularityChat = require(ARKHER.ui.windows.singularity_chat)
local LoadingScreen = require(ARKHER.ui.windows.loading_screen)
local GeneratedPalette = require(ARKHER.ui.windows.generated_palette)

local SelectionService = require(ARKHER.systems.selection_service)
local InsertService = require(ARKHER.systems.insert_service)
local FlyCamera = require(ARKHER.systems.fly_camera)
local Gizmo = require(ARKHER.systems.gizmo)
local WorldMap = require(ARKHER.maps.world_map)

-- Editors
local Modeler = require(ARKHER.editors.modeler)
local Animator = require(ARKHER.editors.animator)
local Material = require(ARKHER.editors.material)
local TerrainEd = require(ARKHER.editors.terrain)
local VFXEd = require(ARKHER.editors.vfx)
local SculptEd = require(ARKHER.editors.sculpt)
local AudioEd = require(ARKHER.editors.audio)
local SequencerEd = require(ARKHER.editors.sequencer)
local AssetBrowser = require(ARKHER.editors.asset_browser)

-- Root ScreenGui
local gui = Instance.new("ScreenGui")
gui.Name = "ARKHER_Studio"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

-- Root container (under TopBar)
local root = Instance.new("Frame")
root.Name = "Root"
root.Size = UDim2.fromScale(1,1)
root.BackgroundColor3 = Theme.tokens.void
root.BorderSizePixel = 0
root.Parent = gui

-- Loading
local loading = LoadingScreen.new(root)
loading:SetProgress(0.15, "Boot ARKHER core…")
task.wait(0.2)
loading:SetProgress(0.35, "Explorer ↔ Properties (live)…")
task.wait(0.15)
loading:SetProgress(0.55, "Gizmos + Fly…")
task.wait(0.15)
loading:SetProgress(0.78, "Singularity Core (Puter.js)…")
task.wait(0.15)
loading:SetProgress(0.92, "Maps & Biomes…")

-- Services
local selSvc = SelectionService.new()
local insertSvc = InsertService.new(selSvc)
local fly = FlyCamera.new()
local gizmo = Gizmo.new(selSvc)

-- TopBar
local editorWins = {} :: {[string]: any}
local mapWin: any = nil
local chatWin: any = nil
local paletteWin: any = nil
local generatedCache = {} :: {[string]: any}

-- create windows first so callbacks can reference them
local explorerWin = Explorer.new(root, selSvc)
local propsWin = Properties.new(root, selSvc)
local outputWin = OutputWin.new(root)
local status = StatusBar.new(root)
mapWin = WorldMap.new(root)
chatWin = SingularityChat.new(root)

-- Editors
editorWins["Modeler"] = Modeler.new(root)
editorWins["Animator"] = Animator.new(root)
editorWins["Material"] = Material.new(root)
editorWins["Terrain"] = TerrainEd.new(root)
editorWins["VFX"] = VFXEd.new(root)
editorWins["Sculpt"] = SculptEd.new(root)
editorWins["Audio"] = AudioEd.new(root)
editorWins["Sequencer"] = SequencerEd.new(root)
editorWins["Assets"] = AssetBrowser.new(root)
-- also allow "Maps" via mapWin

local function openGenerated(id: string)
	if generatedCache[id] then
		generatedCache[id]:Toggle()
		return
	end
	local genFolder = ARKHER:FindFirstChild("generated")
	if genFolder and genFolder:FindFirstChild(id) then
		local mod = require(genFolder[id])
		local win = mod.new(root)
		generatedCache[id]=win
		win:Toggle()
		outputWin:Log("Opened "..id.." — unique functional UI", Theme.tokens.arkherBlue)
		status:SetText(id.." opened — functional")
	else
		outputWin:Log("Generated "..id.." not found", Theme.tokens.ember)
	end
end

local function log(msg: string, col: Color3?)
	outputWin:Log(msg, col)
end

-- palette (needs openGenerated)
paletteWin = GeneratedPalette.new(root, openGenerated)

local top = TopBar.new(root, {
	onToggleExplorer = function()
		explorerWin.Win:Toggle()
		log("Explorer toggled", Theme.tokens.slate400)
	end,
	onToggleProperties = function()
		propsWin.Win:Toggle()
		log("Properties toggled", Theme.tokens.slate400)
	end,
	onInsert = function(shape: string)
		local inst = insertSvc:Part(shape)
		log("Inserted "..shape.." → "..inst.Name.." (undoable)", Theme.tokens.aurora)
		status:SetText("Inserted "..shape.." — selected")
	end,
	onGizmo = function(mode: string)
		gizmo:SetMode(mode)
		log("Gizmo: "..mode, Theme.tokens.arkherBlue)
		status:SetText("Gizmo "..mode)
	end,
	onToggleFly = function()
		local on = fly:Toggle()
		log("Fly "..(on and "ON (RMB drag + WASD Q/E Shift)" or "OFF"), Theme.tokens.arkherBlue)
		status:SetText("Fly "..(on and "ON" or "OFF"))
	end,
	onOpenMaps = function()
		mapWin:Toggle()
		log("World Maps toggled (Mapbox/OSM/ESA 11 + 32 biomes)", Theme.tokens.teal)
	end,
	onOpenSingularity = function()
		chatWin:Toggle()
		log("Singularity Core toggled", Theme.tokens.violet)
	end,
	onOpenEditor = function(name: string)
		-- Terrain maps to TerrainEd, etc
		local key = name
		if name=="Maps" then mapWin:Toggle(); return end
		if name=="Terrain" then editorWins["Terrain"].Win:Toggle()
		elseif editorWins[key] then editorWins[key]:Toggle()
		else
			log("Editor "..name.." not found", Theme.tokens.ember)
			return
		end
		log(name.." toggled", Theme.tokens.arkherBlue)
	end,
	onOpenPalette = function()
		paletteWin:Toggle()
		log("Palette 332 opened — search any ARKHER_V1_*", Theme.tokens.arkherGlow)
	end,
})

-- Wire gizmo refresh on selection
selSvc.OnSelectionChanged:Connect(function()
	gizmo:Refresh()
	local sel = selSvc:Get()
	if #sel==1 then status:SetText("Selected: "..sel[1].Name.." ("..sel[1].ClassName..")")
	elseif #sel>1 then status:SetText(#sel.." selected")
	else status:SetText("No selection") end
end)

-- Keyboard shortcuts
local UIS = game:GetService("UserInputService")
UIS.InputBegan:Connect(function(input, gp)
	if gp then return end
	if input.KeyCode==Enum.KeyCode.F and not UIS:IsKeyDown(Enum.KeyCode.LeftControl) and not UIS:IsKeyDown(Enum.KeyCode.RightControl) then
		local on = fly:Toggle()
		log("Fly "..(on and "ON" or "OFF").." [F]", Theme.tokens.arkherBlue)
	end
	if input.KeyCode==Enum.KeyCode.Delete then
		local sel = selSvc:Get()
		if #sel>0 then
			ChangeHistoryService:SetWaypoint("Before Delete")
			for _,inst in sel do
				pcall(function() inst.Parent=nil end)
			end
			ChangeHistoryService:SetWaypoint("Delete")
			selSvc:Clear()
			log("Deleted "..#sel.." instance(s)", Theme.tokens.ember)
		end
	end
end)

loading:SetProgress(1, "Ready — Explorer ↔ Properties live, gizmos & fly active")
log("ARKHER Studio V2 ready — Explorer ↔ Properties functional, primitive parts submenu, gizmos, fly preserved. Singularity: single ◆ button.", Theme.tokens.arkherGlow)
status:SetText("Ready — Explorer ↔ Properties live • Insert via TopBar • Gizmo: Select/Move/Rotate/Scale • Fly: F or button • ◆ Singularity")

-- Ensure Explorer/Properties start visible
explorerWin.Win.Root.Visible = true
propsWin.Win.Root.Visible = true
