local P,F=PLUGIN,ix.Facility
P.cableModes={};P.linkEntities={};P.backupEntities={}
util.AddNetworkString("ixFacilityMode")

function P:GeneratorOperator(p,d)
 return F.Active(p) and (p:IsAdmin() or d.owner==p:GetCharacter():GetID() or F.Access(p,3))
end
function P:SetCableMode(p,mode,id,start)
 if mode=="connect" and not start then
  local d=self.store.devices[id];if d and IsValid(d.entity) then start=d.entity:WorldToLocal(F.GeneratorSocket(d.entity)) end
 end
 self.cableModes[p]=mode and {mode=mode,id=id,character=p:GetCharacter():GetID(),expires=CurTime()+120,start=start} or nil
 if not IsValid(p) then return end
 net.Start("ixFacilityMode");net.WriteString(mode or "");net.WriteUInt(id or 0,32);if mode=="connect" then net.WriteVector(start or Vector()) end;net.Send(p)
end
function P:CableItem(p)
 if not F.Active(p) or not p.inventories then return end
 local found,item=p:HasItem("facility_cable")
 if not found or not item or item:GetOwner()~=p or IsValid(item:GetEntity()) then return end
 if ix.Inventory and ix.Inventory.pendingTransfers and ix.Inventory.pendingTransfers["item_"..item.id] then return end
 return item
end
function P:BeginCable(p,disconnect)
 if not F.Active(p) or (not disconnect and not self:CableItem(p)) then return false end
 self:SetCableMode(p,disconnect and "disconnect" or "source",0);return true
end
function P:DisconnectCable(p,d,index)
 local link=d.links and d.links[index];if not link then return false,"Кабель уже снят." end
 local inv=p:GetInventory("main");if not inv then return false,"Инвентарь недоступен." end
 local item=ix.Item:Instance("facility_cable")
 if not item then return false,"Не удалось вернуть кабель." end
 if not inv:AddItem(item) then item:Remove(true);return false,"Освободите место в инвентаре для кабеля." end
 item:Save();inv:Sync()
 self.linkEntities[link]=nil;table.remove(d.links,index)
 self:RecomputePower(0);self.dirty=true;self:SaveData();self:Audit(p,"cableDisconnect",d.id)
 return true,"Кабель снят и возвращён в инвентарь."
end
function P:DropSourceCables(d)
 -- Entity removal must not eat the physical cables. Normal unplugging uses the inventory.
 for i=#(d.links or {}),1,-1 do
  local link=d.links[i];local item=ix.Item:Instance("facility_cable")
  if item then
   local pos=IsValid(d.entity) and F.GeneratorSocket(d.entity) or F.Vector(d.pos) or Vector()
   ix.Item:Spawn(pos+Vector(0,0,4+i),Angle(),item)
  end
  self.linkEntities[link]=nil;table.remove(d.links,i)
 end
end
function P:BeginGeneratorPlacement(p,item)
 if not F.Active(p) or not item or (item.uniqueID~="facility_generator" and item.uniqueID~="facility_battery") or item:GetOwner()~=p or IsValid(item:GetEntity()) then return false end
 self:SetCableMode(p,item.uniqueID=="facility_battery" and "place_battery" or "place",item.id);return true
end
function P:PlacePortableGenerator(p,yaw)
 local mode=self.cableModes[p];local item=mode and ix.Item.instances[mode.id]
 local kind=mode and mode.mode=="place_battery" and "battery" or "generator"
 if not mode or (mode.mode~="place" and mode.mode~="place_battery") or mode.character~=p:GetCharacter():GetID() or mode.expires<CurTime() or
  not item or item.uniqueID~="facility_"..kind or item:GetOwner()~=p or IsValid(item:GetEntity()) or not F.Number(yaw,-360,360) then return false,"Предмет недоступен. Начните размещение из инвентаря." end
 if ix.Inventory and ix.Inventory.pendingTransfers and ix.Inventory.pendingTransfers['item_'..item.id] then return false,"Дождитесь перемещения предмета в инвентаре." end
 local tr=p:GetEyeTrace();local probe=ents.Create("prop_physics")
 if not IsValid(probe) then return false,"Не удалось проверить размещение." end
 probe:SetModel(F.kinds[kind].model)
 local pos=F.GeneratorPlacement(p,tr,yaw,probe);probe:Remove()
 if not pos then return false,"Нужен свободный ровный пол рядом." end
 local d=self:DeviceRecord(kind,pos,Angle(0,yaw,0));if not d then return false,"Достигнут предел устройств." end
 self:PortableState(d,item,p:GetCharacter():GetID())
 self.store.devices[d.id]=d
 if not self:SpawnDevice(d) then self.store.devices[d.id]=nil;return false,"Не удалось разместить оборудование." end
 -- This fork only deletes the inventory/database instance with Remove(true).
 item:Remove(true);self:SetCableMode(p);self.dirty=true;self:SaveData();self:Audit(p,"generatorPlace",d.id)
 return true,kind=="battery" and "Аккумулятор установлен. E → Подключить кабель к устройству или щитку." or "Генератор установлен. E → Подключить кабель."
