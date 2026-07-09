-- Плита — крафт-станция (ix_station_station_stove). Ставим саму станцию, как
-- это делает station_combine; персистентность обеспечивает ixcraft (SaveStations,
-- ents.FindByClass("ix_station_*")).
ITEM.category = "item.category.construction_furniture"
ITEM.model = "models/props/appliances/kitchen_stove_home.mdl"
ITEM.preview_model = "models/props/appliances/kitchen_stove_home.mdl"
ITEM.width = 3
ITEM.height = 3

ITEM.name = "item.furn_stove"
ITEM.description = "item.furn_stove.desc"

function ITEM:OnPlace(client, pos, angle)
	local ent = ents.Create("ix_station_station_stove")

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
