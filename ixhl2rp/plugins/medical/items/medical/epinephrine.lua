-- Legacy item IDs intentionally retained so stored inventories and recipes migrate.
local def = ix.Medicine.Catalog["epinephrine"]
ITEM.name = def.name
ITEM.description = "Устраняет остановку сердца от SCP-049. Пробуждает пострадавшего после устранения тяжёлых ран и кровопотери; поддерживает сознание 90 секунд. Не заменяет перевязки и переливание крови."
ITEM.model = Model(ix.Medicine.Model(def))
ITEM.skin = def.skin or 0
ITEM.width = 1
ITEM.height = 1
ITEM.cost = 60
ITEM.rarity = 2
ITEM.stats.uses = def.uses
ITEM.stats.time = def.time
ITEM.medicalID = "epinephrine"
