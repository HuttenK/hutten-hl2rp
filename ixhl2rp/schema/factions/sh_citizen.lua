FACTION.name = "Жители"
FACTION.info = "Житель средневекового мира"
FACTION.description = "Начните историю своего персонажа."
FACTION.color = Color(150, 125, 100, 255)
FACTION.icon = Material("autonomous/factions/citizen.png")
FACTION.showCreationMenu = true
FACTION.isDefault = true
FACTION.bHumanVoices = true

local startingModel = "models/players/templar_archer_03.mdl"
FACTION.models = {
 [1] = {startingModel},
 [2] = {startingModel},
}
FACTION.sdSkinCounts = {[startingModel] = 12}
FACTION.npcRelations = {
	["npc_strider"] = D_HT,
	["npc_metropolice"] = D_NU
}

function FACTION:GetModels(client, gender)
	return self.models[gender or 1] or {}
end

function FACTION:OnTransferred(character)
	Schema:ResetFactionClass(character, self.index)
end

-- Стартовый баланс гражданина. Вызывается ядром (GM:OnCharacterCreated ->
-- faction:OnCharacterCreated) один раз при создании персонажа.
function FACTION:OnCharacterCreated(client, character)
	character:SetMoney(150)
end

function FACTION:GenerateName(gender)
 -- The optional name-list addon is not required for character creation.
 -- Leave the field empty so the player can enter their own name.
 if not isfunction(GetHumanFirstNames) or not isfunction(GetHumanLastNames) then return "" end
 local firstNames, lastNames = GetHumanFirstNames(gender == 1), GetHumanLastNames()
 if not istable(firstNames) or not istable(lastNames) or #firstNames == 0 or #lastNames == 0 then return "" end
 local first, last = firstNames[math.random(#firstNames)], lastNames[math.random(#lastNames)]
 if not isstring(first) or not isstring(last) then return "" end
 return first .. " " .. last
end

FACTION_CITIZEN = FACTION.index
