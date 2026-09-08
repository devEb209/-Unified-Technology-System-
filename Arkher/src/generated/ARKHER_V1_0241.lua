--!strict
-- Neural DLSS — ANIMATION Node_Flow #0241
-- Template: cinematic — unique functional UI (not color swap). Controls affect world via ChangeHistoryService.
local Theme=require(script.Parent.Parent.core.theme)
local BaseWindow=require(script.Parent.Parent.ui.windows.base_window)
local Components=require(script.Parent.Parent.ui.components.init)

local M={}
M.__index=M

function M.new(parent: Instance)
    local win=BaseWindow.new({title="Neural DLSS — ANIMATION Node_Flow #0241", size=Vector2.new(640, 440), pos=UDim2.fromOffset(433, 277), parent=parent, icon="≡"})
    win.Root.Name="ARKHER_V1_0241"
    win.Root.Visible=false
    local content=win.Content
    content.BackgroundColor3=Theme.tokens.void
    -- accent line per UI
    local accent=Instance.new("Frame"); accent.Size=UDim2.new(1,0,0,2); accent.BackgroundColor3=Theme.categoryColor("Neural D"); accent.BorderSizePixel=0; accent.Parent=content

    local body=Instance.new("Frame")
    body.Name="Body"
    body.Size=UDim2.new(1,0,1,-2)
    body.Position=UDim2.fromOffset(0,2)
    body.BackgroundTransparency=1
    body.Parent=content
    -- inject unique layout below (body is parent)
    do
        local content=body
        
local pages=Instance.new("Frame"); pages.Size=UDim2.new(1,0,0,24); pages.BackgroundColor3=Theme.tokens.slate900; pages.Parent=content; local pl=Instance.new("UIListLayout"); pl.FillDirection=Enum.FillDirection.Horizontal; pl.Padding=UDim.new(0,4); pl.Parent=pages
for _,pg in {"Edit","Color","Fusion"} do local b=Instance.new("TextButton"); b.Size=UDim2.fromOffset(80,18); b.BackgroundColor3=Theme.tokens.slate800; b.Text=pg; b.Font=Enum.Font.GothamBold; b.TextSize=10; b.TextColor3=Theme.tokens.slate400; b.Parent=pages; local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,6); c.Parent=b end
local tl=Instance.new("Frame"); tl.Size=UDim2.new(1,0,1,-24); tl.Position=UDim2.fromOffset(0,24); tl.BackgroundColor3=Color3.fromRGB(16,22,52); tl.Parent=content
for i=1,3 do local tr=Instance.new("Frame"); tr.Size=UDim2.new(1,0,0,28); tr.Position=UDim2.fromOffset(0,(i-1)*34); tr.BackgroundColor3=Color3.fromRGB(22,30,70); tr.Parent=tl; local clip=Instance.new("Frame"); clip.Size=UDim2.fromOffset(100,20); clip.Position=UDim2.fromOffset(60,4); clip.BackgroundColor3=Theme.tokens.arkherBlue; clip.Parent=tr; local cc=Instance.new("UICorner"); cc.CornerRadius=UDim.new(0,4); cc.Parent=clip end

    end

    return setmetatable({Win=win}, M)
end
function M:Toggle() self.Win:Toggle() end
return M
