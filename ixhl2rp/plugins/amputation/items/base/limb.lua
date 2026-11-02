-- Severed limbs remain loot, not medicine. Ordinary treatment cannot restore them.
local ItemLimb = class("ItemLimb"):implements("Item")

ItemLimb = ix.meta.ItemLimb
ItemLimb.width = 1
ItemLimb.height = 2
ItemLimb.model = "models/gibs/hgibs.mdl"

function ItemLimb:Init()
	self.category = "Останки"
	self.functions.reattach = nil
end

return ItemLimb
