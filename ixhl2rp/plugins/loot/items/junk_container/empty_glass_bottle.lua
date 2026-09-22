ITEM.name = "item.empty_glass_bottle"
ITEM.description = "item.empty_glass_bottle.desc"
ITEM.model = "models/props_junk/garbage_glassbottle003a.mdl"
ITEM.width = 1
ITEM.height = 2
ITEM.volume = 500

-- Keep the bottle as a refillable container; no external melee SWEP is required.
function ITEM:OnLoadout()
 self:SetData("equip", false)
end
