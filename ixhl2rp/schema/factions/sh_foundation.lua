FACTION.name = "faction.foundation"
FACTION.description = "faction.foundation.desc"
FACTION.color = Color(110, 155, 185)
FACTION.isDefault = false
FACTION.showCreationMenu = false
FACTION.bHumanVoices = true
-- Assignment preserves the character's existing appearance and equipment.
FACTION.models = table.Copy(ix.faction.teams.citizen.models)
function FACTION:OnTransferred(character)
	Schema:ResetFactionClass(character, self.index)
end
FACTION_FOUNDATION = FACTION.index
