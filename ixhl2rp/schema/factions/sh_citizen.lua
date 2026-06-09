FACTION.name = "faction.citizen"
FACTION.info = "faction.citizen.info"
FACTION.description = "faction.citizen.desc"
FACTION.color = Color(150, 125, 100, 255)
FACTION.icon = Material("autonomous/factions/citizen.png")
FACTION.showCreationMenu = true
FACTION.isDefault = true
FACTION.bHumanVoices = true
FACTION.bCanUseRations = true
FACTION.bAllowDatafile = true

-- Male models: all hair variants are listed so server can look them up by index.
-- Hair1 entries are the "base" shown in the scroller; hair2/3/4 are selected via
-- the hair picker and their indices are stored in payload.model.
FACTION.models = {
	[1] = {
		-- male_01
		"models/autonomous/africa/male_01_hair1.mdl",
		"models/autonomous/africa/male_01_hair2.mdl",
		"models/autonomous/africa/male_01_hair3.mdl",
		-- male_02
		"models/autonomous/africa/male_02_hair1.mdl",
		"models/autonomous/africa/male_02_hair2.mdl",
		"models/autonomous/africa/male_02_hair3.mdl",
		-- male_03
		"models/autonomous/africa/male_03_hair1.mdl",
		"models/autonomous/africa/male_03_hair2.mdl",
		"models/autonomous/africa/male_03_hair3.mdl",
		-- male_04
		"models/autonomous/africa/male_04_hair1.mdl",
		"models/autonomous/africa/male_04_hair2.mdl",
		"models/autonomous/africa/male_04_hair3.mdl",
		"models/autonomous/africa/male_04_hair4.mdl",
		-- male_05
		"models/autonomous/africa/male_05_hair1.mdl",
		"models/autonomous/africa/male_05_hair2.mdl",
		"models/autonomous/africa/male_05_hair3.mdl",
		"models/autonomous/africa/male_05_hair4.mdl",
		-- male_06
		"models/autonomous/africa/male_06_hair1.mdl",
		"models/autonomous/africa/male_06_hair2.mdl",
		"models/autonomous/africa/male_06_hair3.mdl",
		-- male_07
		"models/autonomous/africa/male_07_hair1.mdl",
		"models/autonomous/africa/male_07_hair2.mdl",
		"models/autonomous/africa/male_07_hair3.mdl",
		"models/autonomous/africa/male_07_hair4.mdl",
		-- male_08
		"models/autonomous/africa/male_08_hair1.mdl",
		"models/autonomous/africa/male_08_hair2.mdl",
		"models/autonomous/africa/male_08_hair3.mdl",
		-- male_09
		"models/autonomous/africa/male_09_hair1.mdl",
		"models/autonomous/africa/male_09_hair2.mdl",
		"models/autonomous/africa/male_09_hair3.mdl",
		-- male_10
		"models/autonomous/africa/male_10_hair1.mdl",
		"models/autonomous/africa/male_10_hair2.mdl",
		"models/autonomous/africa/male_10_hair3.mdl",
	},
	[2] = {
		"models/autonomous/africa/female_01.mdl",
		"models/autonomous/africa/female_02.mdl",
		"models/autonomous/africa/female_03.mdl",
		"models/autonomous/africa/female_04.mdl",
		"models/autonomous/africa/female_05.mdl",
		"models/autonomous/africa/female_06.mdl",
		"models/autonomous/africa/female_07.mdl",
		"models/autonomous/africa/female_08.mdl",
		"models/autonomous/africa/female_09.mdl",
		"models/autonomous/africa/female_10.mdl",
		"models/autonomous/africa/female_11.mdl",
		"models/autonomous/africa/female_12.mdl",
		"models/autonomous/africa/female_13.mdl",
		"models/autonomous/africa/female_14.mdl",
		"models/autonomous/africa/female_15.mdl",
	},
}
FACTION.npcRelations = {
	["npc_strider"] = D_HT,
	["npc_metropolice"] = D_NU
}

function FACTION:GetModels(client, gender)
	return self.models[gender]
end

function FACTION:GetRationType(character)
	return Schema:GetCitizenRationTypes(character)
end

function FACTION:OnSpawn(client, firstTime)
	if firstTime then
		local character = client:GetCharacter()
		
		character:CreateIDCard("card")
	end
end

function FACTION:GenerateName(gender)
	local isMale = gender == 1
	local firstname = GetHumanFirstNames(isMale)[isMale and math.random(1, HUMAN_NAMES_MALE) or math.random(1, HUMAN_NAMES_FEMALE)]
	local lastname = GetHumanLastNames()[math.random(1, HUMAN_LASTNAMES)]

	return firstname:sub(1, 1):upper() .. firstname:sub(2):lower() .. " " .. lastname:sub(1, 1):upper() .. lastname:sub(2):lower()
end

FACTION_CITIZEN = FACTION.index
