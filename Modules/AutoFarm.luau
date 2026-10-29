-- Controlador experimental: ações normais, sem remotes inventados de dano.
local AutoFarm = {}
AutoFarm.__index = AutoFarm

function AutoFarm.new(context, resolver, settings, onStatus)
    return setmetatable({context = context, resolver = resolver, settings = settings,
        onStatus = onStatus, enabled = false, token = 0, state = "OFF", detail = "Desligado",
        pending = false, lastRequest = -math.huge}, AutoFarm)
end

function AutoFarm:status(state, detail)
    self.state, self.detail = state, detail
    if self.onStatus then pcall(self.onStatus, state, detail, self.enabled) end
end

function AutoFarm:alive(token)
    return self.enabled and self.token == token
end

function AutoFarm:character()
    local model = self.context.player.Character
    local humanoid = model and model:FindFirstChildOfClass("Humanoid")
    local root = model and model:FindFirstChild("HumanoidRootPart")
    if not humanoid or not root or humanoid.Health <= 0 then return nil end
    return model, humanoid, root
end

function AutoFarm:tool()
    local model, humanoid = self:character()
    if not model then return nil end
    if self.settings.equipment == "Equipped" then return model:FindFirstChildOfClass("Tool") end
    for _, container in ipairs({model, self.context.player:FindFirstChild("Backpack")}) do
        for _, item in ipairs(container:GetChildren()) do
            if item:IsA("Tool") and item.ToolTip == self.settings.equipment then
                if item.Parent ~= model then humanoid:EquipTool(item) end
                return item
            end
        end
    end
    return nil
end

function AutoFarm:stop(reason)
    self.enabled = false
    self.token += 1
    if self.tween then self.tween:Cancel(); self.tween = nil end
    local _, humanoid, root = self:character()
    if humanoid then humanoid:MoveTo(root.Position) end
    if self.activeTool then pcall(function() self.activeTool:Deactivate() end) end
    self.activeTool = nil
    self:status("OFF", reason or "Desligado; movimento e ataques cancelados.")
end

function AutoFarm:move(position, radius, token)
    local model, humanoid, root = self:character()
    if not model then return false end
    local distance = (root.Position - position).Magnitude
    if distance <= radius then return true end
    local movementTween
    if self.settings.movement == "Tween" then
        local duration = math.clamp(distance / 90, 0.2, 30)
        local tween = self.context.tweens:Create(root, TweenInfo.new(duration, Enum.EasingStyle.Linear),
            {CFrame = CFrame.new(position + Vector3.new(0, 2, 0))})
        self.tween = tween
        movementTween = tween
        tween:Play()
    else
        humanoid:MoveTo(position)
    end
    local deadline = os.clock() + (if self.settings.movement == "Tween" then math.clamp(distance / 90, 0.2, 30) + 2 else 7)
    while self:alive(token) and os.clock() < deadline do
        if self.context.player.Character ~= model or humanoid.Health <= 0 then break end
        if (root.Position - position).Magnitude <= radius then break end
        task.wait(0.1)
    end
    if movementTween then movementTween:Cancel() end
    if self.tween == movementTween then self.tween = nil end
    if not self:alive(token) or self.context.player.Character ~= model or humanoid.Health <= 0 then return false end
    return (root.Position - position).Magnitude <= radius
end

function AutoFarm:startQuest(quest, token)
    if self.pending then error("StartQuest anterior ainda pendente; aguarde ou reentre no jogo.") end
    local remotes = self.context.storage:FindFirstChild("Remotes")
    local remote = remotes and remotes:FindFirstChild("CommF_")
    assert(remote and remote:IsA("RemoteFunction"), "Remotes.CommF_ indisponível.")
    while self:alive(token) and os.clock() - self.lastRequest < 3 do task.wait(0.1) end
    if not self:alive(token) then return end
    self.pending, self.lastRequest = true, os.clock()
    local done, ok, result = false, false, nil
    task.spawn(function()
        if not self:alive(token) then
            self.pending, done = false, true
            result = "Cancelado antes do envio."
            return
        end
        ok, result = pcall(function() return remote:InvokeServer("StartQuest", quest.id, quest.index) end)
        self.pending, done = false, true
    end)
    local deadline = os.clock() + 8
    while self:alive(token) and not done and os.clock() < deadline do task.wait(0.1) end
    if not self:alive(token) then return end
    assert(done, "StartQuest sem resposta em 8s. Pedido já enviado não pode ser retirado do servidor.")
    assert(ok, "StartQuest falhou: " .. tostring(result))
    deadline = os.clock() + 5
    while self:alive(token) and os.clock() < deadline do
        if self.resolver:matchesUI(quest, self.resolver:questUI()) then return end
        task.wait(0.2)
    end
    if self:alive(token) then error("Missão não confirmada na interface. Confira NPC, distância e título da missão.") end
end

function AutoFarm:attack(tool, target, root)
    root.CFrame = CFrame.lookAt(root.Position, target.root.Position)
    self.activeTool = tool
    if self.settings.attackMode == "Click" then
        local input = self.context.input
        assert(input, "Entrada virtual indisponível. Selecione Tool.")
        input:CaptureController()
        input:Button1Down(Vector2.new(0, 0), self.context.world.CurrentCamera.CFrame)
        -- Não há yield entre pressionar/soltar: evita entrada presa no cancelamento.
        input:Button1Up(Vector2.new(0, 0), self.context.world.CurrentCamera.CFrame)
    else
        tool:Activate()
    end
end

