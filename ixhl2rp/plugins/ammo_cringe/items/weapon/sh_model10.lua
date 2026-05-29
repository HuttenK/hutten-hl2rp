ITEM.name = "Револьвер 329PD"
ITEM.description = "Cверхлегкий 6-зарядный револьвер калибра .44 Magnum, созданный для самообороны и ношения, весом всего около 600 грамм. Он оснащен рамой из скандиевого сплава и титановым барабаном, что делает его одним из самых легких и прочных револьверов в своем классе. Если вы собираетесь убить кого-то в толпе и при этом успешно скрыться, то этот револьвер - ваш выбор."
ITEM.model = "models/weapons/arccw/c_ur_329pd.mdl"
ITEM.class = "arccw_ur_329"
ITEM.weaponCategory = "sidearm"
ITEM.flag = "Z"
ITEM.width = 2
ITEM.height = 1
ITEM.price = 145;
ITEM.noBusiness = true

ITEM.iconCam = {
	pos = Vector(-2.8, 248.36601257324, 3.65),
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
					["Position"] = Vector(-7.2545166015625, 2.3027777671814, -5.39306640625),
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
					["Model"] = "models/weapons/arccw_ins2/w_38rev.mdl",
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
	Dmg = {AP=5,Limb=35,Shock={80,2000},Blood={35,160},Bleed=55}
}

