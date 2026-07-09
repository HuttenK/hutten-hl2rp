ITEM.name        = "Кассетный плеер"
ITEM.description = "Портативный аудиоплеер. Выложите на пол, вставьте кассету через ТАБ-меню."
ITEM.model       = "models/props_generic/bm_batteryradio01.mdl"
ITEM.category    = "item.category.misc"
ITEM.width       = 2
ITEM.height      = 2
ITEM.rarity      = 1

if SERVER then
    function ITEM:OnDrop(owner)
        -- Spawn a custom ix_boombox entity instead of the default ix_item prop.
        local ent = ents.Create("ix_boombox")
        if not IsValid(ent) then return end

        -- Cast a short trace in the player's look direction to find a floor.
        local eyePos = owner:GetShootPos()
        local eyeVec = owner:GetAimVector()
        local tr = util.TraceLine({
            start  = eyePos,
            endpos = eyePos + eyeVec * 60,
            filter = owner,
        })
        local pos = tr.Hit and (tr.HitPos + tr.HitNormal * 3) or (eyePos + eyeVec * 60)

        ent:SetPos(pos)
        ent:SetAngles(Angle(0, owner:GetAngles().y, 0))
        ent:Spawn()

        -- Store the original item instance ID so pickup can restore it exactly.
        ent.boomboxItemID = self.id

        owner:EmitSound("physics/cardboard/cardboard_box_impact_soft3.wav", 70, 100)

        -- Return true to prevent Helix from also spawning a plain ix_item.
        return true
    end
end
