-- Serviços próprios. Nenhum hub enviado é executado ou baixado.
local Services = {}
Services.__index = Services

function Services.new(context, notify)
    return setmetatable({context=context, notify=notify, jobs={}, connections={}, originals={},
        closed=false, pending=false, experimental=false, armed=nil, cancelToken=0},Services)
end

function Services:message(title, detail)
    if not self.closed then pcall(self.notify,title,tostring(detail)) end
end

function Services:remote(args, active)
    assert(not self.closed,"Hub fechado.")
    assert(self.experimental,"Módulo experimental bloqueado. Autorize o teste antes.")
    assert(not self.pending,"Outro pedido CommF_ ainda está pendente; não será duplicado.")
    local folder=self.context.storage:FindFirstChild("Remotes")
    local remote=folder and folder:FindFirstChild("CommF_")
    assert(remote and remote:IsA("RemoteFunction"),"CommF_ não encontrado.")
    self.pending=true
    local token=self.cancelToken
    local done,ok,result=false,false,nil
    task.spawn(function()
        if self.closed or self.cancelToken~=token or (active and not active()) then
            self.pending,done=false,true
            result="Cancelado antes do envio."
            return
        end
        ok,result=pcall(function() return remote:InvokeServer(table.unpack(args)) end)
        self.pending,done=false,true
    end)
    local deadline=os.clock()+8
    while not done and not self.closed and os.clock()<deadline do task.wait(0.1) end
    assert(done,"Pedido sem resposta em 8s. Já enviado: não pode ser retirado do servidor.")
    assert(ok,tostring(result))
    return result
end

function Services:confirm(key, action)
    if self.closed then return end
    if not self.armed or self.armed.key~=key or os.clock()>self.armed.untilTime then
        self.armed={key=key,untilTime=os.clock()+15}
        self:message("Confirme a ação",key .. "\nClique novamente em até 15s. Pode gastar moeda/itens do jogo ou mudar seu progresso/servidor.")
        return
    end
    self.armed=nil
    local ok,result=pcall(action)
    self:message(if ok then "Pedido executado" else "Ação interrompida",if ok then "Resposta: "..tostring(result)..". Confira o resultado no jogo; não implica compra/conclusão confirmada." else result)
end

function Services:set(id, enabled, interval, fn, cleanup, onStop)
    local old=self.jobs[id]
    if old then
        self.jobs[id]=nil
        if old.cleanup then pcall(old.cleanup) end
        if old.onStop then pcall(old.onStop) end
    end
    if not enabled or self.closed then return end
    local job={cleanup=cleanup,onStop=onStop}
    self.jobs[id]=job
    task.spawn(function()
        while not self.closed and self.jobs[id]==job do
            local ok,reason=pcall(fn,function() return not self.closed and self.jobs[id]==job end)
            if not ok then
                if self.jobs[id]==job then
                    self:set(id,false)
                    self:message(id .. " — OFF",reason)
                end
                return
            end
            if self.jobs[id]~=job or self.closed then break end
            task.wait(interval)
        end
    end)
end

function Services:stopAll()
    self.armed=nil
    self.cancelToken+=1
    local ids={}
    for id in pairs(self.jobs) do table.insert(ids,id) end
    for _,id in ipairs(ids) do self:set(id,false) end
    if self.movement then self.movement:stop("Parar tudo.") end
    for _,connection in ipairs(self.connections) do connection:Disconnect() end
    self.connections={}
end

function Services:close()
    self.closed=true
    self:stopAll()
end

function Services:property(instance, property, value, id, enabled)
    local original=instance[property]
    if enabled then
        self:set(id,true,1,function() instance[property]=value end,function() instance[property]=original end)
    else self:set(id,false) end
end

