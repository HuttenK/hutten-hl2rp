PLUGIN.name = "Civic Journal"
PLUGIN.author = "Hutten"
PLUGIN.description = "Private, persistent field records connecting development and assignments."

if CLIENT then return end

local function Record(character, key, value)
	if not character then return end
	local entries = table.Copy(character:GetData("civicJournal", {}))
	table.insert(entries, 1, {key = key, value = tostring(value or ""):utf8sub(1, 120), time = os.time()})
	while #entries > 32 do table.remove(entries) end
	character:SetData("civicJournal", entries)
end

function PLUGIN:CharacterLevelChanged(client, character, previous, current)
	Record(character, "civic.event.level", current)
end

function PLUGIN:CharacterAcceptedTask(client, character, task)
	Record(character, "civic.event.task", task.title)
end

function PLUGIN:CharacterCompletedTask(client, character, task)
	Record(character, "civic.event.complete", task.title)
end

function PLUGIN:CharacterAllocatedSpecials(client, character)
	Record(character, "civic.event.skills")
end

function PLUGIN:CharacterCraftedRecipe(client, character, recipe)
	-- Batch repeated production into one entry per recipe per minute.
	local recent = character.ixCivicCraftRecord
	if recent and recent.id == recipe.uniqueID and recent.time > CurTime() then return end
	character.ixCivicCraftRecord = {id = recipe.uniqueID, time = CurTime() + 60}
	Record(character, "civic.event.craft", L(recipe.name, client))
end
