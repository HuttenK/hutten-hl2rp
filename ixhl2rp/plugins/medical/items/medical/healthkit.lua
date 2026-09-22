-- Legacy item IDs intentionally retained so stored inventories and recipes migrate.
local def = ix.Medicine.Catalog["healthkit"]
ITEM.name = def.name
ITEM.description = "Обрабатывает раны и восстанавливает повреждённые ткани. Переломы требуют шины или операции."
ITEM.model = Model(ix.Medicine.Model(def))
ITEM.skin = def.skin or 0
ITEM.width = 2
ITEM.height = 2
ITEM.cost = 60
ITEM.rarity = 2
ITEM.stats.uses = def.uses
ITEM.stats.time = def.time
ITEM.medicalID = "healthkit"
