ITEM.name           = "Дробовик SPAS-12"
ITEM.description    = "Итальянский полуавтоматический дробовик под патрон калибра 12/70 мм. Наравне с такими дробовиками, как Remington 870 и Winchester 1897, Franchi Spas-12 является настоящей легендой среди знающих людей. Ружьё сочетает в себе высокую убойную силу и скорострельность, а самое главное - может быть серьёзно модифицирован владельцем. В настоящее время стоит на вооружении Патруля Альянса и штурмовых подразделений Гражданской Обороны. Существуют модификации под патрон с импульсным зарядом."
ITEM.model          = "models/weapons/tnmmod/w_shotgun.mdl"
ITEM.class          = "arccw_ur_spas12"
ITEM.weaponCategory = "primary"
ITEM.flag           = "Z"
ITEM.width          = 4
ITEM.height         = 1
ITEM.rarity         = 2
ITEM.contraband     = true
ITEM.noBusiness     = true

ITEM.iconCam = {
	pos = Vector(0, 200, 1),
	ang = Angle(0, 270, 0),
	fov = 13
}

ITEM.pacData = {
	[1] = {
		["children"] = {
			[1] = {
				["children"] = {},
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
					["UniqueID"] = "3196800276",
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
					["Position"] = Vector(9.7060546875, -4.0811157226563, -0.068412780761719),
					["AngleOffset"] = Angle(0, 0, 0),
					["AlternativeScaling"] = false,
					["Hide"] = false,
					["OwnerEntity"] = false,
					["Scale"] = Vector(1, 1, 1),
					["ClassName"] = "model",
					["EditorExpand"] = false,
					["Size"] = 0.9,
					["ModelFallback"] = "",
					["Angles"] = Angle(31.623342514038, 8.4504747390747, -0.0010232086060569),
					["TextureFilter"] = 3,
					["Model"] = "models/weapons/tnmmod/w_shotgun.mdl",
					["BlendMode"] = "",
				},
			},
		},
		["self"] = {
			["DrawOrder"] = 0,
			["UniqueID"] = "3903261695",
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

-- ArcCW при Give() автоматически выдаёт DefaultClip патронов в резерв.
-- Сбрасываем их и восстанавливаем только сохранённый в айтеме боезапас.
function ITEM:OnEquipWeapon(client, weapon)
	local ammoType = weapon:GetPrimaryAmmoType()

	-- Убираем автоматически выданные резервные патроны
	client:SetAmmo(0, ammoType)

	-- Восстанавливаем патроны из айтема
	local saved = self:GetData("ammo", 0)
	weapon:SetClip1(saved)
end

function ITEM:OnUnequipWeapon(client, weapon)
	-- Сохраняем текущий боезапас при снятии
	self:SetData("ammo", weapon:Clip1())

	-- Убираем резервные патроны при снятии чтобы не накапливались
	local ammoType = weapon:GetPrimaryAmmoType()
	client:SetAmmo(0, ammoType)
end

ITEM.Info = {
	Skill = "guns",
	Distance = {[1]=8,[2]=3,[3]=-5,[4]=-15},
	Dmg = {AP=9,Limb=34,Shock={555,25000},Blood={250,500},Bleed=75}
}

