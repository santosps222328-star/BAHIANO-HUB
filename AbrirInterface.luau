-- BAHIANO HUB: CyberBlue + farm experimental com módulos próprios.
-- Extraia RedzCyberBlue/ para a pasta workspace de arquivos do executor.
assert(type(readfile) == "function", "Este teste local precisa de readfile.")
assert(type(loadstring) == "function", "Este teste local precisa de loadstring.")

local root = "RedzCyberBlue"
local environment = (getgenv and getgenv()) or (getfenv and getfenv()) or {}
local visuals = environment.RedzCyberBlue or {}
assert(type(visuals) == "table", "RedzCyberBlue deve ser uma tabela de configurações.")
visuals.AssetFolder = visuals.AssetFolder or (root .. "/assets")
environment.RedzCyberBlue = visuals

local function loadLocal(path)
    local ok, source = pcall(readfile, path)
    assert(ok and type(source) == "string" and #source > 0,
        "Não foi possível ler o arquivo local: " .. path)
    local chunk, message = loadstring(source, "@" .. path)
    assert(chunk, message)
    return chunk()
end

-- Reexecutar este teste fecha apenas a instância anterior criada pelo teste.
if environment.RedzCyberBluePreview then
    if environment.BahianoServices then pcall(function() environment.BahianoServices:close() end) end
    if environment.BahianoFarm then pcall(function() environment.BahianoFarm:stop("Reexecução.") end) end
    pcall(function() environment.RedzCyberBluePreview:Destroy() end)
end
local library = loadLocal(root .. "/Library/main.luau")
environment.RedzCyberBluePreview = library
local ok, icons = pcall(loadLocal, root .. "/Library/Utils/Icons.lua")
if ok and type(icons) == "table" then
    library.Icons = icons
end

local window = library:MakeWindow({
    Title = "BAHIANO HUB",
    SubTitle = "CYBER BLUE / FARM EXPERIMENTAL",
    ScriptFolder = root .. "/PreviewSettings",
})
library:SetTheme("CyberBlue")

local home = window:MakeTab({Name = "Início", Icon = "home"})
home:AddParagraph("CYBER BLUE", "Tema azul/cyberpunk com seu banner como fundo e os pinguins como avatar do criador.")
home:AddParagraph("Farm experimental", "Módulos próprios, sem hubs externos. Começa desligado. Primeiro teste: Terceiro Mar, nível 2550, perto do Tiki Quest Giver 3. Execução no jogo ainda precisa ser validada.")
home:AddButton({Name = "Testar notificação", Callback = function()
    window:Notify({Title = "BAHIANO HUB", Content = "Interface ativa. Veja status e diagnóstico na aba Farm."})
end})

local farmTab = window:MakeTab({Name = "Farm", Icon = "swords"})
local status = farmTab:AddParagraph("Auto Farm Level — OFF", "Desligado. Selecione equipamento antes de ativar.")
local Config = loadLocal(root .. "/Modules/FarmConfig.luau")
local Resolver = loadLocal(root .. "/Modules/QuestResolver.luau")
local Controller = loadLocal(root .. "/Modules/AutoFarm.luau")
local http = game:GetService("HttpService")
local settings = Config.load(root .. "/FarmSettings.json", http)
local context = {player = game:GetService("Players").LocalPlayer, players = game:GetService("Players"),
    storage = game:GetService("ReplicatedStorage"), world = workspace, placeId = game.PlaceId,
    tweens = game:GetService("TweenService")}
pcall(function() context.input = game:GetService("VirtualUser") end)
local resolver = Resolver.new(context, loadLocal(root .. "/Data/QuestFallback.luau"), loadLocal(root .. "/Data/NPCNames.luau"))
local toggle, closed = nil, false
local farm = Controller.new(context, resolver, settings, function(state, detail, enabled)
    if closed then return end
    status:SetTitle("Auto Farm Level — " .. state)
    status:SetDescription(detail)
    if not enabled and toggle and toggle.Value then toggle:SetValue(false) end
end)
environment.BahianoFarm = farm
local function change(key, value)
    if closed or settings[key] == value then return end
    if farm.enabled then farm:stop("Configuração alterada. Ative novamente quando estiver pronto.") end
    settings[key] = value
    local saved, reason = Config.save(root .. "/FarmSettings.json", http, settings)
    if not saved then warn("[BAHIANO HUB] Config não salva: " .. tostring(reason)) end
