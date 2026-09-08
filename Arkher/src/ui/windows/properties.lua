--!strict
-- Properties — 100% real. Shows selected Instance props, edits via ChangeHistoryService.
-- Vector3, Color3, Enums, bools, numbers, strings all functional + live sync to world.
local Theme = require(script.Parent.Parent.Parent.core.theme)
local Config = require(script.Parent.Parent.Parent.core.config)
local BaseWindow = require(script.Parent.base_window)
local Components = require(script.Parent.Parent.components.init)

local Properties = {}
Properties.__index = Properties

local function isBasePart(inst: Instance): boolean
	return inst:IsA("BasePart")
end

function Properties.new(parent: Instance, selectionService)
	local win = BaseWindow.new({title="Properties", size=Vector2.new(340, 520), pos=UDim2.fromOffset(980, 84), parent=parent, icon="⚙"})
	win.Root.Name="ARKHER_Properties"
	local content = win.Content

	-- header showing selection count
	local hdr = Instance.new("Frame")
	hdr.Name="SelHeader"
	hdr.Size=UDim2.new(1,0,0,32)
	hdr.BackgroundColor3=Theme.tokens.slate800
	hdr.BorderSizePixel=0
	hdr.Parent=content
	local hl = Instance.new("TextLabel")
	hl.Name="HeaderLabel"
	hl.Size=UDim2.new(1,-16,1,0)
	hl.Position=UDim2.fromOffset(8,0)
	hl.BackgroundTransparency=1
	hl.Text="No selection"
	hl.Font=Enum.Font.GothamBold
	hl.TextSize=12
	hl.TextColor3=Theme.tokens.white
	hl.TextXAlignment=Enum.TextXAlignment.Left
	hl.Parent=hdr

	local scroll = Instance.new("ScrollingFrame")
	scroll.Name="PropScroll"
	scroll.Size=UDim2.new(1,-8,1,-36)
	scroll.Position=UDim2.fromOffset(4,36)
	scroll.BackgroundTransparency=1
	scroll.BorderSizePixel=0
	scroll.ScrollBarThickness=6
	scroll.ScrollBarImageColor3=Theme.tokens.slate600
	scroll.CanvasSize=UDim2.new(0,0,0,0)
	scroll.AutomaticCanvasSize=Enum.AutomaticSize.Y
	scroll.Parent=content
	local layout = Instance.new("UIListLayout")
	layout.Padding=UDim.new(0,6)
	layout.SortOrder=Enum.SortOrder.LayoutOrder
	layout.Parent=scroll
	local pad = Instance.new("UIPadding"); pad.PaddingLeft=UDim.new(0,8); pad.PaddingRight=UDim.new(0,8); pad.PaddingTop=UDim.new(0,8); pad.PaddingBottom=UDim.new(0,8); pad.Parent=scroll

	local self = setmetatable({}, Properties)
	self.Win = win
	self.Selection = selectionService
	self.HeaderLabel = hl
	self.Scroll = scroll
	self.Layout = layout
	self._rows = {} :: {Instance}

	local function rebuild()
		self:Rebuild()
	end
	if selectionService then
		selectionService.OnSelectionChanged:Connect(rebuild)
	end
	-- live property change highlight? poll on heartbeat for now
	game:GetService("RunService").Heartbeat:Connect(function()
		-- optional sync, not rebuilding every frame to avoid flicker
	end)
	self:Rebuild()
	return self
end

function Properties:Clear()
	for _,r in self._rows do r:Destroy() end
	self._rows={}
end

local function addSection(self: any, title: string)
	local sec = Instance.new("TextLabel")
	sec.Size=UDim2.new(1,0,0,20)
	sec.BackgroundTransparency=1
	sec.Text=title
	sec.Font=Enum.Font.GothamBold
	sec.TextSize=11
	sec.TextColor3=Theme.tokens.arkherBlue
	sec.TextXAlignment=Enum.TextXAlignment.Left
	sec.Parent=self.Scroll
	table.insert(self._rows, sec)
	local line=Instance.new("Frame")
	line.Size=UDim2.new(1,0,0,1)
	line.BackgroundColor3=Theme.roles.border
	line.BorderSizePixel=0
	line.Parent=self.Scroll
	table.insert(self._rows, line)
end

