ITEM.name = "Защитные наплечники"
ITEM.description = "Наружные защитные накладки. Имеют собственную прочность, сопоставимую с одной бронепластиной."
ITEM.model = "models/sd/citizens/props/shoulders.mdl"
ITEM.width = 2
ITEM.height = 1
ITEM.equip_inv = "armprotection"
ITEM.equip_slot = nil
ITEM.bodyGroups = {[5] = 1}
ITEM.bodyGroupsMPF = {}
ITEM.bodyGroupsMilitia = {}
ITEM.limbPadding = true
ITEM.armor = {
	class = 2,
	max_durability = 500,
	density = 0.75,
	coverage = {
		[HITGROUP_LEFTARM] = 0.5,
		[HITGROUP_RIGHTARM] = 0.5,
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
