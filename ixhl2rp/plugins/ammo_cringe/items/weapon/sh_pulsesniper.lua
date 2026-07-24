ITEM.name = "OSIPMR"
ITEM.description = "Импульсная снайперская винтовка сил Надзора. Убойная сила данного оружия является совершенно запредельной. Способна пробивать легкобронированные цели, вроде самодельных броневиков сопротивления или металлических укрытий. В конструкцию встроен 8-ми кратный прицел со встроенным тепловизором и NVG. Используется сугубо силами Сверх-Надзора."
ITEM.model = "models/weapons/w_heavysniper.mdl"
ITEM.class = "arccw_pulsesniper_tn"
ITEM.weaponCategory = "primary"
ITEM.classes = {CLASS_EOW}
ITEM.width = 4
ITEM.height = 2
ITEM.noBusiness = true

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
					["Bone"] = "spine",
					["UniqueID"] = "2961833181",
					["BoneMerge"] = false,
					["EyeTargetUID"] = "",
					["Position"] = Vector(17.3359375, -1.4512634277344, -7.8893432617188),
					["BlendMode"] = "",
					["Angles"] = Angle(-22.310424804688, -160.15397644043, -16.494787216187),
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
					["Model"] = "models/weapons/w_heavysniper.mdl",
				},
			},
		},
		["self"] = {
			["DrawOrder"] = 0,
			["UniqueID"] = "2864977925",
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

ITEM.iconCam = {
	pos = Vector(0, 200, 0),
	ang = Angle(0, 270, 8),
	fov = 14.705882352941,
}

ITEM.Info = {
	Skill = "impulse",
	Damage = {108, 135},
	Distance = {[1]=5,[2]=5,[3]=5,[4]=5},
	Dmg = {AP=22,Limb=90,Shock={600,18000},Blood={90,600},Bleed=5}
}

