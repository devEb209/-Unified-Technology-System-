--!strict
-- Sketchfab — ANIMATION Profiler #0059
-- Template: asset_grid — unique functional UI (not color swap). Controls affect world via ChangeHistoryService.
local Theme=require(script.Parent.Parent.core.theme)
local BaseWindow=require(script.Parent.Parent.ui.windows.base_window)
local Components=require(script.Parent.Parent.ui.components.init)

local M={}
M.__index=M

function M.new(parent: Instance)
    local win=BaseWindow.new({title="Sketchfab — ANIMATION Profiler #0059", size=Vector2.new(680, 500), pos=UDim2.fromOffset(467, 303), parent=parent, icon="◤"})
    win.Root.Name="ARKHER_V1_0059"
    win.Root.Visible=false
    local content=win.Content
    content.BackgroundColor3=Theme.tokens.void
    -- accent line per UI
    local accent=Instance.new("Frame"); accent.Size=UDim2.new(1,0,0,2); accent.BackgroundColor3=Theme.categoryColor("Sketchfa"); accent.BorderSizePixel=0; accent.Parent=content

    local body=Instance.new("Frame")
    body.Name="Body"
    body.Size=UDim2.new(1,0,1,-2)
    body.Position=UDim2.fromOffset(0,2)
    body.BackgroundTransparency=1
    body.Parent=content
    -- inject unique layout below (body is parent)
    do
        local content=body
        
local grid=Instance.new("ScrollingFrame"); grid.Size=UDim2.new(1,0,1,0); grid.BackgroundColor3=Color3.fromRGB(14,20,48); grid.ScrollBarThickness=6; grid.CanvasSize=UDim2.new(0,0,0,0); grid.AutomaticCanvasSize=Enum.AutomaticSize.Y; grid.Parent=content; local gl=Instance.new("UIGridLayout"); gl.CellSize=UDim2.fromOffset(110,90); gl.CellPadding=UDim2.fromOffset(8,8); gl.Parent=grid
for i=1,9 do local card=Instance.new("Frame"); card.BackgroundColor3=Theme.tokens.slate800; card.Parent=grid; local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,8); c.Parent=card; local th=Instance.new("Frame"); th.Size=UDim2.new(1,0,0,56); th.BackgroundColor3=Theme.categoryColor("as"..i..59); th.Parent=card; local tc=Instance.new("UICorner"); tc.CornerRadius=UDim.new(0,8); tc.Parent=th; local btn=Instance.new("TextButton"); btn.Size=UDim2.new(1,-8,0,16); btn.Position=UDim2.fromOffset(4,66); btn.BackgroundColor3=Theme.tokens.arkherBlue; btn.Text="Import"; btn.Font=Enum.Font.GothamBold; btn.TextSize=9; btn.TextColor3=Color3.fromRGB(14,20,48); btn.Parent=card; local bc=Instance.new("UICorner"); bc.CornerRadius=UDim.new(0,4); bc.Parent=btn end

    end

    return setmetatable({Win=win}, M)
end
function M:Toggle() self.Win:Toggle() end
return M
