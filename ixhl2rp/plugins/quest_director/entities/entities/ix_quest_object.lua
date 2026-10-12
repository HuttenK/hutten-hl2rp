ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Квестовый объект"
ENT.Spawnable = false

if SERVER then
    local launchers = {rpg_missile = "weapon_rpg", crossbow_bolt = "weapon_crossbow", npc_grenade_frag = "weapon_frag",
        grenade_ar2 = "weapon_ar2", prop_combine_ball = "weapon_ar2"}
    function ENT:Initialize()
        ix.questDirector:InitializePlacementPhysics(self)
    end
    function ENT:ApplyDefinition(row) self:SetSkin(row.skin) end
    function ENT:Use(client)
        if not IsValid(client) or not client:IsPlayer() or (client.ixQDUse or 0) > CurTime() then return end
        client.ixQDUse = CurTime() + 0.5
        ix.questDirector:UsePlacement(client, self)
    end
    function ENT:OnTakeDamage(info)
        local Q = ix.questDirector
        local row = Q.defs.object[self.ixQuestDefinition]
        local client = info:GetAttacker()
        if not row or not row.enabled or not IsValid(client) or not client:IsPlayer() or not client:Alive()
            or not client:GetCharacter() or info:GetDamage() <= 0 then return end
        local inflictor = info:GetInflictor()
        -- Native projectile classes map to their launcher. Custom projectile classes
        -- remain selectable by their own class (no inference from a switched weapon).
        local weapon = IsValid(inflictor) and inflictor ~= client and inflictor or client:GetActiveWeapon()
        local class = IsValid(weapon) and weapon:GetClass() or ""
        Q:Advance(client, "damage", row.target, math.min(info:GetDamage(), 1000000), {quest = row.quest, weapon = launchers[class] or class})
        return 0
    end
else
    ENT.PopulateEntityInfo = true
    function ENT:OnPopulateEntityInfo(tooltip)
        local title = tooltip:AddRow("name")
        title:SetText(self:GetNetVar("questLabel", self.PrintName)) title:SizeToContents()
        local hint = tooltip:AddRow("questHint")
        hint:SetText(ix.questDirector.CanEdit(LocalPlayer()) and LocalPlayer():GetMoveType() == MOVETYPE_NOCLIP
            and "E — настройки и удаление размещения" or (self:GetNetVar("questEnabled", false)
            and "E — взаимодействовать" or "Квестовый объект выключен"))
        hint:SizeToContents()
    end
    function ENT:Draw() self:DrawModel() end
end
