ITEM.name = "Бандана"
ITEM.description = "Плотная матерчатая бандана насыщенного тёмного цвета, сложенная по диагонали и завязанная так, чтобы закрывать нос и рот. Швы ровные, ткань не просвечивает — чужой взгляд упирается только в глаза. Простая и надёжная защита от пыли, дыма и лишних вопросов."
ITEM.model = Model("models/autonomous/africa/items/prop_face_scarf.mdl")
ITEM.rarity = 1
ITEM.width = 1
ITEM.height = 1
ITEM.bodyGroups = {
	[2] = 1
}
-- Bodygroups used on the militia/conscript model (open-face uniform). Совпадает с
-- гражданским значением, но задано явно: иначе смена ITEM.bodyGroups молча
-- утянула бы за собой и модель ополченца.
ITEM.bodyGroupsMilitia = {
	[2] = 1,
}
ITEM.equip_inv = 'mask'
ITEM.equip_slot = nil
