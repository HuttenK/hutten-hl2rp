ITEM.name = "Капеллина Дорожного караула"
ITEM.description = "Стальная шляпа с широкими полями. Бережёт голову от ударов сверху и избавляет от необходимости приветливо прищуриваться на солнце."
ITEM.model = "models/kettlehelm2.mdl"
ITEM.width = 2
ITEM.height = 2
ITEM.cost = 95
ITEM.helmetGroups = {archer = 1, knight = 1}
ITEM.protectionDescription = "Открытый шлем: частичная защита головы; лицо остаётся открытым."
ITEM.armor = {
 class = 1,
 density = 0.55,
 max_durability = 260,
 coverage = {[HITGROUP_HEAD] = 0.75},
 damage = {slash = 0.8, club = 2, fists = 1, bullet = 8, buckshot = 8, impulse = 12, explosive = 30, acid = 12, poison = 12, shock = 4, burn = 6, physics = 4},
 penetration = {slash = 0.5, club = 1, fists = 1, bullet = 1, buckshot = 1, impulse = 1, explosive = 1, acid = 1, poison = 1, shock = 1, burn = 1, physics = 1}
}
