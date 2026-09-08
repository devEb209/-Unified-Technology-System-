--!strict
-- Houdini — CORE Node_Flow #0056
-- Template: layer_graph — unique functional UI (not color swap). Controls affect world via ChangeHistoryService.
local Theme=require(script.Parent.Parent.core.theme)
local BaseWindow=require(script.Parent.Parent.ui.windows.base_window)
local Components=require(script.Parent.Parent.ui.components.init)

local M={}
M.__index=M

function M.new(parent: Instance)
    local win=BaseWindow.new({title="Houdini — CORE Node_Flow #0056", size=Vector2.new(680, 440), pos=UDim2.fromOffset(428, 252), parent=parent, icon="◉"})
    win.Root.Name="ARKHER_V1_0056"
    win.Root.Visible=false
    local content=win.Content
    content.BackgroundColor3=Theme.tokens.void
    -- accent line per UI
    local accent=Instance.new("Frame"); accent.Size=UDim2.new(1,0,0,2); accent.BackgroundColor3=Theme.categoryColor("Houdini "); accent.BorderSizePixel=0; accent.Parent=content

    local body=Instance.new("Frame")
    body.Name="Body"
    body.Size=UDim2.new(1,0,1,-2)
    body.Position=UDim2.fromOffset(0,2)
    body.BackgroundTransparency=1
    body.Parent=content
    -- inject unique layout below (body is parent)
    do
        local content=body
        
local left=Instance.new("ScrollingFrame"); left.Size=UDim2.new(0,160,1,0); left.BackgroundColor3=Theme.tokens.slate900; left.BorderSizePixel=0; left.ScrollBarThickness=6; left.CanvasSize=UDim2.new(0,0,0,0); left.AutomaticCanvasSize=Enum.AutomaticSize.Y; left.Parent=content
local ll=Instance.new("UIListLayout"); ll.Padding=UDim.new(0,2); ll.Parent=left
for _,n in {"Layer A","Mask","Fill","Paint"} do local r=Instance.new("Frame"); r.Size=UDim2.new(1,0,0,24); r.BackgroundColor3=Theme.tokens.slate800; r.Parent=left; local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,6); c.Parent=r; local l=Instance.new("TextLabel"); l.Size=UDim2.new(1,-8,1,0); l.Position=UDim2.fromOffset(8,0); l.BackgroundTransparency=1; l.Text=n; l.Font=Enum.Font.Gotham; l.TextSize=11; l.TextColor3=Theme.tokens.slate200; l.TextXAlignment=Enum.TextXAlignment.Left; l.Parent=r end
local graph=Instance.new("Frame"); graph.Size=UDim2.new(1,-320,1,0); graph.Position=UDim2.fromOffset(160,0); graph.BackgroundColor3=Color3.fromRGB(14,20,48); graph.Parent=content
local function node(pos, ttl, col) local f=Instance.new("Frame"); f.Size=UDim2.fromOffset(110,56); f.Position=UDim2.fromOffset(pos.X,pos.Y); f.BackgroundColor3=Theme.tokens.slate800; f.Parent=graph; local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,8); c.Parent=f; local s=Instance.new("UIStroke"); s.Color=col; s.Thickness=1.5; s.Parent=f; local t=Instance.new("TextLabel"); t.Size=UDim2.new(1,0,0,16); t.BackgroundColor3=col; t.Text=ttl; t.Font=Enum.Font.GothamBold; t.TextSize=9; t.TextColor3=Color3.new(1,1,1); t.Parent=f; local tc=Instance.new("UICorner"); tc.CornerRadius=UDim.new(0,8); tc.Parent=t; return f end
node(Vector2.new(20,30),"Input",Theme.tokens.arkherBlue); node(Vector2.new(160,60),"Process",Theme.tokens.violet); node(Vector2.new(300,30),"Output",Theme.tokens.aurora)
local right=Instance.new("ScrollingFrame"); right.Size=UDim2.new(0,160,1,0); right.Position=UDim2.new(1,-160,0,0); right.BackgroundColor3=Theme.tokens.slate800; right.Parent=content; local rl=Instance.new("UIListLayout"); rl.Padding=UDim.new(0,6); rl.Parent=right
Components.ColorField(right, "Tint", Color3.fromRGB(180,190,210), function(c) local s=game:GetService("Selection"):Get()[1]; if s and s:IsA("BasePart") then (s :: BasePart).Color=c end end)
Components.Slider(right, "Opacity", 0,1,1, function(v) local s=game:GetService("Selection"):Get()[1]; if s and s:IsA("BasePart") then (s :: BasePart).Transparency=1-v end end)

    end

    return setmetatable({Win=win}, M)
end
function M:Toggle() self.Win:Toggle() end
return M
