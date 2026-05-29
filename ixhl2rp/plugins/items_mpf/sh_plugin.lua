local PLUGIN = PLUGIN

PLUGIN.name = "MPF Items"
PLUGIN.author = "SchwarzKruppzo"
PLUGIN.description = ""

ix.Net:AddPlayerVar("PrimaryVisorColor", Vector(0, 0, 0), nil, ix.Net.Type.Vector)
ix.Net:AddPlayerVar("SecondaryVisorColor", Vector(0, 0, 0), nil, ix.Net.Type.Vector)

local playerMeta = FindMetaTable("Player")

function playerMeta:SetPrimaryVisorColor(color)
	self:SetNetVar("PrimaryVisorColor", color)
end

function playerMeta:GetPrimaryVisorColor()
	return self:GetNetVar("PrimaryVisorColor", Vector(0, 0, 0))
end

function playerMeta:SetSecondaryVisorColor(color)
	self:SetNetVar("SecondaryVisorColor", color)
end

function playerMeta:GetSecondaryVisorColor()
	return self:GetNetVar("SecondaryVisorColor", Vector(0, 0, 0))
end

if SERVER then
	function PLUGIN:PlayerLoadedCharacter(client, character, lastChar)
		client.ArmorItems = {}

		client:SetNWInt("sg_uniform", 0)
		client:SetNWInt("sg_armband", 0)

		client:SetPrimaryVisorColor(Vector(0, 0, 0))
		client:SetSecondaryVisorColor(Vector(0, 0, 0))
/*
		local equipment = character:GetEquipment()

		if equipment then
			local outfit = equipment:HasItemOfBase("base_outfitmpf", {equip = true})

			if outfit then
				local armband = outfit:GetData("armband", 0)

				client:SetNWInt("sg_uniform", outfit.uniform)
				client:SetNWInt("sg_armband", armband)

				client:SetPrimaryVisorColor(outfit.primaryVisor)
				client:SetSecondaryVisorColor(outfit.secondaryVisor)
			end

			local items = equipment:GetItems()

			for _, v in pairs(items) do
				if v.Stats then
					client.ArmorItems[v] = true
				end
			end
		end*/
	end
end