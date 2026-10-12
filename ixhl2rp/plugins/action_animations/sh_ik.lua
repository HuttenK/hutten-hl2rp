-- Adapted from the restored PushCart.SolveArm / Rodrigues implementation.
-- Independent of plugin load order, model paths and precompiled sequences.
ix.LimbIK=ix.LimbIK or {}
local K=ix.LimbIK
local EPS=.00001
function K.Perpendicular(direction)
 local axis=math.abs(direction.z)<.8 and Vector(0,0,1) or Vector(0,1,0)
 return (axis-direction*axis:Dot(direction)):GetNormalized()
end
function K.Solve(root,joint,tip,target,pole)
 local upper,lower=(joint-root):Length(),(tip-joint):Length()
 if upper<EPS or lower<EPS then return end
 local offset=target-root;local distance=offset:Length()
 local direction=distance>EPS and offset*(1/distance) or (tip-root):GetNormalized()
 if direction:Length()<EPS then direction=Vector(1,0,0) end
 local reach=math.Clamp(distance,math.abs(upper-lower)+.001,(upper+lower)*.99999)
 local bend=pole-direction*pole:Dot(direction)
 if bend:Length()<EPS then bend=K.Perpendicular(direction) end
 bend=bend:GetNormalized()
 local along=(upper*upper+reach*reach-lower*lower)/(2*reach)
 local across=math.sqrt(math.max(0,upper*upper-along*along))
 return root+direction*along+bend*across,root+direction*reach
end
function K.RotateVector(vector,axis,degrees)
 local angle=math.rad(degrees);local c,s=math.cos(angle),math.sin(angle)
 return vector*c+axis:Cross(vector)*s+axis*(axis:Dot(vector)*(1-c))
end
function K.Rotation(from,to,pivot,weight)
 if from:Length()<EPS or to:Length()<EPS then return Matrix() end
 local a,b=from:GetNormalized(),to:GetNormalized();local axis=a:Cross(b)
 local sine=axis:Length();local cosine=math.Clamp(a:Dot(b),-1,1)
 if sine<EPS then
  if cosine>0 then return Matrix() end
  axis=K.Perpendicular(a)
 else axis=axis*(1/sine) end
 local angle=math.atan2(sine,cosine)*(weight or 1)
 local c,s=math.cos(angle),math.sin(angle);local t=1-c
 local x,y,z=axis.x,axis.y,axis.z
 local rows={{t*x*x+c,t*x*y-s*z,t*x*z+s*y},{t*x*y+s*z,t*y*y+c,t*y*z-s*x},{t*x*z-s*y,t*y*z+s*x,t*z*z+c}}
 local matrix=Matrix();local values={pivot.x,pivot.y,pivot.z}
 for r=1,3 do
  local translated=values[r]
  for col=1,3 do matrix:SetField(r,col,rows[r][col]);translated=translated-rows[r][col]*values[col] end
  matrix:SetField(r,4,translated)
 end
 return matrix
end
function K.Descendant(parents,index,root)
 for _=1,256 do
  if index==root then return true end
  index=parents[index]
  if not index or index<0 then return false end
 end
 return false
end
-- Returns a fresh matrix set. Helpers under the limb follow their real parent;
-- unrelated arms, pelvis and legs are never rewritten.
function K.MoveChain(matrices,parents,chain,target,pole,weight,keepTip)
 local upper,lower,tip=unpack(chain)
 local a,b,c=matrices[upper],matrices[lower],matrices[tip]
 if not a or not b or not c or not K.Descendant(parents,lower,upper) or not K.Descendant(parents,tip,lower) then return end
 local root,joint,finish=a:GetTranslation(),b:GetTranslation(),c:GetTranslation()
 local elbow,wrist=K.Solve(root,joint,finish,target,pole)
 if not elbow then return end
 local out={};for index,m in pairs(matrices) do out[index]=m end
 local turn=K.Rotation(joint-root,elbow-root,root,weight)
 for index,m in pairs(out) do if K.Descendant(parents,index,upper) then out[index]=turn*m end end
 joint=out[lower]:GetTranslation();finish=out[tip]:GetTranslation()
 turn=K.Rotation(finish-joint,wrist-joint,joint,weight)
 for index,m in pairs(out) do if K.Descendant(parents,index,lower) then out[index]=turn*m end end
 if keepTip then
  local desired=c*Matrix();desired:SetTranslation(out[tip]:GetTranslation())
  local inverse=out[tip]:GetInverse()
  if inverse then
   local correction=desired*inverse
   for index,m in pairs(out) do if K.Descendant(parents,index,tip) then out[index]=correction*m end end
  end
 end
 return out,wrist
end
