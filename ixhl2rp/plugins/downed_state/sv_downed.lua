local D = ix.Downed
util.AddNetworkString("ixDownedGiveUp")
function D.EndLife()
    -- No legacy damage caller or give-up packet can bypass the timed actions.
    return false
end
function D.FinishAction(client, actor, action)
    if not D.Active(client) or client.ixDownedEnding or not IsValid(actor) or actor == client
        or not actor:Alive() or not actor:GetCharacter()
        or (action ~= "finish" and action ~= "rob") then return false end
    client.ixDownedEnding = true
    client.ixGiveUpRequest = nil
    client:SetAction()
    client.ixRegainConscious = nil
    client.KilledByRP = false -- Ordinary death, never a character ban.
    client.KilledBySystem = false
    if ix.BodyDrag then ix.BodyDrag.DropPatient(client) end
    client:Kill()
    return true
end
net.Receive("ixDownedGiveUp", function(_, client)
    -- Old clients may still have the former give-up button after a hot reload.
    client.ixGiveUpRequest = nil
end)
function PLUGIN:EntityTakeDamage(entity, damage)
    if D.BlockDamage(entity, damage) then return true end
end
function PLUGIN:PlayerShouldTakeDamage(client)
    if D.Active(client) then return false end
end
function PLUGIN:PlayerSpawn(client)
	client:SetNetVar("criticalCrawlUntil", nil)
	if D.RestoreCrawl then D.RestoreCrawl(client) end
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
