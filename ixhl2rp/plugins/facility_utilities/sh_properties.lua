local F=ix.Facility
properties.Add("ixFacilityConfigure",{
 MenuLabel="Инфраструктура: настроить / подключить",Order=900,MenuIcon="icon16/cog.png",
 Filter=function(_,ent,p)
  return IsValid(p) and p:IsAdmin() and IsValid(ent) and (F.EntityKind(ent)~=nil or F.Door(ent) or ent:GetNW2Int("ixFacilityPanelID",0)>0)
 end,
 Action=function(self,ent) self:MsgStart();net.WriteEntity(ent);self:MsgEnd() end,
 Receive=function(_,length,p)
  if length>512 or not F.Active(p) or not p:IsAdmin() or (p.ixFacilityConfigureAt or 0)>CurTime() then return end
  p.ixFacilityConfigureAt=CurTime()+.3
  local ent=net.ReadEntity();local plugin=ix.plugin.list.facility_utilities
  if plugin then plugin:ConfigureEntity(p,ent) end
 end
})
