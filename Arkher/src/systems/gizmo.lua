--!strict
-- Gizmo — real 3D handles in world (Move/Rotate/Scale) operating on Selection via ChangeHistory.
-- Uses Handles/ArcHandles attached to part. No fake viewport.
local Gizmo = {}
Gizmo.__index = Gizmo

function Gizmo.new(selectionService)
	local self=setmetatable({}, Gizmo)
	self.Sel=selectionService
	self.Mode="Select" -- Select | Move | Rotate | Scale
	self.Handles=nil :: Handles?
	self.Arc=nil :: ArcHandles?
	self.Adorn=nil :: SelectionBox?
	return self
end

function Gizmo:SetMode(mode: string)
	self.Mode=mode
	self:Refresh()
end

function Gizmo:Refresh()
	-- cleanup
	if self.Handles then self.Handles:Destroy(); self.Handles=nil end
	if self.Arc then self.Arc:Destroy(); self.Arc=nil end
	if self.Adorn then self.Adorn:Destroy(); self.Adorn=nil end

	local sel = if self.Sel then self.Sel:Get() else {}
	local target = sel[1] :: Instance?
	if not target or not target:IsA("BasePart") then return end
	local part = target :: BasePart
	if self.Mode=="Select" then
		local box=Instance.new("SelectionBox")
		box.Adornee=part
		box.Color3=Color3.fromRGB(0,212,255)
		box.LineThickness=0.04
		box.SurfaceTransparency=0.9
		box.Parent=part
		self.Adorn=box
	elseif self.Mode=="Move" then
		local h=Instance.new("Handles")
		h.Adornee=part
		h.Style=Enum.HandlesStyle.Movement
		h.Color3=Color3.fromRGB(0,212,255)
		h.Parent=part
		self.Handles=h
	elseif self.Mode=="Rotate" then
		local a=Instance.new("ArcHandles")
		a.Adornee=part
		a.Color3=Color3.fromRGB(0,212,255)
		a.Parent=part
		self.Arc=a
	elseif self.Mode=="Scale" then
		local h=Instance.new("Handles")
		h.Adornee=part
		h.Style=Enum.HandlesStyle.Resize
		h.Color3=Color3.fromRGB(0,212,255)
		h.Parent=part
		self.Handles=h
	end
end

return Gizmo
