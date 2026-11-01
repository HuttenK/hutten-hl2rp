ITEM.name = "Инвалидная коляска"
ITEM.description = "Коляска для перевозки одного пострадавшего сидя. Подведите раненого к коляске и нажмите использование, затем возьмитесь за ручки."
ITEM.model = "models/props_unique/wheelchair01.mdl"
ITEM.width = 3
ITEM.height = 3
ITEM.category = "Логистика"
ITEM.functions.Deploy = {
 name = "Установить", icon = "icon16/lorry.png",
 OnRun = function(item) ix.PushCart:Deploy(item, "ix_medical_wheelchair") return false end,
 OnCanRun = function(item) return not IsValid(item:GetEntity()) and not item.inUse end
}
