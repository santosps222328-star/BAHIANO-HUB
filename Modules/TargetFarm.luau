-- Reutiliza movimento/equipamento/ataque do controlador, sem loops duplicados de hubs.
local TargetFarm={}

function TargetFarm.configure(controller, definition)
    controller.definition=definition
    controller.run=function(self,token)
        assert(definition and type(definition.enemies)=="table","Selecione o alvo primeiro.")
        local waitedAt,damageAt,lastHealth,lastModel=os.clock(),os.clock(),nil,nil
        while self:alive(token) do
            local _,_,root=self:character()
            if not root then
                self:status("RESPAWN","Esperando personagem.")
                task.wait(0.5);waitedAt=os.clock();continue
            end
            local best,distance
            if definition.nearest then
                local folder=self.context.world:FindFirstChild("Enemies")
                if folder then
                    for _,model in ipairs(folder:GetChildren()) do
                        if not model:IsA("Model") then continue end
                        if self.context.players:GetPlayerFromCharacter(model) then continue end
                        local humanoid=model:FindFirstChildOfClass("Humanoid")
                        local targetRoot=model:FindFirstChild("HumanoidRootPart")
                        if not humanoid or humanoid.Health<=0 or not targetRoot then continue end
                        local d=(targetRoot.Position-root.Position).Magnitude
                        if not distance or d<distance then best={model=model,humanoid=humanoid,root=targetRoot};distance=d end
                    end
                end
            else
                for _,enemy in ipairs(definition.enemies) do
                    local target=self.resolver:closestEnemy({enemy=enemy},root.Position)
                    if not target then continue end
                    local d=(target.root.Position-root.Position).Magnitude
                    if not distance or d<distance then best,distance=target,d end
                end
            end
            if not best then
                self:status("NPCS",definition.name.." — esperando NPC local. Não invoca/spawna boss.")
                assert(os.clock()-waitedAt<60,"Nenhum NPC compatível em 60s. Aproxime-se manualmente da área.")
                task.wait(0.5);continue
            end
            if best.model~=lastModel then lastModel,lastHealth,damageAt=best.model,best.humanoid.Health,os.clock() end
            if distance>6 then
                self:status("MOVIMENTO",best.model.Name)
                self:move(best.root.Position,5,token);damageAt=os.clock()
                assert(os.clock()-waitedAt<45,"Alvo inacessível em 45s. Reposicione o personagem.")
            else
                waitedAt=os.clock()
                if not self:alive(token) then break end
                if self.context.players:GetPlayerFromCharacter(best.model) then error("Jogador recusado.") end
                if not best.model.Parent or best.humanoid.Health<=0 then continue end
                local tool=self:tool()
                assert(tool,"Equipamento não encontrado; selecione Melee, Sword ou Equipped.")
                if best.humanoid.Health<lastHealth then damageAt=os.clock() end
                lastHealth=best.humanoid.Health
                assert(os.clock()-damageAt<15,"Sem redução de HP em 15s. Ataque normal sem dano confirmado.")
                self:status("COMBATE",best.model.Name.." | HP "..math.floor(lastHealth).." | "..tool.Name)
                self:attack(tool,best,root)
                task.wait(0.25)
            end
            task.wait(0.1)
        end
    end
    return controller
end

return TargetFarm