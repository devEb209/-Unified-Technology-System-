--!strict
-- Marvelous — ANIMATION Stack #0325
-- Template: code — unique functional UI (not color swap). Controls affect world via ChangeHistoryService.
local Theme=require(script.Parent.Parent.core.theme)
local BaseWindow=require(script.Parent.Parent.ui.windows.base_window)
local Components=require(script.Parent.Parent.ui.components.init)

local M={}
M.__index=M

function M.new(parent: Instance)
    local win=BaseWindow.new({title="Marvelous — ANIMATION Stack #0325", size=Vector2.new(640, 420), pos=UDim2.fromOffset(325, 145), parent=parent, icon="✥"})
    win.Root.Name="ARKHER_V1_0325"
    win.Root.Visible=false
    local content=win.Content
    content.BackgroundColor3=Theme.tokens.void
    -- accent line per UI
    local accent=Instance.new("Frame"); accent.Size=UDim2.new(1,0,0,2); accent.BackgroundColor3=Theme.categoryColor("Marvelou"); accent.BorderSizePixel=0; accent.Parent=content

    local body=Instance.new("Frame")
    body.Name="Body"
    body.Size=UDim2.new(1,0,1,-2)
    body.Position=UDim2.fromOffset(0,2)
    body.BackgroundTransparency=1
    body.Parent=content
    -- inject unique layout below (body is parent)
    do
        local content=body
        
local tree=Instance.new("ScrollingFrame"); tree.Size=UDim2.new(0,140,1,0); tree.BackgroundColor3=Theme.tokens.slate900; tree.Parent=content; local tl=Instance.new("UIListLayout"); tl.Padding=UDim.new(0,2); tl.Parent=tree
for _,f in {"main.lua","utils.lua","config.lua"} do local r=Instance.new("TextLabel"); r.Size=UDim2.new(1,0,0,18); r.BackgroundTransparency=1; r.Text="  "..f; r.Font=Enum.Font.Code; r.TextSize=11; r.TextColor3=Theme.tokens.slate200; r.TextXAlignment=Enum.TextXAlignment.Left; r.Parent=tree end
local editor=Instance.new("Frame"); editor.Size=UDim2.new(1,-280,1,0); editor.Position=UDim2.fromOffset(140,0); editor.BackgroundColor3=Color3.fromRGB(14,20,48); editor.Parent=content; local lbl=Instance.new("TextLabel"); lbl.Size=UDim2.new(1,0,0,20); lbl.BackgroundColor3=Theme.tokens.slate800; lbl.Text="  -- code editor (Luau)"; lbl.Font=Enum.Font.Code; lbl.TextSize=11; lbl.TextColor3=Theme.tokens.slate400; lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.Parent=editor
local out=Instance.new("ScrollingFrame"); out.Size=UDim2.new(0,140,1,0); out.Position=UDim2.new(1,-140,0,0); out.BackgroundColor3=Theme.tokens.slate800; out.Parent=content; local ol=Instance.new("UIListLayout"); ol.Padding=UDim.new(0,6); ol.Parent=out
Components.Button(out, "▶ Run", {size=UDim2.new(1,0,0,24), color=Theme.tokens.aurora})
Components.Button(out, "Format", {size=UDim2.new(1,0,0,24)})

    end

    return setmetatable({Win=win}, M)
end
function M:Toggle() self.Win:Toggle() end
return M
