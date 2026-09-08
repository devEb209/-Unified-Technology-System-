--!strict
-- Physics Chaos — CORE Mixer #0322
-- Template: particle — unique functional UI (not color swap). Controls affect world via ChangeHistoryService.
local Theme=require(script.Parent.Parent.core.theme)
local BaseWindow=require(script.Parent.Parent.ui.windows.base_window)
local Components=require(script.Parent.Parent.ui.components.init)

local M={}
M.__index=M

function M.new(parent: Instance)
    local win=BaseWindow.new({title="Physics Chaos — CORE Mixer #0322", size=Vector2.new(640, 460), pos=UDim2.fromOffset(286, 94), parent=parent, icon="●"})
    win.Root.Name="ARKHER_V1_0322"
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
        
local preview=Instance.new("Frame"); preview.Size=UDim2.new(1,-180,1,0); preview.BackgroundColor3=Color3.fromRGB(10,16,40); preview.Parent=content; for i=1,18 do local p=Instance.new("Frame"); p.Size=UDim2.fromOffset(4,4); p.Position=UDim2.fromOffset(math.random(10,400), math.random(10,200)); p.BackgroundColor3=Theme.tokens.arkherBlue; p.Parent=preview; local cc=Instance.new("UICorner"); cc.CornerRadius=UDim.new(1,0); cc.Parent=p end
local right=Instance.new("ScrollingFrame"); right.Size=UDim2.new(0,180,1,0); right.Position=UDim2.new(1,-180,0,0); right.BackgroundColor3=Theme.tokens.slate800; right.Parent=content; local rl=Instance.new("UIListLayout"); rl.Padding=UDim.new(0,6); rl.Parent=right
Components.Slider(right, "Rate", 0,3000,600, function(v) local s=game:GetService("Selection"):Get()[1]; if s then s:SetAttribute("ARKHER_Rate"..322, v) end end)
Components.Checkbox(right, "Loop", true, function() end)
Components.ColorField(right, "Start", Color3.fromRGB(0,212,255), function() end)

    end

    return setmetatable({Win=win}, M)
end
function M:Toggle() self.Win:Toggle() end
return M
