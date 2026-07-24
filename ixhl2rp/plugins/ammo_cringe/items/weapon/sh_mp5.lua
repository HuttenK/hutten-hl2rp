ITEM.name = "Пистолет-пулемет MP5"
ITEM.description = "Семейство пистолетов-пулемётов , разработанных немецкой фирмой Heckler & Koch в 1960-х годах на основе винтовки HK G3. Это одно из самых широко используемых пистолетов-пулемётов в мире, применяемое спецподразделениями, полицией и в других структурах. Популярен среди членов сопротивления за свою неприхотливость и распространенный боеприпас."
ITEM.model = "models/flaymi/anomaly/weapons/w_models/wpn_mp5_w.mdl"
ITEM.class = "arccw_ur_mp5"
ITEM.weaponCategory = "primary"
ITEM.flag = "Z"
ITEM.width = 3
ITEM.height = 2
ITEM.price = 285;
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
					["UniqueID"] = "1644819129",
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
					["Position"] = Vector(5.61328125, -4.640380859375, -3.19747924804688),
					["AngleOffset"] = Angle(0, 0, 0),
					["AlternativeScaling"] = false,
					["Hide"] = false,
					["OwnerEntity"] = false,
					["Scale"] = Vector(1, 1, 1),
					["ClassName"] = "model",
					["EditorExpand"] = false,
					["Size"] = 0.85,
					["ModelFallback"] = "",
					["Angles"] = Angle(-18.622611999512, -174.59838867188, -6.4337058067322),
					["TextureFilter"] = 3,
					["Model"] = "models/weapons/w_mp5.mdl",
					["BlendMode"] = "",
				},
			},
		},
		["self"] = {
			["DrawOrder"] = 0,
			["UniqueID"] = "186800644",
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
	pos = Vector(6.5359477996826, 222.22222900391, 5),
	ang = Angle(0, 270, 0),
	fov = 8.8235294117647,
}

ITEM.Info = {
	Skill = "guns",
	Damage = {29, 40},
	Distance = {[1]=5,[2]=2,[3]=-2,[4]=-5},
	Dmg = {AP=4,Limb=26,Shock={75,1600},Blood={22,90},Bleed=40}
}

