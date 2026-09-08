--!strict
-- Mapbox GL — ANIMATION Map #0313
-- Template: timeline — unique functional UI (not color swap). Controls affect world via ChangeHistoryService.
local Theme=require(script.Parent.Parent.core.theme)
local BaseWindow=require(script.Parent.Parent.ui.windows.base_window)
local Components=require(script.Parent.Parent.ui.components.init)

local M={}
M.__index=M

function M.new(parent: Instance)
    local win=BaseWindow.new({title="Mapbox GL — ANIMATION Map #0313", size=Vector2.new(640, 480), pos=UDim2.fromOffset(169, 201), parent=parent, icon="◨"})
    win.Root.Name="ARKHER_V1_0313"
    win.Root.Visible=false
    local content=win.Content
    content.BackgroundColor3=Theme.tokens.void
    -- accent line per UI
    local accent=Instance.new("Frame"); accent.Size=UDim2.new(1,0,0,2); accent.BackgroundColor3=Theme.categoryColor("Mapbox G"); accent.BorderSizePixel=0; accent.Parent=content

    local body=Instance.new("Frame")
    body.Name="Body"
    body.Size=UDim2.new(1,0,1,-2)
    body.Position=UDim2.fromOffset(0,2)
    body.BackgroundTransparency=1
    body.Parent=content
    -- inject unique layout below (body is parent)
    do
        local content=body
        
local ruler=Instance.new("Frame"); ruler.Size=UDim2.new(1,0,0,20); ruler.BackgroundColor3=Theme.tokens.slate800; ruler.Parent=content
for i=0,16 do local tk=Instance.new("TextLabel"); tk.Size=UDim2.fromOffset(32,20); tk.Position=UDim2.fromOffset(i*32,0); tk.BackgroundTransparency=1; tk.Text=tostring(i); tk.Font=Enum.Font.Code; tk.TextSize=10; tk.TextColor3=Theme.tokens.slate400; tk.Parent=ruler end
local track=Instance.new("Frame"); track.Size=UDim2.new(1,0,1,-20); track.Position=UDim2.fromOffset(0,20); track.BackgroundColor3=Color3.fromRGB(20,26,62); track.Parent=content
for r=1,4 do local row=Instance.new("Frame"); row.Size=UDim2.new(1,0,0,18); row.Position=UDim2.fromOffset(0,(r-1)*22); row.BackgroundColor3= if r%2==0 then Color3.fromRGB(26,34,78) else Color3.fromRGB(22,30,70); row.Parent=track; for _,k in {2,7,11} do local key=Instance.new("Frame"); key.Size=UDim2.fromOffset(10,10); key.Position=UDim2.fromOffset(k*32+11,4); key.BackgroundColor3=Theme.tokens.arkherBlue; key.Rotation=45; key.Parent=row; local cc=Instance.new("UICorner"); cc.CornerRadius=UDim.new(0,2); cc.Parent=key end end
local props=Instance.new("Frame"); props.Size=UDim2.new(1,0,0,80); props.Position=UDim2.new(0,0,1,-80); props.BackgroundColor3=Theme.tokens.slate800; props.Parent=content; local pl=Instance.new("UIListLayout"); pl.FillDirection=Enum.FillDirection.Horizontal; pl.Padding=UDim.new(0,8); pl.Parent=props
Components.Dropdown(props, "Interp", {"Bezier","Linear","Constant"}, "Bezier", function() end)
Components.Slider(props, "Value", -5,5,0, function(v) local s=game:GetService("Selection"):Get()[1]; if s and s:IsA("BasePart") then s:SetAttribute("ARKHER_T"..313, v) end end)

    end

    return setmetatable({Win=win}, M)
end
function M:Toggle() self.Win:Toggle() end
return M
