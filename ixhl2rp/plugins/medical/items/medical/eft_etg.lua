-- Legacy item IDs intentionally retained so stored inventories and recipes migrate.
local def = ix.Medicine.Catalog["eft_etg"]
ITEM.name = def.name
ITEM.description = "Стимулятор восстановления повреждённых тканей. На 60 секунд замедляет разъедание тканей от SCP-106 на 50%, но не останавливает и не обращает его вспять. Повторная доза обновляет время без усиления эффекта. Не восполняет потерянную кровь."
ITEM.model = Model(ix.Medicine.Model(def))
ITEM.skin = def.skin or 0
ITEM.width = 1
ITEM.height = 1
ITEM.cost = 120
ITEM.rarity = 2
ITEM.stats.uses = def.uses
ITEM.stats.time = def.time
ITEM.medicalID = "eft_etg"
