-- Legacy item IDs intentionally retained so stored inventories and recipes migrate.
local def = ix.Medicine.Catalog["bandage"]
ITEM.name = def.name
ITEM.description = "Чистая полоска ткани для тугой перевязки. Останавливает кровотечения выбранной части тела, заменяя и повязку, и жгут. Кровь и повреждённые ткани восстанавливают отвары."
ITEM.model = Model(ix.Medicine.Model(def))
ITEM.skin = def.skin or 0
ITEM.width = 1
ITEM.height = 1
ITEM.cost = 60
ITEM.rarity = 2
ITEM.stats.uses = def.uses
ITEM.stats.time = def.time
ITEM.medicalID = "bandage"
