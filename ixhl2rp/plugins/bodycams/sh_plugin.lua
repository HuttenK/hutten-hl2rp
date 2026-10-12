PLUGIN.name = "Helmet bodycams"
PLUGIN.author = "Hutten"
PLUGIN.description = "Removable helmet cameras for the existing Foundation CCTV network."
ix.bodycams = ix.bodycams or {}
ix.util.Include("sh_bodycams.lua")
ix.util.Include("sv_bodycams.lua")
ix.util.Include("cl_bodycams.lua")

function PLUGIN:InitializedPlugins()
 ix.bodycams.RegisterHelmets()
end

ix.command.Add("Bodycam", {
 description = "Включить или выключить камеру на надетом шлеме.",
 OnRun = function(_, client)
  local helmet = ix.bodycams.WornHelmet(client)
  if not helmet or not ix.bodycams.Attached(helmet) then return "На надетом шлеме нет камеры." end
  local ok, message = ix.bodycams.Change(client, helmet, "toggle")
  return message
 end
})
