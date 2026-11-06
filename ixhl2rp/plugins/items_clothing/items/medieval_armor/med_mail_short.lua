ITEM.name = "Кольчуга Вольного копья"
ITEM.description = "Практичная кольчуга с короткой туникой. В ней легче шагать по грязи и труднее убедить сборщика податей, что вы простой крестьянин."
ITEM.model = "models/armor_stand.mdl"
ITEM.replacement = "models/players/templar_archer_04.mdl"
ITEM.width = 2
ITEM.height = 3
ITEM.cost = 250
ITEM.protectionDescription = "Кольчуга: защита торса и рук, небольшое прикрытие ног; скорость передвижения снижена на 15%."
ITEM.armor = {
 class = 2,
 density = 0.6,
 max_durability = 550,
 coverage = {
  [HITGROUP_CHEST] = 1, [HITGROUP_STOMACH] = 1,
  [HITGROUP_LEFTARM] = 0.8, [HITGROUP_RIGHTARM] = 0.8,
  [HITGROUP_LEFTLEG] = 0.35, [HITGROUP_RIGHTLEG] = 0.35
 },
 damage = {slash = 0.8, club = 2, fists = 1, bullet = 8, buckshot = 8, impulse = 12, explosive = 30, acid = 12, poison = 12, shock = 4, burn = 6, physics = 4},
 penetration = {slash = 0.5, club = 1, fists = 1, bullet = 1, buckshot = 1, impulse = 1, explosive = 1, acid = 1, poison = 1, shock = 1, burn = 1, physics = 1}
}
