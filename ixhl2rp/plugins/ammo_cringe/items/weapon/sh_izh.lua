ITEM.name = "Дробовик Иж-58"
ITEM.description = "Простое двуствольное ружьё с горизонтальным расположением комор. Точно опознать, когда и кем была произведена именно эта единица трудно, однако надпись “ИЖ” с затёртым номерным знаком даёт понять, что данное ружьём попало к вам в руки прямиком из России… или Советского Союза, а может быть и империи. Этого вы уже не узнаете."
ITEM.model = "models/weapons/arccw/c_ur_dbs.mdl"
ITEM.class = "arccw_ur_db"
ITEM.weaponCategory = "primary"
ITEM.width = 3
ITEM.height = 1
ITEM.flag = "Z"
ITEM.price = 200;
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
					["Model"] = "models/weapons/arccw_ins2/w_toz.mdl",
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
	pos = Vector(-13.2, 200, 2.9),
	ang = Angle(0, 270, 0),
	fov = 11.9976470588235,
}

ITEM.Info = {
	Skill = "guns",
	Distance = {[1]=8,[2]=3,[3]=-5,[4]=-15},
	Dmg = {AP=9,Limb=30,Shock={500,22000},Blood={230,480},Bleed=70}
}

