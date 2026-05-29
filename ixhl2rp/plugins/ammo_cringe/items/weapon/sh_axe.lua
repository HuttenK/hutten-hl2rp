ITEM.name = "Топор"
ITEM.description = "Обычный топор. Хорошо прорубает как дрова, так и черепа."
ITEM.model = "models/weapons/hl2meleepack/w_axe.mdl"
ITEM.class = "arccw_axe_tn"
ITEM.category = "Melee"
ITEM.weaponCategory = "melee"
ITEM.flag = "V"
ITEM.width = 1
ITEM.height = 4
ITEM.bDropOnDeath = true
ITEM.noBusiness = true

ITEM.iconCam = {
	pos = Vector(0, 0, 200),
	ang = Angle(90, 0, 0),
	fov = 4.176470588235,
}
ITEM.Info = {
	Type=1,
	Skill = "meleeguns",
	Dmg = {Attack=8,Limb=70,Shock={50,1200},Blood={65,300},Bleed=80}
}

