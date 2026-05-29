ITEM.name = "Пистолет M1911"
ITEM.description = "Полуавтоматический пистолет американского производства, использовавшийся в армиях половины стран мира. Сочетает в себе высокую убойную силу, скорострельность и простоту в использовании. Имеет один крупный недостаток: вместимость магазина крайне мала. В настоящее время пистолет используется силами сопротивления и второсортными подразделениями армии Надзора."
ITEM.model = "models/weapons/arccw/c_ur_m1911.mdl"
ITEM.class = "arccw_ur_m1911"
ITEM.weaponCategory = "sidearm"
ITEM.flag = "Z"
ITEM.width = 2
ITEM.height = 1
ITEM.price = 200;
ITEM.noBusiness = true

ITEM.iconCam = {
	pos = Vector(-2.5, 248.36601257324, 3.4),
	ang = Angle(0, 270, 0),
	fov = 3.9411764705882,
}
ITEM.cpArmory = true
ITEM.pacData = {
	[1] = {
		["children"] = {
			[1] = {
				["children"] = {
				},
				["self"] = {
					["Invert"] = false,
					["EyeTargetName"] = "",
					["NoLighting"] = false,
					["OwnerName"] = "self",
					["AimPartName"] = "",
					["IgnoreZ"] = false,
					["AimPartUID"] = "",
					["Materials"] = "",
					["Name"] = "",
					["LevelOfDetail"] = 0,
					["NoTextureFiltering"] = false,
					["PositionOffset"] = Vector(0, 0, 0),
					["NoCulling"] = false,
					["Translucent"] = false,
					["DrawOrder"] = 0,
					["Alpha"] = 1,
					["Material"] = "",
					["Bone"] = "pelvis",
					["UniqueID"] = "4251342202",
					["BoneMerge"] = false,
					["EyeTargetUID"] = "",
					["Position"] = Vector(-7.162353515625, -1.9388008117676, -4.5009765625),
					["BlendMode"] = "",
					["Angles"] = Angle(6.790819644928, -88.49681854248, 3.8541214466095),
					["Hide"] = false,
					["EyeAngles"] = false,
					["Scale"] = Vector(1, 1, 1),
					["AngleOffset"] = Angle(0, 0, 0),
					["EditorExpand"] = false,
					["Size"] = 1,
					["Color"] = Vector(1, 1, 1),
					["ClassName"] = "model2",
					["IsDisturbing"] = false,
					["ModelModifiers"] = "",
					["Model"] = "models/weapons/arccw_ins2/w_1911.mdl",
				},
			},
		},
		["self"] = {
			["DrawOrder"] = 0,
			["UniqueID"] = "3557420388",
			["AimPartUID"] = "",
			["Hide"] = false,
			["Duplicate"] = false,
			["ClassName"] = "group",
			["OwnerName"] = "self",
			["IsDisturbing"] = false,
			["Name"] = "my outfit",
			["EditorExpand"] = true,
		},
	},
}

ITEM.bDropOnDeath = true

ITEM.Info = {
	Skill = "guns",
	Distance = {[1]=5,[2]=2,[3]=-2,[4]=-5},
	Dmg = {AP=6,Limb=38,Shock={90,2200},Blood={40,200},Bleed=60}
}

