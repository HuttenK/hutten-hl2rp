-- Legacy item IDs intentionally retained so stored inventories and recipes migrate.
local def = ix.Medicine.Catalog["eft_l1"]
ITEM.name = def.name
ITEM.description = "Устраняет аномальное истощение от SCP-966 и нервный шок. Подавляет боль на 2 минуты. Не устраняет остановку сердца, инфекцию или кровопотерю."
ITEM.model = Model(ix.Medicine.Model(def))
ITEM.skin = def.skin or 0
ITEM.width = 1
ITEM.height = 1
ITEM.cost = 120
ITEM.rarity = 2
ITEM.stats.uses = def.uses
ITEM.stats.time = def.time
ITEM.medicalID = "eft_l1"