end
function P:BatteryConnected(d)
 for _,g in pairs(self.store.devices) do
  for _,link in ipairs(g.links or {}) do if self:ResolvePowerTarget(link)==d.entity then return true end end
 end
 return false
end
function P:PackGenerator(p,d)
 local reason=self:SourceMoveReason(p,d);if reason then return false,reason end
 local inv=p:GetInventory("main");if not inv then return false,"Инвентарь недоступен." end
 local item=ix.Item:Instance("facility_"..d.kind,{fuel=d.fuel or 0,fault=d.fault==true,charge=d.charge,circuit=d.circuit,capacity=d.capacity})
 if not item then return false,"Не удалось создать предмет." end
 if not inv:AddItem(item) then item:Remove(true);return false,"В инвентаре недостаточно места." end
 item:Save();inv:Sync();self.store.devices[d.id]=nil
 if IsValid(d.entity) then d.entity:Remove() end
 self:RecomputePower(0);self.dirty=true;self:SaveData();self:Audit(p,"generatorPack",d.id)
 return true,d.kind=="battery" and "Аккумулятор убран в инвентарь; заряд сохранён." or "Генератор убран в инвентарь; топливо сохранено."
end
local function bind(e)
 return {class=e:GetClass(),model=e:GetModel(),mapid=e:MapCreationID(),pos=e:GetPos()}
end
function P:PowerTarget(e,p)
 if not IsValid(e) or e:IsPlayer() or e:IsNPC() then return end
 local selected=IsValid(p) and ix.PropScreens.Aim(p,140)
 if selected then
  local row=selected.row
  if selected.kind=="panel" and row.entity:GetParent()==e then return {kind="device",id=row.id,name=row.name},row.entity end
  if (selected.kind=="cctv" or selected.kind=="tv") and row.entity==e then return {kind=selected.kind,id=row.id,name=row.name},e end
 end
 local d=self.store.devices[e.facilityID or e:GetNW2Int("ixFacilityPanelID",0)]
 if d and IsValid(d.entity) and (d.entity==e or d.entity:GetParent()==e) then
  if d.kind=="generator" or d.kind=="workpoint" then return end
  if d.kind=="battery" then return {kind="battery",id=d.id,name="Зарядка: "..d.name},d.entity end
  return {kind="device",id=d.id,name=d.name},d.entity
 end
 local b=ix.plugin.list.blackout
 if e:GetClass()=="ix_blackout_fusebox" and b then
  local zone=b:GetOwningZone(e:GetPos());if not zone then return end
  local name;for key,value in pairs(b.zones) do if value==zone then name=key;break end end
  if name then return {kind="zone",zone=name,name="Щиток: "..name,binding=bind(e)},e end
 end
 for _,row in pairs(self.store.doors) do if row.entity==e then return {kind="door",id=row.id,name=row.name},e end end
 local c=ix.plugin.list.cctv
 for _,row in pairs(c and c.devices or {}) do if row.entity==e then return {kind="cctv",id=row.id,name=row.name},e end end
 local t=ix.plugin.list.tv_screen
 for _,row in pairs(t and t.screens or {}) do if row.entity==e then return {kind="tv",id=row.id,name="ТВ #"..row.id},e end end
 if b and b:IsPoweredClass(e:GetClass()) then return {kind="entity",name=e.PrintName or e:GetClass(),binding=bind(e)},e end
