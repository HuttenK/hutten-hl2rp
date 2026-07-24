ITEM.name = "item.broken_ar2"
ITEM.description = "item.broken_ar2.desc"
ITEM.category = "item.category.raw"
ITEM.model = "models/weapons/w_irifle.mdl"
ITEM.rarity = 1
ITEM.width = 4
ITEM.height = 2
-- icon_model указывал на models/weapons/tfa_mmod/w_irifle.mdl из аддона TFA MMOD,
-- который здесь не смонтирован — иконка рисовалась ERROR-моделью. Без icon_model
-- иконка берётся из ITEM.model, то есть из стандартной импульсной винтовки.
ITEM.iconCam = {
	pos = Vector(60.106246948242, -803.26910400391, 172.6411895752),
	ang = Angle(11.997188568115, 93.719779968262, 0),
	fov = 2.6968534692095,
}
ITEM.contraband = true