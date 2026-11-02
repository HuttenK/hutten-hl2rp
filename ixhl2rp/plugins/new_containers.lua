PLUGIN.name = "Деревянные хранилища"
for model, data in pairs({
 ["models/woodenchest.mdl"]={name="Сундук бережливого хозяина",width=8,height=5},
 ["models/wardrobe.mdl"]={name="Шкаф доброго плотника",width=8,height=8},
 ["models/cabinets4.mdl"]={name="Поставец хозяйского дома",width=6,height=5},
 ["models/cabinets6.mdl"]={name="Шкафец старого поместья",width=6,height=6},
 ["models/props_junk/wood_crate001a.mdl"]={name="Деревянный ящик",width=6,height=6},
 ["models/props_c17/furnituredrawer001a.mdl"]={name="Деревянный шкаф",width=6,height=5},
 ["models/props_c17/furnituredrawer002a.mdl"]={name="Комод",width=4,height=4},
 ["models/props_c17/furnituredrawer003a.mdl"]={name="Тумба",width=3,height=3}
}) do data.description="Хранилище для вещей."; ix.container.Register(model,data) end