end
function P:ResolvePowerTarget(link)
 if link.kind=="device" or link.kind=="battery" then local d=self.store.devices[link.id];return d and d.entity end
 if link.kind=="door" then local d=self.store.doors[link.id];return d and d.entity end
 if link.kind=="cctv" or link.kind=="tv" then
  local plugin=ix.plugin.list[link.kind=="tv" and "tv_screen" or "cctv"]
  local rows=plugin and (plugin.devices or plugin.screens);local d=rows and rows[link.id];return d and d.entity
 end
 local b=link.binding;if not b then return end
 -- The registered fusebox keeps its class and saved position after the stock
 -- model replacement. Upgrade only that old binding, not arbitrary props.
 if b.class=="ix_blackout_fusebox" and b.model=="models/props_se/propper/power_box_2.mdl" then
  b.model="models/props_c17/powerbox.mdl";self.dirty=true
 end
 local cached=self.linkEntities[link]
 if cached then return IsValid(cached) and cached or nil end -- never rebind a removed live entity
 local e=b.mapid and b.mapid>=0 and ents.GetMapCreatedEntity(b.mapid)
 if not IsValid(e) and F.Vector(b.pos) then
  for _,candidate in ipairs(ents.FindByClass(b.class or "")) do
   if candidate:GetModel()==b.model and candidate:GetPos():DistToSqr(F.Vector(b.pos))<16 then e=candidate;break end
  end
 end
 if IsValid(e) and e:GetClass()==b.class and e:GetModel()==b.model then self.linkEntities[link]=e;return e end
