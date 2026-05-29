ITEM.name = "Модульная платформа АК"
ITEM.description = "Советская общевойсковая штурмовая винтовка под калибр 7.62.39 мм. Для автомата 70-х годов прошлого века он имеет весьма неплохие характеристики и эргономику. Устаревшая основа позволяет достаточно хорошо модифицировать винтовку, что делает это оружие одним из самых востребованных даже в настоящее время."
ITEM.model = "models/weapons/arccw_insurgency/w_ak74.mdl"
ITEM.class = "arccw_ur_ak"
ITEM.weaponCategory = "primary"
ITEM.width = 4
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
					["Model"] = "models/weapons/arccw_insurgency/w_ak74.mdl",
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
	fov = 14.9976470588235,
}


function ITEM:OnEquipWeapon(client, weapon)
	local ammoType = weapon:GetPrimaryAmmoType()

	client:SetAmmo(0, ammoType)

	local saved = self:GetData("ammo", 0)
	weapon:SetClip1(saved)
end

function ITEM:OnUnequipWeapon(client, weapon)
	self:SetData("ammo", weapon:Clip1())

	local ammoType = weapon:GetPrimaryAmmoType()
	client:SetAmmo(0, ammoType)
end


ITEM.Info = {
	Skill = "guns",
	Distance = {[1]=5,[2]=5,[3]=3,[4]=-1},
	Dmg = {AP=11,Limb=40,Shock={100,2100},Blood={32,170},Bleed=55}
}

