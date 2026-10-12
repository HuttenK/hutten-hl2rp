ITEM.name = "Сложенная грузовая тележка"
ITEM.description = "Тележка для восьми грузовых ящиков. Поднесите ящик к платформе — он закрепится автоматически."
ITEM.model = "models/props_junk/pushcart02a.mdl"
ITEM.width = 3
ITEM.height = 3
ITEM.category = "Логистика"
ITEM.functions.Deploy = {
	name = "Установить", icon = "icon16/lorry.png",
	OnRun = function(item) ix.PushCart:Deploy(item, "ix_pushcart") return false end,
	OnCanRun = function(item) return !IsValid(item:GetEntity()) and !item.inUse end
}
