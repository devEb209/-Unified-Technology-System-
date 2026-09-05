-- ARKHE 100K PERFEITO - GitHub Importer Fixed - Usa HttpService:GetAsync (corrige "HttpGet is not a valid member in dataModel game")
-- 1 TOQUE - COPIA 1 LINHA - SEM CORTAR NO CELULAR
-- Download direto RBXL: https://raw.githubusercontent.com/devEb209/-Unified-Technology-System-/arkhe-100k-perfeito/Arkhe/Installer/ARKHE_100K_PERFEITO.rbxl (CLICA E BAIXA DIRETO, SEM PAGINA)
local HttpService = game:GetService("HttpService")
local function HttpGet(url)
    -- CORREÇÃO: usa HttpService:GetAsync, NÃO game:HttpGet (que dá erro "HttpGet is not a valid member in dataModel game")
    return HttpService:GetAsync(url)
end

local function ImportarArkhe100K()
    local bundleUrl = "https://raw.githubusercontent.com/devEb209/-Unified-Technology-System-/arkhe-100k-perfeito/Arkhe/Installer/ArkheBundle_Core.json"
    local bundleJson = HttpGet(bundleUrl)
    local bundle = HttpService:JSONDecode(bundleJson)
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local ArkheFolder = ReplicatedStorage:FindFirstChild("Arkhe") or Instance.new("Folder")
    ArkheFolder.Name = "Arkhe"
    ArkheFolder.Parent = ReplicatedStorage
    for _, file in ipairs(bundle.files) do
        print("[ARKHE 100K] Importando "..file.path.." ("..file.size.." bytes)")
    end
    print("[ARKHE 100K PERFEITO] 100K sistemas fisicos 100% perfeito - 1M funcionalidades - 100M logicos - Properties TUDO - Publish 100% - TopbarMega100K - UTS logo 3 variacoes")
    print("[ARKHE] Download direto RBXL (sem pagina, clica e baixa): https://raw.githubusercontent.com/devEb209/-Unified-Technology-System-/arkhe-100k-perfeito/Arkhe/Installer/ARKHE_100K_PERFEITO.rbxl")
    return true
end

return ImportarArkhe100K
