ITEM.name = "Ручной однозарядный гранатомет M79"
ITEM.description = "Ручной гранатомёт американского производства. Был популярен в годы Вьетнамской войны, что, впрочем, не мешает ему принимать участие и в современных конфликтах. Отсутствие как таковой эргономики, запредельный вес и полное отсутствие возможностей для модификации делает этот гранатомёт весьма спорным решением, однако за неимением лучшего - сойдёт."
ITEM.model = "models/weapons/arccw/c_ud_m79.mdl"
ITEM.class = "arccw_ud_m79"
ITEM.weaponCategory = "primary"
ITEM.width = 4
ITEM.height = 1
ITEM.flag = "Z"
ITEM.price = 250;
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
					["UniqueID"] = "3955494487",
					["BoneMerge"] = false,
					["EyeTargetUID"] = "",
					["Position"] = Vector(2.2767333984375, -3.71337890625, 1.6093139648438),
					["BlendMode"] = "",
					["Angles"] = Angle(35.397720336914, 6.2540001869202, 5.5118503570557),
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
					["Model"] = "models/weapons/arccw_ins2/w_m590.mdl",
				},
			},
		},
		["self"] = {
			["DrawOrder"] = 0,
			["UniqueID"] = "4155247001",
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
	pos = Vector(-10.2, 200, 2.5),
	ang = Angle(0, 270, 0),
	fov = 14.9976470588235,
}

ITEM.Info = {
	Skill = "guns",
	Launcher = true,
	Damage = {240, 300},
	Distance = {[1]=15,[2]=10,[3]=5,[4]=0},
	Dmg = {AP=30,Limb=50,Shock={555,25000},Blood={250,500},Bleed=75}
}

