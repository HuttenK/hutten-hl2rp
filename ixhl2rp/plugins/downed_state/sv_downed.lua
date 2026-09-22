local D = ix.Downed
util.AddNetworkString("ixDownedGiveUp")
function D.EndLife(client, voluntary)
    if not D.Active(client) or client.ixDownedEnding then return false end
    client.ixDownedEnding = true
    client.ixGiveUpRequest = nil
    client:SetAction()
    client.ixRegainConscious = nil
    client.KilledByRP = false -- Ordinary death, never a character ban.
    client.KilledBySystem = voluntary == true
    client:Kill()
    return true
end
net.Receive("ixDownedGiveUp", function(_, client)
    local operation = net.ReadUInt(2)
    if operation == 1 then client.ixGiveUpRequest = nil return end
    if not D.Active(client) or client.ixDownedEnding then return end
    if operation == 0 then
        client.ixGiveUpRequest = {started = CurTime(), character = client:GetCharacter(),
            episode = client:GetNetVar("downedSince")}
    elseif operation == 2 then
        local request = client.ixGiveUpRequest
        if not request or request.character ~= client:GetCharacter() or
            request.episode ~= client:GetNetVar("downedSince") or CurTime() - request.started < D.HoldTime or
            CurTime() - request.started > 8 then return end
        D.EndLife(client, true)
    end
end)
function PLUGIN:PlayerSpawn(client)
    client.ixDownedEnding = nil
    client.ixGiveUpRequest = nil
    client:SetNetVar("crit", nil)
    client:SetNetVar("downedSince", nil)
    client:SetLocalVar("knocked", false)
end
function PLUGIN:CanPlayerSuicide(client)
    if D.Active(client) then return false end
end
function PLUGIN:PlayerLoadedCharacter(client, character)
    timer.Simple(0.25, function()
        if IsValid(client) and client:Alive() and client:GetCharacter() == character and character:GetData("crit") then
            client:SetCriticalState(true)
        end
    end)
end
