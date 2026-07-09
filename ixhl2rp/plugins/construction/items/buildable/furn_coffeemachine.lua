-- Кофемашина — крафт-станция (ix_station_station_coffeemachine). См. furn_stove.
ITEM.category = "item.category.construction_furniture"
ITEM.model = "models/cellar/teapot_machine.mdl"
ITEM.preview_model = "models/cellar/teapot_machine.mdl"
ITEM.width = 2
ITEM.height = 2

ITEM.name = "item.furn_coffeemachine"
ITEM.description = "item.furn_coffeemachine.desc"

function ITEM:OnPlace(client, pos, angle)
	local ent = ents.Create("ix_station_station_coffeemachine")

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
end
