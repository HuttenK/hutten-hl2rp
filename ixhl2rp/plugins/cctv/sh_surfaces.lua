local C=ix.CCTV
C.terminalWidth=800;C.terminalHeight=580
C.surfaceFields={"x","y","z","p","yaw","r","w","h"}
function C.SurfaceConfig(v)
 if not istable(v) then return end
 local out={}
 for _,key in ipairs(C.surfaceFields) do
  local low,high=-4096,4096
  if key=="w" or key=="h" then low,high=1,1024
  elseif key=="p" or key=="yaw" or key=="r" then low,high=-360,360 end
  if not C.Number(v[key],low,high) then return end;out[key]=v[key]
 end
 return out
end
function C.PropModel(model)
 return isstring(model) and #model<=240 and model:match("^models/[%w_/%-%.]+%.mdl$") and not model:find("..",1,true)
end
function C.SurfaceParent(ent)
 return IsValid(ent) and not ent:IsPlayer() and not ent:IsNPC() and not ent:IsWeapon()
  and not ent.CCTVKind and ent:GetClass()~="ix_item" and C.PropModel(ent:GetModel())
end
function C.SurfacePlacement(p,tr)
 if not tr.Hit or tr.HitSky or tr.HitWorld or not C.Vector(tr.HitPos) or not C.SurfaceParent(tr.Entity)
  or tr.HitPos:DistToSqr(p:GetShootPos())>256^2 then return end
 local pos=tr.HitPos+tr.HitNormal*.35
 local ang=tr.HitNormal:Angle();ang.p=ang.p+90
 pos,ang=WorldToLocal(pos,ang,tr.Entity:GetPos(),tr.Entity:GetAngles())
 return C.SurfaceConfig({x=pos.x,y=pos.y,z=pos.z,p=math.NormalizeAngle(ang.p),yaw=math.NormalizeAngle(ang.y),
  r=math.NormalizeAngle(ang.r),w=32,h=23.2}),tr.Entity
end
function C.SurfaceTransform(d)
 local ent=d.entity or Entity(d.entityIndex or -1);local cfg=d.config
 if not IsValid(ent) or not cfg or ent:GetModel()~=d.model or (CLIENT and ent:IsDormant()) then return end
 if not (CLIENT and d.preview) and not ix.PropScreens.Has(ent,"ixCCTVSurfaceID",d.id) then return end
 local pos,ang=LocalToWorld(Vector(cfg.x,cfg.y,cfg.z),Angle(cfg.p,cfg.yaw,cfg.r),ent:GetPos(),ent:GetAngles())
 return pos,ang,ent
end
function C.TerminalGeometry(d)
 local center,ang,w,h,ent=C.Screen(d);if not center then return end
 -- Fit the same interface into any chosen aspect ratio, without clipping controls.
 local scale=math.min(w/C.terminalWidth,h/C.terminalHeight)
 return center-ang:Forward()*(C.terminalWidth*scale/2)-ang:Right()*(C.terminalHeight*scale/2),ang,scale,ent
end
function C.TerminalRay(d,eye,direction)
 local origin,angle,scale=C.TerminalGeometry(d);if not origin then return end
 local denominator=direction:Dot(angle:Up());if denominator>=-.001 then return end
 local distance=(origin-eye):Dot(angle:Up())/denominator;if distance<=0 then return end
 local hit=eye+direction*distance;local delta=hit-origin
 local x,y=delta:Dot(angle:Forward())/scale,delta:Dot(angle:Right())/scale
 if x<0 or y<0 or x>=C.terminalWidth or y>=C.terminalHeight then return end
 return x,y,hit
end
function C.TerminalReach(p,d)
 local pos,ang,_,_,ent=C.Screen(d)
 if not pos or not IsValid(ent) then return false end
 local delta=p:GetShootPos()-pos
 return delta:Length()<=C.useDistance and (not d.surface or delta:Dot(ang:Up())>0)
  and C.Visible(p,pos,ent)
end
function C.AimTerminal(p,devices)
 local best,bestHit,depth=nil,nil,C.useDistance^2
 for _,d in pairs(devices) do
  if d.kind=="terminal" and d.surface then
   local _,_,hit=C.TerminalRay(d,p:GetShootPos(),p:GetAimVector())
   if hit and hit:DistToSqr(p:GetShootPos())<depth and C.TerminalReach(p,d) then
    best=d;bestHit=hit;depth=hit:DistToSqr(p:GetShootPos())
   end
  end
 end
 return best,bestHit
end
