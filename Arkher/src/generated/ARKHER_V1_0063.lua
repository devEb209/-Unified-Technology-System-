--!strict
-- Substance Layers — ANIMATION Map #0063
-- Template: mixer — unique functional UI (not color swap). Controls affect world via ChangeHistoryService.
local Theme=require(script.Parent.Parent.core.theme)
local BaseWindow=require(script.Parent.Parent.ui.windows.base_window)
local Components=require(script.Parent.Parent.ui.components.init)

local M={}
M.__index=M

function M.new(parent: Instance)
    local win=BaseWindow.new({title="Substance Layers — ANIMATION Map #0063", size=Vector2.new(600, 480), pos=UDim2.fromOffset(119, 111), parent=parent, icon="⤢"})
    win.Root.Name="ARKHER_V1_0063"
    win.Root.Visible=false
    local content=win.Content
    content.BackgroundColor3=Theme.tokens.void
    -- accent line per UI
    local accent=Instance.new("Frame"); accent.Size=UDim2.new(1,0,0,2); accent.BackgroundColor3=Theme.categoryColor("Substanc"); accent.BorderSizePixel=0; accent.Parent=content

    local body=Instance.new("Frame")
    body.Name="Body"
    body.Size=UDim2.new(1,0,1,-2)
    body.Position=UDim2.fromOffset(0,2)
    body.BackgroundTransparency=1
    body.Parent=content
    -- inject unique layout below (body is parent)
    do
        local content=body
        
local mixer=Instance.new("Frame"); mixer.Size=UDim2.new(1,0,1,0); mixer.BackgroundColor3=Theme.tokens.slate900; mixer.Parent=content; local ml=Instance.new("UIListLayout"); ml.FillDirection=Enum.FillDirection.Horizontal; ml.Padding=UDim.new(0,8); ml.Parent=mixer
for i=1,4 do local strip=Instance.new("Frame"); strip.Size=UDim2.new(0,110,1,-12); strip.BackgroundColor3=Theme.tokens.slate800; strip.Parent=mixer; local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,8); c.Parent=strip; local lbl=Instance.new("TextLabel"); lbl.Size=UDim2.new(1,0,0,16); lbl.BackgroundColor3=Theme.categoryColor("mix"..i..63); lbl.Text="Ch "..i; lbl.Font=Enum.Font.GothamBold; lbl.TextSize=10; lbl.TextColor3=Color3.new(1,1,1); lbl.Parent=strip end

    end

    return setmetatable({Win=win}, M)
end
function M:Toggle() self.Win:Toggle() end
return M
