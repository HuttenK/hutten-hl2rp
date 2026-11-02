ITEM.name = "Туника Чёрного тракта"
ITEM.description = "Плотная тёмная туника, усиленная подкладкой. Не заменит сталь, но примет на себя часть удара и дорожных невзгод. Наплечную накидку можно надеть или снять."
ITEM.model = "models/players/templar_archer_02.mdl"
ITEM.replacement = ITEM.model
ITEM.cloakModel = "models/players/templar_archer_01.mdl"
ITEM.width = 2
ITEM.height = 3
ITEM.cost = 65
ITEM.protectionDescription = "Плотная ткань: небольшая защита прикрытых частей тела, без замедления."
ITEM.armor = {
 class = 1,
 density = 0.18,
 max_durability = 140,
 coverage = {
  [HITGROUP_CHEST] = 0.8, [HITGROUP_STOMACH] = 0.8,
  [HITGROUP_LEFTARM] = 0.35, [HITGROUP_RIGHTARM] = 0.35,
  [HITGROUP_LEFTLEG] = 0.15, [HITGROUP_RIGHTLEG] = 0.15
 },
 damage = {slash = 3, club = 3, fists = 1, bullet = 8, buckshot = 8, impulse = 12, explosive = 30, acid = 12, poison = 12, shock = 4, burn = 6, physics = 4},
 penetration = {slash = 1, club = 1, fists = 1, bullet = 1, buckshot = 1, impulse = 1, explosive = 1, acid = 1, poison = 1, shock = 1, burn = 1, physics = 1}
}
