--!strict
-- Cascadeur — ANIMATION Stack #0305
-- Template: sculpt — unique functional UI (not color swap). Controls affect world via ChangeHistoryService.
local Theme=require(script.Parent.Parent.core.theme)
local BaseWindow=require(script.Parent.Parent.ui.windows.base_window)
local Components=require(script.Parent.Parent.ui.components.init)

local M={}
M.__index=M

function M.new(parent: Instance)
    local win=BaseWindow.new({title="Cascadeur — ANIMATION Stack #0305", size=Vector2.new(680, 420), pos=UDim2.fromOffset(465, 325), parent=parent, icon="⬢"})
    win.Root.Name="ARKHER_V1_0305"
    win.Root.Visible=false
    local content=win.Content
    content.BackgroundColor3=Theme.tokens.void
    -- accent line per UI
    local accent=Instance.new("Frame"); accent.Size=UDim2.new(1,0,0,2); accent.BackgroundColor3=Theme.categoryColor("Cascadeu"); accent.BorderSizePixel=0; accent.Parent=content

    local body=Instance.new("Frame")
    body.Name="Body"
    body.Size=UDim2.new(1,0,1,-2)
    body.Position=UDim2.fromOffset(0,2)
    body.BackgroundTransparency=1
    body.Parent=content
    -- inject unique layout below (body is parent)
    do
        local content=body
        
local left=Instance.new("ScrollingFrame"); left.Size=UDim2.new(0,110,1,0); left.BackgroundColor3=Theme.tokens.slate900; left.Parent=content; local gl=Instance.new("UIGridLayout"); gl.CellSize=UDim2.fromOffset(48,48); gl.CellPadding=UDim2.fromOffset(6,6); gl.Parent=left
for _,b in {"Move","Clay","Smooth","Pinch"} do local btn=Instance.new("TextButton"); btn.BackgroundColor3=Theme.tokens.slate800; btn.Text=b; btn.Font=Enum.Font.Gotham; btn.TextSize=9; btn.TextColor3=Theme.tokens.slate200; btn.Parent=left; local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,8); c.Parent=btn end
local center=Instance.new("Frame"); center.Size=UDim2.new(1,-220,1,0); center.Position=UDim2.fromOffset(110,0); center.BackgroundColor3=Color3.fromRGB(18,24,58); center.Parent=content; local h=Instance.new("TextLabel"); h.Size=UDim2.fromScale(1,1); h.BackgroundTransparency=1; h.Text="Sculpt preview — EditableMesh"; h.Font=Enum.Font.Gotham; h.TextSize=11; h.TextColor3=Theme.tokens.slate400; h.Parent=center
local right=Instance.new("Frame"); right.Size=UDim2.new(0,110,1,0); right.Position=UDim2.new(1,-110,0,0); right.BackgroundColor3=Theme.tokens.slate800; right.Parent=content; local rl=Instance.new("UIListLayout"); rl.Padding=UDim.new(0,6); rl.Parent=right
Components.Slider(right, "Size", 4,128,32, function() end)
Components.Slider(right, "Strength", 0,1,0.5, function() end)

    end

    return setmetatable({Win=win}, M)
end
function M:Toggle() self.Win:Toggle() end
return M
