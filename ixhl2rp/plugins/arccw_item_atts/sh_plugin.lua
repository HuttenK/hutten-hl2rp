local PLUGIN = PLUGIN
PLUGIN.name = "ARC9 Gunsmith"
PLUGIN.author = "Hutten / Legends"
PLUGIN.description = "Inventory-linked ARC9 servicing at persistent gunsmith benches."
PLUGIN.range = 200
PLUGIN.cost = 5
PLUGIN.pageSize = 24
ix.gunsmith = PLUGIN
ix.util.Include("sv_plugin.lua", "server")
ix.util.Include("cl_preview.lua", "client")
ix.util.Include("cl_display.lua", "client")
ix.util.Include("cl_plugin.lua", "client")

function PLUGIN:StartCommand(client, command)
 local weapon = client:GetActiveWeapon()
 if ARC9 and ARC9.IN_CUSTOMIZE and IsValid(weapon) and weapon.ARC9 then command:RemoveKey(ARC9.IN_CUSTOMIZE) end
 if SERVER and self:IsUsingBench(client) then
  command:RemoveKey(IN_ATTACK); command:RemoveKey(IN_ATTACK2); command:RemoveKey(IN_RELOAD)
 end
end
