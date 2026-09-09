--!strict
-- Anvil Crowd 10k CUSTOM 264149
local Theme=require(script.Parent.Parent.core.theme)
local BaseWindow=require(script.Parent.Parent.ui.windows.base_window)
local Components=require(script.Parent.Parent.ui.components.init)
local M={}; M.__index=M
function M.new(parent: Instance)
    local win=BaseWindow.new({title="Anvil Crowd 10k CUSTOM 264149", size=Vector2.new(657, 453), pos=UDim2.fromOffset(303, 297), parent=parent, icon="⬢"})
    win.Root.Name="ARKHER_CUST_264149"
    win.Root.Visible=false
    local content=win.Content
    content.BackgroundColor3=Theme.tokens.void
    local accent=Instance.new("Frame"); accent.Size=UDim2.new(1,0,0,2); accent.BackgroundColor3=Theme.categoryColor("Anvi"); accent.BorderSizePixel=0; accent.Parent=content
    local body=Instance.new("Frame"); body.Name="Body"; body.Size=UDim2.new(1,0,1,-2); body.Position=UDim2.fromOffset(0,2); body.BackgroundTransparency=1; body.Parent=content
    do local content=body
local hdr=Instance.new("TextLabel"); hdr.Size=UDim2.new(1,0,0,22); hdr.BackgroundTransparency=1; hdr.Text="Anvil Crowd 10k CUSTOM 264149"; hdr.Font=Enum.Font.GothamBold; hdr.TextSize=11; hdr.TextColor3=Theme.tokens.arkherGlow; hdr.TextXAlignment=Enum.TextXAlignment.Left; hdr.Parent=content
Components.TextField(content, "Value", "CUSTOM_264149", function(v) local s=game:GetService("Selection"):Get()[1]; if s then s:SetAttribute("ARKHER_T", v) end end)
Components.Slider(content, "Level", 0,1,0.5, function(v) end)
    end
    local img=Instance.new("ImageLabel"); img.Name="Thumb_264149"; img.Size=UDim2.fromOffset(80,80); img.Position=UDim2.fromOffset(12,12); img.BackgroundColor3=Theme.tokens.slate800; img.Image="rbxassetid://0"; img.ScaleType=Enum.ScaleType.Crop; img.BorderSizePixel=0; img.Parent=body; local ic=Instance.new("UICorner"); ic.CornerRadius=UDim.new(0,8); ic.Parent=img
    local idLbl=Instance.new("TextLabel"); idLbl.Size=UDim2.new(1,0,0,12); idLbl.Position=UDim2.new(0,0,1,-12); idLbl.BackgroundTransparency=1; idLbl.Text="ID "..(2000000+264149*137); idLbl.Font=Enum.Font.Code; idLbl.TextSize=8; idLbl.TextColor3=Theme.tokens.slate400; idLbl.Parent=img
    return setmetatable({Win=win}, M)
end
function M:Toggle() self.Win:Toggle() end
return M
