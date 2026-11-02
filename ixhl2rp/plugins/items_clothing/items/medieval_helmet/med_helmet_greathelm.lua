ITEM.name = "Тотенхельм Последнего довода"
ITEM.description = "Массивный глухой шлем для тех, кто предпочитает веские доводы. Противник видит сталь, владелец — узкую полоску будущих неприятностей."
ITEM.model = "models/early_century_greathelm.mdl"
ITEM.width = 2
ITEM.height = 2
ITEM.cost = 220
ITEM.helmetGroups = {archer = 6, knight = 5}
ITEM.protectionDescription = "Глухой шлем: высокая защита головы и лица."
ITEM.armor = {
 class = 3,
 density = 0.85,
 max_durability = 600,
 coverage = {[HITGROUP_HEAD] = 1},
 damage = {slash = 0.5, club = 1.5, fists = 1, bullet = 8, buckshot = 8, impulse = 12, explosive = 30, acid = 12, poison = 12, shock = 4, burn = 6, physics = 4},
 penetration = {slash = 0.3, club = 0.7, fists = 1, bullet = 1, buckshot = 1, impulse = 1, explosive = 1, acid = 1, poison = 1, shock = 1, burn = 1, physics = 1}
}
