ITEM.category = "item.category.construction"
ITEM.name = "item.gunsmith_bench"
ITEM.description = "item.gunsmith_bench.desc"
ITEM.model = "models/props_combine_enhanced/combine_table.mdl"
ITEM.preview_model = "models/props_combine_enhanced/combine_table.mdl"
ITEM.width = 3
ITEM.height = 2

function ITEM:OnPlace(client, pos, angle)
	local ent = ents.Create("ix_gunsmith")

	if !IsValid(ent) then
		return
	end

	ent:SetPos(pos)
	ent:SetAngles(angle)
	ent:Spawn()

	local phys = ent:GetPhysicsObject()

	if IsValid(phys) then
		phys:EnableMotion(false)
	end

	ent:SetNetVar("owner", client:GetCharacter():GetID())
	-- Persisted by the arccw_item_atts plugin's SaveData (ents.FindByClass("ix_gunsmith")).
end
