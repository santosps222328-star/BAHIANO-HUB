-- Portas próprias para contratos simples presentes nas fontes; teste explícito obrigatório.
local Extras={}

function Extras.attach(window,services,options,ui)
    local ctx=options.context
    local fruit=window:MakeTab({Name="Frutas / raids",Icon="cherry"})
    fruit:AddParagraph("Experimental / sem compras automáticas","GetFruits, PurchaseRawFruit, Cousin, StoreFruit, RaidsNpc e Awakener são referências dos arquivos fornecidos. Requisitos atuais são validados pelo jogo. Autorize o teste na aba Loja; compras exigem confirmação.")
    local stock={}
    local selectedStock,selectedTool
    local info=fruit:AddParagraph("Estoque / ferramentas","Atualize o estoque ou as frutas na mochila. Não há lista de preços inventada.")
    local stockDrop=fruit:AddDropdown({Name="Fruta no estoque",Options={"Atualize o estoque"},Default="Atualize o estoque",Callback=function(value)
        selectedStock=stock[value];services.armed=nil
        if selectedStock then info:SetDescription(selectedStock.Name.." | Price: "..tostring(selectedStock.Price).." | OnSale: "..tostring(selectedStock.OnSale)) end
    end})
    ui.button(fruit,"Consultar estoque atual",function()
        local response=services:remote({"GetFruits",false})
        assert(type(response)=="table","GetFruits não retornou uma tabela.")
        stock={};local labels={}
        for _,entry in pairs(response) do
            if type(entry)=="table" and type(entry.Name)=="string" and entry.OnSale==true then
                stock[entry.Name]=entry;table.insert(labels,entry.Name)
            end
        end
        table.sort(labels)
        if #labels==0 then labels={"Nenhuma fruta à venda"} end
        stockDrop:NewOptions(labels)
    end)
    ui.button(fruit,"Comprar fruta selecionada (2 cliques)",function()
        assert(selectedStock,"Atualize e selecione uma fruta disponível.")
        local name=selectedStock.Name
        services:confirm("PurchaseRawFruit: "..name,function() return services:remote({"PurchaseRawFruit",name}) end)
    end)
    ui.button(fruit,"Random Fruit / comprar do Cousin (2 cliques)",function()
        services:confirm("Cousin Buy",function() return services:remote({"Cousin","Buy"}) end)
    end)
    local tools={}
    local function originalName(tool)
        local remote=tool:FindFirstChild("EatRemote",true)
        return tool:GetAttribute("OriginalName") or (remote and remote.Parent:GetAttribute("OriginalName"))
    end
    local function availableTools()
        local output={}
        local containers={}
        local backpack=ctx.player:FindFirstChild("Backpack")
        if backpack then table.insert(containers,backpack) end
        if ctx.player.Character then table.insert(containers,ctx.player.Character) end
        for _,container in ipairs(containers) do
            for _,tool in ipairs(container:GetChildren()) do
                if tool:IsA("Tool") and type(originalName(tool))=="string" then table.insert(output,tool) end
            end
        end
        return output
    end
    local toolDrop=fruit:AddDropdown({Name="Fruta física para guardar",Options={"Atualize a mochila"},Default="Atualize a mochila",Callback=function(value)
        selectedTool=tools[value];services.armed=nil
    end})
    ui.button(fruit,"Atualizar frutas na mochila",function()
        tools={};local labels={}
        for index,tool in ipairs(availableTools()) do
            local label=tool.Name.." #"..index;tools[label]=tool;table.insert(labels,label)
        end
        if #labels==0 then labels={"Nenhuma fruta com OriginalName reconhecido"} end
        toolDrop:NewOptions(labels)
    end)
    ui.button(fruit,"Guardar fruta selecionada (2 cliques)",function()
        assert(selectedTool and selectedTool.Parent,"Escolha uma fruta física disponível.")
        local tool=selectedTool;local name=originalName(tool)
        services:confirm("StoreFruit: "..tostring(name),function()
            assert(tool.Parent,"Fruta não está mais disponível.")
            return services:remote({"StoreFruit",name,tool})
        end)
    end)
    ui.toggle(fruit,"Auto Store Fruit (experimental)",function(enabled,off)
        assert(not enabled or services.experimental,"Autorize testes experimentais primeiro.")
        local attempted=setmetatable({},{__mode="k"})
        services:set("Auto Store Fruit",enabled,5,function(active)
            for _,tool in ipairs(availableTools()) do
                if not active() then return end
                if not attempted[tool] and not services.pending then
                    attempted[tool]=true
                    local response=services:remote({"StoreFruit",originalName(tool),tool},active)
                    services:message("StoreFruit / resposta",response)
                    -- Uma tentativa por instância; evita spam se o armazenamento estiver cheio.
                end
            end
        end,nil,off)
    end)
    fruit:AddParagraph("Raids / escopo","Compra de chip e pedido de despertar estão portados. Auto Complete Raid, Kill Aura, Kill NPC por alteração de HP e próximo estágio automático permanecem indisponíveis; não há falsa conclusão de raid.")
    local chip="Flame"
    fruit:AddDropdown({Name="Select Chip",Options={"Flame","Ice","Quake","Light","Dark","String","Rumble","Magma","Human: Buddha","Sand","Bird: Phoenix","Dough"},Default=chip,Callback=function(value)
        chip=value;services.armed=nil
    end})
    ui.button(fruit,"Comprar chip selecionado (2 cliques)",function()
        local selected=chip
        services:confirm("RaidsNpc Select: "..selected,function() return services:remote({"RaidsNpc","Select",selected}) end)
    end)
    ui.button(fruit,"Consultar despertar",function() services:message("Awakener Check",services:remote({"Awakener","Check"})) end)
    ui.button(fruit,"Pedir despertar (2 cliques)",function()
        services:confirm("Awakener Awaken",function() return services:remote({"Awakener","Awaken"}) end)
    end)
    local status=fruit:AddParagraph("Status local","Clique em Atualizar para ler o timer do jogo; não prova conclusão de raid.")
    ui.button(fruit,"Atualizar status local",function()
        local gui=ctx.player:FindFirstChild("PlayerGui")
        local main=gui and gui:FindFirstChild("Main")
        local timer=main and main:FindFirstChild("Timer")
        status:SetDescription("Timer visible: "..tostring(timer and timer.Visible).." | Server time: "..math.floor(ctx.world.DistributedGameTime).."s")
    end)

    local playerTab=window:MakeTab({Name="Jogadores / câmera",Icon="users"})
    playerTab:AddParagraph("PvP — limites claros","ESP e spectate são locais. Aimbot de remotes, kill trial players, hitbox e ataques automáticos contra jogadores permanecem indisponíveis no catálogo.")
    local playerMap,playerNames={},{}
    local selectedPlayer
    local playerDrop=playerTab:AddDropdown({Name="Jogador para observar",Options={"Atualize jogadores"},Default="Atualize jogadores",Callback=function(value) selectedPlayer=playerMap[value] end})
    ui.button(playerTab,"Atualizar jogadores",function()
        playerMap,playerNames={},{}
        for _,player in ipairs(ctx.players:GetPlayers()) do
            if player~=ctx.player then playerMap[player.Name]=player;table.insert(playerNames,player.Name) end
        end
        table.sort(playerNames);if #playerNames==0 then playerNames={"Nenhum outro jogador"} end
        playerDrop:NewOptions(playerNames)
    end)
    ui.toggle(playerTab,"Spectate jogador selecionado",function(enabled,off)
        local camera=ctx.world.CurrentCamera
        local originalSubject=camera.CameraSubject
        services:set("Spectate",enabled,0.5,function()
            assert(selectedPlayer and selectedPlayer.Parent,"Jogador não selecionado/disponível.")
            local humanoid=selectedPlayer.Character and selectedPlayer.Character:FindFirstChildOfClass("Humanoid")
            assert(humanoid,"Jogador está sem personagem.")
            camera.CameraSubject=humanoid
        end,function()
            local selfHumanoid=ctx.player.Character and ctx.player.Character:FindFirstChildOfClass("Humanoid")
            camera.CameraSubject=selfHumanoid or originalSubject
        end,off)
    end)
end

return Extras