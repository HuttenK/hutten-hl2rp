PLUGIN.name = "NPC Relations"
PLUGIN.author = "SchwarzKruppzo"
PLUGIN.description = "Allows easy setting of NPC relations."

if SERVER then
	local function ready(entity)
		return IsValid(entity) and entity:IsNPC() and (not entity.IsCPTBase_NPC or istable(entity.MemoryTable))
	end

	local function apply(entity, client)
		if not ready(entity) or not IsValid(client) then return end
		local character = client:GetCharacter()
		local faction = character and ix.faction.indices[character:GetFaction()]
		if not faction then return end
		local relation = faction.npcRelations and faction.npcRelations[entity:GetClass()]
		-- Scripted NPCs own their default factions. Only explicit schema overrides
		-- should replace them, and CPT's Lua memory must match the engine relation.
		if entity.IsCPTBase_NPC then
			if relation and entity.SetRelationship then entity:SetRelationship(client, relation, 0) end
		else
			entity:AddEntityRelationship(client, relation or D_HT, 0)
		end
	end

	function PLUGIN:OnEntityCreated(entity)
		-- OnEntityCreated runs inside ents.Create, before ENT:Initialize.
		timer.Simple(0, function()
			if not ready(entity) then return end
			for _, client in ipairs(player.GetAll()) do apply(entity, client) end
		end)
	end

	function PLUGIN:PlayerSpawn(client)
		timer.Simple(0, function()
			if not IsValid(client) then return end
			for _, entity in ipairs(ents.GetAll()) do apply(entity, client) end
		end)
	end
end
