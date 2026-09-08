--!strict
-- Creation2 — CORE Mixer #0062
-- Template: toggles — unique functional UI (not color swap). Controls affect world via ChangeHistoryService.
local Theme=require(script.Parent.Parent.core.theme)
local BaseWindow=require(script.Parent.Parent.ui.windows.base_window)
local Components=require(script.Parent.Parent.ui.components.init)

local M={}
M.__index=M

function M.new(parent: Instance)
    local win=BaseWindow.new({title="Creation2 — CORE Mixer #0062", size=Vector2.new(680, 460), pos=UDim2.fromOffset(106, 94), parent=parent, icon="↻"})
    win.Root.Name="ARKHER_V1_0062"
    win.Root.Visible=false
    local content=win.Content
    content.BackgroundColor3=Theme.tokens.void
    -- accent line per UI
    local accent=Instance.new("Frame"); accent.Size=UDim2.new(1,0,0,2); accent.BackgroundColor3=Theme.categoryColor("Creation"); accent.BorderSizePixel=0; accent.Parent=content

    local body=Instance.new("Frame")
    body.Name="Body"
    body.Size=UDim2.new(1,0,1,-2)
    body.Position=UDim2.fromOffset(0,2)
    body.BackgroundTransparency=1
    body.Parent=content
    -- inject unique layout below (body is parent)
    do
        local content=body
        
local list=Instance.new("ScrollingFrame"); list.Size=UDim2.new(1,0,1,0); list.BackgroundTransparency=1; list.ScrollBarThickness=6; list.CanvasSize=UDim2.new(0,0,0,0); list.AutomaticCanvasSize=Enum.AutomaticSize.Y; list.Parent=content; local ll=Instance.new("UIListLayout"); ll.Padding=UDim.new(0,6); ll.Parent=list
Components.Checkbox(list, "Enable Feature", true, function(v) local s=game:GetService("Selection"):Get()[1]; if s then s:SetAttribute("ARKHER_F"..62, v) end end)
Components.Checkbox(list, "Cast Shadows", true, function(v) local s=game:GetService("Selection"):Get()[1]; if s and s:IsA("BasePart") then (s :: BasePart).CastShadow=v end end)
Components.Slider(list, "Intensity", 0,2,1, function(v) local s=game:GetService("Selection"):Get()[1]; if s then s:SetAttribute("ARKHER_I"..62, v) end end)
Components.Dropdown(list, "Quality", {"Low","Medium","High","Ultra"}, "High", function() end)
Components.TextField(list, "Tag", "ARKHER_"..62, function(v) local s=game:GetService("Selection"):Get()[1]; if s then s:SetAttribute("ARKHER_Tag", v) end end)

    end

    return setmetatable({Win=win}, M)
end
function M:Toggle() self.Win:Toggle() end
return M
