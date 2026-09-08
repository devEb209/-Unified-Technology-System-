--!strict
-- SelectionService — wraps game.Selection + ChangeHistoryService + Instance lifecycle
local SelectionService = {}
SelectionService.__index = SelectionService

function SelectionService.new()
	local self = setmetatable({}, SelectionService)
	self._sel = game:GetService("Selection")
	self._history = game:GetService("ChangeHistoryService")
	self._onChange = Instance.new("BindableEvent")
	self.OnSelectionChanged = self._onChange.Event
	self._sel.SelectionChanged:Connect(function()
		self._onChange:Fire(self._sel:Get())
	end)
	return self
end

function SelectionService:Get(): {Instance}
	return self._sel:Get()
end
function SelectionService:GetSingle(): Instance?
	local s=self._sel:Get()
	return s[1]
end
function SelectionService:Set(objs: {Instance})
	self._sel:Set(objs)
end
function SelectionService:Clear()
	self._sel:Set({})
end
-- Wrap property writes so they are undoable
function SelectionService:SetProperty(obj: Instance, prop: string, value: any)
	self._history:SetWaypoint("Before "..prop)
	pcall(function()
		(obj :: any)[prop] = value
	end)
	self._history:SetWaypoint("Set "..prop)
end

return SelectionService
