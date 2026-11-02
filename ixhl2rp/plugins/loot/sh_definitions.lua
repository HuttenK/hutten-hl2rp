ix.LootContainer:Add("supplies", {
 Name="Припасы", Description="Ящик с припасами и материалами.",
 Model="models/props_junk/wood_crate001a.mdl", SearchText="Осмотр припасов", SearchTime=5,
 Hide=false, Respawn=1000, Tool=false, NoRate=true,
 LootGroup={supplies={
  {id="mat_wood",weight=40,min=1,max=3}, {id="mat_cloth_reclaimed",weight=30},
  {id="metal_scrap",weight=25}, {id="mat_leather",weight=20}, {id="mat_charcoal",weight=25},
  {id="box_of_nails",weight=15}, {id="box_of_needles",weight=10}, {id="bandage",weight=10},
  {id="cook_flour",weight=20}, {id="cook_yeast",weight=10}, {id="cook_tea",weight=10},
  {id="fresh_bread",weight=15}, {id="union_branded_apple",weight=20}, {id="purified_water",weight=20}
 }}, Loot={{lootGroup="supplies",min=1,max=3}}
})
