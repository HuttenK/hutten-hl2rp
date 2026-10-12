local S=ix.PoseStudio
local anatomy
function S.StarterRig()
 if anatomy then return anatomy end
 local rig={bones={},names={},count=#S.starterAnatomy}
 for index,data in ipairs(S.starterAnatomy) do
  local i=index-1; local localBind=Matrix()
  for r=1,3 do for c=1,4 do localBind:SetField(r,c,data.m[(r-1)*4+c]) end end
  local bind=data.parent>=0 and rig.bones[data.parent].bind*localBind or localBind
  rig.bones[i]={name=data.name,parent=data.parent,localBind=localBind,bind=bind,inverse=bind:GetInverse()}
  rig.names[data.name]=i
 end
 rig.height=(rig.bones[rig.names['ValveBiped.Bip01_Head1']].bind:GetTranslation()-rig.bones[rig.names['ValveBiped.Bip01_Pelvis']].bind:GetTranslation()):Length()
 anatomy=rig; return rig
end

-- Reuse playback's ancestor-aware retargeter, including helper bones and limb
-- lengths. The embedded numerical authoring rig needs no installed source model.
function S.BuildStarterClip(preset,rig,matrices,base,model)
 local source=S.StarterRig(); local mapping=S.RigMap(rig,source)
 if not mapping then return nil,"Нужен совместимый гуманоидный скелет ValveBiped." end
 -- Unused attachments/physics helpers need not have render matrices. Optional
 -- fingers/toes may also be culled; only sample their keys when available.
 local active={}
 for name,entry in pairs(mapping) do
  local optional=name:find("Finger",1,true) or name:find("Toe",1,true)
  local available=true; local i=entry.target
  while i>=0 do
   if not matrices[i] then
    available=false
    if not optional then return nil,"Скелет ещё не готов: "..rig.bones[i].name,true end
    break
   end
   i=rig.bones[i].parent
  end
  if available then active[name]=entry end
 end
 mapping=active
 local locals={}
 for i=0,source.count-1 do
  local bone=source.bones[i]; local pose=bone.localBind*Matrix(); local rotation=preset.bones[bone.name]
  if rotation then for r=1,3 do for c=1,3 do pose:SetField(r,c,rotation[(r-1)*3+c]) end end end
  if bone.parent<0 then pose:SetTranslation(Vector(unpack(preset.rootPosition))) end
  locals[bone.name]=pose
 end
 local desired={}
 local target={GetBoneCount=function() return rig.count end,GetBoneMatrix=function(_,i) return matrices[i] end,
  GetBoneParent=function(_,i) return rig.bones[i].parent end,GetBoneName=function(_,i) return rig.bones[i].name end,
  GetPos=function() return vector_origin end,GetAngles=function() return angle_zero end,
  GetRenderAngles=function() return angle_zero end,GetModelScale=function() return 1 end,
  SetBoneMatrix=function(_,i,m) desired[i]=m end}
 S.ApplyLayer(target,{clip={portable=true,mask="full"},reference={rig=source,locals=locals},
  targetRig=rig,rigMap=mapping,rigRatio=rig.height/source.height,transforms={}})
 local bones={}
 for name,entry in pairs(mapping) do
  local i=entry.target; local parent=rig.bones[i].parent
  local originalParent=parent>=0 and matrices[parent] or Matrix()
  local posedParent=parent>=0 and (desired[parent] or matrices[parent]) or Matrix()
  local sampled=originalParent:GetInverse()*matrices[i]
  local posed=posedParent:GetInverse()*(desired[i] or matrices[i])
  local delta=sampled:GetInverse()*posed
  local a,p=delta:GetAngles(),delta:GetTranslation()
  bones[name]={a={math.NormalizeAngle(a.p),math.NormalizeAngle(a.y),math.NormalizeAngle(a.r)},p={p.x,p.y,p.z}}
 end
 return S.Validate({name=preset.name,model=model,base=base,cycle=0,portable=true,mask="full",
  loop=true,smooth=true,frames={{duration=1,bones=bones}},props={}})
end

function S.CreateStarterClip(id,callback)
 local function reject(message)
  if callback then callback(nil,message) end
  return nil,message
 end
 local preset
 for _,value in ipairs(S.starterPoses) do if value.id==id then preset=value; break end end
 if not preset then return reject("Неизвестная стартовая поза.") end
 local player=LocalPlayer()
 if not IsValid(player) then return reject("Персонаж ещё не загружен.") end
 local model=player:GetModel():lower()
 local rig=ix.sharedPoses and ix.sharedPoses.Rig(model)
 if not S.RigMap(rig,S.StarterRig()) then return reject("Нужен совместимый гуманоидный скелет ValveBiped.") end
 local entity=ClientsideModel(model,RENDERGROUP_OTHER)
 if not IsValid(entity) then return reject("Не удалось открыть модель персонажа.") end
 entity:SetNoDraw(true)
 if entity.SetLOD then entity:SetLOD(0) end
 if entity.SetIK then entity:SetIK(false) end
 local attempts=0
 local function sample()
 local ok,clip,err,retry=pcall(function()
  if not IsValid(entity) then return nil,"Модель предпросмотра удалена." end
  local base
  for _,name in ipairs({"idle_all_01","idle_unarmed","idle01","idle","ragdoll"}) do
   if entity:LookupSequence(name)>=0 then base=name; break end
  end
  if not base then
   local current=player:GetSequenceName(player:GetSequence())
   if isstring(current) and entity:LookupSequence(current)>=0 then base=current end
  end
  if not base then return nil,"В модели персонажа нет доступной базовой анимации." end
  entity:SetPos(vector_origin); entity:SetAngles(angle_zero)
  entity:ResetSequence(entity:LookupSequence(base)); S.FreezeBase(entity,{cycle=0}); entity:SetupBones()
  local matrices={}
  for i=0,rig.count-1 do matrices[i]=entity:GetBoneMatrix(i) end
  return S.BuildStarterClip(preset,rig,matrices,base,model)
 end)
 attempts=attempts+1
 if callback and ok and retry and attempts<5 then timer.Simple(.05,sample); return end
 if IsValid(entity) then entity:Remove() end
 if not ok then ErrorNoHalt("[Pose Studio starters] "..tostring(clip).."\n"); clip=nil;err="Ошибка подготовки позы. Подробности в консоли." end
 if not clip then
  print("[Pose Studio starters] model="..model.." preset="..id.." attempts="..attempts.." error="..tostring(err))
 end
 if callback then callback(clip,err) end
 return clip,err
 end
 -- Give a fresh clientside model a frame before selecting/sampling a sequence.
 if callback then timer.Simple(0,sample); return end
 return sample()
end
