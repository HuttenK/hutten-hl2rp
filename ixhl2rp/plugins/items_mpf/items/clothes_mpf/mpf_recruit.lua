ITEM.name = "item.mpf_recruit"
ITEM.description = "item.mpf_recruit.desc"
ITEM.genderReplacement = {
	[GENDER_MALE] = "models/autonomous/eurasia_nemanus/metropolice/male.mdl",
	[GENDER_FEMALE] = "models/autonomous/eurasia_nemanus/metropolice/female.mdl"
}
ITEM.uniform = 0
ITEM.primaryVisor = Vector(0, 1, 1)
ITEM.secondaryVisor = Vector(0, 2, 2)
ITEM.specialization = nil
ITEM.bodyGroups = {
	[3] = 3,
}
-- Самая слабая форма ГО: ровно вдвое хуже обычной (mpf_regular) по трём осям —
-- вдвое меньше запас прочности, вдвое меньше площадь покрытия (вдвое чаще удар
-- проходит мимо брони) и вдвое больший пробой по плотности: урон «через броню»
-- считается как (1 - density), т.е. 0.5 против 0.25 у обычной формы.
-- Таблицы penetration/damage оставлены как у обычной формы: у mpf_regular они уже
-- по большинству классов = 1 (максимум), а удвоение damage дало бы вчетверо
-- быстрый износ в связке с урезанной прочностью.
ITEM.armor = {
	class = 1,
	max_durability = 375,
	density = 0.5,
	coverage = {
		[HITGROUP_HEAD] = 0.25,
		[HITGROUP_CHEST] = 0.5,
		[HITGROUP_STOMACH] = 0.125,
		[HITGROUP_LEFTARM] = 0.15,
		[HITGROUP_RIGHTARM] = 0.15,
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
