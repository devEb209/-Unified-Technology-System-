--!strict
-- Roblox Studio — CORE Profiler #0094
-- Template: form — unique functional UI (not color swap). Controls affect world via ChangeHistoryService.
local Theme=require(script.Parent.Parent.core.theme)
local BaseWindow=require(script.Parent.Parent.ui.windows.base_window)
local Components=require(script.Parent.Parent.ui.components.init)

local M={}
M.__index=M

function M.new(parent: Instance)
    local win=BaseWindow.new({title="Roblox Studio — CORE Profiler #0094", size=Vector2.new(640, 500), pos=UDim2.fromOffset(122, 118), parent=parent, icon="✥"})
    win.Root.Name="ARKHER_V1_0094"
    win.Root.Visible=false
    local content=win.Content
    content.BackgroundColor3=Theme.tokens.void
    -- accent line per UI
    local accent=Instance.new("Frame"); accent.Size=UDim2.new(1,0,0,2); accent.BackgroundColor3=Theme.categoryColor("Roblox S"); accent.BorderSizePixel=0; accent.Parent=content

    local body=Instance.new("Frame")
    body.Name="Body"
    body.Size=UDim2.new(1,0,1,-2)
    body.Position=UDim2.fromOffset(0,2)
    body.BackgroundTransparency=1
    body.Parent=content
    -- inject unique layout below (body is parent)
    do
        local content=body
        
local form=Instance.new("ScrollingFrame"); form.Size=UDim2.new(1,0,1,0); form.BackgroundTransparency=1; form.ScrollBarThickness=6; form.CanvasSize=UDim2.new(0,0,0,0); form.AutomaticCanvasSize=Enum.AutomaticSize.Y; form.Parent=content; local fl=Instance.new("UIListLayout"); fl.Padding=UDim.new(0,6); fl.Parent=form
Components.TextField(form, "Name", "Object_"..94, function(v) local s=game:GetService("Selection"):Get()[1]; if s then game:GetService("ChangeHistoryService"):SetWaypoint("Before Name"); s.Name=v; game:GetService("ChangeHistoryService"):SetWaypoint("Name") end end)
Components.Vector3Field(form, "Position", Vector3.new(0,5,0), function(v) local s=game:GetService("Selection"):Get()[1]; if s and s:IsA("BasePart") then s.Position=v end end)
Components.ColorField(form, "Color", Color3.fromRGB(180,190,210), function(c) local s=game:GetService("Selection"):Get()[1]; if s and s:IsA("BasePart") then (s :: BasePart).Color=c end end)
Components.Dropdown(form, "Material", {"Plastic","Metal","Wood","Glass"}, "Plastic", function(opt) local s=game:GetService("Selection"):Get()[1]; if s and s:IsA("BasePart") then (s :: BasePart).Material=Enum.Material[opt] end end)

    end

    return setmetatable({Win=win}, M)
end
function M:Toggle() self.Win:Toggle() end
return M