function AutoFarm:run(token)
    self:status("DADOS", "Lendo missões do jogo; fallback identificado como snapshot.")
    self.resolver:refresh()
    if not self:alive(token) then return end
    local previousQuest, targetModel, lastHealth, damageAt, navigationAt, activeQuest
    navigationAt = os.clock()
    while self:alive(token) do
        local model, humanoid, root = self:character()
        if not model then
            self:status("RESPAWN", "Esperando personagem vivo.")
            task.wait(0.5)
            navigationAt = os.clock()
            continue
        end
        local quest, reason = self.resolver:choose()
        assert(quest, reason)
        local ui = self.resolver:questUI()
        assert(ui, "PlayerGui.Main.Quest/título não reconhecido. Envie o diagnóstico.")
        -- Subir de nível no meio da missão não a abandona: termina a antiga e troca no ciclo seguinte.
        if activeQuest and self.resolver:matchesUI(activeQuest, ui) then
            activeQuest.playerLevel = quest.playerLevel
            quest = activeQuest
        elseif not ui.visible then activeQuest = nil end
        local key = quest.id .. "/" .. quest.index
        if previousQuest ~= key then
            previousQuest, targetModel = key, nil
            navigationAt = os.clock()
        end
        if ui.visible and not self.resolver:matchesUI(quest, ui) then
            error("Missão ativa diferente: " .. ui.text .. ". Termine/cancele manualmente antes de ativar.")
        end
        if not ui.visible then
            local position, npc = self.resolver:npcPosition(quest)
            assert(position, npc)
            self:status("MISSÃO", quest.id .. "/" .. quest.index .. " | " .. npc .. " | " .. quest.source)
            if self:move(position, 7, token) then
                self:startQuest(quest, token)
                if self:alive(token) then activeQuest = quest end
                navigationAt = os.clock()
            elseif self:alive(token) and os.clock() - navigationAt > 45 then
                error("Não alcancei o quest giver em 45s. Walk não navega entre ilhas; aproxime-se manualmente.")
            end
        else
            activeQuest = quest
            local target = self.resolver:closestEnemy(quest, root.Position)
            if not target then
                self:status("NPCS", "Esperando " .. quest.enemy .. " | nível " .. quest.playerLevel)
                local spawn = self.resolver:spawnPosition(quest, root.Position)
                if spawn then self:move(spawn, 10, token) else task.wait(1) end
                if os.clock() - navigationAt > 60 then error("NPC/spawn não disponível em 60s. Aproxime-se da área da missão.") end
            else
                if target.model ~= targetModel then
                    targetModel, lastHealth, damageAt = target.model, target.humanoid.Health, os.clock()
                end
                if (target.root.Position - root.Position).Magnitude > 6 then
                    self:status("MOVIMENTO", "Aproximando de " .. quest.enemy)
                    self:move(target.root.Position, 5, token)
                    damageAt = os.clock()
                    if os.clock() - navigationAt > 45 then error("Não alcancei o NPC. Reposicione-se ou teste Tween experimental.") end
                else
                    navigationAt = os.clock()
                    -- Revalida após qualquer yield e nunca ataca jogadores.
                    if not self:alive(token) then break end
                    if not self.resolver:matchesUI(quest, self.resolver:questUI()) then continue end
                    if self.context.players:GetPlayerFromCharacter(target.model) then error("Alvo jogador recusado.") end
                    if target.humanoid.Health <= 0 or not target.model.Parent then continue end
                    local tool = self:tool()
                    assert(tool, "Equipamento não encontrado. Melee/Sword usam ToolTip; Equipped exige ferramenta na mão.")
                    if target.humanoid.Health < lastHealth then damageAt = os.clock() end
                    lastHealth = target.humanoid.Health
                    assert(os.clock() - damageAt < 15, "Sem redução de HP em 15s. Tool/Click não produziu dano confirmado; confira equipamento.")
                    self:status("COMBATE", quest.enemy .. " | HP " .. math.floor(lastHealth) .. " | " .. tool.Name)
                    self:attack(tool, target, root)
                    task.wait(0.25)
                end
            end
        end
        task.wait(0.1)
    end
end

function AutoFarm:start()
    if self.enabled then return end
    self.enabled = true
    self.token += 1
    local token = self.token
    task.spawn(function()
        local ok, reason = pcall(function() self:run(token) end)
        if self:alive(token) then self:stop(if ok then "Finalizado." else tostring(reason)) end
    end)
end

function AutoFarm:diagnostic()
    local quest, reason = self.resolver:choose()
    local ui = self.resolver:questUI()
    local position, npc
    if quest then position, npc = self.resolver:npcPosition(quest) end
    return table.concat({"BAHIANO HUB / farm experimental", "PlaceId: " .. tostring(self.context.placeId),
        "Level: " .. tostring(self.resolver:getLevel()), "Fonte: " .. self.resolver.source,
        "Module: " .. tostring(self.resolver.moduleError),
        "Missão: " .. (if quest then quest.id .. "/" .. quest.index .. " / " .. quest.enemy else tostring(reason)),
        "NPC: " .. tostring(npc), "Posição: " .. tostring(position),
        "UI: " .. (if ui then tostring(ui.visible) .. " / " .. ui.text else "não reconhecida"),
        "Equipamento: " .. self.settings.equipment .. " / " .. self.settings.attackMode,
        "Estado: " .. self.state .. " / " .. self.detail,
        "StartQuest pendente: " .. tostring(self.pending)}, "\n")
end

return AutoFarm