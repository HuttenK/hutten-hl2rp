ITEM.name = "Бронежилет сотрудника ГО"
ITEM.model = "models/autonomous/armor_tier1.mdl"
ITEM.width = 2
ITEM.height = 2
ITEM.iconCam = {
	pos = Vector(283.96502685547, -2.7559235095978, 189.72630310059),
	ang = Angle(33.174201965332, 179.3546295166, 0),
	fov = 2.9430843245987,
}
ITEM.rarity = 1
ITEM.description = "Стандартный кевларовый жилет рядового сотрудника ГО"
ITEM.equip_inv = 'vest'
ITEM.equip_slot = nil
ITEM.bodyGroups = {
	[7] = 1
}
ITEM.armor = {
	class = 2,
	max_durability = 600,
	density = 0.8,
	coverage = {
		[HITGROUP_CHEST] = 1,
		[HITGROUP_STOMACH] = 1,
		[HITGROUP_LEFTARM] = 0.5,
		[HITGROUP_RIGHTARM] = 0.5,
	},
	penetration = {
		bullet = 1,
		impulse = 1,
		buckshot = 1,
		explosive = 1,
		burn = 1,
		poison = 0,
		slash = 1,
		club = 1,
		fists = 0.1
	},
	damage = {
		bullet = 0.75,
		impulse = 1,
		buckshot = 3,
		explosive = 1,
		burn = 1,
		poison = 1,
		slash = 2,
		club = 5,
		fists = 1
	}
}
ITEM.contraband = true


-- Overlay disabled: armor is now shown via the citizen model's built-in
-- bodygroup (ITEM.bodyGroups above -> clean Main-layer auto-appearance).
-- Re-enable this block to restore the separate nato prop + Torso_OnlyHands mask.
--[[
ITEM.displayID = ix.Appearance:New("nato_torso", {
	slot = ix.Appearance.Slot.Torso,
	layer = ix.Appearance.Layer.Top,
	bodyMask = "Torso_OnlyHands",
	variants = {
		male = {
			model = "models/cellar/male_torso_nato.mdl"
		},
		female = {
            model = "models/cellar/female_jacket_nato.mdl"
        },
	}
})
]]