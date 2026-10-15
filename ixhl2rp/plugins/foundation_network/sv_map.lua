local P=PLUGIN
local oldPage,oldAction=P.Page,P.Action
local function xyz(v) return {v.x,v.y,v.z} end
local function hasLive(t)
 for ent in pairs(t or {}) do if IsValid(ent) then return true end end
 return false
end
function P:MapSnapshot(p)
 local data={name=game.GetMap(),origin=xyz(p:GetPos()),areas={},alerts={},terminals={}}
 local power=ix.plugin.list.blackout
 local infection=ix.plugin.list.infectionzone
 local function alert(name,kind,a,b)
  data.alerts[#data.alerts+1]={name=tostring(name):sub(1,100),kind=kind,active=true,
   pos={(a.x+b.x)*.5,(a.y+b.y)*.5,(a.z+b.z)*.5},low=a.z,high=b.z}
 end
 -- Only ordinary /areaedit areas are architectural overlays. Hazard volumes
 -- never become boundaries, including when their layer is toggled on.
 for name,z in SortedPairs(ix.area and ix.area.stored or {}) do
  if z.type=='area' and not z.bNoReplicate and z.startPosition and z.endPosition then
   if #data.areas>=128 then data.truncated=true;break end
   local c=(z.properties or {}).color
   for _,box in ipairs(ix.area.GetVolumes(z)) do
    if #data.areas>=128 then data.truncated=true;break end
    data.areas[#data.areas+1]={name=tostring(name):sub(1,100),min=xyz(box.min),max=xyz(box.max),
     color=c and {c.r,c.g,c.b} or nil}
   end
  end
 end
 local n=0
 for name,z in SortedPairs(power and power.zones or {}) do
  if z.active==true and z.min and z.max then
   if n>=128 then data.truncated=true;break end
   alert(name,'power',z.min,z.max);n=n+1
  end
 end
 n=0
 for name,z in SortedPairs(infection and ix.area and ix.area.stored or {}) do
  if z.type=='infection' and z.startPosition and z.endPosition then
   -- Suppression only stops new growth: an uncleared pool, existing flora or
   -- infected entities still constitute an incident. Missing state is not one.
   local active=(tonumber((infection.remaining or {})[name]) or 0)>0
    or (z.properties or {}).indestructible==true
    or hasLive((infection.flora or {})[name]) or hasLive((infection.zombies or {})[name])
   if active then
    if n>=128 then data.truncated=true;break end
    alert(name,'infection',z.startPosition,z.endPosition);n=n+1
   end
  end
 end
 -- Released biological waste can spread outside all configured areas.
 n=0
 for ent in pairs(infection and infection.flora and infection.flora.__waste or {}) do
  if IsValid(ent) and (ent.ixWasteExpires or 0)>CurTime() then
   if n>=48 then data.truncated=true;break end
   local pos=ent:GetPos();alert('Биоотходы','infection',pos,pos);n=n+1
  end
 end
 for _,ent in ipairs(ents.FindByClass('ix_foundation_terminal')) do
  if #data.terminals>=128 then data.truncated=true;break end
  data.terminals[#data.terminals+1]={pos=xyz(ent:GetPos()),off=power and power:IsEntityBlackedOut(ent) or false}
 end
 return data
end
function P:Page(p,s,identity,card,route)
 if route~='scip://map' then
  local page=oldPage(self,p,s,identity,card,route)
  if route=='scip://home' then table.insert(page.rows,1,{title='Карта / сканер этажей',url='scip://map'}) end
  return page
 end
 return {route=route,token=s.token,name=identity.name,level=card.clearanceLevel,department=card.departmentLabel or '',webAdmin=p:IsAdmin(),title='КАРТА ОБЪЕКТА',rows={},mapData=self:MapSnapshot(p),mapUpdate=s.mapUpdate==true}
end
function P:Action(p,action,data)
 if not istable(data) then return end
 if action~='mapSync' and not (action=='navigate' and data.route=='scip://map') then return oldAction(self,p,action,data) end
 local s,identity,card=self:Session(p,data.token);if not s then return end
 if action=='mapSync' and (s.nextMapSync or 0)>CurTime() then return end
 s.nextMapSync=CurTime()+5;s.mapUpdate=action=='mapSync'
 -- Background telemetry does not keep an abandoned session alive.
 if action=='navigate' then s.idle=CurTime()+600 end
 self:SendPage(p,s,identity,card,'scip://map');s.mapUpdate=nil
end
