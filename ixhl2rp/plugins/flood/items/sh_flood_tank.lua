ITEM.name        = "Накопительный бак"
ITEM.description  = "Переносной бак для откачки. Выложите на сухом месте и подключите к нему насос кабелем. Присесть + E — поднять обратно."
ITEM.model        = "models/props_borealis/bluebarrel001.mdl"
ITEM.category     = "item.category.misc"
ITEM.width        = 3
ITEM.height       = 3

if (SERVER) then
	function ITEM:OnDrop(owner)
		local ent = ents.Create("ix_flood_tank")
		if (!IsValid(ent)) then return end

		local eyePos = owner:GetShootPos()
		local eyeVec = owner:GetAimVector()
		local tr = util.TraceLine({
			start  = eyePos,
			endpos = eyePos + eyeVec * 80,
			filter = owner,
		})
		local pos = tr.Hit and (tr.HitPos + tr.HitNormal * 4) or (eyePos + eyeVec * 80)

		ent:SetPos(pos)
		ent:SetAngles(Angle(0, owner:GetAngles().y, 0))
		ent:Spawn()

		ent.ixItemID     = self.id
		ent.ixItemUnique = self.uniqueID

		if (owner:GetCharacter()) then
			ent:SetNetVar("owner", owner:GetCharacter():GetID())
		end

		owner:EmitSound("physics/metal/metal_barrel_impact_hard" .. math.random(1, 3) .. ".wav", 70, 100)

		local p = ix.plugin.list["flood"]
		if (p and p.SaveData) then p:SaveData() end

		return true
	end
end
