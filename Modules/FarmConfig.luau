-- Configurações locais. Nunca salva Auto Farm ligado.
local FarmConfig = {}
FarmConfig.Defaults = {equipment = "Melee", attackMode = "Tool", movement = "Walk"}

function FarmConfig.sanitize(input)
    local output = table.clone(FarmConfig.Defaults)
    if type(input) ~= "table" then return output end
    if input.equipment == "Melee" or input.equipment == "Sword" or input.equipment == "Equipped" then
        output.equipment = input.equipment
    end
    if input.attackMode == "Tool" or input.attackMode == "Click" then output.attackMode = input.attackMode end
    if input.movement == "Walk" or input.movement == "Tween" then output.movement = input.movement end
    return output
end

function FarmConfig.load(path, http)
    if type(readfile) ~= "function" then return FarmConfig.sanitize(nil) end
    local ok, decoded = pcall(function() return http:JSONDecode(readfile(path)) end)
    return FarmConfig.sanitize(if ok then decoded else nil)
end

function FarmConfig.save(path, http, settings)
    if type(writefile) ~= "function" then return false, "writefile indisponível" end
    return pcall(function() writefile(path, http:JSONEncode(FarmConfig.sanitize(settings))) end)
end

return FarmConfig