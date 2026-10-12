local C=ix.CCTV
C.recognition={range=1024,limit=8,interval=.4,ttl=.85,frameTTL=.45}
-- This is an in-universe card reader, not a lookup of the wearer's character.
function C.IdentityText(value,limit)
 if not isstring(value) or #value>1024 or value:find("[%c]") then return end
 local count=utf8.len(value);if not count then return end
 value=string.Trim(value);if value=="" then return end
 count=utf8.len(value)
 if count>limit then value=value:sub(1,utf8.offset(value,limit+1)-1) end
 return value
end
function C.Recognizable(p)
 if not IsValid(p) or not p:IsPlayer() or not p:Alive() or p:GetNoDraw() then return false end
 if p:GetMoveType()==MOVETYPE_NOCLIP or p:GetMoveType()==MOVETYPE_OBSERVER then return false end
 if CLIENT and p:IsDormant() then return false end
 if SERVER and not p:GetCharacter() then return false end
 if p.GetLocalVar then
  local ragdoll=p:GetLocalVar("ragdoll")
  if IsValid(ragdoll) or (isnumber(ragdoll) and ragdoll>0) or p:GetLocalVar("knocked",false) then return false end
 end
 return true
end
function C.FacePosition(p)
 local eyes=p:EyePos();if not C.Vector(eyes) then return end
 local head=p:LookupBone("ValveBiped.Bip01_Head1")
 local point=head and p:GetBonePosition(head)
 -- Bone zero/model origin is a common uninitialised matrix result. EyePos is
 -- safe on non-ValveBiped players and while the client's skeleton is loading.
 if not C.Vector(point) or point:DistToSqr(eyes)>28^2 or point:DistToSqr(p:GetPos())<8^2 then point=eyes end
 return point+p:EyeAngles():Forward()*3
end
function C.FaceProjection(point,origin,angles,fov)
 if not C.Vector(point) or not C.Vector(origin) or not C.Angle(angles) then return end
 local delta=point-origin;local depth=delta:Dot(angles:Forward())
 if depth<12 or delta:LengthSqr()>C.recognition.range^2 then return end
 local tan=math.tan(math.rad(math.Clamp(tonumber(fov) or 75,30,110)*.5))
 local x=.5+.5*delta:Dot(angles:Right())/(depth*tan)
 local y=.5-.5*delta:Dot(angles:Up())*(16/9)/(depth*tan)
 local size=14/(2*depth*tan) -- Square in the 16:9 image's pixels.
 local sy=size*16/9
 if x-size/2<0 or x+size/2>1 or y-sy/2<0 or y+sy/2>1 then return end
 return {x=x,y=y,w=size,h=sy,depth=depth}
end
function C.VisibleFace(p,origin,angles,fov,cameraEntity)
 if p==cameraEntity or not C.Recognizable(p) then return end
 local point=C.FacePosition(p);if not point then return end
 local box=C.FaceProjection(point,origin,angles,fov);if not box then return end
 -- Do not identify the back of somebody's head.
 if p:EyeAngles():Forward():Dot((origin-point):GetNormalized())<.1 then return end
 local filter={};if IsValid(cameraEntity) then filter[1]=cameraEntity end
 local trace=util.TraceLine({start=origin,endpos=point,filter=filter,mask=MASK_VISIBLE})
 if trace.StartSolid or (trace.Hit and trace.Entity~=p) then return end
 return box
end
function C.SameIdentity(a,b)
 return a and b and a.entity==b.entity and a.userid==b.userid and a.name==b.name and a.department==b.department and a.level==b.level
end
