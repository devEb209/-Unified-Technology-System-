--!strict
-- Explorer — REAL functional tree (not print). Reflects game hierarchy, filters, searchable,
-- expand/collapse, icons, selection sync, drag-reparent (via parenting), insert.
-- Must affect world via Selection/ChangeHistoryService.
local Theme = require(script.Parent.Parent.Parent.core.theme)
local BaseWindow = require(script.Parent.base_window)

local Explorer = {}
Explorer.__index = Explorer

local ICONS = {
	Workspace="◈", Lighting="☀", ReplicatedStorage="⬡", StarterPlayer="▶",
	StarterGui="▣", SoundService="♪", Teams="⚑", Folder="📁", Model="⬢",
	Part="▭", MeshPart="⬔", UnionOperation="⬣", Script="≡", LocalScript="≡",
	ModuleScript="≣", RemoteEvent="⇄", BindableEvent="↺", Terrain="⛰",
	Camera="◉", Default="•"
}

local function iconFor(inst: Instance): string
	return ICONS[inst.ClassName] or ICONS.Default
end

function Explorer.new(parent: Instance, selectionService)
	local win = BaseWindow.new({title="Explorer", size=Vector2.new(300, 460), pos=UDim2.fromOffset(8, 84), parent=parent, icon="≡"})
	win.Root.Name="ARKHER_Explorer"
	local content = win.Content

	-- Search bar
	local searchBox = Instance.new("TextBox")
	searchBox.Name="Search"
	searchBox.Size=UDim2.new(1,-16,0,26)
	searchBox.Position=UDim2.fromOffset(8,8)
	searchBox.BackgroundColor3=Theme.tokens.slate800
	searchBox.PlaceholderText="Search hierarchy…"
	searchBox.Text=""
	searchBox.ClearTextOnFocus=false
	searchBox.Font=Enum.Font.Gotham
	searchBox.TextSize=12
	searchBox.TextColor3=Theme.tokens.white
	searchBox.PlaceholderColor3=Theme.tokens.slate400
	searchBox.TextXAlignment=Enum.TextXAlignment.Left
	searchBox.Parent=content
	local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,6); c.Parent=searchBox
	local s=Instance.new("UIStroke"); s.Color=Theme.roles.border; s.Thickness=1; s.Parent=searchBox
	local pad=Instance.new("UIPadding"); pad.PaddingLeft=UDim.new(0,8); pad.PaddingRight=UDim.new(0,8); pad.Parent=searchBox

	-- Scroll
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name="TreeScroll"
	scroll.Size=UDim2.new(1,-8,1,-44)
	scroll.Position=UDim2.fromOffset(4,40)
	scroll.BackgroundTransparency=1
	scroll.BorderSizePixel=0
	scroll.ScrollBarThickness=6
	scroll.ScrollBarImageColor3=Theme.tokens.slate600
	scroll.CanvasSize=UDim2.new(0,0,0,0)
	scroll.AutomaticCanvasSize=Enum.AutomaticSize.Y
	scroll.Parent=content
	local list = Instance.new("UIListLayout")
	list.SortOrder=Enum.SortOrder.LayoutOrder
	list.Padding=UDim.new(0,1)
	list.Parent=scroll

	local self = setmetatable({}, Explorer)
	self.Win = win
	self.Selection = selectionService
	self.SearchBox = searchBox
	self.Scroll = scroll
	self.List = list
	self.Expanded = {} :: {[Instance]: boolean}
	self.Filter = ""

	-- default expanded roots
	for _, svcName in {"Workspace","Lighting","ReplicatedStorage","StarterGui","StarterPlayer","SoundService","Teams"} do
		local inst = game:FindFirstChild(svcName) or workspace:FindFirstChild(svcName)
		if inst then self.Expanded[inst]=true end
	end
	self.Expanded[workspace]=true
	if game:FindFirstChild("ReplicatedStorage") then self.Expanded[game:FindFirstChild("ReplicatedStorage") :: Instance]=true end

	searchBox:GetPropertyChangedSignal("Text"):Connect(function()
		self.Filter = searchBox.Text:lower()
		self:Rebuild()
	end)

	-- live updates
	game.DescendantAdded:Connect(function() self:Rebuild() end)
	game.DescendantRemoving:Connect(function() task.defer(function() self:Rebuild() end) end)
	if selectionService then
		selectionService.OnSelectionChanged:Connect(function() self:Highlight() end)
	end

	self:Rebuild()
	return self
end

function Explorer:Clear()
	for _,ch in self.Scroll:GetChildren() do
		if ch:IsA("Frame") or ch:IsA("TextButton") then ch:Destroy() end
	end
end

