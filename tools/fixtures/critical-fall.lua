-- Engine boundaries for the real health-system SetRagdolled implementation.
concommand={Add=function() end}
p.SetRagdolled=nil -- Exercise the real Player metatable implementation.
hooks={}
function hook.Add(event,id,fn) hooks[event]=hooks[event] or {};hooks[event][id]=fn end
function hook.Run(event,...)
 for _,fn in pairs(hooks[event] or {}) do local value=fn(...);if value~=nil then return value end end
 if PLUGIN[event] then return PLUGIN[event](PLUGIN,...) end
end
function os.time() return 1000+math.floor(clock) end
MOVETYPE_OBSERVER=10;MOVETYPE_WALK=2;FL_DUCKING=2;MASK_PLAYERSOLID=1
vector_origin=Vector()
function p:GetLocalVar(k,d) return self:GetNetVar(k,d) end
function p:InVehicle() return self.vehicle end
function p:ExitVehicle() self.vehicle=false;self.exited=true end
function p:GetPos() return self.pos or Vector() end
function p:SetPos(v) self.pos=v end
function p:SetNoDraw(v) self.hidden=v end
function p:SetNotSolid(v) self.notSolid=v end
function p:SetMoveType(v) self.move=v end
function p:SetLocalVelocity(v) self.velocity=v end
function p:GodDisable() end
function p:SteamID() return 'fall-test' end
function p:AddFlags(flag) self.flags=flag end
function p:AnimRestartMainSequence() self.animationRestarted=true end
function p:GetHullDuck() return Vector(-16,-16,0)*.9166667,Vector(16,16,36)*.9166667 end
function p:LookupSequence(name) return name=='pwalk_all' and 12 or 13 end
function p:SetWepRaised(value) self.raised=value end
function p:CreateServerRagdoll()
 self.created=(self.created or 0)+1
 local body={valid=true,callbacks={},pos=Vector(120,25,15)}
 function body:CallOnRemove(id,fn) self.callbacks[id]=fn end
 function body:Remove()
  self.valid=false
  for _,fn in pairs(self.callbacks) do fn(self) end
 end
 function body:GetPos() return self.pos end
 function body:EntIndex() return 9 end
 function body:IsPlayerHolding() return self.held end
 function body:GetNW2Entity(k) return self[k] end
 return body
end
function weapon(class)
 local w={valid=true,class=class,clip=23}
 function w:GetClass() return self.class end
 function w:Clip1() return self.clip end
 function w:SetClip1(v) self.clip=v end
 function w:GetPrimaryAmmoType() return 1 end
 return w
end
p.weapons={weapon('arc9_eft_ak74'),weapon('ix_hands')};p.active=p.weapons[1]
function p:GetActiveWeapon() return self.active end
function p:SetActiveWeapon(w) self.active=w end
function p:GetWeapons() return self.weapons end
function p:GetAmmoCount() return self.ammo or 90 end
function p:SetAmmo(v) self.ammo=v end
function p:GetWeapon(class) for _,w in ipairs(self.weapons) do if w.class==class then return w end end end
function p:HasWeapon(class) return self:GetWeapon(class)~=nil end
function p:SelectWeapon(class) self.active=self:GetWeapon(class) end
function p:StripWeapons() self.weapons={};self.active=nil end
function p:Give(class) local w=weapon(class);self.weapons[#self.weapons+1]=w;return w end
function util.TraceLine(data)
 return {Hit=not airborne,StartSolid=false,HitNormal=Vector(0,0,1),HitPos=Vector(data.start.x,data.start.y,0)}
end
function util.TraceHull(data)
 near(data.maxs.z,33.0000012)
 return {Hit=blocked,StartSolid=blocked}
end
