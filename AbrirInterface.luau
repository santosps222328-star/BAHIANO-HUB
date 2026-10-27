-- Redz CyberBlue: teste SOMENTE da interface. Não carrega scripts de jogos.
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
    pcall(function() environment.RedzCyberBluePreview:Destroy() end)
end
local library = loadLocal(root .. "/Library/main.luau")
environment.RedzCyberBluePreview = library
local ok, icons = pcall(loadLocal, root .. "/Library/Utils/Icons.lua")
if ok and type(icons) == "table" then
    library.Icons = icons
end

local window = library:MakeWindow({
    Title = "Redz Hub",
    SubTitle = "CYBER BLUE / INTERFACE",
    ScriptFolder = root .. "/PreviewSettings",
})
library:SetTheme("CyberBlue")

local home = window:MakeTab({Name = "Início", Icon = "home"})
home:AddParagraph("CYBER BLUE", "Tema azul/cyberpunk com seu banner como fundo e os pinguins como avatar do criador.")
home:AddParagraph("Somente interface", "Este arquivo não faz farm, coleta itens nem carrega o loader original. O BloxFruits.luau recebido está vazio.")
home:AddButton({Name = "Testar notificação", Callback = function()
    window:Notify({Title = "Redz Hub", Content = "Teste visual de notificação. Nenhuma função de jogo foi executada."})
end})

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
creator:AddParagraph("Créditos", "Biblioteca original: tlredz / Redz Hub. Esta edição altera apenas a aparência; não substitui a autoria original.")
creator:AddParagraph("Se as imagens não aparecerem", "Consulte LEIA-ME.txt: o executor precisa aceitar arquivos locais como imagens, ou você deve fornecer IDs de imagem do Roblox.")

window:SelectTab(1)
if window:GetElements().BackgroundImage.Image == "" then
    window:Notify({Title = "Imagens não carregadas", Content = "A interface abriu com fundo azul. Confira a pasta assets ou configure IDs de imagem do Roblox."})
end
return window