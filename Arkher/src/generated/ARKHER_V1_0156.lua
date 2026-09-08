--!strict
-- Creation2 — CORE Node_Flow #0156
-- Template: profiler — unique functional UI (not color swap). Controls affect world via ChangeHistoryService.
local Theme=require(script.Parent.Parent.core.theme)
local BaseWindow=require(script.Parent.Parent.ui.windows.base_window)
local Components=require(script.Parent.Parent.ui.components.init)

local M={}
M.__index=M

function M.new(parent: Instance)
    local win=BaseWindow.new({title="Creation2 — CORE Node_Flow #0156", size=Vector2.new(600, 440), pos=UDim2.fromOffset(128, 132), parent=parent, icon="▭"})
    win.Root.Name="ARKHER_V1_0156"
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
        
local bars=Instance.new("Frame"); bars.Size=UDim2.new(1,0,1,0); bars.BackgroundTransparency=1; bars.Parent=content; local bl=Instance.new("UIListLayout"); bl.Padding=UDim.new(0,8); bl.Parent=bars
for i=1,5 do local row=Instance.new("Frame"); row.Size=UDim2.new(1,0,0,22); row.BackgroundTransparency=1; row.Parent=bars; local lbl=Instance.new("TextLabel"); lbl.Size=UDim2.new(0,100,1,0); lbl.BackgroundTransparency=1; lbl.Text="System "..i; lbl.Font=Enum.Font.Gotham; lbl.TextSize=11; lbl.TextColor3=Theme.tokens.slate400; lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.Parent=row; local track=Instance.new("Frame"); track.Size=UDim2.new(1,-110,0,8); track.Position=UDim2.new(0,110,0.5,-4); track.BackgroundColor3=Theme.tokens.slate700; track.Parent=row; local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,4); c.Parent=track; local fill=Instance.new("Frame"); fill.Size=UDim2.new(math.random(30,90)/100,0,1,0); fill.BackgroundColor3=Theme.qualityColor(math.random()); fill.Parent=track; local fc=Instance.new("UICorner"); fc.CornerRadius=UDim.new(0,4); fc.Parent=fill end

    end

    return setmetatable({Win=win}, M)
end
function M:Toggle() self.Win:Toggle() end
return M
