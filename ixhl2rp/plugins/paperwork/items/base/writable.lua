local PLUGIN = PLUGIN
local Writable = class("ItemWritable"):implements("Item")

function Writable:Init()
	self.stackable = false
	self.isPaper = true
	self.bAllowMultiCharacterInteraction = true
	for key, transmit in pairs({O = ix.transmit.all, C = ix.transmit.all,
		T = ix.transmit.none, D = ix.transmit.none, canEdit = ix.transmit.all}) do
		self:AddData(key, {Transmit = transmit})
	end
	self.functions.View = {
		name = "use.read",
		OnRun = function(item)
			item:OpenDocument(item.player, false)
			return false
		end,
		OnCanRun = function(item) return item:GetData("O", 0) ~= 0 end
	}
	self.functions.Write = {
		name = "use.write",
		OnRun = function(item)
			if item:CanWrite(item.player) then item:OpenDocument(item.player, true) end
			return false
		end,
		OnCanRun = function(item) return item:CanWrite(item.player) end
	}
end

function Writable:CanWrite(client)
	local character = IsValid(client) and client:GetCharacter()
	if not character then return false end
	local author = self:GetData("O", 0)
	return author == 0 or author == character:GetID()
end

function Writable:OpenDocument(client, editing)
	self.user = self.user or {}
	-- A read session cannot be used to submit a forged rewrite.
	self.user[client] = {character = client:GetCharacter():GetID(), editing = editing}
	netstream.Start(client, "ixOpenPaper", self:GetID(), self:GetData("T", ""), self:GetTitle(), editing)
end

function Writable:GetTitle() return self:GetData("C", "") end

if CLIENT then
	function Writable:PopulateTooltip(tooltip)
		tooltip:AddRowAfter("name"):SetText(L("iPaperTitle", self:GetTitle()))
	end
else
	function Writable:Write(title, text, character)
		if title then self:SetData("C", tostring(title):sub(1, PLUGIN.maxTitleLength)) end
		self:SetData("T", tostring(text):sub(1, PLUGIN.maxLength), false, false, true)
		if character then self:SetData("O", character:GetID()) end
	end

	function Writable:CanTake(client)
		local author = self:GetData("O", 0)
		if author ~= 0 and self:GetData("D", false) and not client:IsAdmin() then
			local character = client:GetCharacter()
			if not character or character:GetID() ~= author then return false end
		end
	end
end

return Writable
