local PLUGIN = PLUGIN

do
	local F1 = "<.*>(.*)</.*>"
	local F2 = "%1"
	local SIGN = "[sign]"
	local FIELD = "[field]"
	local SIGNF = "$s$%s$/s$"
	local FIELDF = "<span class=\"textarea\" contenteditable></span>$f$"

	function PLUGIN:ParseText(character, text)
		text = string.gsub(text, F1, F2)
		text = string.Replace(text, "$s$", "")
		text = string.Replace(text, "$/s$", "")
		text = string.Replace(text, "$f$", "")
		text = string.utf8sub(text, 1, self.maxLength)
		text = string.Replace(text, SIGN, Format(SIGNF, character:GetName()))
		text = string.Replace(text, FIELD, FIELDF)

		return text
	end
end

do
	local FIELD = "[field]"
	local FIELDF = "<span class%=%ptextarea%p contenteditable><%/span>%$f%$"

	function PLUGIN:ParseFields(character, text, fields)
		local i = 1
		for field in string.gmatch(text, FIELDF) do
			local replacement = FIELD
			
			if fields[i] and #fields[i] != 0 and !string.match(fields[i], "^s*$") then
				replacement = "[u]"..self:ParseText(character, fields[i]).."[/u]"
			end
			
			text = string.gsub(text, FIELDF, replacement, 1)

			i = i + 1
		end

		text = string.Replace(text, FIELD, "<span class=\"textarea\" contenteditable></span>$f$")

		return text
	end
end

local function DocumentSession(item, client, character, editing)
	if not item or not item.isPaper or not item.user then return false end
	local session = item.user[client]
	if not session then return false end
	if item.CanWrite then
		if not istable(session) or session.character ~= character:GetID() then return false end
		if editing and (not session.editing or not item:CanWrite(client)) then return false end
		-- The item can be traded/dropped while an editor window is still open.
		if item:GetOwner() ~= client then
			local entity = item:GetEntity()
			if not IsValid(entity) or client:GetShootPos():DistToSqr(entity:NearestPoint(client:GetShootPos())) > 128 * 128 then return false end
		end
	end
	return true
end

netstream.Hook("ixWritePaper", function(client, itemID, title, text, pickup)
	local character = client:GetCharacter()

	if !character then return end

	local item = ix.Item.instances[itemID]

	if not DocumentSession(item, client, character, true) then return end
	if not isstring(title) or not isstring(text) or #text > PLUGIN.maxLength * 4 then return end

	local owner = item:GetData("O", 0)
	local time = item:GetData("canEdit", nil)

	if item.CanWrite then
		-- Bound journals/scrolls stay editable by their author across sessions.
	elseif owner == 0 then
		item:SetData("canEdit", os.time() + 600)
	elseif owner != 0 and (time and os.time() > time) then 
		return 
	end

	text = PLUGIN:ParseText(character, text)

	item:Write(title, text, character)
	item:SetData("D", pickup)

	item.user[client] = nil
end)

netstream.Hook("ixEditPaper", function(client, itemID, fields)
	local character = client:GetCharacter()

	if !character then return end

	local item = ix.Item.instances[itemID]

	if not DocumentSession(item, client, character, false) or not istable(fields) then return end
	for _, value in pairs(fields) do
		if not isstring(value) or #value > PLUGIN.maxLength * 4 then return end
	end

	local owner = item:GetData("O", 0)

	if owner == 0 then return end

	local text = item:GetData("T", "")

	text = PLUGIN:ParseFields(character, text, fields)

	item:Write(nil, text, nil)

	item.user[client] = nil
end)

netstream.Hook("ixWritePaperClosed", function(client, itemID)
	local item = ix.Item.instances[itemID]

	if !item then return end
	if item.user and item.user[client] then
		item.user[client] = nil
	end
end)
