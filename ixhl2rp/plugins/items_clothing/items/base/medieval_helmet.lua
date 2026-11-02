local Helmet = class("ItemMedievalHelmet"):implements("ItemMedievalArmor")

function Helmet:Init()
	ix.meta.ItemMedievalArmor.Init(self)
	self.equip_inv = "head"
	self.templarHelmet = true
	self.functions.cloakOn = nil
	self.functions.cloakOff = nil
end

function Helmet:OnRegistered()
	self.plainDisplayID = ix.Appearance:New(self.uniqueID, {
		slot = 1, layer = ix.Appearance.Layer.Main,
		templarBodyGroups = {
			archer = {[2] = self.helmetGroups.archer},
			knight = {[2] = self.helmetGroups.knight}
		}
	})
	self.displayID = self.plainDisplayID
end

function Helmet:CanEquip(client)
	client = client or self.player
	if not IsValid(client) or not ix.Templar then return false end
	local value = self.helmetGroups[ix.Templar.Family(client:GetModel())]
	return value ~= nil and client:GetBodygroupCount(2) > value
end

function Helmet:IsProtectionActive(client)
	if not self:CanEquip(client) then return false end
	local outfit = client.char_outfit
	local value = self.helmetGroups[ix.Templar.Family(client:GetModel())]
	return outfit ~= nil and outfit.displayIds[1] == ix.Appearance.Database[self.plainDisplayID]
		and client:GetBodygroup(2) == value
end

function Helmet:OnEquipped(client)
	ix.meta.ItemMedievalArmor.OnEquipped(self, client)
	client.char_outfit.armor[self] = self:IsProtectionActive(client)
end

function Helmet:OnUnequipped(client)
	ix.meta.ItemClothArmor.OnUnequipped(self, client)
	-- Inactive helmets are stored as false; the parent only clears truthy entries.
	client.char_outfit.armor[self] = nil
end

return Helmet
