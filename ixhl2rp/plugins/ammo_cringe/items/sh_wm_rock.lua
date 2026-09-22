-- Ordinary crafting item; legacy ID intentionally retained.
ITEM.name = "Камень"
ITEM.description = "Хозяйственный инструмент или материал. Используется в ремесле и взаимодействиях; не экипируется как оружие."
ITEM.model = "models/props_junk/rock001a.mdl"
ITEM.category = "Инструменты и материалы"
ITEM.width = 1
ITEM.height = 2
ITEM.noBusiness = true
ITEM.DurabilityCraft = 20
function ITEM:OnInstanced() if SERVER then self:SetData("equip",false) end end
