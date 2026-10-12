FACTION.name = "faction.mtf"
FACTION.description = "faction.mtf.desc"
FACTION.color = Color(105, 135, 105)
FACTION.isDefault = false
FACTION.showCreationMenu = false
FACTION.bHumanVoices = true
FACTION.models = table.Copy(ix.faction.teams.citizen.models)
function FACTION:OnTransferred(character)
	Schema:ResetFactionClass(character, self.index)
end
FACTION_MTF = FACTION.index
