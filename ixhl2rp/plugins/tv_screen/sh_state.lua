ix.TV=ix.TV or {}
local T=ix.TV
T.maxChannels=8
T.maxScreens=128
T.defaultModel="models/props_c17/tv_monitor01.mdl"
-- Equivalent to the old TV plane's local rotation (R270 then U90).
-- The old x=6 plane intersects the curved front of the stock television.
T.defaultConfig={x=7.65,y=-2,z=.75,p=0,yaw=90,r=90,w=14.5,h=10.5}
do
 local a=Angle()
 a:RotateAroundAxis(a:Right(),270)
 a:RotateAroundAxis(a:Up(),90)
 T.defaultConfig.p=math.NormalizeAngle(a.p)
 T.defaultConfig.yaw=math.NormalizeAngle(a.y)
 T.defaultConfig.r=math.NormalizeAngle(a.r)
end
T.fields={"x","y","z","p","yaw","r","w","h"}
function T.Number(v,low,high) return isnumber(v) and v==v and v>=low and v<=high end
function T.Position(v)
 if not isvector(v) and not istable(v) then return end
 if T.Number(v.x,-1000000,1000000) and T.Number(v.y,-1000000,1000000) and T.Number(v.z,-1000000,1000000) then return Vector(v.x,v.y,v.z) end
end
function T.Text(v,limit)
 if not isstring(v) or #v>limit*4 or v:find("[%c<>]") then return end
 local ok,length=pcall(string.utf8len,v)
 if not ok or not length or length>limit then return end
 v=string.Trim(v);if v~="" then return v end
end
function T.Config(v)
 if not istable(v) then return end
 local out={}
 for _,key in ipairs(T.fields) do
  local low,high=-4096,4096
  if key=="w" or key=="h" then low,high=1,1024
  elseif key=="p" or key=="yaw" or key=="r" then low,high=-360,360 end
  if not T.Number(v[key],low,high) then return end
  out[key]=v[key]
 end
 return out
end
function T.UpgradeConfig(model,v)
 local c=T.Config(v);if not c or model~=T.defaultModel then return c end
 -- Only repair the untouched legacy preset. Keep deliberate calibrations.
 for _,key in ipairs(T.fields) do
  local old=key=="x" and 6 or T.defaultConfig[key]
  if math.abs(c[key]-old)>.001 then return c end
 end
 c.x=T.defaultConfig.x
 return c
end
function T.Model(v)
 return isstring(v) and #v<=240 and v:match("^models/[%w_/%-%.]+%.mdl$") and not v:find("..",1,true)
end
function T.Source(v,empty)
 if not ix.BroadcastMedia.ValidSource(v,empty) then return false end
 local host=v:match("^https?://([^/]+)")
 if host then
  host=host:lower()
  if host:find("youtube",1,true) or host:find("youtu.be",1,true) or host:find("twitch",1,true) then return false end
 end
 return true
end
function T.Channel(id,name)
 return {id=id,name=name,source="",sound="",subtitles="",loop=false,soundLoop=false,playing=false,volume=1,start=CurTime(),revision=1}
end
function T.Subtitles(raw)
 if not ix.BroadcastMedia.ParseSubtitles(raw) then return false end
 -- JSON escaping may expand text; reserve room for URLs and channel fields
 -- below the engine's net-message size limit.
 local encoded=util.TableToJSON({text=raw})
 return encoded and #encoded<=54000
end
function T.Elapsed(c) return math.max(0,CurTime()-(c.start or CurTime())) end
function T.Transform(screen)
 local c=screen.config;if not c then return end
 local pos,ang=Vector(c.x,c.y,c.z),Angle(c.p,c.yaw,c.r)
 if screen.world then
  local origin=T.Position(screen.origin);if not origin then return end
  return pos+origin,ang
 end
 local ent=screen.entity
 if not IsValid(ent) and screen.entityIndex then ent=Entity(screen.entityIndex) end
 if not IsValid(ent) or ent:GetModel()~=screen.model then return end
 if CLIENT and screen.entityIndex and not ix.PropScreens.Has(ent,"ixTVScreenID",screen.id) then return end
 return LocalToWorld(pos,ang,ent:GetPos(),ent:GetAngles())
end
function T.ScreenPlane(screen)
 local center,ang=T.Transform(screen);if not center then return end
 local c=screen.config;local scale=c.w/1024
 -- cam.Start3D2D maps pixel +Y to Angle:Right(), not its negative.
 -- Both axes must therefore be subtracted to reach the upper-left corner.
 -- https://wiki.facepunch.com/gmod/cam.Start3D2D
 local origin=center-ang:Forward()*(c.w*.5)-ang:Right()*(c.h*.5)
 return origin,ang,scale,c.h/scale,center
end
function T.SurfaceConfig(trace)
 if not trace.Hit or trace.HitSky then return end
 local pos=trace.HitPos+trace.HitNormal*.35
 local ang=trace.HitNormal:Angle();ang.p=ang.p+90
 local ent=trace.Entity
 local world=trace.HitWorld or not IsValid(ent)
 if not world then
  if ent:IsPlayer() or ent:IsNPC() or not T.Model(ent:GetModel()) then return end
  pos,ang=WorldToLocal(pos,ang,ent:GetPos(),ent:GetAngles())
 else pos=Vector() end
 return {x=pos.x,y=pos.y,z=pos.z,p=math.NormalizeAngle(ang.p),yaw=math.NormalizeAngle(ang.y),r=math.NormalizeAngle(ang.r),w=48,h=27},world,ent
end
function T.AimScreen(ply,screens,distance)
 local origin,dir=ply:GetShootPos(),ply:GetAimVector()
 local best,bestHit,depth=nil,nil,distance or 220
 for _,s in pairs(screens) do
  local pos,ang=T.Transform(s)
  if pos then
   local denom=dir:Dot(ang:Up())
   if math.abs(denom)>.001 then
    local t=(pos-origin):Dot(ang:Up())/denom
    if t>0 and t<depth then
     local delta=origin+dir*t-pos
     if math.abs(delta:Dot(ang:Forward()))<=s.config.w/2 and math.abs(delta:Dot(ang:Right()))<=s.config.h/2 then
      local hit=util.TraceLine({start=origin,endpos=origin+dir*t,filter=ply,mask=MASK_SOLID})
      if not hit.Hit or hit.HitPos:DistToSqr(origin+dir*t)<16 then best,bestHit,depth=s,origin+dir*t,t end
     end
    end
   end
  end
 end
 return best,bestHit
end

