if CLIENT then return end

util.AddNetworkString("arcticnvgs_toggle")

hook.Add("PlayerSpawn","ArcticNVGs_PlayerSpawn",function(ply)
    if GetConVar("sh_arctic_nvg_losegoggles"):GetBool() then
        ply:SetNWInt("nvg", 0)
    end
end)

function ArcticNVGs_SetPlayerGoggles(ply, goggles)
    local id = ArcticNVGs_ShortNameToID[goggles]

    if ply:GetNWInt("nvg", 0) != 0 then
        -- drop the old ones
        local drop = (ArcticNVGs[ply:GetNWInt("nvg", 0)] or {}).Entity

        if drop then
            local ent = ents.Create(drop)
            ent:SetPos(ply:EyePos())
            ent:SetAngles(ply:EyeAngles())
            ent:SetOwner(ply)
            ent:Spawn()
        end
    end

    ply:SetNWInt("nvg", id)
end

net.Receive("arcticnvgs_toggle", function(len, ply)
    local onoff = net.ReadBool()

    ply:SetNWBool("nvg_on", onoff)
end)