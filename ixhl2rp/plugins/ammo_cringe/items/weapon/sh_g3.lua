ITEM.name = "Винтовка G3A3"
ITEM.description = "Немецкая штурмовая винтовка послевоенного периода. В 2000 годах была выведена из эксплуатации и с тех пор пользуется популярностью лишь среди гражданских лиц и полиции. Многие решения в этом оружии были признаны не самыми удачными, однако это не помешало ему стать одним из самых знаменитых образцов личного вооружения в мире. Версия под патрон калибра 7.62.51 мм."
ITEM.model = "models/weapons/arccw/c_ur_g3.mdl"
ITEM.class = "arccw_ur_g3"
ITEM.weaponCategory = "primary"
ITEM.width = 4
ITEM.height = 2
ITEM.flag = "Z"
ITEM.price = 390;
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
					["Position"] = Vector(4.4104919433594, -3.2929999828339, 0.28570556640625),
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
					["Model"] = "models/weapons/arccw_ins2/w_fal.mdl",
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
	pos = Vector(-9.5, 200, 2.5),
	ang = Angle(0, 270, 0),
	fov = 14.9976470588235,
}

ITEM.Info = {
	Skill = "guns",
	Damage = {58, 72},
	Distance = {[1]=6,[2]=6,[3]=6,[4]=3},
	Dmg = {AP=11,Limb=65,Shock={120,3000},Blood={55,400},Bleed=65}
}

