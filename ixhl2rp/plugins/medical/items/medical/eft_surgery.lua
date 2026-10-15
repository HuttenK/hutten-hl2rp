-- Legacy item IDs intentionally retained so stored inventories and recipes migrate.
local def = ix.Medicine.Catalog["eft_surgery"]
ITEM.name = def.name
ITEM.description = "Пять применений. Устраняет перелом выбранной конечности или обструкцию дыхательных путей от SCP-1048. Не лечит паралич от SCP-173 и не восстанавливает утраченную конечность; кровотечение и раны лечатся отдельно."
ITEM.model = Model(ix.Medicine.Model(def))
ITEM.skin = def.skin or 0
ITEM.width = 2
ITEM.height = 2
ITEM.cost = 120
ITEM.rarity = 2
ITEM.stats.uses = def.uses
ITEM.stats.time = def.time
ITEM.medicalID = "eft_surgery"
