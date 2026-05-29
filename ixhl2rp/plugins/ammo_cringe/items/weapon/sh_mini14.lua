ITEM.name = "Винтовка Мини-14"
ITEM.description = "Марксманская винтовка американского производства. Версия с деревянным корпусом. Весьма несовершенное и устаревшое оружие, использующееся некоторыми силовыми структурами и гражданским населением."
ITEM.model = "models/weapons/arccw/c_ud_mini14.mdl"
ITEM.class = "arccw_ud_mini14"
ITEM.weaponCategory = "primary"
ITEM.width = 4
ITEM.height = 1
ITEM.flag = "Z"
ITEM.price = 300;
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
					["Position"] = Vector(3.822265625, -4.9462524414063, 2.0389709472656),
					["BlendMode"] = "",
					["Angles"] = Angle(36.454326629639, 3.1711353063583, -6.9382472038269),
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
					["Model"] = "models/weapons/fas2wm/rifles/w_sks.mdl",
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
	pos = Vector(-2, 200, 0),
	ang = Angle(0, 270, 0),
	fov = 14.705882352941,
}

ITEM.Info = {
	Skill = "guns",
	Distance = {[1]=6,[2]=6,[3]=4,[4]=1},
	Dmg = {AP=12,Limb=45,Shock={110,2700},Blood={48,320},Bleed=60}
}

