--!strict
-- GeneratedPalette — searchable launcher for 332 ARKHER_V1_* unique functional windows
local Theme=require(script.Parent.Parent.Parent.core.theme)
local BaseWindow=require(script.Parent.base_window)

local Palette={}
Palette.__index=Palette

function Palette.new(parent: Instance, onOpen: (string)->())
    local win=BaseWindow.new({title="All Windows — 332 Unique", size=Vector2.new(520, 460), pos=UDim2.fromOffset(320, 100), parent=parent, icon="▣"})
    win.Root.Name="ARKHER_Palette"
    win.Root.Visible=false
    local content=win.Content

    local search=Instance.new("TextBox")
    search.Size=UDim2.new(1,-16,0,28)
    search.Position=UDim2.fromOffset(8,8)
    search.BackgroundColor3=Theme.tokens.slate800
    search.PlaceholderText="Search 332 windows… (e.g., Terrain, Maya, ESA)"
    search.Text=""
    search.Font=Enum.Font.Gotham
    search.TextSize=12
    search.TextColor3=Theme.tokens.white
    search.PlaceholderColor3=Theme.tokens.slate400
    search.TextXAlignment=Enum.TextXAlignment.Left
    search.ClearTextOnFocus=false
    search.Parent=content
    local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,6); c.Parent=search
    local s=Instance.new("UIStroke"); s.Color=Theme.roles.border; s.Thickness=1; s.Parent=search
    local pad=Instance.new("UIPadding"); pad.PaddingLeft=UDim.new(0,8); pad.PaddingRight=UDim.new(0,8); pad.Parent=search

    local scroll=Instance.new("ScrollingFrame")
    scroll.Size=UDim2.new(1,-8,1,-44)
    scroll.Position=UDim2.fromOffset(4,44)
    scroll.BackgroundTransparency=1
    scroll.BorderSizePixel=0
    scroll.ScrollBarThickness=6
    scroll.ScrollBarImageColor3=Theme.tokens.slate600
    scroll.CanvasSize=UDim2.new(0,0,0,0)
    scroll.AutomaticCanvasSize=Enum.AutomaticSize.Y
    scroll.Parent=content
    local list=Instance.new("UIListLayout"); list.Padding=UDim.new(0,4); list.Parent=scroll
    Instance.new("UIPadding", scroll).PaddingLeft=UDim.new(0,4)

    local ARKHER = game:GetService("ReplicatedStorage"):WaitForChild("ARKHER")
    local genFolder = ARKHER:FindFirstChild("generated")
    local ids = {}
    if genFolder then
        for _,m in genFolder:GetChildren() do
            if m:IsA("ModuleScript") and m.Name:match("^ARKHER_V1_") then table.insert(ids, m.Name) end
        end
        table.sort(ids)
    else
        -- fallback from registry
        local ok, reg = pcall(function() return require(ARKHER.generated.registry) end)
        if ok and reg and reg.ids then ids = reg.ids end
    end

    local rows = {}

    local function rebuild(filter: string)
        for _,r in rows do r:Destroy() end
        rows={}
        local fLower = filter:lower()
        local shown=0
        for _,id in ids do
            if fLower=="" or id:lower():find(fLower,1,true) then
                shown+=1
                if shown>80 then break end -- limit visible for perf
                local btn=Instance.new("TextButton")
                btn.Size=UDim2.new(1,-8,0,26)
                btn.BackgroundColor3=Theme.tokens.slate800
                btn.Text="  "..id
                btn.Font=Enum.Font.Gotham
                btn.TextSize=11
                btn.TextColor3=Theme.tokens.slate200
                btn.TextXAlignment=Enum.TextXAlignment.Left
                btn.Parent=scroll
                local cc=Instance.new("UICorner"); cc.CornerRadius=UDim.new(0,6); cc.Parent=btn
                local st2=Instance.new("UIStroke"); st2.Color=Theme.roles.border; st2.Thickness=1; st2.Parent=btn
                btn.MouseButton1Click:Connect(function() onOpen(id) end)
                btn.MouseEnter:Connect(function() btn.BackgroundColor3=Theme.tokens.slate700 end)
                btn.MouseLeave:Connect(function() btn.BackgroundColor3=Theme.tokens.slate800 end)
                table.insert(rows, btn)
            end
        end
        if #rows==0 then
            local lbl=Instance.new("TextLabel"); lbl.Size=UDim2.new(1,0,0,30); lbl.BackgroundTransparency=1; lbl.Text="No match"; lbl.Font=Enum.Font.Gotham; lbl.TextSize=11; lbl.TextColor3=Theme.tokens.slate400; lbl.Parent=scroll; table.insert(rows,lbl)
        end
    end

    search:GetPropertyChangedSignal("Text"):Connect(function() rebuild(search.Text) end)
    rebuild("")

    local self=setmetatable({Win=win}, Palette)
    function self:Toggle() win:Toggle() end
    function self:Show() win:Show() end
    return self
end

return Palette
