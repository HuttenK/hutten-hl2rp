local P,F=PLUGIN,ix.Facility
function P:RawGrid(c)
 local b=ix.plugin.list.blackout;local z=b and b.zones[c.zone]
 if not z then return false,true end -- never silently energize an unbound sector
 local first=ix.area.GetVolumes(z)[1]
 local center=(first.min+first.max)*.5;local available=not c.mainsOff;local isolated=c.isolated==true
 for _,zone in pairs(b.zones) do if ix.area.Contains(zone,center) then
  if zone.active then available=false end
  if zone.remoteIsolation then isolated=true end
 end end
 return available,isolated
end
function P:DevicePowered(d)
 if not d or d.fault or d.enabled==false or not IsValid(d.entity) then return false end
 local b=ix.plugin.list.blackout
 local override=b and b.ElectronicsOverride and b:ElectronicsOverride(d.entity:GetPos())
 if override~=nil then return not override end
 if d.kind=="generator" or d.kind=="battery" or d.kind=="workpoint" then return true end
 if self:EntityIsolated(d.entity) then return false end
 return F.EntityBackup(d.entity) or self:DirectGrid(d.entity)
end
function P:BatteryMains(d)
 if not IsValid(d.entity) then return false end
 local b=ix.plugin.list.blackout;local pos=d.entity:GetPos()
 local override=b and b.ElectronicsOverride and b:ElectronicsOverride(pos)
 if override~=nil then return not override end
 if self:EntityIsolated(d.entity) then return false end
 for _,z in pairs(b and b.zones or {}) do if z.active and ix.area.Contains(z,pos) then return false end end
 for _,c in pairs(self.store.circuits) do
  local z=b and b.zones[c.zone]
  if z and ix.area.Contains(z,pos) and (c.mainsOff or c.isolated) then return false end
 end
 return true
