local S=ix.PoseStudio
function S.TargetChain(reference,clip,name)
 local side,part=(name or ""):match("^ValveBiped%.Bip01_([LR])_(.+)$")
 local parts=part=="Hand" and {"UpperArm","Forearm","Hand"} or part=="Foot" and {"Thigh","Calf","Foot"}
 if not parts or not reference or not ix.LimbIK then return end
 local names,indices={},{}
 for i,value in ipairs(parts) do
  names[i]="ValveBiped.Bip01_"..side.."_"..value
  indices[i]=reference.rig.names[names[i]]
  if indices[i]==nil or not S.EditableBone(clip,names[i]) then return end
 end
 return indices,names
end
function S.TargetWorld(reference,bones)
 local matrices,parents={},{}
 for i=0,reference.rig.count-1 do
  local bone=reference.rig.bones[i];local pose=reference.locals[bone.name] or bone.localBind
  if not pose then return end
  local delta=Matrix();local value=bones[bone.name]
  if value then delta:SetAngles(Angle(unpack(value.a)));delta:SetTranslation(Vector(unpack(value.p))) end
  parents[i]=bone.parent
  matrices[i]=(bone.parent>=0 and matrices[bone.parent] or Matrix())*pose*delta
 end
 return matrices,parents
end
function S.MakeTarget(reference,clip,bones,name)
 local chain,names=S.TargetChain(reference,clip,name)
 if not chain then return nil,"Выберите доступную кисть или стопу. Для ног нужен режим всего тела." end
 local matrices,parents=S.TargetWorld(reference,bones)
 if not matrices then return nil,"Не удалось прочитать скелет модели автора." end
 local root,joint,tip=matrices[chain[1]]:GetTranslation(),matrices[chain[2]]:GetTranslation(),matrices[chain[3]]:GetTranslation()
 local direction=(tip-root):GetNormalized();local pole=joint-root-direction*(joint-root):Dot(direction)
 if pole:Length()<.001 then pole=ix.LimbIK.Perpendicular(direction) end
 return {reference=reference,chain=chain,names=names,matrices=matrices,parents=parents,bones=table.Copy(bones),root=root,goal=tip,pole=pole:GetNormalized()}
end
function S.SolveTarget(target,goal,bend)
 local direction=(goal-target.root):GetNormalized()
 if direction:Length()<.001 then direction=Vector(1,0,0) end
 local pole=ix.LimbIK.RotateVector(target.pole,direction,bend or 0)
 local matrices,reached=ix.LimbIK.MoveChain(target.matrices,target.parents,target.chain,goal,pole,1,true)
 if not matrices then return nil,"Не удалось решить цепь костей." end
 local result=table.Copy(target.bones)
 for n,index in ipairs(target.chain) do
  local name=target.names[n];local parent=target.parents[index]
  local parentInverse=(parent>=0 and matrices[parent] or Matrix()):GetInverse()
  local baseInverse=target.reference.locals[name] and target.reference.locals[name]:GetInverse()
  if not parentInverse or not baseInverse then return nil,"Некорректная основа кости." end
  local delta=baseInverse*parentInverse*matrices[index];local angle=delta:GetAngles()
  -- Only rotations are baked; authored offsets and segment lengths survive.
  local value=table.Copy(result[name] or S.Identity())
  value.a={math.NormalizeAngle(angle.p),math.NormalizeAngle(angle.y),math.NormalizeAngle(angle.r)}
  result[name]=S.Transform(value,S.BonePositionLimit(name))
  if not result[name] then return nil,"Результат выходит за пределы формата позы." end
 end
 return result,nil,reached
end

-- The visible character can have different proportions from the saved rig.
-- Solve on the displayed matrices, then map the three rotations back to the
-- saved reference. Neither the missing donor entity nor its mesh is required.
function S.MakeViewportTarget(reference,clip,bones,name,rig,matrices)
 if not rig or not reference or not reference.rig then return nil,"Скелет модели предпросмотра ещё загружается." end
 local map=S.RigMap(rig,reference and reference.rig)
 local chain,names=S.TargetChain({rig=rig},clip,name)
 if not map or not chain or not matrices then return nil,"Кисть / стопа ещё не готова. Дождитесь предпросмотра." end
 local parents={}
 for i=0,rig.count-1 do parents[i]=rig.bones[i].parent end
 for _,part in ipairs(names) do
  local item=map[part]
  if not item or not matrices[item.target] then return nil,"Неполная цепь костей в модели предпросмотра." end
 end
 local root,joint,tip=matrices[chain[1]]:GetTranslation(),matrices[chain[2]]:GetTranslation(),matrices[chain[3]]:GetTranslation()
 local direction=(tip-root):GetNormalized();local pole=joint-root-direction*(joint-root):Dot(direction)
 if pole:Length()<.001 then pole=ix.LimbIK.Perpendicular(direction) end
 return {reference=reference,chain=chain,names=names,matrices=matrices,parents=parents,bones=table.Copy(bones),
  root=root,goal=tip,pole=pole:GetNormalized(),mapping=map}
end
function S.SolveViewportTarget(target,goal,bend)
 if not target.mapping then return S.SolveTarget(target,goal,bend) end
 local direction=(goal-target.root):GetNormalized()
 if direction:Length()<.001 then direction=Vector(1,0,0) end
 local pole=ix.LimbIK.RotateVector(target.pole,direction,bend or 0)
 local solved,reached=ix.LimbIK.MoveChain(target.matrices,target.parents,target.chain,goal,pole,1,true)
 if not solved then return nil,"Не удалось решить цепь костей." end
 local desired={}
 for _,name in ipairs(target.names) do
  local entry=target.mapping[name]
  local ancestor=entry.ancestor>=0 and solved[entry.ancestor] or Matrix()
  local inverse=ancestor and ancestor:GetInverse()
  if not inverse then return nil,"Некорректная основа цепи." end
  desired[name]=inverse*solved[entry.target]
 end
 local reference=target.reference;local result=table.Copy(target.bones);local world={}
 for i=0,reference.rig.count-1 do
  local bone=reference.rig.bones[i];local base=reference.locals[bone.name] or bone.localBind
  local value=table.Copy(result[bone.name] or S.Identity());local delta=Matrix()
  delta:SetAngles(Angle(unpack(value.a)));delta:SetTranslation(Vector(unpack(value.p)))
  local parent=bone.parent>=0 and world[bone.parent] or Matrix()
  if not base or not parent then return nil,"Некорректная сохранённая цепь." end
  if desired[bone.name] then
   local entry=target.mapping[bone.name]
   local ancestor=entry.sourceAncestor>=0 and world[entry.sourceAncestor] or Matrix()
   local parentInverse,baseInverse=parent:GetInverse(),base:GetInverse()
   if not ancestor or not parentInverse or not baseInverse then return nil,"Некорректная основа кости." end
   local adjusted=baseInverse*parentInverse*ancestor*desired[bone.name]
   local angle=adjusted:GetAngles();value.a={math.NormalizeAngle(angle.p),math.NormalizeAngle(angle.y),math.NormalizeAngle(angle.r)}
   result[bone.name]=S.Transform(value,S.BonePositionLimit(bone.name))
   if not result[bone.name] then return nil,"Результат выходит за пределы формата позы." end
   delta:SetAngles(angle)
  end
  world[i]=parent*base*delta
 end
 return result,nil,reached
end
