ITEM.name = "Пистолет Glock-17"
ITEM.description = "Австрийский пистолет, разработанный фирмой Glock для нужд Вооружённых сил Австрии. В настоящий момент этот пистолет является одним из самых распространенных в мире. Поставляется в самые крупные армии мира. Некоторое время стоял на вооружении армии Надзора и Патруля Альянса. Существует модификация под импульсный боеприпас."
ITEM.model = "models/flaymi/anomaly/weapons/w_models/wpn_glock_w.mdl"
ITEM.class = "arccw_ud_glock"
ITEM.weaponCategory = "sidearm"
ITEM.flag = "Z"
ITEM.width = 2
ITEM.height = 1
ITEM.price = 200;
ITEM.noBusiness = true

ITEM.iconCam = {
	pos = Vector(-2.5, 248.36601257324, 3.4),
	ang = Angle(0, 270, 0),
	fov = 3.9411764705882,qй
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
	Damage = {28, 39},
	Distance = {[1]=6,[2]=4,[3]=2,[4]=-2},
	Dmg = {AP=7,Limb=40,Shock={90,2200},Blood={40,200},Bleed=60}
}

