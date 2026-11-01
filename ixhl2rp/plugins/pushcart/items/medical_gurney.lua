ITEM.name = "Медицинская каталка"
ITEM.description = "Передвижная койка для одного пострадавшего. Подведите раненого к каталке и нажмите использование, затем возьмитесь за ручку."
ITEM.model = "models/props_unique/hospital/gurney.mdl"
ITEM.width = 3
ITEM.height = 3
ITEM.category = "Логистика"
ITEM.functions.Deploy = {
 name = "Установить", icon = "icon16/lorry.png",
 OnRun = function(item) ix.PushCart:Deploy(item, "ix_medical_gurney") return false end,
 OnCanRun = function(item) return not IsValid(item:GetEntity()) and not item.inUse end
}
