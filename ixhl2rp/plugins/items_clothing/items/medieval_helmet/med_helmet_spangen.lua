ITEM.name = "Спангельхельм Старой дружины"
ITEM.description = "Надёжный шлем дружинника, привыкшего считать вмятины вместо побед. Последнюю вмятину кузнец выправил, а историю о ней оставил."
ITEM.model = "models/bascinet_novis.mdl"
ITEM.width = 2
ITEM.height = 2
ITEM.cost = 130
ITEM.helmetGroups = {archer = 2, knight = 8}
ITEM.protectionDescription = "Шлем дружинника: усиленная защита головы с неполным прикрытием."
ITEM.armor = {
 class = 2,
 density = 0.65,
 max_durability = 360,
 coverage = {[HITGROUP_HEAD] = 0.85},
 damage = {slash = 0.8, club = 2, fists = 1, bullet = 8, buckshot = 8, impulse = 12, explosive = 30, acid = 12, poison = 12, shock = 4, burn = 6, physics = 4},
 penetration = {slash = 0.5, club = 1, fists = 1, bullet = 1, buckshot = 1, impulse = 1, explosive = 1, acid = 1, poison = 1, shock = 1, burn = 1, physics = 1}
}
