-- Engine boundaries only; actual water/session/IK implementations load after this.
ix.util={Include=function() end};ix.command={Add=function() end}
ix.Reagents={IsRefillable=function(_,item) return not item.closed end}
ix.Item={instances={}};NULL={};MOVETYPE_OBSERVER=10;FACTION_VORTIGAUNT=999
local oldAdmin=admin
function waterUser()
 local p=oldAdmin();p.items={};p.trace={};p.nw={};p.locals={};p.model='models/player/test.mdl'
 function p:GetInventory() return {GetItems=function() return self.items end} end
 function p:GetNetVar(k,d) if self[k]~=nil then return self[k] end;return d end
 function p:GetLocalVar(k,d) if self.locals[k]~=nil then return self.locals[k] end;return d end
 function p:GetNW2String(k,d) return self.nw[k] or d end
 function p:GetNW2Entity(k) return self.nw[k] or NULL end
 function p:GetNW2Float(k,d) return self.nw[k] or d end
 function p:GetNW2Vector(k,d) return self.nw[k] or d end
 function p:GetNW2Bool(k,d) if self.nw[k]~=nil then return self.nw[k] end;return d end
 function p:SetNW2String(k,v) self.nw[k]=v end
 function p:SetNW2Entity(k,v) self.nw[k]=v end
 function p:SetNW2Float(k,v) self.nw[k]=v end
 function p:SetNW2Vector(k,v) self.nw[k]=v end
 function p:IsWepRaised() return self.raised end
 function p:GetActiveWeapon() return nil end
 function p:GetMoveType() return 2 end
 function p:GetNoDraw() return self.hidden end
 function p:SetAction(text) hook.Run('PlayerActionChanged',self,text);self.action=text end
 function p:Team() return 1 end
 function p:GetModel() return self.model end
 function p:GetRenderAngles() return self.ang or Angle() end
 function p:IsDormant() return self.dormant end
 function p:AddCallback(_,fn) self.callback=fn;self.adds=(self.adds or 0)+1;return self.adds end
 function p:RemoveCallback() self.removes=(self.removes or 0)+1 end
 function p:InvalidateBoneCache() end
 function p.character:UpdateNeeds(n) self.thirst=(self.thirst or 0)+n end
 function p.character:GetRadLevel() return self.rad or 0 end
 function p.character:SetRadLevel(n) self.rad=n end
 return p
end
function waterSource(p,kind)
 local e=entity(700+(sourceID or 0),'models/props_c17/furnituresink001a.mdl',Vector(30,0,48));sourceID=(sourceID or 0)+1
 e.class=kind=='toilet' and 'ix_toilet_trigger' or 'ix_sink_trigger'
 function e:GetClass() return self.class end
 function e:NearestPoint() return self.pos end
 function e:OBBMins() return Vector(-12,-14,-20) end
 function e:OBBMaxs() return Vector(12,14,20) end
 function e:LocalToWorld(v) return LocalToWorld(v,Angle(),self.pos,self.ang) end
 function e:IsDormant() return self.dormant end
 p.trace={Entity=e,HitPos=e:LocalToWorld(Vector(-10,3,7))}
 return e
end
function waterContainer(p,id,model)
 local item={id=id,owner=p,model=model or 'models/props_junk/garbage_plasticbottle003a.mdl',isReagentHolder=true,reagents={volume=0,max_volume=330,reagents={}}}
 function item:GetOwner() return self.owner end
 function item:GetName() return 'Selected container '..self.id end
 function item:GetModel() return self.model end
 function item.reagents:AddReagent(kind,n) self.added=kind;self.volume=self.volume+n end
 function item.reagents:UpdateTotal() end
 p.items[#p.items+1]=item;return item
end
net.WriteEntity=function() end
util.TraceLine=function() return {Hit=wall==true} end
ix.chat.Send=function() end
function waterNear(a,b) assert(a:DistToSqr(b)<.001,tostring(a)..' ~= '..tostring(b)) end
function FrameTime() return .05 end
function math.Approach(a,b,c) return a<b and math.min(a+c,b) or math.max(a-c,b) end
