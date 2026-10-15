ix.CCTV=ix.CCTV or {}
local C=ix.CCTV
C.cameraRig={version=1,model="models/props_glackmesa/securitycamera.mdl",legacyModel="models/dav0r/camera.mdl",
 lens=Vector(18.58,0,7.46),angle=Angle(25,0,0),wall=Vector(-11,0,1.8)}
C.kinds={camera={class="ix_cctv_camera",model=C.cameraRig.model,name="Камера",limit=64},
 monitor={class="ix_cctv_monitor",model="models/props_c17/tv_monitor01.mdl",name="Монитор",limit=64},
 terminal={class="ix_cctv_terminal",model="models/props_c17/tv_monitor01.mdl",name="Экран управления CCTV",limit=16}}
C.maxFeeds=4;C.viewDistance=900;C.useDistance=128
function C.Number(n,low,high) return isnumber(n) and n==n and n>=low and n<=high end
function C.ID(n) return C.Number(n,1,1000000) and n%1==0 end
function C.Name(s)
 if not isstring(s) or #s>192 or s:find("[%c]") then return end
 s=string.Trim(s);if s=="" or (utf8.len(s) or 1000)>48 then return end;return s
end
function C.Vector(v)
 if (isvector(v) or istable(v)) and C.Number(v.x,-32768,32768) and C.Number(v.y,-32768,32768) and C.Number(v.z,-32768,32768) then return Vector(v.x,v.y,v.z) end
end
function C.Angle(v)
 if (isangle(v) or istable(v)) and C.Number(v.p,-360,360) and C.Number(v.y,-360,360) and C.Number(v.r,-360,360) then return Angle(v.p,v.y,v.r) end
end
function C.Transform(d)
 if d.bodycam then
  local p=d.entity or Entity(d.entityIndex or -1)
  if IsValid(p) and p:IsPlayer() and ix.bodycams then
   local pos,ang=ix.bodycams.HeadFrame(p)
   return pos,ang,p
  end
  return C.Vector(d.pos),C.Angle(d.ang)
 end
 if d.surface then return C.SurfaceTransform(d) end
 local ent=d.entity or Entity(d.entityIndex or -1)
 if IsValid(ent) and ent:GetNW2Int("ixCCTVID",0)==d.id and (SERVER or not ent:IsDormant()) then return ent:GetPos(),ent:GetAngles(),ent end
 return C.Vector(d.pos),C.Angle(d.ang)
end
function C.Lens(d)
 if d.bodycam then
  if ix.bodycams and ix.bodycams.Active(d) then return ix.bodycams.Lens(d.entity or Entity(d.entityIndex or -1)) end
  return
 end
 local pos,ang=C.Transform(d);if not pos or not ang then return end
 return C.CameraLens(pos,ang,d.model)
end
-- Calibrated against the model's idle skeleton, not its unposed VVD bounds.
-- The camera head is tilted 25 degrees; both preview and capture use this lens.
function C.CameraLens(pos,ang,model)
 if model and model~=C.cameraRig.model then return pos+ang:Forward()*12,ang end
 return LocalToWorld(C.cameraRig.lens,C.cameraRig.angle,pos,ang)
end
function C.RestoreCameraTransform(row)
 local pos,ang=C.Vector(row.pos),C.Angle(row.ang)
 if row.cameraRig==C.cameraRig.version or (row.model and row.model~=C.cameraRig.legacyModel) then return pos,ang end
 -- Keep the old feed position and direction. Migrate once, then save the rig
 -- revision so loading or saving again cannot accumulate a rotation/offset.
 local oldLens=pos+ang:Forward()*12
 local _,newAngle=LocalToWorld(Vector(),Angle(-25,0,0),Vector(),ang)
 local offset=LocalToWorld(C.cameraRig.lens,Angle(),Vector(),newAngle)
 return oldLens-offset,newAngle
end
function C.Screen(d)
 local pos,ang,ent=C.Transform(d);if not pos or not ang then return end
 if d.surface then return pos,ang,d.config.w,d.config.h,ent end
 -- Calibrated front surface of the stock TV model used by both devices.
 local center,a=LocalToWorld(Vector(7.65,-2,.75),Angle(0,90,90),pos,ang)
 return center,a,14.5,10.5,ent
end
function C.Powered(d)
 if not d or d.on==false then return false end
 -- A helmet camera is self-powered: blacked-out rooms remain visible as dark
 -- scenes. The destination monitor still uses ordinary facility power.
 if d.bodycam then return ix.bodycams and ix.bodycams.Active(d) or false end
 local pos,_,ent=C.Transform(d);if not pos then return false end
 local blackout=ix.plugin.list.blackout
 if blackout and blackout.IsElectronicsOffAt then return not blackout:IsElectronicsOffAt(pos,ent) end
 if ix.Facility and ix.Facility.EntityBackup(ent) then return true end
 return not blackout or not blackout:IsPosBlackedOut(pos)
end
function C.Placement(p,tr,kind)
 if not C.kinds[kind] or not tr.Hit or tr.HitSky or not C.Vector(tr.HitPos) then return end
 if tr.HitPos:DistToSqr(p:GetShootPos())>256*256 then return end
 if IsValid(tr.Entity) and (tr.Entity:IsPlayer() or tr.Entity:IsNPC()) then return end
 local normal=tr.HitNormal
 local angle=normal:Angle()
 if kind~="camera" and math.abs(normal.z)>.8 then angle=Angle(0,p:EyeAngles().y+180,0) end
 if kind=="camera" then
  local mount=LocalToWorld(C.cameraRig.wall,Angle(),Vector(),angle)
  return tr.HitPos+normal*.3-mount,angle
 end
 return tr.HitPos+normal*12,angle
end
function C.Visible(p,point,parent)
 local filter={p};if IsValid(parent) then filter[#filter+1]=parent end
 return not util.TraceLine({start=p:GetShootPos(),endpos=point,filter=filter,mask=MASK_VISIBLE}).Hit
end
