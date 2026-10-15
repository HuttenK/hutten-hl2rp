PLUGIN.name = "Foundation Decontamination"
PLUGIN.author = "Hutten"
PLUGIN.description = "Powered decontamination showers, local sensors and infected NPC remains disposal."
local P = PLUGIN
ix.Decon = ix.Decon or {}
local D = ix.Decon
D.kinds = {
 decon_shower = {name="Душ деконтаминации",model="models/props_wasteland/shower_system001a.mdl"},
 decon_sensor = {name="Датчик биологической опасности",model="models/props_lab/reciever01b.mdl"},
 decon_disposal = {name="Утилизатор заражённых останков",model="models/props_c17/furnitureboiler001a.mdl"}
}
function P:InitializedPlugins()
 if not ix.Facility then return end
 for kind,def in pairs(D.kinds) do
  ix.Facility.kinds[kind]=def
  ix.Facility.help[kind]="E — использовать. Администратор: Alt + E — питание, название и неисправности."
 end
end
P:InitializedPlugins()
function D.ZoneDistance(pos,area)
 return ix.area.DistanceSqr(area,pos)
end
ix.util.Include("sv_decon.lua")
ix.util.Include("cl_decon.lua")
