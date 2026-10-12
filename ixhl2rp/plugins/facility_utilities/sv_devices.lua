local P,F=PLUGIN,ix.Facility
util.AddNetworkString("ixFacilityInspect")
local function has(p,id) return p.inventories and p:HasItem(id)==true end
P.deviceMenuLinkTokens=setmetatable({}, {__mode="k"})
function P:DeviceLinkToken(link)
 local token=self.deviceMenuLinkTokens[link]
 if not token then
  F.nextMenuLinkToken=(F.nextMenuLinkToken or 0)+1;token=F.nextMenuLinkToken
  self.deviceMenuLinkTokens[link]=token
 end
 return token
end
function P:DeviceSnapshot(p,d)
 self:DiscoverJobs()
 local job;for _,j in pairs(self.store.jobs) do if j.status~="closed" and j.targetKind=="device" and j.target==d.id then job=j;break end end
 local circuits=0;for _ in pairs(self.store.circuits) do circuits=circuits+1 end
 local links=self:GeneratorConnections(p,d)
 for _,row in ipairs(links) do local link=d.links[row.index];if link then row.token=self:DeviceLinkToken(link) end end
 return {page="device",device={id=d.id,name=d.name,kind=d.kind,fault=d.fault,running=d.running,fuel=d.fuel,charge=d.charge,capacity=d.capacity,
  powered=self:DevicePowered(d),entity=d.entity:EntIndex(),circuits=circuits,canStart=(d.kind=="generator" or d.kind=="battery") and self:GeneratorOperator(p,d) or F.Access(p,3),hasFuel=has(p,"facility_fuel"),
  portable=d.portable,links=links,hasCable=self:CableItem(p)~=nil,charging=d.chargeSource,connected=d.kind=="battery" and self:BatteryConnected(d),
  moveReason=(d.kind=="generator" or d.kind=="battery") and self:SourceMoveReason(p,d) or nil,heldByMe=d.entity.ixHeldOwner==p,
  hasTool=has(p,"tool_screw") or has(p,"wm_screwdriver"),hasParts=has(p,"facility_spares"),repairAllowed=job and self:JobAllowed(p,job),
  owner=job and job.ownerName,mine=job and job.owner==p:GetCharacter():GetID(),workpoint=d.kind=="workpoint"}}
end
function P:SendDeviceUI(p,d,message,close)
 if not d or not F.Near(p,d.entity,140) then return end
 local data=self:DeviceSnapshot(p,d);data.message=message;data.close=close==true
 local packed=util.Compress(util.TableToJSON(data));if not packed or #packed>60000 then return end
 net.Start("ixFacilityUI");net.WriteUInt(#packed,16);net.WriteData(packed,#packed);net.Send(p)
end
function P:RepairHere(p,d)
 if not d.fault then return false,"Оборудование исправно — ремонт не нужен." end
 self:DiscoverJobs()
 local job;for _,j in pairs(self.store.jobs) do if j.status~="closed" and j.targetKind=="device" and j.target==d.id then job=j;break end end
 if not job or not self:JobAllowed(p,job) then return false,"Для этой работы не хватает допуска." end
 local owner=p:GetCharacter():GetID()
 if job.owner and job.owner~=owner then return false,"Работу уже принял другой сотрудник: "..(job.ownerName or "—") end
 local claimed=not job.owner
 if claimed then job.owner=owner;job.ownerName=p:Name();job.status="assigned";self.dirty=true end
 local ok,msg=self:BeginWork(p,job)
 if not ok and claimed then job.owner=nil;job.ownerName=nil;job.status="open" end
 return ok,msg
end
function P:DeviceAction(p,a)
 local d=self.store.devices[a.id]
 if not d or not F.Near(p,d.entity,110) then return false,"Подойдите к оборудованию." end
 if a.command=="refresh" then return true end
 if IsValid(d.entity.ixHeldOwner) and (a.command=="generator" or a.command=="connect") then return false,"Сначала поставьте оборудование на землю." end
 if d.kind=="generator" or d.kind=="battery" then
  if a.command=="pack" then return self:PackGenerator(p,d) end
  if a.command=="carry" then return self:CarrySource(p,d) end
  if a.command=="release" then return self:ReleaseSource(p,d) end
 end
 if (d.kind=="generator" or d.kind=="battery") and self:GeneratorOperator(p,d) then
  if a.command=="pack" then return self:PackGenerator(p,d) end
  if a.command=="connect" then
   if not self:CableItem(p) then return false,"Нужен предмет «Силовой кабель»." end
   self:SetCableMode(p,"connect",d.id);return true,"Подойдите к устройству и нажмите ЛКМ." end
  if a.command=="disconnect" and F.Number(a.index,1,F.cablePorts) and a.index%1==0 and d.links and d.links[a.index] then
   if a.expectedLink~=nil and a.expectedLink~=self:DeviceLinkToken(d.links[a.index]) then return false,"Подключения изменились. Выберите кабель заново." end
   return self:DisconnectCable(p,d,a.index)
  end
 end
 if a.command=="refuel" then return self:Refuel(p,d.id) end
 if a.command=="generator" and d.kind=="generator" then
  if a.expectedRunning~=nil and a.expectedRunning~=(d.running==true) then return false,"Состояние двигателя изменилось. Выберите действие заново." end
  return self:PowerAction(p,{command="generator",id=d.id})
 end
 if a.command=="repair" then return self:RepairHere(p,d) end
 return false,"Действие недоступно."
end
-- Passive aim snapshots have a separate bounded read budget. They cannot use
-- the action cooldown and swallow an E press that arrives in the same frame.
net.Receive("ixFacilityInspect",function(bits,p)
 if bits~=32 or not F.Active(p) or CurTime()<(p.ixFacilityInspectAt or 0) then return end
 p.ixFacilityInspectAt=CurTime()+.75
 local d=P.store.devices[net.ReadUInt(32)]
 if not d or not F.Near(p,d.entity,110) then return end
 local start=p:GetShootPos()
 local tr=util.TraceLine({start=start,endpos=start+p:GetAimVector()*150,filter=p,mask=MASK_SOLID})
 if tr.Entity~=d.entity then return end
 P:SendDeviceUI(p,d)
end)
