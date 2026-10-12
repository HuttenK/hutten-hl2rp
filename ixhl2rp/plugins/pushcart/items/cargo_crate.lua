-- Compatibility entry for already saved items and admin item spawns. World
-- items become real containers; physical crates can no longer be folded.
ITEM.name = "Грузовой ящик"
ITEM.description = "Грузовой ящик с инвентарём 4×4. Переносится руками и автоматически крепится к тележке."
ITEM.model = "models/props_junk/wood_crate001a.mdl"
ITEM.width = 2
ITEM.height = 2
ITEM.category = "Логистика"
ITEM.functions.Deploy = {
	name = "Поставить ящик", icon = "icon16/box.png",
	OnRun = function(item) ix.PushCart:Deploy(item, "ix_cargo_crate") return false end,
	OnCanRun = function(item) return !IsValid(item:GetEntity()) and !item.inUse end
}

function ITEM:OnEntityCreated(entity)
	if !SERVER then return end
	-- SetItem runs before Spawn and before the item receives its world entity.
	timer.Simple(0, function()
		if IsValid(entity) and self:GetEntity() == entity then
			ix.PushCart:ConvertCrateItem(self, entity)
		end
	end)
end
