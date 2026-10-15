local D = ix.Downed
D.HoldTime = 1.5
function D.Active(client)
    return IsValid(client) and client:GetCharacter() and client:Alive() and client:GetNetVar("crit") == true
end
function D.ConsciousParalysis(client)
    return D.Active(client) and client:GetNetVar("scpParalyzed", false) == true
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
    -- Kept for callers from older plugins. Damage can never execute a casualty.
    return false
end
function D.DamagePatient(entity)
    if not IsValid(entity) then return end
    local patient = entity:IsPlayer() and entity or entity.ixPlayer
    if D.Active(patient) then return patient end
end
function D.BlockDamage(entity, damage)
    if not D.DamagePatient(entity) then return false end
    damage:SetDamage(0)
    damage:SetDamageForce(vector_origin)
    return true
end
function D.CanRecover(health)
    if ix.SCPMedicine and ix.SCPMedicine.BlocksRecovery(health) then return false end
    return health:GetConsciousness() >= 0.4 and health:GetPartHealth(2) > 0 and
        health:GetPartHealth(3) > 0 and health:GetBleedRate() < 0.1 and D.Blood(health.character) > 0.25
end