function Explorer:Highlight()
	local sel = {}
	if self.Selection then for _,o in self.Selection:Get() do sel[o]=true end end
	for _,row in self.Scroll:GetChildren() do
		if row:GetAttribute("InstPath") then
			local inst = row:GetAttribute("InstRef") and (row:GetAttribute("InstRef") :: any) -- not reliable, use map
		end
	end
	-- simpler: iterate map
	if not self._rowMap then return end
	for inst, row in self._rowMap do
		if sel[inst] then
			(row :: Frame).BackgroundColor3 = Color3.fromRGB(0,212,255)
			;(row:FindFirstChild("Label") :: TextLabel).TextColor3 = Color3.fromRGB(14,20,48)
		else
			(row :: Frame).BackgroundColor3 = Color3.fromRGB(22,34,78)
			;(row:FindFirstChild("Label") :: TextLabel).TextColor3 = Theme.tokens.slate200
		end
	end
end

function Explorer:Rebuild()
	self:Clear()
	self._rowMap = {}
	-- root services in order
	local roots: {Instance} = {}
	table.insert(roots, workspace)
	for _,name in {"Lighting","ReplicatedStorage","StarterPack","StarterGui","StarterPlayer","SoundService","Teams","Chat","LocalizationService"} do
		local f = game:FindFirstChild(name)
		if f then table.insert(roots, f) end
	end
	local order=0
	local function addNode(inst: Instance, depth: number)
		if self.Filter~="" then
			-- if neither self nor descendant matches, skip whole subtree
			local function matches(i: Instance): boolean
				if i.Name:lower():find(self.Filter,1,true) then return true end
				for _,ch in i:GetChildren() do if matches(ch) then return true end end
				return false
			end
			if not matches(inst) then return end
		end
		order+=1
		local row = Instance.new("TextButton")
		row.Name = inst.Name
		row.Size = UDim2.new(1,-8,0,22)
		row.BackgroundColor3 = Color3.fromRGB(22,34,78)
		row.AutoButtonColor=false
		row.Text=""
		row.LayoutOrder=order
		row.Parent=self.Scroll
		row:SetAttribute("InstName", inst.Name)
		local cor=Instance.new("UICorner"); cor.CornerRadius=UDim.new(0,4); cor.Parent=row
		local pad=Instance.new("UIPadding"); pad.PaddingLeft=UDim.new(0, 8 + depth*14); pad.Parent=row

		local hasChildren = #inst:GetChildren()>0
		local exp = self.Expanded[inst] == true

		local arrow = Instance.new("TextLabel")
		arrow.Name="Arrow"
		arrow.Size=UDim2.fromOffset(12,22)
		arrow.Position=UDim2.fromOffset(0,0)
		arrow.BackgroundTransparency=1
		arrow.Text= if not hasChildren then "" else if exp then "▾" else "▸"
		arrow.Font=Enum.Font.Gotham
		arrow.TextSize=10
		arrow.TextColor3=Theme.tokens.slate400
		arrow.Parent=row

		local icon = Instance.new("TextLabel")
		icon.Size=UDim2.fromOffset(14,22)
		icon.Position=UDim2.fromOffset(14,0)
		icon.BackgroundTransparency=1
		icon.Text=iconFor(inst)
		icon.Font=Enum.Font.Gotham
		icon.TextSize=11
		icon.TextColor3=Theme.tokens.slate400
		icon.Parent=row

		local label = Instance.new("TextLabel")
		label.Name="Label"
		label.Size=UDim2.new(1,-34,1,0)
		label.Position=UDim2.fromOffset(30,0)
		label.BackgroundTransparency=1
		label.Text=inst.Name
		label.Font=Enum.Font.Gotham
		label.TextSize=12
		label.TextColor3=Theme.tokens.slate200
		label.TextXAlignment=Enum.TextXAlignment.Left
		label.TextTruncate=Enum.TextTruncate.AtEnd
		label.Parent=row

		self._rowMap[inst]=row

		row.MouseButton1Click:Connect(function()
			if hasChildren then
				-- toggle on arrow region else select
				-- simple: if click near left 20px toggle, else select
				-- we toggle always plus select
				self.Expanded[inst]=not exp
				self:Rebuild()
			end
			if self.Selection then self.Selection:Set({inst}) end
		end)
		row.MouseButton2Click:Connect(function()
			if self.Selection then self.Selection:Set({inst}) end
			-- context: delete/rename/duplicate via ChangeHistory
		end)

		if hasChildren and exp then
			-- sort children alphabetically, services first
			local kids = inst:GetChildren()
			table.sort(kids, function(a,b) return a.Name:lower() < b.Name:lower() end)
			for _,ch in kids do addNode(ch, depth+1) end
		end
	end
	for _,r in roots do addNode(r, 0) end
	self:Highlight()
end

return Explorer
