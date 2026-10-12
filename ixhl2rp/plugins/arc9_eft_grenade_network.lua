PLUGIN.name = "EFT Grenade Compatibility"
PLUGIN.author = "Legends"
PLUGIN.description = "Provides missing EFT explosion and legacy smoke support."

-- Selected weapon packs can contain the sender without the shared autorun
-- registration. Keep the original wire format and EFT client handler intact.
-- AddNetworkString is idempotent when EFT SHARED also registers this name.
if SERVER then
 util.AddNetworkString("arc9eftexplosion")
end

if CLIENT then
 -- The selected M18 entities still register themselves in the legacy smoke
 -- list, which newer EFT SHARED builds no longer initialize. Their particles
 -- and server smoke trails are independent of this optional tracking table.
 local function SmokeRegistry()
  ARC9EFT = ARC9EFT or {}
  ARC9EFT.Smokeslist = ARC9EFT.Smokeslist or {}
  return ARC9EFT.Smokeslist
 end

 SmokeRegistry()
 -- Keep an existing registry intact when a full support pack supplies it.
 -- Without that pack, removed grenades must not accumulate between cleanups.
 timer.Create("ixEFTSmokeRegistryCleanup", 5, 0, function()
  local registry = SmokeRegistry()
  for i = #registry, 1, -1 do
   if not IsValid(registry[i]) then table.remove(registry, i) end
  end
 end)
end
