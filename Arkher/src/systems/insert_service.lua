--!strict
-- InsertService — primitive parts + models, with HistoryService
local InsertService = {}
InsertService.__index = InsertService

function InsertService.new(selectionService)
	local self = setmetatable({}, InsertService)
	self.sel = selectionService
	self.history = game:GetService("ChangeHistoryService")
	return self
end

local function place(part: BasePart)
	part.Anchored = true
	local cam = workspace.CurrentCamera
	if cam then part.CFrame = cam.CFrame * CFrame.new(0,0,-12) end
	part.Parent = workspace
end

function InsertService:Part(shape: string)
	self.history:SetWaypoint("Before Insert "..shape)
	local p: BasePart
	if shape=="Block" then p=Instance.new("Part"); p.Shape=Enum.PartType.Block
	elseif shape=="Sphere" then p=Instance.new("Part"); p.Shape=Enum.PartType.Ball
	elseif shape=="Cylinder" then p=Instance.new("Part"); p.Shape=Enum.PartType.Cylinder
	elseif shape=="Wedge" then p=Instance.new("WedgePart")
	elseif shape=="CornerWedge" then p=Instance.new("CornerWedgePart")
	else p=Instance.new("Part") end
	p.Name=shape
	p.Size=Vector3.new(4,4,4)
	p.Material=Enum.Material.SmoothPlastic
	p.Color=Color3.fromRGB(180,190,210)
	place(p)
	self.history:SetWaypoint("Insert "..shape)
	if self.sel then self.sel:Set({p}) end
	return p
end

function InsertService:Model(name: string)
	-- placeholder: imports kit later; for now a Model with Part
	self.history:SetWaypoint("Before Insert Model")
	local m=Instance.new("Model"); m.Name=name
	local part=Instance.new("Part"); part.Size=Vector3.new(4,4,4); part.Anchored=true; part.Parent=m
	place(part)
	m.Parent=workspace
	self.history:SetWaypoint("Insert "..name)
	if self.sel then self.sel:Set({m}) end
	return m
end

return InsertService
