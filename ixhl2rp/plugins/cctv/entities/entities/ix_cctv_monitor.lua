ENT.Type="anim"
ENT.Base="ix_cctv_device"
ENT.PrintName="CCTV / Монитор"
ENT.Category="Foundation"
ENT.SubCategory="CCTV"
ENT.IconOverride="icon16/monitor.png"
ENT.CCTVKind="monitor"
ENT.Spawnable=true
ENT.AdminOnly=true
ENT.bNoPersist=true

if SERVER then
 function ENT:SpawnFunction(p)
  local plugin=ix.plugin.list.cctv
  if not IsValid(p) or not p:IsAdmin() or not plugin then return end
  -- The spawn-menu entry starts surface placement instead of spawning a TV.
  -- Do not return the host prop: sandbox undo would otherwise own/remove it.
  plugin:OpenAdmin(p,"monitor")
 end
end
