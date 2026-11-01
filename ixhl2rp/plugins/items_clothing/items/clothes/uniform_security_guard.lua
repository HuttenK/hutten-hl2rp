ITEM.name = "Форма охранника"
ITEM.description = "Полная форма сотрудника службы безопасности. Меняет внешний вид до снятия. Не предоставляет защиты или бонусов."
ITEM.model = "models/props_c17/SuitCase001a.mdl"
ITEM.width = 2
ITEM.height = 2
ITEM.equip_inv = "torso"
ITEM.equip_slot = nil

ITEM.displayID = ix.Appearance:New("uniform_security_guard", {
	slot = 13,
	layer = ix.Appearance.Layer.Main,
	fullBodyModel = "models/arty/codmw2022/sp/mexican federal police/grunts/scp_oz_security_1.mdl"
})
