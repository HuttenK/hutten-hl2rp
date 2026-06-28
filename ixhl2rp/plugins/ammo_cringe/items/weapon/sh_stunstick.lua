ITEM.name = "Парализатор"
ITEM.description = "Самое лучшее средство контроля недовольной толпы. Металлический жезл бьет больно, а если подключить к нему еще и электрические разряды, то любой, даже самый закоренелый бунтовщик, будет лежать на полу и сопеть."
ITEM.model = "models/weapons/tnmmod/w_stunbaton.mdl"
ITEM.class = "ix_stunstick"
ITEM.weaponCategory = "melee"
ITEM.width = 1
ITEM.height = 2
ITEM.base = "weapon"
ITEM.category = "Melee"
ITEM.noBusiness = true

ITEM.iconCam = {
	pos = Vector(0, 200, 0),
	ang = Angle(0, 270, 0),
	fov = 12,
}

ITEM.Info = {
	Dmg = {
		Limb = 5,
		Shock = {15, 30},
		Blood = {0, 0},
		Bleed = 0,
		AP = 0
	}
}

ITEM.pacData = {
	[1] = {
		["children"] = {
			[1] = {
				["children"] = {
				},
				["self"] = {
					["Model"] = "models/weapons/w_stunbaton.mdl",
					["ClassName"] = "model",
					["Bone"] = "pelvis",
					["Position"] = Vector(-5, -2, 0),
					["Angles"] = Angle(0, 0, 90),
					["UniqueID"] = "1",
				},
			},
		},
		["self"] = {
			["ClassName"] = "group",
			["UniqueID"] = "2",
			["EditorExpand"] = true,
		},
	},
}
