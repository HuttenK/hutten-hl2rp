ITEM.name = "Штаны с бронепластинами"
ITEM.model = "models/cellar/prop_legs_nato.mdl"
ITEM.width = 2
ITEM.height = 2
ITEM.description = "Обычные армейские штаны с бронепластинами, обеспечивающие слабую защиту ногам."
ITEM.equip_inv = 'legprotection'
ITEM.equip_slot = nil
ITEM.bodyGroups = {
	[9] = 1,
}
-- Bodygroups used when the wearer has an MPF uniform on (metropolice model,
-- different bodygroup layout than citizen models). 0 hides the uniform's boots
-- bodygroup so the armored legs show instead.
ITEM.bodyGroupsMPF = {
	[5] = 0,
}
ITEM.rarity = 1
ITEM.iconCam = {
	pos = Vector(-3.2253472805023, -271.79052734375, 326.21942138672),
	ang = Angle(49.733085632324, 89.282318115234, 0),
	fov = 2.2571822456483,
}
ITEM.armor = {
	class = 2,
	max_durability = 500,
	density = 0.75,
	coverage = {
		[HITGROUP_LEFTLEG] = 0.5,
		[HITGROUP_RIGHTLEG] = 0.5,
	},
	penetration = {
		bullet = 0.7,
		impulse = 1,
		buckshot = 0.7,
		explosive = 1,
		burn = 1,
		poison = 0,
		slash = 1,
		club = 1,
		fists = 0.1
	},
	damage = {
		bullet = 0.8,
		impulse = 1,
		buckshot = 3,
		explosive = 1,
		burn = 1,
		poison = 1,
		slash = 1.25,
		club = 4,
		fists = 1
	}
}
ITEM.contraband = true

-- Overlay disabled: leg armor is now shown via the citizen model's built-in
-- bodygroup (ITEM.bodyGroups above -> clean Main-layer auto-appearance).
-- Re-enable this block to restore the separate nato legs prop.
--[[
ITEM.displayID = ix.Appearance:New("nato_legs", {
	slot = ix.Appearance.Slot.Legs,
	layer = ix.Appearance.Layer.Bottom,
	variants = {
		male = {
			model = "models/cellar/male_legs_nato.mdl"
		},
		female = {
			model = "models/cellar/female_legs_nato.mdl"
		},
	}
})
]]