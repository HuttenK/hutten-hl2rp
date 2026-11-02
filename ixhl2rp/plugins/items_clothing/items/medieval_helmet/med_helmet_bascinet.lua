ITEM.name = "Бацинет Стального обета"
ITEM.description = "Закрытый бацинет с суровым профилем. Хорошо хранит голову и тайны владельца; с внятной беседой справляется заметно хуже."
ITEM.model = "models/bascinet_cl.mdl"
ITEM.width = 2
ITEM.height = 2
ITEM.cost = 190
ITEM.helmetGroups = {archer = 4, knight = 6}
ITEM.protectionDescription = "Закрытый бацинет: высокая защита почти всей головы."
ITEM.armor = {
 class = 3,
 density = 0.8,
 max_durability = 500,
 coverage = {[HITGROUP_HEAD] = 0.95},
 damage = {slash = 0.5, club = 1.5, fists = 1, bullet = 8, buckshot = 8, impulse = 12, explosive = 30, acid = 12, poison = 12, shock = 4, burn = 6, physics = 4},
 penetration = {slash = 0.3, club = 0.7, fists = 1, bullet = 1, buckshot = 1, impulse = 1, explosive = 1, acid = 1, poison = 1, shock = 1, burn = 1, physics = 1}
}
