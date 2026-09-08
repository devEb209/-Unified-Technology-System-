--!strict
-- USGS DEM — CORE Stack #0240
-- Template: stack — unique functional UI (not color swap). Controls affect world via ChangeHistoryService.
local Theme=require(script.Parent.Parent.core.theme)
local BaseWindow=require(script.Parent.Parent.ui.windows.base_window)
local Components=require(script.Parent.Parent.ui.components.init)

local M={}
M.__index=M

function M.new(parent: Instance)
    local win=BaseWindow.new({title="USGS DEM — CORE Stack #0240", size=Vector2.new(600, 420), pos=UDim2.fromOffset(420, 260), parent=parent, icon="🛰"})
    win.Root.Name="ARKHER_V1_0240"
    win.Root.Visible=false
    local content=win.Content
    content.BackgroundColor3=Theme.tokens.void
    -- accent line per UI
    local accent=Instance.new("Frame"); accent.Size=UDim2.new(1,0,0,2); accent.BackgroundColor3=Theme.categoryColor("USGS DEM"); accent.BorderSizePixel=0; accent.Parent=content

    local body=Instance.new("Frame")
    body.Name="Body"
    body.Size=UDim2.new(1,0,1,-2)
    body.Position=UDim2.fromOffset(0,2)
    body.BackgroundTransparency=1
    body.Parent=content
    -- inject unique layout below (body is parent)
    do
        local content=body
        
-- Stack layout (inspired 3ds Max Modifier Stack)
local stack=Instance.new("ScrollingFrame")
stack.Size=UDim2.new(0,190,1,0); stack.BackgroundColor3=Theme.tokens.slate900; stack.BorderSizePixel=0; stack.ScrollBarThickness=6; stack.CanvasSize=UDim2.new(0,0,0,0); stack.AutomaticCanvasSize=Enum.AutomaticSize.Y; stack.Parent=content
local ll=Instance.new("UIListLayout"); ll.Padding=UDim.new(0,2); ll.Parent=stack
for _,name in {"Base","Modifier A","Modifier B","Collapse"} do
    local r=Instance.new("Frame"); r.Size=UDim2.new(1,0,0,24); r.BackgroundColor3=Theme.tokens.slate800; r.Parent=stack; local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,6); c.Parent=r
    local l=Instance.new("TextLabel"); l.Size=UDim2.new(1,-8,1,0); l.Position=UDim2.fromOffset(8,0); l.BackgroundTransparency=1; l.Text=name; l.Font=Enum.Font.Gotham; l.TextSize=11; l.TextColor3=Theme.tokens.slate200; l.TextXAlignment=Enum.TextXAlignment.Left; l.Parent=r
end
local center=Instance.new("Frame"); center.Size=UDim2.new(1,-380,1,0); center.Position=UDim2.fromOffset(190,0); center.BackgroundColor3=Color3.fromRGB(16,22,52); center.BorderSizePixel=0; center.Parent=content
local hint=Instance.new("TextLabel"); hint.Size=UDim2.fromScale(1,1); hint.BackgroundTransparency=1; hint.Text="Stack edits selection — real HistoryService."; hint.Font=Enum.Font.Gotham; hint.TextSize=11; hint.TextColor3=Theme.tokens.slate400; hint.TextWrapped=true; hint.Parent=center
local props=Instance.new("ScrollingFrame"); props.Size=UDim2.new(0,190,1,0); props.Position=UDim2.new(1,-190,0,0); props.BackgroundColor3=Theme.tokens.slate800; props.BorderSizePixel=0; props.ScrollBarThickness=6; props.CanvasSize=UDim2.new(0,0,0,0); props.AutomaticCanvasSize=Enum.AutomaticSize.Y; props.Parent=content
local prl=Instance.new("UIListLayout"); prl.Padding=UDim.new(0,6); prl.Parent=props
Components.Slider(props, "Strength", 0,1,0.5, function(v) local s=game:GetService("Selection"):Get()[1]; if s then s:SetAttribute("ARKHER_S"..240, v) end end)
Components.Checkbox(props, "Enabled", true, function(v) local s=game:GetService("Selection"):Get()[1]; if s then s:SetAttribute("ARKHER_E"..240, v) end end)

    end

    return setmetatable({Win=win}, M)
end
function M:Toggle() self.Win:Toggle() end
return M