function Services:esp(id, getObjects, enabled, onStop)
    local markers={}
    local function cleanup()
        for _,mark in pairs(markers) do mark:Destroy() end
        markers={}
    end
    self:set(id,enabled,1,function()
        local found={}
        for _,object in ipairs(getObjects()) do
            local adornee
            if object:IsA("BasePart") then adornee=object
            elseif object:IsA("Model") then adornee=object:FindFirstChild("HumanoidRootPart") or object.PrimaryPart
            elseif object:IsA("Tool") then adornee=object:FindFirstChild("Handle") end
            if not adornee then continue end
            found[object]=true
            if not markers[object] then
                local gui=Instance.new("BillboardGui")
                gui.Name="BahianoESP";gui.Adornee=adornee;gui.AlwaysOnTop=true
                gui.Size=UDim2.fromOffset(180,32);gui.StudsOffset=Vector3.new(0,3,0)
                local label=Instance.new("TextLabel")
                label.Size=UDim2.fromScale(1,1);label.BackgroundTransparency=1
                label.Text=object.Name;label.TextColor3=Color3.fromRGB(45,205,255)
                label.TextStrokeTransparency=0.25;label.TextSize=13;label.Font=Enum.Font.GothamSemibold
                label.Parent=gui;gui.Parent=adornee;markers[object]=gui
            end
        end
        for object,gui in pairs(markers) do
            if not found[object] or not object.Parent then gui:Destroy();markers[object]=nil end
        end
    end,cleanup,onStop)
end

function Services:antiAFK(enabled, onStop)
    self:set("Anti AFK",false)
    if not enabled then return end
    local connection=self.context.player.Idled:Connect(function()
        if self.closed or not self.jobs["Anti AFK"] then return end
        local ok,reason=pcall(function()
            local input=self.context.input
            assert(input,"VirtualUser indisponível.")
            input:CaptureController()
            input:Button2Down(Vector2.new(0,0),workspace.CurrentCamera.CFrame)
            input:Button2Up(Vector2.new(0,0),workspace.CurrentCamera.CFrame)
        end)
        if not ok then self:set("Anti AFK",false);self:message("Anti AFK",reason) end
    end)
    self.jobs["Anti AFK"]={cleanup=function() connection:Disconnect() end,onStop=onStop}
end

function Services:fps(enabled, onStop)
    local saved={}
    local waiting={}
    local listener
    local function assign(object,key,value)
        saved[object]=saved[object] or {}
        if saved[object][key]==nil then saved[object][key]=object[key] end
        object[key]=value
    end
    local function cleanup()
        if listener then listener:Disconnect() end
        for object,properties in pairs(saved) do
            if object.Parent then for key,value in pairs(properties) do pcall(function() object[key]=value end) end end
        end
        saved={}
    end
    if enabled then
        waiting=self.context.world:GetDescendants()
        listener=self.context.world.DescendantAdded:Connect(function(object) table.insert(waiting,object) end)
    end
    self:set("FPS Booster",enabled,0.15,function()
        assign(game:GetService("Lighting"),"GlobalShadows",false)
        -- Processa em lotes para não varrer o mundo inteiro a cada frame no Android.
        for _=1,math.min(#waiting,250) do
            local object=table.remove(waiting)
            if not object.Parent then continue end
            if object:IsA("ParticleEmitter") or object:IsA("Trail") then assign(object,"Enabled",false)
            elseif object:IsA("BasePart") then assign(object,"CastShadow",false) end
        end
    end,cleanup,onStop)
end

function Services:stats(stat, enabled, amount, onStop)
    self:set("Auto Stats "..stat,enabled,1.5,function(active)
        assert(self.experimental,"Auto Stats indisponível até autorizar módulos experimentais.")
        local data=self.context.player:FindFirstChild("Data")
        local points=data and data:FindFirstChild("Points")
        assert(points and type(points.Value)=="number","Data.Points não encontrado.")
        local n=math.min(math.floor(amount()),points.Value)
        if n>0 and active() and not self.pending then self:remote({"AddPoint",stat,n},active) end
    end,nil,onStop)
end

return Services