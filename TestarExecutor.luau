-- BAHIANO HUB: interface + módulos próprios de farm experimental.
local base = "https://raw.githubusercontent.com/santosps222328-star/BAHIANO-HUB/main/"
local root = "RedzCyberBlue"

assert(type(readfile) == "function", "Seu executor não oferece readfile.")
assert(type(writefile) == "function", "Seu executor não oferece writefile.")
assert(type(makefolder) == "function", "Seu executor não oferece makefolder.")
assert(type(loadstring) == "function", "Seu executor não oferece loadstring.")

-- Para a edição anterior ANTES de baixar arquivos: falha HTTP não deixa um farm antigo rodando.
local environment = (getgenv and getgenv()) or (getfenv and getfenv()) or {}
if environment.BahianoServices then pcall(function() environment.BahianoServices:close() end) end
if environment.BahianoFarm then pcall(function() environment.BahianoFarm:stop("Reexecução do loader.") end) end
if environment.RedzCyberBluePreview then pcall(function() environment.RedzCyberBluePreview:Destroy() end) end

for _, folder in {root, root .. "/Library", root .. "/Library/Utils", root .. "/assets", root .. "/PreviewSettings", root .. "/Modules", root .. "/Data"} do
    local ok, message = pcall(makefolder, folder)
    if not ok and type(isfolder) == "function" then
        assert(isfolder(folder), "Não foi possível criar " .. folder .. ": " .. tostring(message))
    end
end

local function download(path)
    local ok, content = pcall(function() return game:HttpGet(base .. path) end)
    assert(ok and type(content) == "string" and #content > 0,
        "Falha ao baixar " .. path .. ": " .. tostring(content))
    assert(content ~= "404: Not Found", "Arquivo não encontrado: " .. path)
    return content
end

local sources = {}
for _, path in {"Library/main.luau", "Library/Utils/Icons.lua", "AbrirInterface.luau",
    "Modules/FarmConfig.luau", "Modules/QuestResolver.luau", "Modules/AutoFarm.luau",
    "Modules/HubServices.luau", "Modules/TargetFarm.luau", "Modules/SourceIntegration.luau", "Modules/FruitRaid.luau",
    "Data/QuestFallback.luau", "Data/NPCNames.luau", "Data/SourceActions.luau",
    "Data/FeatureCatalog.luau", "Data/FarmTargets.luau"} do
    local source = download(path)
    local compiled, message = loadstring(source, "@" .. path)
    assert(compiled, "Erro de sintaxe em " .. path .. ": " .. tostring(message))
    sources[path] = source
end
-- Só atualiza arquivos depois que TODOS os módulos baixaram e compilaram.
for path, source in pairs(sources) do writefile(root .. "/" .. path, source) end

-- Imagens são opcionais: falhas não impedem o tema azul de abrir.
if type(getcustomasset or getsynasset) == "function" then
    for _, path in {"assets/banner.png", "assets/creator.jpg"} do
        local ok, message = pcall(function() writefile(root .. "/" .. path, download(path)) end)
        if not ok then warn("[BAHIANO-HUB] Imagem indisponível: " .. path .. " / " .. tostring(message)) end
    end
else
    warn("[BAHIANO-HUB] Sem suporte a imagens locais. O teste usará fundo azul e avatar alternativo.")
end

local settings = environment.RedzCyberBlue or {}
assert(type(settings) == "table", "RedzCyberBlue deve ser uma tabela.")
settings.AssetFolder = root .. "/assets"
environment.RedzCyberBlue = settings

local start, message = loadstring(readfile(root .. "/AbrirInterface.luau"), "@AbrirInterface.luau")
assert(start, message)
return start()