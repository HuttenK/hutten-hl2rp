-- Legacy item IDs intentionally retained so stored inventories and recipes migrate.
local def = ix.Medicine.Catalog["eft_surgery"]
ITEM.name = def.name
ITEM.description = "Пять применений. Каждое устраняет один перелом выбранной конечности. Не лечит раны, кровотечение или ампутации."
ITEM.model = Model(ix.Medicine.Model(def))
ITEM.skin = def.skin or 0
ITEM.width = 2
ITEM.height = 2
ITEM.cost = 120
ITEM.rarity = 2
ITEM.stats.uses = def.uses
ITEM.stats.time = def.time
ITEM.medicalID = "eft_surgery"
