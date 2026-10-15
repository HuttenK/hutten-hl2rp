PLUGIN.name = "SCP NPC Compatibility"
PLUGIN.author = "Hutten"
PLUGIN.description = "Helix integration for CPTBase Redux and the SCP CB/Unity packs."

ix.SCPCompat = ix.SCPCompat or {}
local C = ix.SCPCompat
C.version = "2026-10-15"

function C.Controlled(client)
    if not IsValid(client) or not client:IsPlayer() then return end
    local npc = client:GetNW2Entity("CPTBase_PossessingEntity")
    if IsValid(npc) and npc.IsCPTBase_NPC and npc.GetPossessor and npc:GetPossessor() == client then return npc end
end

-- The file exists in CPTBase but its shared.lua includes it without sending it.
-- Register the mounted original; never copy or edit the addon.
if SERVER and file.Exists("weapons/weapon_cpt_base/sh_anim.lua", "LUA") then
    AddCSLuaFile("weapons/weapon_cpt_base/sh_anim.lua")
end

ix.util.Include("sv_control.lua")
ix.util.Include("sv_medical.lua")
ix.util.Include("sv_compat.lua")
ix.util.Include("cl_control.lua")

-- Helix plugin hooks otherwise run before the addon's CalcView/input hooks.
-- Called by the dispatcher only while a verified possession session is active.
local controlHooks = {PlayerNoClip=true, PlayerUse=true, CanPlayerEnterVehicle=true, CanPlayerInteractEntity=true,
    CanPlayerDropItem=true, StartCommand=true, SetupMove=true, CalcView=true, PlayerBindPress=true,
    EntityTakeDamage=true, PlayerShouldTakeDamage=true, PlayerSwitchWeapon=true}
function C.OverrideHook(name, client, ...)
    if not controlHooks[name] then return false end
    if (name == "StartCommand" or name == "SetupMove") and IsValid(client)
        and client:GetNW2Float("ixSCPStunUntil", 0) > CurTime() then
        if name == "StartCommand" then
            local command = ...
            command:ClearMovement()
            command:RemoveKey(IN_JUMP + IN_ATTACK + IN_ATTACK2 + IN_RELOAD)
            return true
        elseif name == "SetupMove" then
            local move = ...
            move:SetForwardSpeed(0); move:SetSideSpeed(0); move:SetUpSpeed(0)
            move:SetMaxSpeed(0); move:SetMaxClientSpeed(0)
            local velocity = move:GetVelocity()
            move:SetVelocity(Vector(0, 0, velocity.z))
            return true
        end
    end
    local npc = C.Controlled(client)
    if not npc then return false end
    -- Helix wounds are applied in Lua even when Source god mode is enabled.
    -- Damage to the controlled NPC still follows its normal damage path.
    if name == "EntityTakeDamage" then
        local damage = ...
        damage:SetDamage(0)
        return true, true
    end
    if name == "PlayerShouldTakeDamage" then return true, false end
    if name == "PlayerSwitchWeapon" then return true, true end
    if name == "PlayerNoClip" or name == "PlayerUse" or name == "CanPlayerEnterVehicle"
        or name == "CanPlayerInteractEntity" or name == "CanPlayerDropItem" then return true, false end
    if name == "StartCommand" then return true end -- Keep the raw keys for CPT ControlKeys.
    if name == "SetupMove" then
        local move = ...
        move:SetOrigin(npc:GetPos() + npc:OBBCenter())
        move:SetVelocity(vector_origin)
        move:SetForwardSpeed(0); move:SetSideSpeed(0); move:SetUpSpeed(0)
        return true
    end
    if CLIENT and name == "CalcView" then return true, C.CalcView(client, npc, ...) end
    if CLIENT and name == "PlayerBindPress" then return true, C.BindPress(client, ...) end
    return false
end

function PLUGIN:ShouldDisableLegs()
    if CLIENT and C.Controlled(LocalPlayer()) then return true end
end