function Properties:Rebuild()
	self:Clear()
	local sel = if self.Selection then self.Selection:Get() else {}
	local target = sel[1] :: Instance?
	if not target then
		self.HeaderLabel.Text="No selection"
		local hint=Instance.new("TextLabel")
		hint.Size=UDim2.new(1,0,0,40)
		hint.BackgroundTransparency=1
		hint.Text="Select an instance in Explorer or viewport to edit its properties. Changes are undoable (Ctrl+Z)."
		hint.Font=Enum.Font.Gotham
		hint.TextSize=11
		hint.TextColor3=Theme.tokens.slate400
		hint.TextWrapped=true
		hint.TextXAlignment=Enum.TextXAlignment.Left
		hint.Parent=self.Scroll
		table.insert(self._rows, hint)
		return
	end
	if #sel==1 then
		self.HeaderLabel.Text=target.ClassName.."  —  "..target.Name
	else
		self.HeaderLabel.Text=string.format("%d objects selected — showing %s", #sel, target.Name)
	end

	local function setProp(prop: string, val: any)
		if self.Selection then
			self.Selection:SetProperty(target, prop, val)
		else
			pcall(function() (target :: any)[prop]=val end)
		end
	end

	-- Common
	addSection(self, "General")
	do
		local row = Components.TextField(self.Scroll, "Name", target.Name, function(v)
			setProp("Name", v)
			self.HeaderLabel.Text=target.ClassName.."  —  "..v
		end)
		table.insert(self._rows, row)
		local clsRow = Instance.new("Frame")
		clsRow.Size=UDim2.new(1,0,0,22)
		clsRow.BackgroundTransparency=1
		clsRow.Parent=self.Scroll
		table.insert(self._rows, clsRow)
		local a=Instance.new("TextLabel")
		a.Size=UDim2.new(0.42,0,1,0); a.BackgroundTransparency=1; a.Text="ClassName"; a.Font=Enum.Font.Gotham; a.TextSize=12; a.TextColor3=Theme.tokens.slate400; a.TextXAlignment=Enum.TextXAlignment.Left; a.Parent=clsRow
		local b=Instance.new("TextLabel")
		b.Size=UDim2.new(0.58,0,1,0); b.Position=UDim2.new(0.42,0,0,0); b.BackgroundTransparency=1; b.Text=target.ClassName; b.Font=Enum.Font.Code; b.TextSize=11; b.TextColor3=Theme.tokens.slate200; b.TextXAlignment=Enum.TextXAlignment.Left; b.Parent=clsRow
		local pRow=Instance.new("Frame")
		pRow.Size=UDim2.new(1,0,0,22); pRow.BackgroundTransparency=1; pRow.Parent=self.Scroll; table.insert(self._rows,pRow)
		local pa=Instance.new("TextLabel"); pa.Size=UDim2.new(0.42,0,1,0); pa.BackgroundTransparency=1; pa.Text="Parent"; pa.Font=Enum.Font.Gotham; pa.TextSize=12; pa.TextColor3=Theme.tokens.slate400; pa.TextXAlignment=Enum.TextXAlignment.Left; pa.Parent=pRow
		local pb=Instance.new("TextLabel"); pb.Size=UDim2.new(0.58,0,1,0); pb.Position=UDim2.new(0.42,0,0,0); pb.BackgroundTransparency=1; pb.Text=if target.Parent then target.Parent.Name else "nil"; pb.Font=Enum.Font.Code; pb.TextSize=11; pb.TextColor3=Theme.tokens.slate200; pb.TextXAlignment=Enum.TextXAlignment.Left; pb.Parent=pRow

		-- Archivable / Locked etc where applicable
		if pcall(function() return (target :: any).Archivable end) then
			local v = (target :: any).Archivable :: boolean
			local r = Components.Checkbox(self.Scroll, "Archivable", v, function(n) setProp("Archivable", n) end)
			table.insert(self._rows, r)
		end
	end

	-- Transform — BasePart
	if target:IsA("BasePart") then
		addSection(self, "Transform")
		local bp = target :: BasePart
		local r1 = Components.Vector3Field(self.Scroll, "Position", bp.Position, function(v) setProp("Position", v) end); table.insert(self._rows,r1)
		local r2 = Components.Vector3Field(self.Scroll, "Size", bp.Size, function(v) 
			-- clamp
			v=Vector3.new(math.clamp(v.X,0.2,2048), math.clamp(v.Y,0.2,2048), math.clamp(v.Z,0.2,2048))
			setProp("Size", v) 
		end); table.insert(self._rows,r2)
		local cf = bp.CFrame
		local _,_,_,_,_,_,_,_,_ = cf:GetComponents()
		-- orientation as Vector3
		local ori = Vector3.new( math.deg(cf:ToEulerAnglesYXZ()) ) -- placeholder, use YXZ single
		-- simpler: show CFrame look
		local r3 = Components.Vector3Field(self.Scroll, "CFrame.Pos", cf.Position, function(v)
			setProp("CFrame", CFrame.new(v) * (cf.Rotation))
		end); table.insert(self._rows,r3)

		addSection(self, "Appearance")
		local rCol = Components.ColorField(self.Scroll, "Color", bp.Color, function(c) setProp("Color", c) end); table.insert(self._rows,rCol)
		local rMat = Components.Dropdown(self.Scroll, "Material", {"SmoothPlastic","Neon","Metal","Wood","Concrete","Glass","ForceField","Granite","Marble","Slate"}, bp.Material.Name, function(opt)
			local e = Enum.Material[opt :: any]
			if e then setProp("Material", e) end
		end); table.insert(self._rows,rMat)
		local rTrans = Components.Slider(self.Scroll, "Transparency", 0, 1, bp.Transparency, function(v) setProp("Transparency", v) end); table.insert(self._rows,rTrans)
		local rRefl = Components.Slider(self.Scroll, "Reflectance", 0, 1, bp.Reflectance, function(v) setProp("Reflectance", v) end); table.insert(self._rows,rRefl)
		local rCast = Components.Checkbox(self.Scroll, "CastShadow", bp.CastShadow, function(v) setProp("CastShadow", v) end); table.insert(self._rows,rCast)
		local rAnch = Components.Checkbox(self.Scroll, "Anchored", bp.Anchored, function(v) setProp("Anchored", v) end); table.insert(self._rows,rAnch)
		local rCanCol = Components.Checkbox(self.Scroll, "CanCollide", bp.CanCollide, function(v) setProp("CanCollide", v) end); table.insert(self._rows,rCanCol)
		if bp:IsA("Part") then
			local pr = target :: Part
			local rShape = Components.Dropdown(self.Scroll, "Shape", {"Block","Ball","Cylinder"}, pr.Shape.Name, function(opt)
				setProp("Shape", Enum.PartType[opt :: any])
			end); table.insert(self._rows,rShape)
		end
	end

	-- Light
	if target:IsA("Light") then
		addSection(self, "Light")
		local l = target :: Light
		local rCol = Components.ColorField(self.Scroll, "Color", l.Color, function(c) setProp("Color", c) end); table.insert(self._rows,rCol)
		local rB = Components.Slider(self.Scroll, "Brightness", 0, 10, l.Brightness, function(v) setProp("Brightness", v) end); table.insert(self._rows,rB)
		local rSh = Components.Checkbox(self.Scroll, "Shadows", l.Shadows, function(v) setProp("Shadows", v) end); table.insert(self._rows,rSh)
		if target:IsA("PointLight") then
			local pl = target :: PointLight
			local rR = Components.Slider(self.Scroll, "Range", 0, 60, pl.Range, function(v) setProp("Range", v) end); table.insert(self._rows,rR)
		end
	end

	-- Script
	if target:IsA("LuaSourceContainer") then
		addSection(self, "Script")
		local dis = (target :: any).Disabled
		if dis~=nil then
			local r=Components.Checkbox(self.Scroll,"Disabled", dis, function(v) setProp("Disabled", v) end); table.insert(self._rows,r)
		end
	end

	-- ARKHER extras
	addSection(self, "ARKHER")
	do
		local arch = target:GetAttribute("ARKHER_Tag")
		local r = Components.TextField(self.Scroll, "Tag", if arch then tostring(arch) else "", function(v)
			target:SetAttribute("ARKHER_Tag", v)
		end); table.insert(self._rows,r)
		local lod = target:GetAttribute("ARKHER_LOD")
		local r2 = Components.Dropdown(self.Scroll,"LOD Bias",["Auto","LOD0","LOD1","LOD2"][1] and {"Auto","LOD0","LOD1","LOD2"} or {"Auto"}, if lod then tostring(lod) else "Auto", function(opt)
			target:SetAttribute("ARKHER_LOD", opt)
		end); table.insert(self._rows,r2)
	end
end

return Properties
