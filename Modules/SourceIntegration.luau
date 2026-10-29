-- Interface única para módulos próprios + catálogo auditável das seis fontes.
local Integration={}

function Integration.attach(window, options)
    local load=options.load
    local Services=load("Modules/HubServices.luau")
    local Controller=load("Modules/AutoFarm.luau")
    local Target=load("Modules/TargetFarm.luau")
    local actions=load("Data/SourceActions.luau")
    local catalog=load("Data/FeatureCatalog.luau")
    local targets=load("Data/FarmTargets.luau")
    local context=options.context
    local services=Services.new(context,function(title,detail) window:Notify({Title=title,Content=detail}) end)
    function services:selectMovement(controller)
        if self.movement and self.movement~=controller then self.movement:stop("Outro módulo assumiu o movimento.") end
        self.movement=controller
    end
    local function toggle(tab,name,callback)
        local element
        local function off() if element and element.Value then element:SetValue(false) end end
        element=tab:AddToggle({Name=name,Default=false,Callback=function(value)
            if services.closed or (element and element.Value~=value) then return end
            local ok,reason=pcall(callback,value,off)
            if not ok then off();services:message(name.." — OFF",reason) end
        end})
        return element
    end
    local function button(tab,name,callback)
        return tab:AddButton({Name=name,Callback=function()
            if services.closed then return end
            local ok,reason=pcall(callback)
            if not ok then services:message(name,reason) end
        end})
    end

    local shop=window:MakeTab({Name="Loja / comandos",Icon="shopping-cart"})
    shop:AddParagraph("Comandos portados, não compras confirmadas",tostring(#actions).." callbacks simples reunidos por assinatura. Crédito e argumentos disponíveis abaixo. Servidor valida requisitos/custos. Não há compra automática ao abrir.")
    toggle(shop,"Autorizar testes experimentais",function(value)
        services.experimental=value
        services.armed=nil
        if not value then services:stopAll() end
    end)
    local actionNames,byName={},{}
    for _,action in ipairs(actions) do table.insert(actionNames,action.label);byName[action.label]=action end
    local selected=actions[1]
    local actionInfo=shop:AddParagraph("Ação selecionada","Escolha um comando. Execução requer autorização + segundo clique de confirmação.")
    shop:AddDropdown({Name="Comando",Options=actionNames,Default=actionNames[1],Callback=function(value)
        selected=byName[value];services.armed=nil
        if not selected then return end
        local args={};for _,arg in ipairs(selected.args) do table.insert(args,tostring(arg)) end
        local source=selected.sources[1]
        actionInfo:SetDescription(table.concat(args," / ").."\nReferência: "..source.file..":"..source.line.."\nExperimental. Pode consumir moedas, itens, resetar stats/raça ou trocar mar/time.")
    end})
    button(shop,"Executar comando (2 cliques)",function()
        assert(services.experimental,"Bloqueado: autorize testes experimentais primeiro.")
        assert(selected,"Selecione um comando.")
        local action=selected
        services:confirm(action.label,function()
            if services.movement then services.movement:stop("Comando manual.") end
            return services:remote(action.args)
        end)
    end)

    local other=window:MakeTab({Name="Farm / alvos",Icon="crosshair"})
    other:AddParagraph("Um controlador de movimento", "Farm Level, materiais, ossos, ectoplasm e NPC escolhido não rodam juntos. O último ativado para o anterior. Ataque normal, com verificação de HP; não há magnet/fast attack externo.")
    local eligible,names={},{}
    local sea=options.resolver.seaForPlace(context.placeId)
    for _,def in ipairs(targets) do if def.sea==sea then eligible[def.name]=def;table.insert(names,def.name) end end
    table.insert(names,1,"NPC mais próximo")
    eligible["NPC mais próximo"]={name="NPC mais próximo",nearest=true,enemies={}}
    local chosen=eligible[names[1]]
    local targetStatus=other:AddParagraph("Farm por alvo — OFF","Selecione um grupo ou NPC local. Não aceita quests, invoca bosses nem comprova drops.")
    local controller,targetToggle
    controller=Controller.new(context,options.resolver,options.settings,function(state,detail,enabled)
        if services.closed then return end
        targetStatus:SetTitle("Farm por alvo — "..state);targetStatus:SetDescription(detail)
        if not enabled and targetToggle and targetToggle.Value then targetToggle:SetValue(false) end
    end)
    local function targetChoice(def)
        controller:stop("Alvo alterado; ative novamente.")
        chosen=def
    end
    other:AddDropdown({Name="Grupo de farm",Options=names,Default=names[1],Callback=function(value)
        if eligible[value]~=chosen then targetChoice(eligible[value]) end
    end})
    local liveNames={"Selecione / atualize"}
    local liveDrop
    liveDrop=other:AddDropdown({Name="Boss / NPC presente",Options=liveNames,Default=liveNames[1],Callback=function(value)
        if value~="Selecione / atualize" then targetChoice({name=value,enemies={value}}) end
    end})
    button(other,"Atualizar NPCs presentes",function()
        local folder=context.world:FindFirstChild("Enemies")
        local found={};liveNames={"Selecione / atualize"}
        if folder then for _,npc in ipairs(folder:GetChildren()) do
            if npc:IsA("Model") and not context.players:GetPlayerFromCharacter(npc) and not found[npc.Name] then
                found[npc.Name]=true;table.insert(liveNames,npc.Name)
            end
        end end
        table.sort(liveNames);liveDrop:NewOptions(liveNames)
    end)
    targetToggle=toggle(other,"Auto Farm alvo selecionado",function(enabled)
        if enabled then
            assert(services.experimental,"Autorize testes experimentais na aba Loja / comandos.")
            assert(chosen,"Escolha um alvo.")
            services:selectMovement(controller)
            Target.configure(controller,chosen):start()
        else controller:stop() end
    end)
    button(other,"Parar todos os módulos",function() options.farm:stop("Parar tudo.");controller:stop("Parar tudo.");services:stopAll() end)

    local util=window:MakeTab({Name="Utilitários / ESP",Icon="settings"})
    util:AddParagraph("Alterações locais reversíveis","Sem autoexecução. FPS Booster restaura as propriedades alteradas; ESP cria apenas etiquetas próprias. Recursos de bypass e propriedades ocultas não foram carregados.")
    toggle(util,"Anti AFK",function(v,off) services:antiAFK(v,off) end)
    toggle(util,"FPS Booster reversível",function(v,off) services:fps(v,off) end)
    local light=game:GetService("Lighting")
    toggle(util,"Remover neblina",function(v,off)
        local original=light.FogEnd
        services:set("Remove Fog",v,1,function() light.FogEnd=100000 end,function() light.FogEnd=original end,off)
    end)
    toggle(util,"Full Bright",function(v,off)
        local original={Brightness=light.Brightness,Ambient=light.Ambient}
        services:set("Full Bright",v,1,function() light.Brightness=2;light.Ambient=Color3.fromRGB(180,180,180) end,
            function() light.Brightness=original.Brightness;light.Ambient=original.Ambient end,off)
    end)
    local function children(folder) return if folder then folder:GetChildren() else {} end
    toggle(util,"ESP NPCs",function(v,off) services:esp("ESP NPCs",function() return children(context.world:FindFirstChild("NPCs")) end,v,off) end)
    toggle(util,"ESP inimigos",function(v,off) services:esp("ESP enemies",function() return children(context.world:FindFirstChild("Enemies")) end,v,off) end)
    toggle(util,"ESP jogadores",function(v,off) services:esp("ESP players",function()
        local models={}
        for _,player in ipairs(context.players:GetPlayers()) do if player~=context.player and player.Character then table.insert(models,player.Character) end end
        return models
    end,v,off) end)
    toggle(util,"ESP frutas",function(v,off) services:esp("ESP fruits",function()
        local fruits={}
        for _,obj in ipairs(context.world:GetChildren()) do if obj:IsA("Tool") and obj.Name:find("Fruit",1,true) then table.insert(fruits,obj) end end
        return fruits
    end,v,off) end)
    toggle(util,"ESP ilhas / localizações",function(v,off) services:esp("ESP islands",function()
        local origin=context.world:FindFirstChild("_WorldOrigin")
        return children(origin and origin:FindFirstChild("Locations"))
    end,v,off) end)
    button(util,"Copiar Job ID",function()
        assert(type(setclipboard)=="function","setclipboard indisponível.")
        setclipboard(game.JobId);services:message("Job ID",game.JobId)
    end)
    button(util,"Reentrar no servidor (2 cliques)",function()
        services:confirm("Rejoin Server",function()
            services:stopAll();options.farm:stop("Rejoin.")
            return game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId,game.JobId,context.player)
        end)
    end)
    local points=1
    util:AddSlider({Name="Pontos por pedido de stats",Min=1,Max=100,Increment=1,Default=1,Callback=function(value) points=value end})
    util:AddParagraph("Auto Stats — experimental","Distribui pontos disponíveis (irreversível sem reset do jogo). Precisa da autorização na aba Loja. Os cinco atributos usam o mesmo serviço sem spam.")
    for _,stat in ipairs({"Melee","Defense","Sword","Gun","Demon Fruit"}) do
        toggle(util,"Auto Stats: "..stat,function(v,off) services:stats(stat,v,function() return points end,off) end)
    end

    load("Modules/FruitRaid.luau").attach(window,services,options,{button=button,toggle=toggle})

    local reference=window:MakeTab({Name="Todas as funções",Icon="list"})
    reference:AddParagraph("Catálogo das seis fontes",tostring(#catalog).." rótulos distintos normalizados, com origem/linha. Isso NÃO significa "..#catalog.." automações implementadas. Portados: comandos simples, farm e utilitários desta edição. Os demais estão explicitamente indisponíveis.")
    local mapped=0
    for _,entry in ipairs(catalog) do if entry.implementation then mapped+=1 end end
    reference:AddParagraph("Cobertura desta edição",mapped.." rótulos/aliases apontam para módulos portados; "..(#catalog-mapped).." ainda estão INDISPONÍVEIS. As implementações de jogo portadas também exigem teste no Delta.")
    local categories,grouped={},{}
    for _,entry in ipairs(catalog) do
        if not grouped[entry.category] then grouped[entry.category]={};table.insert(categories,entry.category) end
        table.insert(grouped[entry.category],entry)
    end
    table.sort(categories)
    local lookup,featureOptions={},{}
    local detail=reference:AddParagraph("Situação do recurso","Selecione uma categoria e função para ver implementação e referência.")
    local function show(label)
        local entry=lookup[label];if not entry then return end
        local sources={}
        for i,source in ipairs(entry.sources) do
            if i>6 then table.insert(sources,"... mais "..(#entry.sources-6).." referências");break end
            table.insert(sources,source.file..":"..source.line)
        end
        local availability
        if entry.implementation and entry.implementation:sub(1,6)=="action" then
            availability="PORTADO / EXPERIMENTAL — aba Loja / comandos; autorização e confirmação obrigatórias. Resposta do servidor não comprova sucesso."
        elseif entry.implementation then
            availability="PORTADO — "..entry.implementation..". Confira o escopo na aba correspondente; variantes de bypass/fast attack não estão habilitadas."
        else
            availability="INDISPONÍVEL — callback original ainda não portado/validado com todas as dependências. Não existe botão de execução para esta função. Código original está no ZIP apenas para auditoria."
            local lower=entry.label:lower()
            if lower:find("fast attack",1,true) or lower:find("bring",1,true) then availability..=" Alguns hubs dependem de FastAttackLoader/BringMobLoader externos, que não foram incluídos no executor." end
        end
        detail:SetTitle(entry.label)
        detail:SetDescription(availability.."\n"..table.concat(sources,"\n"))
    end
    local featureDrop=reference:AddDropdown({Name="Função (consulta, não execução)",Options={"Escolha categoria"},Default="Escolha categoria",Callback=show})
    reference:AddDropdown({Name="Categoria",Options=categories,Default=categories[1],Callback=function(category)
        lookup,featureOptions={},{}
        for _,entry in ipairs(grouped[category] or {}) do
            local label=(if entry.implementation then "[PORTADO] " else "[INDISPONÍVEL] ")..entry.label
            lookup[label]=entry;table.insert(featureOptions,label)
        end
        table.sort(featureOptions);featureDrop:NewOptions(featureOptions)
        if featureOptions[1] then show(featureOptions[1]) end
    end})
    reference:AddParagraph("Créditos / limites","Fontes fornecidas: Eclipse, Fai Fao, Kakah Menu (2 versões), Skibidi/Haidepzai e Xester. Biblioteca visual: tlredz / Redz Hub. Ter código legível não comprova licença de redistribuição. Não há promessa antiban nem validação no Roblox neste ambiente.")
    reference:AddParagraph("Não carregado","Webhooks, auto-load koby, bibliotecas Fluent/Paste, FastAttackLoader, BringMobLoader, kick/shutdown e inicializadores dos hubs não são executados. Nenhuma automação importa os originais em AUDITORIA.")
    return services
end

return Integration