-- Legacy item IDs intentionally retained so stored inventories and recipes migrate.
local def = ix.Medicine.Catalog["epinephrine"]
ITEM.name = def.name
ITEM.description = "Временно поддерживает сознание и подавляет боль на 90 секунд."
ITEM.model = Model(ix.Medicine.Model(def))
ITEM.skin = def.skin or 0
ITEM.width = 1
ITEM.height = 1
ITEM.cost = 60
ITEM.rarity = 2
ITEM.stats.uses = def.uses
ITEM.stats.time = def.time
ITEM.medicalID = "epinephrine"
