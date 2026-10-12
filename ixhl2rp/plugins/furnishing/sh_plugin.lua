local P = PLUGIN
P.name = "Foundation Furnishing"
P.author = "AUTONOMOUS / Hutten integration"
P.description = "Inventory furniture placement, relocation and packing with a shared placement grid."
ix.util.Include("sh_grid.lua")
ix.Net:AddEntityVar("furnOwner", nil, ix.Net.Type.CharacterID)
ix.Net:AddEntityVar("furnApt", nil, ix.Net.Type.String)
ix.config.Add("furnitureAreaOnly", false, "Разрешать мебель только в зонах обустройства /AreaEdit.", nil, {category="Инфраструктура"})
ix.config.Add("furnitureLimit", 40, "Максимум предметов мебели одного персонажа на карте.", nil, {data={min=1,max=200},category="Инфраструктура"})
function P:SetupAreaProperties()
 ix.area.AddType("furnishing", "Обустройство")
 ix.area.AddProperty("furnishingOwner", ix.type.number, 0)
end
ix.util.Include("sv_furnish.lua")
ix.util.Include("cl_furnish.lua")
ix.command.Add("Furnish", {description="Переставить или забрать свою мебель.", OnRun=function(_,p) ix.furnish.BeginEdit(p) end})
