-- Offline engine boundary: entities, authenticated users and persistent storage.
local V=getmetatable(Vector())
function V.__div(v,n) return v*(1/n) end
function V:WithinAABox(a,b) return self.x>=a.x and self.x<=b.x and self.y>=a.y and self.y<=b.y and self.z>=a.z and self.z<=b.z end
function table.HasValue(t,v) for _,x in pairs(t) do if x==v then return true end end;return false end
function SortedPairs(t)
 local keys={};for k in pairs(t) do keys[#keys+1]=k end;table.sort(keys,function(a,b) return tostring(a)<tostring(b) end)
 local i=0;return function() i=i+1;local k=keys[i];if k then return k,t[k] end end
end
function util.Compress(v) return v end;function util.Decompress(v) return v end
function net.WriteVector(v) net.packet.vector=v end
function net.ReadVector() return net.packet.vector end
function net.WriteData(v) net.packet.data=v end
function net.ReadString() return net.payload end
game={GetMap=function() return 'test_map' end};SOLID_NONE=0;MOVETYPE_NONE=0
ix.plugin.list.facility_utilities=PLUGIN
local oldEntity=entity
function entity(...)
 local e=oldEntity(...);e.state={m_bLocked=false,m_eDoorState=0};e.inputs={}
 local physics={valid=true,mass=30,moving=true}
 function physics:EnableMotion(v) self.moving=v end
 function physics:IsMoveable() return self.moving end
 function physics:SetMass(v) self.mass=v end
 function physics:GetMass() return self.mass end
 function physics:Wake() end
 function e:GetPhysicsObject() return physics end
 function e:GetParent() return self.parent end
 function e:GetAngles() return Angle(self.ang.p,self.ang.y,self.ang.r) end
 function e:GetUp() return self.ang:Up() end
 function e:GetRight() return self.ang:Right() end
 function e:GetForward() return self.ang:Forward() end
 function e:LocalToWorld(v) return LocalToWorld(v,Angle(),self.pos,self.ang) end
 function e:WorldToLocal(v) return WorldToLocal(v,Angle(),self.pos,self.ang) end
 function e:SetNW2Vector(k,v) self[k]=v end
 function e:GetNW2Vector(k,d) return self[k] or d end
 function e:SetParent(v) self.parent=v end
 function e:SetLocalPos(v) self.localPos=v;if IsValid(self.parent) then self.pos=LocalToWorld(v,self.localAng or Angle(),self.parent.pos,self.parent.ang) end end
 function e:SetLocalAngles(v) self.localAng=v end
 function e:GetLocalPos() return self.localPos or self.pos end
 function e:GetLocalAngles() return self.localAng or self.ang end
 function e:SetNW2Bool(k,v) self[k]=v end;function e:GetNW2Bool(k,d) if self[k]~=nil then return self[k] end;return d end
 function e:SetNW2String(k,v) self[k]=v end;function e:GetNW2String(k,d) return self[k] or d end
 function e:SetNW2Float(k,v) self[k]=v end;function e:GetNW2Float(k,d) return self[k] or d end
 function e:SetNW2Entity(k,v) self[k]=v end;function e:GetNW2Entity(k) return self[k] end
 function e:GetModelBounds() return Vector(-20,-20,-10),Vector(20,20,30) end
 function e:GetSaveTable() return self.state end
 function e:GetDoorPartner() return self.partner end
 function e:Fire(command)
  if PLUGIN.AcceptInput and PLUGIN:AcceptInput(self,command) then self.blocked=command;return end
  self.inputs[#self.inputs+1]=command
  if command=='Lock' then self.state.m_bLocked=true elseif command=='Unlock' then self.state.m_bLocked=false
  elseif command=='Close' then self.state.m_eDoorState=0 elseif command=='Open' then self.state.m_eDoorState=2 end
 end
 function e:EmitSound(v) self.lastSound=v;self.soundCount=(self.soundCount or 0)+1 end
 function e:GetBroken() return self.broken==true end
 function e:SetBroken(v) self.broken=v end
 return e
end
local create=ents.Create
function ents.Create(class) local e=create(class);e.FacilityKind=class:match('^ix_facility_(.+)$');return e end
local newPlayer=admin;local players={};local nextChar=0
function admin(level,department)
 local p=newPlayer();p.pos=Vector();nextChar=nextChar+1;p.character={id=nextChar,GetID=function(s) return s.id end};p.inventories={};p.items={}
 p.card={clearanceLevel=level or 4,department=department or 'security'}
 function p:GetCharacter() return not self.noCharacter and self.character or nil end
 function p:GetIDCard() return self.card end
 function p:Name() return 'Worker '..self.character.id end
 function p:InVehicle() return self.vehicle==true end;function p:IsRestricted() return self.restricted==true end
 function p:GetLocalVar(k,d) if self[k]~=nil then return self[k] end;return d end
 function p:SetAction(text) self.action=text end
 function p:SetNW2Bool(k,v) self[k]=v end
 function p:SetNW2String(k,v) self[k]=v end
 function p:GetNW2String(k,d) return self[k] or d end
 function p:HasItem(id) return self.items[id]~=nil,self.items[id] end
 function p:SteamID64() return tostring(self.character.id) end
 players[#players+1]=p;return p
end
player={GetAll=function() return players end}
function giveItem(p,id)
 local item={removed=0}
 function item:Remove() self.removed=self.removed+1;p.items[id]=nil end
 p.items[id]=item;return item
end
ix.Fieldlink={CardIdentity=function(card) if card then return {id=1} end end}
ix.plugin.list.foundation_network={sessions={},store={},Session=function(self,p,token)
 local s=self.sessions[p]
 if s and s.token==token and not s.public and ix.Facility.Active(p) and ix.Facility.Near(p,s.entity,128) and s.character==p:GetCharacter():GetID() then return s end
end,Audit=function() end}
function session(p)
 local s={entity=entity(800+p.character.id,'test',p.pos),token='session-'..p.character.id,character=p.character.id}
 ix.plugin.list.foundation_network.sessions[p]=s;return s
end
ix.plugin.list.blackout={zones={},fuseboxes={},SetZoneLights=function(self) self.refreshes=(self.refreshes or 0)+1 end,NetworkZones=function() end,SaveData=function() end,
 IsPosBlackedOut=function(self,pos)
  local override=PLUGIN:FacilityPowerAt(pos);if override~=nil then return override end
  for _,z in pairs(self.zones) do if z.active and pos:WithinAABox(z.min,z.max) then return true end end;return false
 end}
function circuit(name,load,priority,off,offset)
 local id=PLUGIN:NewID();offset=offset or id*1000
 ix.plugin.list.blackout.zones[name]={min=Vector(offset,0,0),max=Vector(offset+100,100,100),active=off==true}
 local c={id=id,name=name,zone=name,load=load or 20,priority=priority or 3,mainsOff=false,isolated=false}
 PLUGIN.store.circuits[id]=c;return c
end
function device(kind,c)
 local id=PLUGIN:NewID();local d={id=id,name=kind..id,kind=kind,circuit=c and c.id or 0,enabled=true,fault=false,level=0,department='',
  fuel=0,charge=6000,running=false,capacity=kind=='battery' and 30 or 60,radius=300,width=32,pos=Vector(),ang=Angle()}
 PLUGIN.store.devices[id]=d;PLUGIN:SpawnDevice(d);return d
end
function connectCircuit(g,c)
 local e=entity(10000+c.id,'fusebox',Vector(100,0,0));e.class='ix_blackout_fusebox'
 local link={kind='zone',zone=c.zone,name=c.zone,binding={class=e.class,model=e:GetModel(),mapid=e:MapCreationID(),pos=e:GetPos()}}
 g.links=g.links or {};g.links[#g.links+1]=link;PLUGIN.linkEntities[link]=e;return e
end
function door(c,level,dual)
 local id=PLUGIN:NewID();local e=entity(200+id,'door',Vector());e.class='prop_door_rotating'
 local d={id=id,name='Door '..id,entity=e,mapid=e:MapCreationID(),circuit=c and c.id or 0,level=level or 2,department='security',dual=dual,camera=0}
 PLUGIN.store.doors[id]=d;return d
end
