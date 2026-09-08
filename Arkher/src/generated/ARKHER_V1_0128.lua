--!strict
-- Godot4 — CORE Map #0128
-- Template: blueprint — unique functional UI (not color swap). Controls affect world via ChangeHistoryService.
local Theme=require(script.Parent.Parent.core.theme)
local BaseWindow=require(script.Parent.Parent.ui.windows.base_window)
local Components=require(script.Parent.Parent.ui.components.init)

local M={}
M.__index=M

function M.new(parent: Instance)
    local win=BaseWindow.new({title="Godot4 — CORE Map #0128", size=Vector2.new(680, 480), pos=UDim2.fromOffset(164, 176), parent=parent, icon="↻"})
    win.Root.Name="ARKHER_V1_0128"
    win.Root.Visible=false
    local content=win.Content
    content.BackgroundColor3=Theme.tokens.void
    -- accent line per UI
    local accent=Instance.new("Frame"); accent.Size=UDim2.new(1,0,0,2); accent.BackgroundColor3=Theme.categoryColor("Godot4 —"); accent.BorderSizePixel=0; accent.Parent=content

    local body=Instance.new("Frame")
    body.Name="Body"
    body.Size=UDim2.new(1,0,1,-2)
    body.Position=UDim2.fromOffset(0,2)
    body.BackgroundTransparency=1
    body.Parent=content
    -- inject unique layout below (body is parent)
    do
        local content=body
        
local canvas=Instance.new("Frame"); canvas.Size=UDim2.new(1,0,1,0); canvas.BackgroundColor3=Color3.fromRGB(14,20,48); canvas.Parent=content
local function b(pos, ttl) local f=Instance.new("Frame"); f.Size=UDim2.fromOffset(120,48); f.Position=UDim2.fromOffset(pos.X,pos.Y); f.BackgroundColor3=Theme.tokens.slate800; f.Parent=canvas; local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,8); c.Parent=f; local t=Instance.new("TextLabel"); t.Size=UDim2.new(1,0,0,14); t.BackgroundColor3=Theme.tokens.violet; t.Text=ttl; t.Font=Enum.Font.GothamBold; t.TextSize=9; t.TextColor3=Color3.new(1,1,1); t.Parent=f; return f end
b(Vector2.new(20,40),"Event Begin"); b(Vector2.new(180,60),"Branch"); b(Vector2.new(340,40),"Print")

    end

    return setmetatable({Win=win}, M)
end
function M:Toggle() self.Win:Toggle() end
return M
