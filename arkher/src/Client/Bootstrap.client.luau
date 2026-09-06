local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local package=ReplicatedStorage:WaitForChild("ARKHER",30)
if not package then warn("[ARKHER] Pacote não instalado em ReplicatedStorage. Consulte o guia de instalação.");return end
local Entry=require(package:WaitForChild("Client"):WaitForChild("Entry"))
local ok,cleanup=pcall(Entry.start,package,Players.LocalPlayer)
if not ok then warn("[ARKHER] Falha na inicialização do editor: "..tostring(cleanup));return end
script.Destroying:Connect(cleanup)
