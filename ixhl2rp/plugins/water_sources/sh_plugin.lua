PLUGIN.name = "Water Sources"
PLUGIN.author = "Hutten"
PLUGIN.description = "Choose how to use a sink without risking inventory contents."
ix.water = ix.water or {}
ix.util.Include("sh_water.lua")
ix.util.Include("sv_water.lua")
ix.util.Include("sv_registry.lua")
ix.util.Include("cl_water.lua")
ix.util.Include("cl_registry.lua")
ix.command.Add("SinkAdmin",{adminOnly=true,description="Добавить модели умывальников и унитазов.",OnRun=function(_,p)
 if SERVER and IsValid(p) and p:IsAdmin() then ix.water.OpenRegistry(p) end
end})
