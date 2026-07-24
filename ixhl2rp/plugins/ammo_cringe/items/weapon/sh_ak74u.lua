ITEM.name = "Автомат АК-74У"
ITEM.description = "Советский специализированный автомат, созданный для специальных подразделений силовых ведомств и ВДВ ВС СССР. Имеет эталонную эргономику и компактность, позволившие ему быть популярным даже в современности. Имеет широкую базу для модификаций, что могут сильно увеличить его боевые возможности. "
ITEM.model = "models/weapons/arccw_insurgency/w_aks74u.mdl"
ITEM.class = "arccw_ins_aks74u_tn"
ITEM.weaponCategory = "primary"
ITEM.width = 3
ITEM.height = 2
ITEM.flag = "Z"
ITEM.price = 385;
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
					["UniqueID"] = "3264878277",
					["BoneMerge"] = false,
					["EyeTargetUID"] = "",
					["Position"] = Vector(3.822265625, -3.8462524414063, 2.0389709472656),
					["BlendMode"] = "",
					["Angles"] = Angle(36.454326629639, 1.1711353063583, -6.9382472038269),
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
					["Model"] = "models/weapons/arccw_insurgency/w_aks74u.mdl",
				},
			},
		},
		["self"] = {
			["DrawOrder"] = 0,
			["UniqueID"] = "3498749371",
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
	pos = Vector(-5.2, 200, 2.5),
	ang = Angle(0, 270, 0),
	fov = 10.4976470588235,
}

ITEM.Info = {
	Skill = "guns",
	Damage = {47, 58},
	Distance = {[1]=5,[2]=1,[3]=-2,[4]=-5},
	Dmg = {AP=8,Limb=32,Shock={90,1900},Blood={26,110},Bleed=50}
}

