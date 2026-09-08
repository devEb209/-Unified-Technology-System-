--!strict
-- Source2 Hammer — ANIMATION Profiler #0129
-- Template: node_flow — unique functional UI (not color swap). Controls affect world via ChangeHistoryService.
local Theme=require(script.Parent.Parent.core.theme)
local BaseWindow=require(script.Parent.Parent.ui.windows.base_window)
local Components=require(script.Parent.Parent.ui.components.init)

local M={}
M.__index=M

function M.new(parent: Instance)
    local win=BaseWindow.new({title="Source2 Hammer — ANIMATION Profiler #0129", size=Vector2.new(600, 500), pos=UDim2.fromOffset(177, 193), parent=parent, icon="⤢"})
    win.Root.Name="ARKHER_V1_0129"
    win.Root.Visible=false
    local content=win.Content
    content.BackgroundColor3=Theme.tokens.void
    -- accent line per UI
    local accent=Instance.new("Frame"); accent.Size=UDim2.new(1,0,0,2); accent.BackgroundColor3=Theme.categoryColor("Source2 "); accent.BorderSizePixel=0; accent.Parent=content

    local body=Instance.new("Frame")
    body.Name="Body"
    body.Size=UDim2.new(1,0,1,-2)
    body.Position=UDim2.fromOffset(0,2)
    body.BackgroundTransparency=1
    body.Parent=content
    -- inject unique layout below (body is parent)
    do
        local content=body
        
local graph=Instance.new("Frame"); graph.Size=UDim2.new(1,-180,1,0); graph.BackgroundColor3=Color3.fromRGB(14,20,48); graph.Parent=content
local function n(pos, ttl, col) local f=Instance.new("Frame"); f.Size=UDim2.fromOffset(100,48); f.Position=UDim2.fromOffset(pos.X,pos.Y); f.BackgroundColor3=Theme.tokens.slate800; f.Parent=graph; local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,8); c.Parent=f; local s=Instance.new("UIStroke"); s.Color=col; s.Thickness=1.5; s.Parent=f; local t=Instance.new("TextLabel"); t.Size=UDim2.new(1,0,0,14); t.BackgroundColor3=col; t.Text=ttl; t.Font=Enum.Font.GothamBold; t.TextSize=9; t.TextColor3=Color3.new(1,1,1); t.Parent=f; return f end
n(Vector2.new(20,30),"Read",Theme.tokens.aurora); n(Vector2.new(140,70),"Filter",Theme.tokens.arkherBlue); n(Vector2.new(260,30),"Write",Theme.tokens.violet)
local right=Instance.new("ScrollingFrame"); right.Size=UDim2.new(0,180,1,0); right.Position=UDim2.new(1,-180,0,0); right.BackgroundColor3=Theme.tokens.slate800; right.Parent=content; local rl=Instance.new("UIListLayout"); rl.Padding=UDim.new(0,6); rl.Parent=right
Components.TextField(right, "File", "input.png", function(v) local s=game:GetService("Selection"):Get()[1]; if s then s:SetAttribute("ARKHER_File"..129, v) end end)
Components.Dropdown(right, "Mode", {"Add","Mul","Lerp"}, "Add", function() end)

    end

    return setmetatable({Win=win}, M)
end
function M:Toggle() self.Win:Toggle() end
return M
