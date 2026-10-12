local S=ix.PoseStudio
S.sharedActors=S.sharedActors or setmetatable({},{__mode="k"})
local references={}
local donorReady=setmetatable({},{__mode="k"})
local referenceRevision=0
local function reference(clip,target)
 if clip.reference then
  local sample=S.DecodeReference(clip)
  if sample then return sample end
  return nil,"Некорректная сохранённая основа скелета."
 end
 if not IsValid(target) and CLIENT and LocalPlayer then target=LocalPlayer() end
 local donor=S.ReferenceEntity(clip,target)
 if not IsValid(donor) then return nil,"Нет совместимой модели для восстановления основы позы." end
 local model=donor:GetModel():lower()
 local base=clip.base
 if clip.portable and (donor:LookupSequence(base) or -1)<0 then base=S.TargetBase(donor,clip) end
 local recovered=model~=clip.model or base~=clip.base
 local key=clip.model..":"..model..":"..tostring(base)..":"..tostring(clip.cycle)
 local cached=references[key]
 if cached then cached.used=RealTime(); return cached end
 local R=ix.sharedPoses
 local rig=R and R.Rig(model)
 if not rig then return nil,"Не удалось прочитать совместимый скелет модели." end
 -- ResetSequence immediately after creating a client model can sample its
 -- reference pose instead of the saved base. Never cache that first-frame pose.
 if not donorReady[donor] then donorReady[donor]={time=RealTime()+.05,frame=FrameNumber()} end
 local ready=donorReady[donor]
 if FrameNumber()<=ready.frame or RealTime()<ready.time then return nil,"Подготовка исходной модели…",true end
 local sequence=base and donor:LookupSequence(base)
 if not sequence or sequence<0 then return nil,"В исходной модели нет основы «"..clip.base.."»." end
 donor:SetPos(vector_origin); donor:SetAngles(angle_zero); donor:ResetSequence(sequence)
 if donor.SetLOD then donor:SetLOD(0) end
 if donor.SetIK then donor:SetIK(false) end
 S.FreezeBase(donor,clip); donor:SetupBones()
 if donor.GetSequence and donor:GetSequence()~=sequence then return nil,"Основа «"..clip.base.."» ещё не готова.",true end
 local origin=Matrix()
 local sample={rig=rig,locals={},used=RealTime(),model=model,recovered=recovered}
 for i=0,rig.count-1 do
  local bone=rig.bones[i]
  local world=donor:GetBoneMatrix(i)
  local parent=origin
  if bone.parent>=0 then parent=donor:GetBoneMatrix(bone.parent) end
  local inverse=parent and parent:GetInverse()
  if world and inverse then sample.locals[bone.name]=inverse*world end
 end
 for name in pairs(S.humanoidBones) do
  local optional=name:find("Finger",1,true) or name:find("Toe",1,true)
  if not optional and rig.names[name]~=nil and not sample.locals[name] then
   return nil,"Нет матрицы исходной кости: "..name,true
  end
 end
 local count,oldest,age=0,nil,math.huge
 for id,value in pairs(references) do count=count+1; if value.used<age then oldest,age=id,value.used end end
 if count>=64 and oldest then references[oldest]=nil end
 references[key]=sample
 return sample
end
-- Editor tools share playback's sampled base and bounded reference cache.
function S.ToolReference(clip,target) return reference(clip,target) end
local function pack(matrix)
 local a,p=matrix:GetAngles(),matrix:GetTranslation()
 return {a={math.NormalizeAngle(a.p),math.NormalizeAngle(a.y),math.NormalizeAngle(a.r)},p={p.x,p.y,p.z}}
