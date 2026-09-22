local D = ix.Downed
function D.Active(client)
    return IsValid(client) and client:GetCharacter() and client:Alive() and client:GetNetVar("crit") == true
end
function D.Blood(character)
    local health = character and character:Health()
    if not health then return 1 end
    local reserve = 1
    for _, condition in pairs(health.hediffs or {}) do
        if condition.uniqueID == "bleeding" then
            local severity = tonumber(condition:GetSeverity()) or 0
            if severity == severity then reserve = math.min(reserve, 1 - math.Clamp(severity, 0, 1)) end
        end
    end
    return reserve
end
function D.ShouldFinish(client, damage)
    if not D.Active(client) then return false end
    local attacker = damage:GetAttacker()
    if not IsValid(attacker) or attacker == client or not (attacker:IsPlayer() or attacker:IsNPC() or attacker:IsNextBot()) then return false end
    local combat = damage:IsBulletDamage() or damage:IsExplosionDamage() or
        damage:IsDamageType(DMG_SLASH) or damage:IsDamageType(DMG_CLUB) or damage:IsDamageType(DMG_ENERGYBEAM)
    return combat and damage:GetDamage() >= ix.config.Get("downedFinishDamage", 15)
end
function D.CanRecover(health)
    return health:GetConsciousness() >= 0.4 and health:GetPartHealth(2) > 0 and
        health:GetPartHealth(3) > 0 and health:GetBleedRate() < 0.1 and D.Blood(health.character) > 0.25
end
