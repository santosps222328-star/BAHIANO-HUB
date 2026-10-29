-- Seleção de missões e leitura do mundo. Sem execução de hubs externos.
local QuestResolver = {}
QuestResolver.__index = QuestResolver
local SPECIAL = {BartiloQuest = true, CitizenQuest = true, MarineQuest = true}
local SEA_PLACES = {[2753915549] = 1, [4442272183] = 2, [7449423635] = 3}

function QuestResolver.normalize(value)
    return tostring(value or ""):gsub("%b[]", ""):gsub("<[^>]+>", ""):lower():gsub("[^%w]", "")
end

function QuestResolver.seaForPlace(placeId)
    return SEA_PLACES[placeId]
end

function QuestResolver.select(quests, level, sea)
    if type(quests) ~= "table" or type(level) ~= "number" or level ~= level or level == math.huge
        or (sea ~= 1 and sea ~= 2 and sea ~= 3) then return nil end
    local minimum = if sea == 1 then 0 elseif sea == 2 then 700 else 1500
    local maximum = if sea == 1 then 700 elseif sea == 2 then 1500 else math.huge
    local best
    for questId, stages in pairs(quests) do
        if type(questId) ~= "string" or SPECIAL[questId] or type(stages) ~= "table" then continue end
        for index, stage in pairs(stages) do
            if type(index) ~= "number" or type(stage) ~= "table" then continue end
            local required = stage.LevelReq
            if type(required) ~= "number" or required ~= required or required < minimum or required >= maximum or required > level then continue end
            if type(stage.Task) ~= "table" then continue end
            local enemy, amount, taskCount
            taskCount = 0
            for target, count in pairs(stage.Task) do
                taskCount += 1
                if type(target) == "string" and type(count) == "number" and count > 1 then
                    enemy, amount = target, count
                end
            end
            -- Exclui chefes de um abate e missões com objetivos misturados.
            if taskCount ~= 1 or not enemy then continue end
            local choice = {id = questId, index = index, enemy = enemy, amount = amount, level = required}
            if not best or required > best.level or (required == best.level and questId < best.id) then best = choice end
        end
    end
    return best
end

function QuestResolver.new(context, fallback, names)
    return setmetatable({context = context, fallback = fallback, names = names, source = "snapshot", quests = fallback}, QuestResolver)
end

local function readGameModule(storage, name)
    local instance = storage:FindFirstChild(name)
    if not instance then
        local modules = storage:FindFirstChild("Modules")
        instance = modules and modules:FindFirstChild(name)
    end
    if not instance or not instance:IsA("ModuleScript") then return nil, "módulo ausente" end
    local finished, ok, value = false, false, nil
    task.spawn(function()
        ok, value = pcall(require, instance)
        finished = true
    end)
    local deadline = os.clock() + 6
    while not finished and os.clock() < deadline do task.wait(0.1) end
    if not finished then return nil, "require excedeu 6 segundos" end
    return if ok and type(value) == "table" then value else nil, if ok then nil else tostring(value)
end

function QuestResolver:refresh()
    local live, reason = readGameModule(self.context.storage, "Quests")
    self.quests = live or self.fallback
    self.source = if live then "jogo" else "snapshot"
    self.moduleError = reason
    self.guide = readGameModule(self.context.storage, "GuideModule")
end

function QuestResolver:getLevel()
    local data = self.context.player:FindFirstChild("Data")
    local object = data and data:FindFirstChild("Level")
    return if object and type(object.Value) == "number" then object.Value else nil
end

function QuestResolver:choose()
    local sea = QuestResolver.seaForPlace(self.context.placeId)
    if not sea then return nil, "PlaceId não reconhecido como um dos três mares de Blox Fruits." end
    local level = self:getLevel()
    if not level then return nil, "Data.Level não está disponível. Espere o jogo carregar." end
    if self.source == "snapshot" and level >= 2600 then
        return nil, "Quests do jogo indisponível; snapshot não cobre nível 2600+. Não vou inventar uma missão."
    end
    local quest = QuestResolver.select(self.quests, level, sea)
    if not quest then return nil, "Nenhuma missão regular compatível com seu nível e mar foi encontrada." end
    quest.sea, quest.playerLevel, quest.source = sea, level, self.source
    return quest
