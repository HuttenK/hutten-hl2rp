local D = ix.Downed
util.AddNetworkString("ixDownedGiveUp")
function D.EndLife()
    -- Legacy damage callers must never bypass the explicit death actions.
    return false
end
local function endLife(client, voluntary)
    if not D.Active(client) or client.ixDownedEnding then return false end
    client.ixDownedEnding = true
    client.ixGiveUpRequest = nil
    client:SetAction()
    client.ixRegainConscious = nil
    client.KilledByRP = false -- Ordinary death, never a character ban.
    client.KilledBySystem = voluntary == true
    if ix.BodyDrag then ix.BodyDrag.DropPatient(client) end
    client:Kill()
    return true
end
function D.FinishAction(client, actor, action)
    if not IsValid(actor) or actor == client or not actor:Alive() or not actor:GetCharacter()
        or (action ~= "finish" and action ~= "rob") then return false end
    return endLife(client, false)
end
net.Receive("ixDownedGiveUp", function(length, client)
    -- The target is always the packet's sender; no client-supplied player ID.
    if length ~= 2 or not IsValid(client) then return end
    local operation = net.ReadUInt(2)
    if operation == 1 then client.ixGiveUpRequest = nil return end
    if not D.Active(client) or client.ixDownedEnding then client.ixGiveUpRequest = nil return end
    if operation == 0 then
        client.ixGiveUpRequest = {started = CurTime(), character = client:GetCharacter(),
            episode = client:GetNetVar("downedSince")}
    elseif operation == 2 then
        local request = client.ixGiveUpRequest
        client.ixGiveUpRequest = nil
        if not request or request.character ~= client:GetCharacter() or
            request.episode ~= client:GetNetVar("downedSince") or CurTime() - request.started < D.HoldTime or
            CurTime() - request.started > 8 then return end
        endLife(client, true)
    end
end)
function PLUGIN:EntityTakeDamage(entity, damage)
    if D.BlockDamage(entity, damage) then return true end
end
function PLUGIN:PlayerShouldTakeDamage(client)
    if D.Active(client) then return false end
end
function PLUGIN:PlayerSpawn(client)
	client:SetNetVar("criticalCrawlUntil", nil)
	client:SetNetVar("criticalFallUntil", nil)
	client.ixCriticalCrawlHandoff = nil
	if D.RestoreCrawl then D.RestoreCrawl(client) end
    client.ixDownedEnding = nil
    client.ixGiveUpRequest = nil
    client:SetNetVar("crit", nil)
    client:SetNetVar("scpParalyzed", nil)
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
