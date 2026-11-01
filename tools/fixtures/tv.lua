SERVER=true;CLIENT=false
PLUGIN={}
ix.plugin.list.tv_screen=PLUGIN
function string.utf8len(s) return utf8.len(s) end
function table.Count(t) local n=0;for _ in pairs(t) do n=n+1 end;return n end
function isvector(v) return type(v)=='table' and getmetatable(v)==getmetatable(Vector()) end
local V=getmetatable(Vector())
function V:DistToSqr(v) local d=self-v;return d:Dot(d) end
function V:Distance(v) return math.sqrt(self:DistToSqr(v)) end
local function rotate(v,a) return a:Forward()*v.x-a:Right()*v.y+a:Up()*v.z end
local function inverse(v,a) return Vector(v:Dot(a:Forward()),-v:Dot(a:Right()),v:Dot(a:Up())) end
local function axes(f,u) local a=f:Angle();a.r=math.deg(math.atan(u:Dot(a:Right()),u:Dot(a:Up())));return a end
function LocalToWorld(p,a,op,oa) return op+rotate(p,oa),axes(rotate(a:Forward(),oa),rotate(a:Up(),oa)) end
function WorldToLocal(p,a,op,oa) return inverse(p-op,oa),axes(inverse(a:Forward(),oa),inverse(a:Up(),oa)) end
local function clone(t)
 if type(t)~='table' then return t end
 local out={};for k,v in pairs(t) do out[k]=clone(v) end
 return setmetatable(out,getmetatable(t))
end
stored={};ix.data={Get=function(k,d) if stored[k]~=nil then return clone(stored[k]) end return d end,Set=function(k,v,global,ignoreMap) stored[k]=clone(v);lastIgnoreMap=ignoreMap end}
json={};function util.TableToJSON(v) json[#json+1]=clone(v);return tostring(#json) end
function util.JSONToTable(v) return clone(json[tonumber(v)]) end
net.packets={};net.Broadcast=function() net.packet.target='all';net.packets[#net.packets+1]=net.packet end
net.Start=function(name) net.packet={name=name} end
net.WriteString=function(v) net.packet.value=v end
net.WriteBool=function(v) net.packet.boolean=v end
net.WriteUInt=function(v) net.packet.integer=v end
net.Send=function(p) net.packet.target=p;net.packets[#net.packets+1]=net.packet end
net.SendToServer=function() net.packet.target='server';net.packets[#net.packets+1]=net.packet end
file={CreateDir=function() end,Size=function() return #subtitleFile end,Read=function() return subtitleFile end}
hooks={};function hook.Add(event,name,fn) hooks[event]=hooks[event] or {};hooks[event][name]=fn end
function hook.Remove(event,name) if hooks[event] then hooks[event][name]=nil end end
function hook.Run(event,...) for _,fn in pairs(hooks[event] or {}) do local r=fn(...);if r~=nil then return r end end end
entities={}
function Entity(id) return entities[id] end
ents.FindByModel=function(model) local out={};for _,e in pairs(entities) do if e.model==model and IsValid(e) then out[#out+1]=e end end;return out end
ents.GetMapCreatedEntity=function(id) for _,e in pairs(entities) do if e.mapid==id then return e end end end
function entity(id,model,pos,ang)
 local e={valid=true,model=model,pos=pos or Vector(),ang=ang or Angle(),id=id,mapid=id}
 function e:GetModel() return self.model end
 function e:GetPos() return self.pos end
 function e:GetAngles() return self.ang end
 function e:MapCreationID() return self.mapid end
 function e:EntIndex() return self.id end
 function e:GetClass() return 'prop_physics' end
 function e:IsPlayer() return false end;function e:IsNPC() return false end
 function e:SetNW2Int(k,v) self[k]=v end
 function e:GetNW2Int(k,d) return self[k] or d end
 function e:SetNW2String(k,v) self[k]=v end
 function e:GetNW2String(k,d) return self[k] or d end
 entities[id]=e;return e
end
function admin()
 local p={valid=true,admin=true,pos=Vector(0,0,64),dir=Vector(1,0,0),notices={}}
 function p:IsPlayer() return true end
 function p:IsAdmin() return self.admin end
 function p:GetShootPos() return self.pos end
 function p:GetPos() return self.pos end
 function p:GetAimVector() return self.dir end
 function p:GetEyeTrace() return self.trace end
 function p:KeyDown() return false end
 function p:Notify(text) self.notices[#self.notices+1]=text end
 return p
end
util.TraceLine=function() return {Hit=false} end
MASK_SOLID=1;IN_USE=32;IN_SPEED=64