end
function P:CableValid(d,link)
 local e=self:ResolvePowerTarget(link)
 if not IsValid(d.entity) or not IsValid(e) then return false,e end
 local endpoint=F.Vector(link.point)
 endpoint=endpoint and e:LocalToWorld(endpoint) or e:WorldSpaceCenter()
 if F.CableStart(d.entity,link.start):DistToSqr(endpoint)>F.cableLength^2 then return false,e end
 if link.kind=="zone" then
  local b=ix.plugin.list.blackout
  if not b or not b.zones[link.zone] or (b.GetOwningZone and b:GetOwningZone(e:GetPos())~=b.zones[link.zone]) then return false,e end
 end
 local filter={d.entity,e};if IsValid(e:GetParent()) then filter[#filter+1]=e:GetParent() end
 if util.TraceLine({start=F.CableStart(d.entity,link.start),endpos=endpoint,filter=filter,mask=MASK_SOLID_BRUSHONLY}).Hit then return false,e end
 return true,e
end
function P:ConnectGenerator(p,d,e,hitPos,start)
 if not d or (d.kind~="generator" and d.kind~="battery") or not self:GeneratorOperator(p,d) or not F.Near(p,e,140) then return false,"Подойдите к устройству." end
 local cableItem=self:CableItem(p)
 if not cableItem then return false,"Нужен предмет «Силовой кабель»: один на подключение." end
 local link,target=self:PowerTarget(e,p)
 if not link then return false,"Выберите щиток, терминал, CCTV, телевизор или другое электрическое устройство." end
 if target==d.entity or (d.kind=="battery" and link.kind=="battery") then return false,"Аккумулятор подключается к потребителю или щитку; заряжается от генератора." end
 if start then link.start=F.Vector(start) end
 if hitPos~=nil then
  if not F.Vector(hitPos) or p:GetShootPos():DistToSqr(hitPos)>140^2 then return false,"Подойдите к точке подключения." end
  link.point=target:WorldToLocal(hitPos)
 end
 d.links=d.links or {};if #d.links>=F.cablePorts then return false,"Все разъёмы заняты (8)." end
 self.linkEntities[link]=target
 if not self:CableValid(d,link) then self.linkEntities[link]=nil;return false,"Кабель слишком короткий или проходит сквозь стену (максимум 15 м)." end
 -- A target has one incoming supply, preventing ambiguous load sharing and backfeed.
 for _,g in pairs(self.store.devices) do for _,other in ipairs(g.links or {}) do
  if (link.kind=="zone" and other.kind=="zone" and link.zone==other.zone) or self:ResolvePowerTarget(other)==target then
   self.linkEntities[link]=nil;return false,"К этому устройству уже подключён источник питания."
  end
 end end
 if link.kind=="zone" then
  local found;for _,c in pairs(self.store.circuits) do if c.zone==link.zone then found=c;break end end
  if not found then
   if table.Count(self.store.circuits)>=32 then self.linkEntities[link]=nil;return false,"Достигнут предел секторов." end
   local id=self:NewID();self.store.circuits[id]={id=id,name=link.zone,zone=link.zone,load=20,priority=3,isolated=false,mainsOff=false}
  end
 end
 cableItem:Remove(true)
 d.links[#d.links+1]=link;self.dirty=true;self:RecomputePower(0);self:SaveData();self:Audit(p,"generatorConnect",d.id)
 return true,"Кабель подключён: "..link.name
end
function P:ConnectionAction(p,a)
 local mode=self.cableModes[p]
 if a.command=="cancel" then self:SetCableMode(p);return true end
 if not mode or mode.expires<CurTime() or mode.character~=p:GetCharacter():GetID() then self:SetCableMode(p);return false,"Возьмите кабель или начните подключение у источника." end
 if (mode.mode=="place" or mode.mode=="place_battery") and a.command=="place" then return self:PlacePortableGenerator(p,a.yaw) end
 if mode.mode=="source" and a.command=="connect" then
  local tr=p:GetEyeTrace();local d=IsValid(tr.Entity) and self.store.devices[tr.Entity.facilityID]
  if not tr.Hit or not d or (d.kind~="generator" and d.kind~="battery") or not self:GeneratorOperator(p,d) or not F.Near(p,d.entity,140)
   or not F.Vector(tr.HitPos) or p:GetShootPos():DistToSqr(tr.HitPos)>140^2 then return false,"Выберите генератор или аккумулятор рядом." end
  if not self:CableItem(p) then self:SetCableMode(p);return false,"Нужен силовой кабель." end
  self:SetCableMode(p,"connect",d.id,d.entity:WorldToLocal(tr.HitPos));return true,"Теперь выберите точку на устройстве или щитке."
 end
 if mode.mode=="disconnect" and a.command=="connect" then
  local tr=p:GetEyeTrace();if not F.Near(p,tr.Entity,140) then return false,"Подойдите к подключённому устройству." end
  local _,target=self:PowerTarget(tr.Entity,p)
  if not IsValid(target) then return false,"Выберите подключённое устройство." end
  for _,d in pairs(self.store.devices) do for i,link in ipairs(d.links or {}) do
   if self:ResolvePowerTarget(link)==target and self:GeneratorOperator(p,d) then
    local ok,msg=self:DisconnectCable(p,d,i);if ok then self:SetCableMode(p) end;return ok,msg
   end
  end end
  return false,"Здесь нет доступного входящего кабеля. Можно снять его через E на источнике."
 end
 if mode.mode=="connect" and a.command=="connect" then
  local tr=p:GetEyeTrace()
  if not tr.Hit or not F.Vector(tr.HitPos) then return false,"Наведите на место подключения на устройстве." end
  local ok,msg=self:ConnectGenerator(p,self.store.devices[mode.id],tr.Entity,tr.HitPos,mode.start)
  if ok then self:SetCableMode(p) end;return ok,msg
 end
 return false,"Действие недоступно."
end
function P:GeneratorConnections(p,d)
 local result={}
 for index,link in ipairs(d.links or {}) do
  local valid=self:CableValid(d,link)
  result[#result+1]={index=index,name=link.name or "Устройство",connected=valid}
 end
 return result
end
function P:EntityIsolated(e)
 local blackout=ix.plugin.list.blackout
 local override=blackout and blackout.ElectronicsOverride and blackout:ElectronicsOverride(e:GetPos())
 if override~=nil then return override end
 if e:GetClass()=="ix_combinelock" and IsValid(e.door) and self:EntityIsolated(e.door) then return true end
 local b=ix.plugin.list.blackout;local pos=e:GetPos()
 for _,z in pairs(b and b.zones or {}) do if z.remoteIsolation and pos:WithinAABox(z.min,z.max) then return true end end
 for _,c in pairs(self.store.circuits) do local z=b and b.zones[c.zone]
  if c.isolated and z and pos:WithinAABox(z.min,z.max) then return true end
 end
 return false
end
function P:DirectGrid(e)
 local b=ix.plugin.list.blackout
 local override=b and b.ElectronicsOverride and b:ElectronicsOverride(e:GetPos())
 if override~=nil then return not override end
 if self:EntityIsolated(e) then return false end
 if e:GetClass()=="ix_combinelock" and IsValid(e.door) and b and b:IsPosBlackedOut(e.door:GetPos()) then return false end
 return not b or not b:IsPosBlackedOut(e:GetPos())
end
function P:ClearGeneratorPower()
 for e in pairs(self.backupEntities) do if IsValid(e) then e:SetNW2Bool("ixGeneratorPower",false) end end
 self.backupEntities={}
end