end
farmTab:AddDropdown({Name = "Equipamento", Options = {"Melee", "Sword", "Equipped"}, Default = settings.equipment,
    Callback = function(value) change("equipment", value) end})
farmTab:AddParagraph("Escolha da arma", "Melee: estilo de luta. Sword: espada. Equipped: ferramenta já na mão (permite escolher uma específica). Não seleciona fruta/arma automaticamente.")
farmTab:AddDropdown({Name = "Ataque", Options = {"Tool", "Click"}, Default = settings.attackMode,
    Callback = function(value) change("attackMode", value) end})
farmTab:AddDropdown({Name = "Movimento", Options = {"Walk", "Tween"}, Default = settings.movement,
    Callback = function(value) change("movement", value) end})
farmTab:AddParagraph("Limites", "Walk não calcula rotas entre ilhas. Tween é experimental e pode ser corrigido pelo servidor. Sem dano confirmado em 15s: para com erro. Missão diferente: cancele manualmente; o hub não a abandona.")
toggle = farmTab:AddToggle({Name = "Auto Farm Level", Default = false, Callback = function(enabled)
    if closed then return end
    -- A biblioteca agenda callbacks; ignora valores antigos já substituídos.
    if toggle and toggle.Value ~= enabled then return end
    if enabled then
        if environment.BahianoServices then environment.BahianoServices:selectMovement(farm) end
        farm:start()
    elseif farm.enabled then farm:stop() end
end})
farmTab:AddButton({Name = "Parar agora", Callback = function() farm:stop("Parada manual.") end})
local diagnostic = farmTab:AddParagraph("Diagnóstico", "Clique abaixo e envie o texto ou captura se o farm não funcionar.")
farmTab:AddButton({Name = "Gerar / copiar diagnóstico", Callback = function()
    local report = farm:diagnostic()
    diagnostic:SetDescription(report)
    if type(setclipboard) == "function" then pcall(setclipboard, report) end
    if type(writefile) == "function" then pcall(writefile, root .. "/DIAGNOSTICO.txt", report) end
end})
window:GetElements().MainFrame.Destroying:Connect(function()
    closed = true
    if environment.BahianoServices then environment.BahianoServices:close() end
    farm:stop("Interface fechada.")
end)

local Integration = loadLocal(root .. "/Modules/SourceIntegration.luau")
environment.BahianoServices = Integration.attach(window, {
    context = context, farm = farm, resolver = resolver, settings = settings,
    load = function(path) return loadLocal(root .. "/" .. path) end,
})

local visual = window:MakeTab({Name = "Aparência", Icon = "palette"})
visual:AddToggle({Name = "Mostrar imagem de fundo", Default = true, Callback = function(enabled)
    window:GetElements().BackgroundImage.Visible = enabled
end})
visual:AddSlider({Name = "Intensidade da imagem", Min = 0, Max = 100, Increment = 1,
    Default = math.floor((1 - window:GetElements().BackgroundImage.ImageTransparency) * 100),
    Callback = function(value)
        window:GetElements().BackgroundImage.ImageTransparency = 1 - value / 100
    end,
})
visual:AddSlider({Name = "Escala da interface", Min = 60, Max = 160, Increment = 5, Default = 100,
    Callback = function(value) library:SetUIScale(value / 100) end,
})
visual:AddButton({Name = "Tema CyberBlue", Callback = function() library:SetTheme("CyberBlue") end})
visual:AddButton({Name = "Tema escuro original", Callback = function() library:SetTheme("Darker") end})

local creator = window:MakeTab({Name = "Criador", Icon = "user"})
creator:AddParagraph(tostring(library.CyberpunkSettings.CreatorName), "Avatar: imagem dos pinguins fornecida por você, exibida no cabeçalho.")
creator:AddParagraph("Créditos", "Biblioteca original: tlredz / Redz Hub. Tema personalizado: CyberBlue. Referências legíveis de quests/NPCs: arquivos fornecidos do projeto original. Farm e configuração: módulos desta edição BAHIANO HUB; a autoria original da biblioteca é preservada.")
creator:AddParagraph("Se as imagens não aparecerem", "Consulte LEIA-ME.txt: o executor precisa aceitar arquivos locais como imagens, ou você deve fornecer IDs de imagem do Roblox.")

window:SelectTab(1)
if window:GetElements().BackgroundImage.Image == "" then
    window:Notify({Title = "Imagens não carregadas", Content = "A interface abriu com fundo azul. Confira a pasta assets ou configure IDs de imagem do Roblox."})
end
return window