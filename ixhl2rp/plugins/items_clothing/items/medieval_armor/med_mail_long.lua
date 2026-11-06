ITEM.name = "Кольчуга Сумеречного дозора"
ITEM.description = "Кольчужный доспех под длинной тёмной накидкой. Кольца держат удар, ткань скрывает пыль, а загадочный вид получается сам собой."
ITEM.model = "models/armor_stand.mdl"
ITEM.replacement = "models/players/templar_archer_06.mdl"
ITEM.width = 2
ITEM.height = 3
ITEM.cost = 280
ITEM.protectionDescription = "Кольчуга: защита торса, частично рук и ног; скорость передвижения снижена на 15%."
ITEM.armor = {
 class = 2,
 density = 0.65,
 max_durability = 600,
 coverage = {
  [HITGROUP_CHEST] = 1, [HITGROUP_STOMACH] = 1,
  [HITGROUP_LEFTARM] = 0.8, [HITGROUP_RIGHTARM] = 0.8,
  [HITGROUP_LEFTLEG] = 0.55, [HITGROUP_RIGHTLEG] = 0.55
 },
 damage = {slash = 0.8, club = 2, fists = 1, bullet = 8, buckshot = 8, impulse = 12, explosive = 30, acid = 12, poison = 12, shock = 4, burn = 6, physics = 4},
 penetration = {slash = 0.5, club = 1, fists = 1, bullet = 1, buckshot = 1, impulse = 1, explosive = 1, acid = 1, poison = 1, shock = 1, burn = 1, physics = 1}
}
