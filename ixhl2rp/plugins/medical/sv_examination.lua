local M=ix.Medicine
util.AddNetworkString("ixMedicalExamine")
net.Receive("ixMedicalExamine",function(length,client)
 if length>64 or (client.ixNextExamine or 0)>CurTime() then return end
 client.ixNextExamine=CurTime()+.5
 local target=net.ReadEntity()
 if not client:Alive() or not client:GetCharacter() or client:IsRestricted() or not IsValid(target) or not target:IsPlayer()
  or not target:GetCharacter() or not M.Reachable(client,target) then return end
 local health=target:GetCharacter():Health()
 if not health or not health.body then return end
 local state={parts={},blood=1}
 local missing=ix.Amputation and ix.Amputation.GetLimb(target:GetCharacter())
 for _,diff in health:GetHediffs() do
  if diff.uniqueID=="bleeding" then state.blood=1-math.Clamp(diff:GetSeverity(),0,1) end
 end
 for _,part in ipairs(health.body.parts) do
  if not part.hidden then
   local max=health:GetMaxHealth(part.id)
   local current=health:GetPartHealth(part.id)
   local row={id=part.id,hitgroup=part.hitgroup,name=part.name,current=current,maximum=max,
    ratio=max>0 and math.Clamp(current/max,0,1) or 0,injuries={},medicines={}}
   row.amputated=missing and missing.hitgroup==part.hitgroup or false
   if row.amputated then row.ratio=0; row.injuries[#row.injuries+1]="Конечность отсутствует" end
   for _,diff in health:GetHediffs() do
    if diff.part==part.id then
     if diff.isFracture and diff:GetSeverity()>0 then row.fractured=true end
     if diff:IsVisible() and #row.injuries<32 then row.injuries[#row.injuries+1]=tostring(diff.Stage and diff:Stage() or diff.name) end
    end
   end
   for _,item in pairs(client:GetItems()) do
    if #row.medicines<256 and item.GetUses and item.functions and item.functions.inject and not item.inUse and item:GetUses()>0
     and M.Eligible(item,target,part.hitgroup) then row.medicines[#row.medicines+1]=item.id end
   end
   state.parts[#state.parts+1]=row
  end
 end
 net.Start("ixMedicalExamine"); net.WriteEntity(target); net.WriteUInt(target:GetCharacter():GetID(),32); net.WriteTable(state); net.Send(client)
end)
