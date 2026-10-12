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
 local a,b=area.startPosition,area.endPosition
 local x=math.max(a.x-pos.x,0,pos.x-b.x)
 local y=math.max(a.y-pos.y,0,pos.y-b.y)
 local z=math.max(a.z-pos.z,0,pos.z-b.z)
 return x*x+y*y+z*z
end
ix.util.Include("sv_decon.lua")
ix.util.Include("cl_decon.lua")