end
function P:RecomputePower(dt)
 if not self.loaded then return end
 dt=math.Clamp(dt or 0,0,2)
 local demand,sources,gens,bats={},{},{},{}
 for _,c in pairs(self.store.circuits) do
  local grid,isolated=self:RawGrid(c);c.wasPowered=c.powered;c.powered=grid and not isolated;c.source=c.powered and "СЕТЬ" or "ОТКЛЮЧЕНА"
  if not grid and not isolated then demand[#demand+1]=c end
 end
 local direct,chargers,batterySources,mainsCharging={},{},{},{}
 for _,d in pairs(self.store.devices) do if d.kind=="battery" then d.chargeSource=nil end end
 for _,d in pairs(self.store.devices) do
  if d.kind=="generator" or d.kind=="battery" then
   local battery=d.kind=="battery"
   local available=self:DevicePowered(d) and not self:EntityIsolated(d.entity)
   local output=battery and math.min(d.capacity or 30,(d.charge or 0)/math.max(dt,1)) or (d.running and (d.fuel or 0)>0 and (d.capacity or 60) or 0)
   local source={d=d,remaining=available and output or 0,zones={},used=0}
   d.links=d.links or {}
   for _,link in ipairs(d.links) do
    local valid,e=self:CableValid(d,link)
    if valid then
     if link.binding then link.binding.pos=e:GetPos() end
     if link.kind=="zone" then source.zones[link.zone]=true
     elseif link.kind=="battery" and not battery then chargers[#chargers+1]={source=source,entity=e,id=link.id}
     elseif link.kind~="battery" then direct[#direct+1]={source=source,entity=e,link=link} end
    end
    -- Invalid or removed endpoints leave a recoverable cable on the source's E menu.
   end
   if IsValid(d.entity) then for i=1,F.cablePorts do
    local link=d.links[i];local valid,e=false,nil
    if link then valid,e=self:CableValid(d,link) end
    d.entity:SetNW2Entity("ixGeneratorCable"..i,valid and e or NULL)
    local point=link and F.Vector(link.point)
    d.entity:SetNW2Vector("ixGeneratorCablePoint"..i,point or (IsValid(e) and e:WorldToLocal(e:WorldSpaceCenter()) or Vector()))
    d.entity:SetNW2Vector("ixGeneratorCableStart"..i,link and F.Vector(link.start) or d.entity:WorldToLocal(F.GeneratorSocket(d.entity)))
   end end
   sources[#sources+1]=source
   if battery then
    bats[#bats+1]=source;batterySources[d.id]=source
    mainsCharging[d.id]=available and self:BatteryMains(d)
   elseif source.remaining>0 then gens[#gens+1]=d end
  end
 end
 table.sort(sources,function(a,b) if a.d.kind~=b.d.kind then return a.d.kind=="generator" end;return a.d.id<b.d.id end)
 table.sort(demand,function(a,b) if a.priority~=b.priority then return a.priority<b.priority end;return a.id<b.id end)
 for _,c in ipairs(demand) do
  local capacity=0;for _,s in ipairs(sources) do if s.zones[c.zone] then capacity=capacity+s.remaining end end
  c.powered=capacity>=c.load;c.source=c.powered and "РЕЗЕРВ" or "НЕТ ПОДКЛЮЧЁННОГО РЕЗЕРВА"
  if c.powered then local needed=c.load;for _,s in ipairs(sources) do if s.zones[c.zone] then
   local n=math.min(needed,s.remaining);s.remaining=s.remaining-n;s.used=(s.used or 0)+n;needed=needed-n
  end end end
 end
 -- Zone loads have priority. A direct cable only powers its endpoint, never its neighbours.
 table.sort(direct,function(a,b) if a.source.d.id~=b.source.d.id then return a.source.d.id<b.source.d.id end;return a.entity:EntIndex()<b.entity:EntIndex() end)
 local powered={}
 for _,target in ipairs(direct) do
  local e,s=target.entity,target.source
  local b=ix.plugin.list.blackout
  local blocked=b and b.ElectronicsOverride and b:ElectronicsOverride(e:GetPos())
  if not blocked and not self:EntityIsolated(e) and not self:DirectGrid(e) and s.remaining>=5 then
   powered[e]=true;s.remaining=s.remaining-5;s.used=s.used+5
  end
 end
 local entityChanged=false
 for e in pairs(self.backupEntities) do if not powered[e] and IsValid(e) then e:SetNW2Bool("ixGeneratorPower",false);entityChanged=true end end
 for e in pairs(powered) do if not self.backupEntities[e] then e:SetNW2Bool("ixGeneratorPower",true);entityChanged=true end end
 self.backupEntities=powered
 for _,s in ipairs(bats) do
  s.d.charge=math.max(0,s.d.charge-(s.used or 0)*dt)
  if (s.used or 0)>0 then s.d.chargeSource="РЕЗЕРВ: ПО КАБЕЛЮ" end
 end
 -- Actual mains at the battery charges it without cables while lights are on.
 -- A restored reserve zone is never considered mains, preventing self-recharging.
 for _,s in ipairs(bats) do if mainsCharging[s.d.id] then
  s.d.charge=math.min(6000,(s.d.charge or 0)+10*dt)
  s.d.chargeSource=s.used>0 and "СЕТЬ / РЕЗЕРВ ПО КАБЕЛЮ" or "ЗАРЯД: СЕТЬ"
 end end
 -- Generator charging uses only its remaining budget, after zone and direct loads.
 table.sort(chargers,function(a,b) if a.source.d.id~=b.source.d.id then return a.source.d.id<b.source.d.id end;return a.id<b.id end)
 local charged={}
 for _,target in ipairs(chargers) do
  local d,s=self.store.devices[target.id],target.source
  local reserve=d and batterySources[d.id]
  if d and d.kind=="battery" and not charged[d.id] and not mainsCharging[d.id]
   and self:DevicePowered(d) and not self:EntityIsolated(d.entity) then
   local amount=math.min(10,s.remaining,math.max(0,6000-(d.charge or 0))/math.max(dt,1))
   if amount>0 then
    s.remaining=s.remaining-amount;charged[d.id]=true;d.chargeSource=reserve and reserve.used>0 and "ГЕНЕРАТОР / РЕЗЕРВ ПО КАБЕЛЮ" or "ЗАРЯД: ГЕНЕРАТОР"
    d.charge=math.min(6000,(d.charge or 0)+amount*math.min(dt,s.d.fuel or 0))
    if dt>0 then self.dirty=true end
   end
  end
 end
 for _,d in pairs(self.store.devices) do if d.kind=="battery" and (d.charge or 0)>=6000 then d.chargeSource="ЗАРЯЖЕН" end end
 for _,d in ipairs(gens) do d.fuel=math.max(0,d.fuel-dt);if d.fuel<=0 then d.running=false end end
 local changed=false
 for _,c in pairs(self.store.circuits) do if c.wasPowered~=c.powered then changed=true end;c.wasPowered=nil end
 for _,d in pairs(self.store.devices) do self:SyncDevice(d) end
 if changed or entityChanged or self.powerTopologyChanged then self.powerTopologyChanged=nil;self:RefreshBlackouts() end
 if dt>0 and (#gens>0 or #bats>0) then self.dirty=true end
end
function P:RefreshBlackouts()
 local b=ix.plugin.list.blackout;if b then b:SetZoneLights();b:NetworkZones() end
end
function P:FacilityBlackoutZoneActive(name,zone)
 if self.stopping then return end
 for _,c in pairs(self.store.circuits) do if c.zone==name and c.powered~=nil then return not c.powered end end
end
function P:FacilityPowerAt(pos)
 if self.stopping then return end
 local b=ix.plugin.list.blackout;local best,size
 for _,z in pairs(b and b.zones or {}) do if z.remoteIsolation and ix.area.Contains(z,pos) then return true end end
 for _,c in pairs(self.store.circuits) do
  local z=b and b.zones[c.zone]
  if z and c.powered~=nil and ix.area.Contains(z,pos) then
   if z.remoteIsolation then return true end
   local n=ix.area.Measure(z)
   if not size or n<size then best=c;size=n end
  end
 end
 if best then return not best.powered end
end
local function visualBox(box,mn,mx)
 return {min=mn or box.min,max=mx or box.max,darkness=box.darkness,softness=box.softness,
  fadeMin=box.fadeMin or box.min,fadeMax=box.fadeMax or box.max}
end
local function subtract(box,cut)
 local a,b=box.min,box.max;local c,d=cut.min,cut.max
 local low=Vector(math.max(a.x,c.x),math.max(a.y,c.y),math.max(a.z,c.z))
 local high=Vector(math.min(b.x,d.x),math.min(b.y,d.y),math.min(b.z,d.z))
 if low.x>=high.x or low.y>=high.y or low.z>=high.z then return {box} end
 local out={}
 local function add(x,y) if x.x<y.x and x.y<y.y and x.z<y.z then out[#out+1]=visualBox(box,x,y) end end
 add(Vector(a.x,a.y,a.z),Vector(low.x,b.y,b.z));add(Vector(high.x,a.y,a.z),Vector(b.x,b.y,b.z))
 add(Vector(low.x,a.y,a.z),Vector(high.x,low.y,b.z));add(Vector(low.x,high.y,a.z),Vector(high.x,b.y,b.z))
 add(Vector(low.x,low.y,a.z),Vector(high.x,high.y,low.z));add(Vector(low.x,low.y,high.z),Vector(high.x,high.y,b.z))
 return out
end
function P:FacilityBlackoutVolumes(zones,active)
 if self.stopping or not next(self.store.circuits) then return end
 local ordered={};for _,c in pairs(self.store.circuits) do
  local z=zones[c.zone];if z and c.powered~=nil then ordered[#ordered+1]={c=c,z=z,volume=ix.area.Measure(z)} end
 end
 table.sort(ordered,function(a,b) return a.volume>b.volume end)
 local boxes={};for _,z in ipairs(active) do boxes[#boxes+1]=visualBox(z) end
 for _,entry in ipairs(ordered) do
  for _,cut in ipairs(ix.area.GetVolumes(entry.z)) do
   local filtered={}
   for _,box in ipairs(boxes) do for _,part in ipairs(subtract(box,cut)) do filtered[#filtered+1]=part end end
   boxes=filtered
  end
  if not entry.c.powered then
   for _,part in ipairs(ix.area.GetVolumes(entry.z)) do boxes[#boxes+1]=visualBox(entry.z,part.min,part.max) end
  end
  if #boxes>512 then return active end
 end
 -- Safety isolations always win, including a smaller backed-up circuit inside.
 for _,z in pairs(zones) do if z.remoteIsolation then
  for _,part in ipairs(ix.area.GetVolumes(z)) do boxes[#boxes+1]=visualBox(z,part.min,part.max) end
 end end
 return boxes
end
function P:PowerAction(p,data)
 local generator=data.command=="generator" and self.store.devices[data.id]
 if not (generator and self:GeneratorOperator(p,generator)) and not F.Access(p,3) then return false,"Требуется L3 или собственный генератор." end
 local c=self.store.circuits[data.id]
 if data.command=="priority" and c and F.Number(data.value,1,5) and data.value%1==0 then c.priority=data.value
 elseif data.command=="isolate" and c then c.isolated=not c.isolated
 elseif data.command=="generator" then
  local d=self.store.devices[data.id]
  if not d or not F.Near(p,d.entity,110) or d.kind~="generator" or d.fault or (d.fuel or 0)<=0 then return false,"Нет топлива или генератор неисправен." end
  d.running=not d.running
 else return false,"Команда недоступна." end
 self:RecomputePower(0);self.dirty=true;self:Audit(p,data.command,data.id);return true,"Команда выполнена."
end
