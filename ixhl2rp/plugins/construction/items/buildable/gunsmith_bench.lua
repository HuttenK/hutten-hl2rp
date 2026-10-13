ITEM.category = "item.category.construction"
ITEM.name = "item.gunsmith_bench"
ITEM.description = "item.gunsmith_bench.desc"
ITEM.model = "models/brickscrafting/workbench_2.mdl"
if not util.IsValidModel(ITEM.model) then ITEM.model = "models/props_c17/FurnitureTable001a.mdl" end
ITEM.preview_model = ITEM.model
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
	if not IsValid(ent) then return end

	local phys = ent:GetPhysicsObject()

	if IsValid(phys) then
		phys:EnableMotion(false)
	end

	ent:SetNetVar("owner", client:GetCharacter():GetID())
	-- Persisted by the arccw_item_atts plugin's SaveData (ents.FindByClass("ix_gunsmith")).
	return ent
end
