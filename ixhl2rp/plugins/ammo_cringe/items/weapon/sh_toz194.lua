ITEM.name = "TOZ-194"
ITEM.description = "Российское помповое ружьё, разработанное в середине 1990-х годов на основе конструкции ружья ТОЗ-94. Производился на Тульском оружейном заводе. В настоящее время используется различными маргинальными ячейками из-за своей распространенности среди гражданского населения."
ITEM.model = "models/weapons/arccw_ins2/w_toz.mdl"
ITEM.class = "arccw_ins2_toz_tn"
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
	Dmg = {AP=8,Limb=32,Shock={500,22000},Blood={230,480},Bleed=70}
}

