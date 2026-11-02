local Armor = class("ItemMedievalArmor"):implements("ItemClothArmor")

function Armor:Init()
	ix.meta.ItemClothArmor.Init(self)
	self.category = "Средневековые доспехи"
	self.equip_inv = "torso"
	self.equip_slot = nil
	self:AddData("medCloak", {Transmit = ix.transmit.all})
	self.functions.cloakOn = {
		name = "Надеть наплечную накидку",
		OnCanRun = function(item) return item:CanToggleCloak(false) end,
		OnRun = function(item) item:ToggleCloak(true); return false end
	}
	self.functions.cloakOff = {
		name = "Снять наплечную накидку",
		OnCanRun = function(item) return item:CanToggleCloak(true) end,
		OnRun = function(item) item:ToggleCloak(false); return false end
	}
end

function Armor:OnRegistered()
	self.plainDisplayID = ix.Appearance:New(self.uniqueID, {
		slot = 13, layer = ix.Appearance.Layer.Main, fullBodyModel = self.replacement
	})
	self.displayID = self.plainDisplayID
	if self.cloakModel then
		self.cloakDisplayID = ix.Appearance:New(self.uniqueID .. "_cloak", {
			slot = 13, layer = ix.Appearance.Layer.Main, fullBodyModel = self.cloakModel
		})
	end
end

function Armor:CanToggleCloak(current)
	return self.cloakModel ~= nil and IsValid(self.player) and self:GetOwner() == self.player
		and self:IsEquipped() and self:GetData("medCloak", false) == current
end

function Armor:ToggleCloak(enabled)
	if not self:CanToggleCloak(not enabled) then return end
	local outfit = self.player.char_outfit
	if not outfit then return end
	outfit:RemoveItem(self)
	self:SetData("medCloak", enabled)
	self.displayID = enabled and self.cloakDisplayID or self.plainDisplayID
	outfit:AddItem(self)
	outfit:Update()
end

function Armor:OnEquipped(client)
	-- Per-instance choice: changing one tunic must not affect anybody else's.
	self.displayID = self.cloakDisplayID and self:GetData("medCloak", false) and self.cloakDisplayID or self.plainDisplayID
	ix.meta.ItemClothArmor.OnEquipped(self, client)
end

if CLIENT then
	function Armor:PaintOver(w, h)
		local value = math.Clamp(self:GetData("value", 1), 0, 1)
		surface.SetDrawColor(42, 34, 25, 220)
		surface.DrawRect(3, h - 5, w - 6, 2)
		surface.SetDrawColor(179, 146, 83, 255)
		surface.DrawRect(3, h - 5, (w - 6) * value, 2)
	end

	function Armor:PopulateTooltip(tooltip)
		local row = tooltip:AddRowAfter("description", "medArmor")
		row:SetText(self.protectionDescription .. "\nСостояние: " .. math.Round(self:GetData("value", 1) * 100) .. "%")
		row:SizeToContents()
	end
end

return Armor
