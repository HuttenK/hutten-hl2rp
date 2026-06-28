local PLUGIN = PLUGIN

PLUGIN.name = "Recipe Unlock Notifications"
PLUGIN.author = "Hutten"
PLUGIN.description = "Notifies players when leveling a skill unlocks new crafting recipes."

if SERVER then
	-- Recipes of a track whose required level falls in (oldLevel, newLevel].
	local function GetUnlocked(character, key, oldLevel, newLevel)
		local unlocked = {}
		local learned

		for uniqueID, recipe in pairs(ix.Craft and ix.Craft.recipes or {}) do
			if not recipe.skill or recipe.skill[1] ~= key then continue end

			local req = tonumber(recipe.skill[2]) or 0
			if req <= oldLevel or req > newLevel then continue end

			-- Blueprint-gated recipes stay hidden until their schematic is learned,
			-- so don't announce ones the player hasn't discovered yet.
			if recipe.blueprint then
				learned = learned or character:GetData("craftLearned", {})
				if not learned[uniqueID] then continue end
			end

			unlocked[#unlocked + 1] = recipe
		end

		return unlocked
	end

	function PLUGIN:CharacterSkillUpdated(client, character, key, bIncreased)
		if not bIncreased or not ix.Craft then return end

		client.ixRecipeLevels = client.ixRecipeLevels or {}

		local oldLevel = client.ixRecipeLevels[key] or 0
		local newLevel = character:GetSkillModified(key)

		-- Always track the latest level; only suppress notifications during the
		-- post-load grace period (so loading a character isn't announced).
		client.ixRecipeLevels[key] = newLevel

		if not client.ixRecipeReady or newLevel <= oldLevel then return end

		local unlocked = GetUnlocked(character, key, oldLevel, newLevel)
		if #unlocked == 0 then return end

		local skillTable = ix.skills and ix.skills.list[key]
		local skillName = skillTable and L(skillTable.name, client) or key

		client:NotifyLocalized("recipeUnlock", #unlocked, skillName)

		-- List the freshly unlocked recipe names in chat (capped to avoid spam).
		local names = {}

		for i = 1, math.min(#unlocked, 6) do
			names[#names + 1] = L(unlocked[i].name, client)
		end

		if #unlocked > 6 then
			names[#names + 1] = "..."
		end

		client:ChatPrint(L("recipeUnlockList", client) .. " " .. table.concat(names, ", "))
	end

	-- Baseline every skill when the character loads so existing recipes aren't
	-- announced, then enable notifications after a short grace period.
	function PLUGIN:PlayerLoadedCharacter(client, character)
		client.ixRecipeReady = false
		client.ixRecipeLevels = {}

		for key in pairs(ix.skills and ix.skills.list or {}) do
			client.ixRecipeLevels[key] = character:GetSkillModified(key)
		end

		timer.Simple(3, function()
			if IsValid(client) then
				client.ixRecipeReady = true
			end
		end)
	end
end