end
function S.CaptureReference(clip,target)
 if not S.Layered(clip) then return true end
 if clip.reference then return S.DecodeReference(clip)~=nil,"Некорректная сохранённая основа скелета." end
 local sample,reason,loading=reference(clip,target)
 if not sample then return false,reason,loading end
 local rig=sample.rig
 local snapshot={version=1,model=clip.model,rigModel=sample.model or clip.model,base=clip.base,cycle=clip.cycle,recovered=sample.recovered==true,bones={}}
 local indices={}
 for i=0,rig.count-1 do
  local bone=rig.bones[i]
  if S.humanoidBones[bone.name] then
   local parent=bone.parent
   local bind,base=bone.localBind,sample.locals[bone.name] or bone.localBind
   while parent>=0 and not indices[parent] do
    local ancestor=rig.bones[parent]
    bind=ancestor.localBind*bind;base=(sample.locals[ancestor.name] or ancestor.localBind)*base;parent=ancestor.parent
   end
   snapshot.bones[#snapshot.bones+1]={name=bone.name,parent=parent>=0 and indices[parent]-1 or -1,bind=pack(bind),base=pack(base)}
   indices[i]=#snapshot.bones
  end
 end
 snapshot=S.ValidateReference(snapshot,clip)
 if not snapshot then return false,"Основа позы выходит за безопасные пределы скелета." end
 local candidate=table.Copy(clip);candidate.reference=snapshot
 if not S.DecodeReference(candidate) then return false,"Не удалось сохранить совместимую основу скелета." end
 clip.reference=snapshot;clip.version=4
 return true,nil,false
end
function S.RetryReferences()
 references={}; donorReady=setmetatable({},{__mode="k"}); referenceRevision=referenceRevision+1
end
concommand.Add("ix_pose_retry",function()
 S.RetryReferences()
 print("[Pose Studio] Reference cache cleared; saved animations were not changed.")
end)
function S.PrepareLayer(entity,state)
 local clip=state.clip
 if not S.Layered(clip) then state.reference=nil; state.targetRig=nil; state.rigMap=nil; state.referenceError=nil; return true end
 local key=clip.model..":"..clip.base..":"..tostring(clip.cycle)..":"..entity:GetModel()..":"..referenceRevision..":"..tostring(clip.reference)
 if state.referenceKey==key and state.reference then return true end
 if state.referenceKey==key and (state.retryReference or 0)>RealTime() then return false end
 state.referenceKey=key; state.reference=nil; state.targetRig=nil; state.rigMap=nil; state.retryReference=RealTime()+.5
 local valid,err,_,target,mapping=S.ModelSupports(entity,clip)
 if not valid then state.referenceError=err; state.referenceLoading=false; return false end
 local sample,reason,loading=reference(clip,entity)
 if not sample then state.referenceError=reason; state.referenceLoading=loading; return false end
 state.reference=sample; state.targetRig=target; state.rigMap=mapping
 state.referenceError=nil; state.referenceLoading=false
 state.rigRatio=target.height/sample.rig.height
 return true
end
function S.ApplyLayer(entity,state)
 local reference,target,mapping=state.reference,state.targetRig,state.rigMap
 if not reference or not target or not mapping then return end
 local source=reference.rig
 local sourcePose={}
 for i=0,source.count-1 do
  local bone=source.bones[i]
  local localPose=reference.locals[bone.name] or bone.localBind
  local transform=state.transforms[bone.name]
  if transform then
   local delta=Matrix(); delta:SetTranslation(Vector(unpack(transform.p))); delta:SetAngles(Angle(unpack(transform.a)))
   localPose=localPose*delta
  end
  sourcePose[i]=bone.parent>=0 and sourcePose[bone.parent]*localPose or localPose
 end
 local original,changed,visited={},{},{}
 local count=math.min(entity:GetBoneCount(),256)
 for i=0,count-1 do original[i]=entity:GetBoneMatrix(i) end
 local origin=Matrix()
 origin:SetTranslation(entity:GetPos()); origin:SetAngles(entity:GetRenderAngles() or entity:GetAngles())
 local scale=entity:GetModelScale(); origin:SetScale(Vector(scale,scale,scale))
 local function apply(i)
  if i<0 or visited[i] then return end
  visited[i]=true
  local matrix=original[i]
  if not matrix then return end
  local parent=entity:GetBoneParent(i)
  if parent>=0 then apply(parent) end
  local name=entity:GetBoneName(i)
  local entry=mapping[name]
  local masked=entry and S.BoneAllowed(state.clip,name)
  local result=matrix
  if masked then
   local sourceParent=entry.sourceAncestor>=0 and sourcePose[entry.sourceAncestor] or Matrix()
   local inverse=sourceParent:GetInverse()
   local localPose=inverse and inverse*sourcePose[entry.source]
   local posed=localPose and S.RetargetLocal(entry.targetBind,entry.sourceBind,localPose,state.rigRatio)
   local ancestor=entry.ancestor
   local basis=ancestor>=0 and (changed[ancestor] or original[ancestor]) or origin
   if posed and basis then result=basis*posed; result:SetScale(matrix:GetScale()) end
  elseif original[parent] and changed[parent] then
   local inverse=original[parent]:GetInverse()
   if inverse then result=changed[parent]*inverse*matrix end
  end
  -- The pelvis/legs remain the engine's matrices in upper-body mode. Helpers
  -- under an affected arm/spine inherit its motion without being editable.
  if result~=matrix then changed[i]=result end
 end
 for i=0,count-1 do apply(i) end
 for i,matrix in pairs(changed) do entity:SetBoneMatrix(i,matrix) end
end

-- Built-in roleplay acts and user-authored clips use the same humanoid mapping.
-- Only registered acts are resolved server-side; this is not a locomotion hook.
function S.ClearSharedAct(entity)
 local state=S.sharedActors[entity]
 if state then
  S.Detach(entity,state); S.sharedActors[entity]=nil
  if IsValid(entity) then entity:SetPlaybackRate(1) end
 end
end
function S.ApplySharedAct(entity,pose)
 local key=pose.model..":"..pose.sequence..":"..tostring(pose.started or 0)
 local state=S.sharedActors[entity]
 if state and (state.key~=key or state.model~=entity:GetModel()) then S.ClearSharedAct(entity); state=nil end
 if not state then
  local clip={model=pose.model,base=pose.sequence,cycle=0,portable=true,mask="full",frames={{duration=1,bones={}}},props={}}
  state={key=key,model=entity:GetModel(),clip=clip,transforms={},started=pose.started or CurTime()}
  S.Attach(entity,state); S.sharedActors[entity]=state
 end
 local duration=math.max(tonumber(pose.duration) or 1,.1)
 local cycle=pose.animated and math.Clamp((CurTime()-state.started)/duration,0,1) or 0
 state.clip.cycle=math.floor(cycle*120)/120
 if not S.PrepareLayer(entity,state) then S.ClearSharedAct(entity); return false end
 S.FreezeBase(entity,{cycle=0})
 return true
end
hook.Add("EntityRemoved","ixPoseSharedActCleanup",S.ClearSharedAct)
hook.Add("ShutDown","ixPoseSharedActCleanup",function() for entity in pairs(S.sharedActors) do S.ClearSharedAct(entity) end end)

local legSequences={walk={"walk_all","walk_all_moderate","walk_unarmed_all","walk_all_01","walk"},
 run={"run_all","run_all_01","run_unarmed_all","run"},crouch={"crouchidle","crouch_idle","crouchidle_all"}}
function S.PreviewBase(entity,clip,state,elapsed,legs)
 local base=S.TargetBase(entity,clip)
 if not base then state.referenceError="Нет доступной основы для модели предпросмотра."; return false end
 local sequence=entity:LookupSequence(base)
 if clip.mask=="upper" then
  local R=ix.sharedPoses
  sequence=R and R.BaseSequence(entity) or sequence
  for _,name in ipairs(legSequences[legs] or {}) do
   local id=entity:LookupSequence(name)
   if id and id>=0 then sequence=id; break end
  end
 end
 if not sequence or sequence<0 then state.referenceError="В модели предпросмотра нет основы «"..base.."»."; return false end
 entity:SetSequence(sequence)
 S.FreezeBase(entity,clip)
 if clip.mask=="upper" then
  local moving=legs=="walk" or legs=="run"
  entity:SetCycle(moving and (elapsed%math.max(entity:SequenceDuration(sequence),.1))/math.max(entity:SequenceDuration(sequence),.1) or 0)
  entity:SetPoseParameter("move_x",moving and 1 or 0); entity:SetPoseParameter("move_y",0)
 end
 return S.PrepareLayer(entity,state)
end