end

local function positionOf(value, depth)
    depth = depth or 0
    if depth > 5 then return nil end
    local kind = typeof(value)
    if kind == "Vector3" then return value end
    if kind == "CFrame" then return value.Position end
    if kind == "Instance" then
        if value:IsA("BasePart") then return value.Position end
        if value:IsA("Model") then
            local root = value:FindFirstChild("HumanoidRootPart") or value.PrimaryPart or value:FindFirstChild("Head")
            return root and root.Position
        end
    elseif kind == "table" then
        return positionOf(value.Position or value.CFrame or value.NPC, depth + 1)
    end
    return nil
end

function QuestResolver:npcPosition(quest)
    local data = self.guide and self.guide.Data
    local name = (data and type(data.NPCs) == "table" and data.NPCs[quest.id]) or self.names[quest.id]
    if data and type(data.NPCList) == "table" then
        for _, entry in pairs(data.NPCList) do
            if type(entry) ~= "table" then continue end
            local entryName = entry.NPCName or entry.Name
            local matches = entry.QuestName == quest.id or entry.Quest == quest.id
                or (name and QuestResolver.normalize(entryName) == QuestResolver.normalize(name))
            if matches then
                local position = positionOf(entry)
                if position then return position, tostring(entryName or name or quest.id) end
            end
        end
    end
    local npcs = self.context.world:FindFirstChild("NPCs")
    if npcs then
        for _, npc in ipairs(npcs:GetDescendants()) do
            if not npc:IsA("Model") then continue end
            if (name and QuestResolver.normalize(npc.Name) == QuestResolver.normalize(name))
                or npc:GetAttribute("QuestName") == quest.id then
                local position = positionOf(npc)
                if position then return position, npc.Name end
            end
        end
    end
    return nil, "NPC de " .. quest.id .. " não localizado. Aproxime-se da ilha/quest giver e use Diagnóstico."
end

function QuestResolver:questUI()
    local gui = self.context.player:FindFirstChild("PlayerGui")
    local main = gui and gui:FindFirstChild("Main")
    local quest = main and main:FindFirstChild("Quest")
    if not quest or not quest:IsA("GuiObject") then return nil end
    local titleHolder = quest:FindFirstChild("QuestTitle", true)
    local label = titleHolder and (titleHolder:FindFirstChild("Title") or titleHolder:FindFirstChildWhichIsA("TextLabel", true))
    label = label or quest:FindFirstChild("Title", true)
    if not label or not label:IsA("TextLabel") then return nil end
    return {visible = quest.Visible, text = label.Text}
end

function QuestResolver:matchesUI(quest, ui)
    return ui and ui.visible and QuestResolver.normalize(ui.text):find(QuestResolver.normalize(quest.enemy), 1, true) ~= nil
end

function QuestResolver:closestEnemy(quest, origin)
    local folder = self.context.world:FindFirstChild("Enemies")
    if not folder then return nil end
    local best, distance
    for _, model in ipairs(folder:GetChildren()) do
        if not model:IsA("Model") or QuestResolver.normalize(model.Name) ~= QuestResolver.normalize(quest.enemy) then continue end
        local humanoid = model:FindFirstChildOfClass("Humanoid")
        local root = model:FindFirstChild("HumanoidRootPart")
        if not humanoid or not root or humanoid.Health <= 0 then continue end
        if self.context.players:GetPlayerFromCharacter(model) then continue end
        local current = (origin - root.Position).Magnitude
        if not distance or current < distance then best, distance = {model = model, root = root, humanoid = humanoid}, current end
    end
    return best
end

function QuestResolver:spawnPosition(quest, origin)
    local worldOrigin = self.context.world:FindFirstChild("_WorldOrigin")
    local spawns = worldOrigin and worldOrigin:FindFirstChild("EnemySpawns")
    if not spawns then return nil end
    local best, distance
    for _, object in ipairs(spawns:GetDescendants()) do
        if QuestResolver.normalize(object.Name) ~= QuestResolver.normalize(quest.enemy) then continue end
        local position = positionOf(object)
        if position then
            local current = (origin - position).Magnitude
            if not distance or current < distance then best, distance = position, current end
        end
    end
    return best
end

return QuestResolver