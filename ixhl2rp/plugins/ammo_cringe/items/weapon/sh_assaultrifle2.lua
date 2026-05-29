ITEM.name = "OSIPR"
ITEM.description = "Импульсная штурмовая винтовка Надзора. Самое совершенное оружие на текущий момент. Использует импульсные патроны в качестве боеприпасов. Стоит на вооружении Сверх-Надзора и специальных подразделений ГО с Армией Надзора. Имеет Био-замок, дабы предотвратить неавторизованный доступ к оружию. Весит очень много, как для штурмовой винтовки. Расчёт тут шёл явно не на простых людей…"
ITEM.model = "models/weapons/tnmmod/w_irifle.mdl"
ITEM.class = "arccw_osipr"
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
					["Skin"] = 0,
					["Invert"] = false,
					["LightBlend"] = 1,
					["CellShade"] = 0,
					["OwnerName"] = "self",
					["AimPartName"] = "",
					["IgnoreZ"] = false,
					["AimPartUID"] = "",
					["Passes"] = 1,
					["Name"] = "",
					["NoTextureFiltering"] = false,
					["DoubleFace"] = false,
					["PositionOffset"] = Vector(0, 0, 0),
					["IsDisturbing"] = false,
					["Fullbright"] = false,
					["EyeAngles"] = false,
					["DrawOrder"] = 0,
					["TintColor"] = Vector(0, 0, 0),
					["UniqueID"] = "2690408469",
					["Translucent"] = false,
					["LodOverride"] = -1,
					["BlurSpacing"] = 0,
					["Alpha"] = 1,
					["Material"] = "",
					["UseWeaponColor"] = false,
					["UsePlayerColor"] = false,
					["UseLegacyScale"] = false,
					["Bone"] = "spine",
					["Color"] = Vector(255, 255, 255),
					["Brightness"] = 1,
					["BoneMerge"] = false,
					["BlurLength"] = 0,
					["Position"] = Vector(3.919921875, -6.4338989257813, 2.810791015625),
					["AngleOffset"] = Angle(0, 0, 0),
					["AlternativeScaling"] = false,
					["Hide"] = false,
					["OwnerEntity"] = false,
					["Scale"] = Vector(1, 1, 1),
					["ClassName"] = "model",
					["EditorExpand"] = false,
					["Size"] = 1,
					["ModelFallback"] = "",
					["Angles"] = Angle(26.343179702759, -0.25702786445618, -0.57948458194733),
					["TextureFilter"] = 3,
					["Model"] = "models/weapons/tnmmod/w_irifle.mdl",
					["BlendMode"] = "",
				},
			},
		},
		["self"] = {
			["DrawOrder"] = 0,
			["UniqueID"] = "1320702186",
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
	ang	= Angle(-0.70499622821808, 268.25439453125, 0),
	fov	= 12.085652091515,
	pos	= Vector(0, 200, 0)
}

ITEM.Info = {
	Skill = "impulse",
	Distance = {[1]=5,[2]=3,[3]=3,[4]=-2},
	Dmg = {AP=18,Limb=60,Shock={90,1500},Blood={35,350},Bleed=0}
}

