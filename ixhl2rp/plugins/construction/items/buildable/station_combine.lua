ITEM.category = "item.category.construction"
ITEM.name = "item.station_combine"
ITEM.description = "item.station_combine.desc"
ITEM.model = "models/props_combine/combine_interface002.mdl"
ITEM.preview_model = "models/props_combine/combine_interface002.mdl"
ITEM.width = 3
ITEM.height = 2

function ITEM:OnPlace(client, pos, angle)
	local ent = ents.Create("ix_station_station_combine")

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
	-- Persisted by the ixcraft plugin's SaveStations (ents.FindByClass("ix_station_*")).
end
