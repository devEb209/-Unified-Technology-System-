--!strict
-- ARKHER Audio Dolby CUSTOM 143076
local Theme=require(script.Parent.Parent.core.theme)
local BaseWindow=require(script.Parent.Parent.ui.windows.base_window)
local Components=require(script.Parent.Parent.ui.components.init)
local M={}; M.__index=M
function M.new(parent: Instance)
    local win=BaseWindow.new({title="ARKHER Audio Dolby CUSTOM 143076", size=Vector2.new(728, 452), pos=UDim2.fromOffset(452, 388), parent=parent, icon="◐"})
    win.Root.Name="ARKHER_CUST_143076"
    win.Root.Visible=false
    local content=win.Content
    content.BackgroundColor3=Theme.tokens.void
    local accent=Instance.new("Frame"); accent.Size=UDim2.new(1,0,0,2); accent.BackgroundColor3=Theme.categoryColor("ARKH"); accent.BorderSizePixel=0; accent.Parent=content
    local body=Instance.new("Frame"); body.Name="Body"; body.Size=UDim2.new(1,0,1,-2); body.Position=UDim2.fromOffset(0,2); body.BackgroundTransparency=1; body.Parent=content
    do local content=body
local hdr=Instance.new("TextLabel"); hdr.Size=UDim2.new(1,0,0,22); hdr.BackgroundTransparency=1; hdr.Text="ARKHER Audio Dolby CUSTOM 143076"; hdr.Font=Enum.Font.GothamBold; hdr.TextSize=11; hdr.TextColor3=Theme.tokens.arkherGlow; hdr.TextXAlignment=Enum.TextXAlignment.Left; hdr.Parent=content
Components.Slider(content, "Scale", 0.1, 5, 1, function(v) local s=game:GetService("Selection"):Get()[1]; if s then s:SetAttribute("ARKHER_C143076", v) end end)
Components.Checkbox(content, "Active", true, function(v) end)
    end
    local img=Instance.new("ImageLabel"); img.Name="Thumb_143076"; img.Size=UDim2.fromOffset(80,80); img.Position=UDim2.fromOffset(12,12); img.BackgroundColor3=Theme.tokens.slate800; img.Image="rbxassetid://0"; img.ScaleType=Enum.ScaleType.Crop; img.BorderSizePixel=0; img.Parent=body; local ic=Instance.new("UICorner"); ic.CornerRadius=UDim.new(0,8); ic.Parent=img
    local idLbl=Instance.new("TextLabel"); idLbl.Size=UDim2.new(1,0,0,12); idLbl.Position=UDim2.new(0,0,1,-12); idLbl.BackgroundTransparency=1; idLbl.Text="ID "..(2000000+143076*137); idLbl.Font=Enum.Font.Code; idLbl.TextSize=8; idLbl.TextColor3=Theme.tokens.slate400; idLbl.Parent=img
    return setmetatable({Win=win}, M)
end
function M:Toggle() self.Win:Toggle() end
return M
