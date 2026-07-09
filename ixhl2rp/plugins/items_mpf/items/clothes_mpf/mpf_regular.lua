ITEM.name = "item.mpf_regular"
ITEM.description = "item.mpf_regular.desc"
ITEM.genderReplacement = {
	[GENDER_MALE] = "models/autonomous/eurasia_nemanus/metropolice/male.mdl",
	[GENDER_FEMALE] = "models/autonomous/eurasia_nemanus/metropolice/female.mdl"
}
ITEM.uniform = 0
ITEM.primaryVisor = Vector(0, 1, 1)
ITEM.secondaryVisor = Vector(0, 2, 2)
ITEM.specialization = nil
ITEM.bodyGroups = {
	[5] = 1, -- boots
}
ITEM.armor = {
	class = 1,
	max_durability = 750,
	density = 0.75,
	coverage = {
		[HITGROUP_HEAD] = 0.5,
		[HITGROUP_CHEST] = 1,
		[HITGROUP_STOMACH] = 0.25,
		[HITGROUP_LEFTARM] = 0.3,
		[HITGROUP_RIGHTARM] = 0.3,
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