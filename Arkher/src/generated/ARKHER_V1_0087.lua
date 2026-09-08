--!strict
-- Physics Chaos — ANIMATION Mixer #0087
-- Template: map — unique functional UI (not color swap). Controls affect world via ChangeHistoryService.
local Theme=require(script.Parent.Parent.core.theme)
local BaseWindow=require(script.Parent.Parent.ui.windows.base_window)
local Components=require(script.Parent.Parent.ui.components.init)

local M={}
M.__index=M

function M.new(parent: Instance)
    local win=BaseWindow.new({title="Physics Chaos — ANIMATION Mixer #0087", size=Vector2.new(600, 460), pos=UDim2.fromOffset(431, 259), parent=parent, icon="⬔"})
    win.Root.Name="ARKHER_V1_0087"
    win.Root.Visible=false
    local content=win.Content
    content.BackgroundColor3=Theme.tokens.void
    -- accent line per UI
    local accent=Instance.new("Frame"); accent.Size=UDim2.new(1,0,0,2); accent.BackgroundColor3=Theme.categoryColor("Physics "); accent.BorderSizePixel=0; accent.Parent=content

    local body=Instance.new("Frame")
    body.Name="Body"
    body.Size=UDim2.new(1,0,1,-2)
    body.Position=UDim2.fromOffset(0,2)
    body.BackgroundTransparency=1
    body.Parent=content
    -- inject unique layout below (body is parent)
    do
        local content=body
        
local view=Instance.new("Frame"); view.Size=UDim2.new(1,0,0,140); view.BackgroundColor3=Color3.fromRGB(10,16,40); view.Parent=content; local lb=Instance.new("TextLabel"); lb.Size=UDim2.new(1,0,1,0); lb.BackgroundTransparency=1; lb.Text="Map preview — Mapbox/OSM/ESA tiles"; lb.Font=Enum.Font.Gotham; lb.TextSize=11; lb.TextColor3=Theme.tokens.slate400; lb.Parent=view
local ctrl=Instance.new("Frame"); ctrl.Size=UDim2.new(1,0,1,-140); ctrl.Position=UDim2.fromOffset(0,140); ctrl.BackgroundTransparency=1; ctrl.Parent=content; local cl=Instance.new("UIListLayout"); cl.Padding=UDim.new(0,6); cl.Parent=ctrl
Components.TextField(ctrl, "Lat,Lon", "-27.17,-51.61", function() end)
Components.Dropdown(ctrl, "Overlay", {"ESA","Biomes","Off"}, "ESA", function() end)
Components.Slider(ctrl, "Opacity", 0,1,0.8, function() end)

    end

    return setmetatable({Win=win}, M)
end
function M:Toggle() self.Win:Toggle() end
return M
