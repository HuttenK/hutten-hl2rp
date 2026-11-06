ITEM.name = "Латы Белого обета"
ITEM.description = "Светлый рыцарский доспех, достойный торжественной клятвы. Чистить его после дороги — отдельное испытание верности."
ITEM.model = "models/armor_stand.mdl"
ITEM.replacement = "models/players/templar_knight_01.mdl"
ITEM.capeBodygroup = 5
ITEM.width = 2
ITEM.height = 3
ITEM.cost = 460
ITEM.protectionDescription = "Тяжёлые латы: высокая защита торса, рук и ног; скорость передвижения снижена на 30%."
ITEM.armor = {
 class = 3,
 density = 0.85,
 max_durability = 1000,
 coverage = {
  [HITGROUP_CHEST] = 1, [HITGROUP_STOMACH] = 1,
  [HITGROUP_LEFTARM] = 0.95, [HITGROUP_RIGHTARM] = 0.95,
  [HITGROUP_LEFTLEG] = 0.9, [HITGROUP_RIGHTLEG] = 0.9
 },
 damage = {slash = 0.5, club = 1.5, fists = 1, bullet = 8, buckshot = 8, impulse = 12, explosive = 30, acid = 12, poison = 12, shock = 4, burn = 6, physics = 4},
 penetration = {slash = 0.3, club = 0.7, fists = 1, bullet = 1, buckshot = 1, impulse = 1, explosive = 1, acid = 1, poison = 1, shock = 1, burn = 1, physics = 1}
}
