local PLUGIN = PLUGIN

PLUGIN.name        = "Realistic Visual Effects"
PLUGIN.author      = "Homigrad / Z-City (Ported by Antigravity)"
PLUGIN.description = "Adds advanced visual effects: realistic blood decals, screen shaders, and camera sway."

ix.util.Include("cl_hooks.lua")
ix.util.Include("cl_camera.lua")

if SERVER then
    util.AddNetworkString("ixRealisticBlood")

    -- Throttle: не спамить сетевыми сообщениями чаще чем раз в 0.1с на сущность
    local lastBloodTime = {}

    function PLUGIN:EntityTakeDamage(entity, damageInfo)
        if not (entity:IsPlayer() or entity:IsNPC()) then return end

        local index = entity:EntIndex()
        local now   = CurTime()

        if (lastBloodTime[index] or 0) + 0.1 > now then return end
        lastBloodTime[index] = now

        local dmgType   = damageInfo:GetDamageType()
        local dmgAmount = damageInfo:GetDamage()
        local hitPos    = damageInfo:GetDamagePosition()

        net.Start("ixRealisticBlood")
            net.WriteEntity(entity)
            net.WriteUInt(dmgType, 32)
            net.WriteFloat(dmgAmount)
            net.WriteVector(hitPos)
        net.Broadcast()
    end

    function PLUGIN:PlayerHurt(victim, attacker, healthRemaining, damageTaken)
        if not IsValid(victim) then return end
        
        local index = victim:EntIndex()
        local now   = CurTime()

        -- Если урон уже был обработан через EntityTakeDamage, пропускаем
        if (lastBloodTime[index] or 0) + 0.1 > now then return end
        lastBloodTime[index] = now

        net.Start("ixRealisticBlood")
            net.WriteEntity(victim)
            net.WriteUInt(0, 32) 
            net.WriteFloat(damageTaken)
            net.WriteVector(victim:GetPos() + Vector(0,0,40))
        net.Broadcast()
    end

    -- Очищаем throttle-таблицу при удалении сущности, чтобы не копить мусор
    function PLUGIN:EntityRemoved(entity)
        lastBloodTime[entity:EntIndex()] = nil
    end
end
