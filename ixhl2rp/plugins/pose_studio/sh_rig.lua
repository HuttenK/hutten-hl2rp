local S=ix.PoseStudio
local core={}
for _,name in ipairs({"Pelvis","Spine","Spine1","Spine2","Neck1","Head1","L_UpperArm","L_Forearm","L_Hand",
 "R_UpperArm","R_Forearm","R_Hand","L_Thigh","L_Calf","L_Foot","R_Thigh","R_Calf","R_Foot"}) do core["ValveBiped.Bip01_"..name]=true end
local maps=setmetatable({},{__mode="k"})
local decoded=setmetatable({},{__mode="k"})
local function matrix(value)
 local out=Matrix();out:SetAngles(Angle(unpack(value.a)));out:SetTranslation(Vector(unpack(value.p)));return out
end
function S.DecodeReference(clip)
 local stored=clip.reference
 if not istable(stored) then return end
 if stored.model~=clip.model or stored.base~=clip.base or stored.cycle~=clip.cycle then return end
 if decoded[stored] then return decoded[stored] end
 local clean=S.ValidateReference(stored,clip)
 if not clean then return end
 local rig={count=#clean.bones,bones={},names={}}
 local sample={rig=rig,locals={},recovered=clean.recovered,model=clean.rigModel}
 for n,row in ipairs(clean.bones) do
  local i=n-1;local localBind=matrix(row.bind)
  local bind=row.parent>=0 and rig.bones[row.parent].bind*localBind or localBind
  local position=bind:GetTranslation()
  if position:Length()>256 then return end
  rig.bones[i]={name=row.name,parent=row.parent,localBind=localBind,bind=bind,inverse=bind:GetInverse()}
  rig.names[row.name]=i;sample.locals[row.name]=matrix(row.base)
 end
 for name in pairs(core) do if rig.names[name]==nil then return end end
 rig.height=(rig.bones[rig.names["ValveBiped.Bip01_Head1"]].bind:GetTranslation()-rig.bones[rig.names["ValveBiped.Bip01_Pelvis"]].bind:GetTranslation()):Length()
 if not S.Finite(rig.height,8,128) then return end
 decoded[stored]=sample
 return sample
end
local function coreParent(rig,index)
 local parent=rig.bones[index].parent
 while parent>=0 do
  local bone=rig.bones[parent]
  if core[bone.name] then return bone.name end
  parent=bone.parent
 end
 return ""
end
local function relativeBind(rig,index,ancestor)
 local result=Matrix()
 while index~=ancestor and index>=0 do
  local bone=rig.bones[index]; result=bone.localBind*result; index=bone.parent
 end
 return {localBind=result}
end
-- Match anatomy, not model paths, total bone counts or immediate helper parents.
-- Extra spine/twist bones collapse into the nearest shared ancestor transform.
function S.RigMap(target,source)
 if not target or not source or target.height/source.height<.55 or target.height/source.height>1.8 then return end
 if maps[target] and maps[target][source] then return maps[target][source] end
 for name in pairs(core) do
  local a,b=target.names[name],source.names[name]
  if a==nil or b==nil or coreParent(target,a)~=coreParent(source,b) then return end
 end
 local common={}
 for name in pairs(S.humanoidBones) do
  local a,b=target.names[name],source.names[name]
  if a~=nil and b~=nil and coreParent(target,a)==coreParent(source,b) then common[name]=true end
 end
 local result={}
 for name in pairs(common) do
  local a,b=target.names[name],source.names[name]
  local ancestors={}; local parent=target.bones[a].parent
  while parent>=0 do ancestors[target.bones[parent].name]=parent; parent=target.bones[parent].parent end
  local sa,ta=source.bones[b].parent,-1
  while sa>=0 do
   local parentName=source.bones[sa].name
   if common[parentName] and ancestors[parentName]~=nil then ta=ancestors[parentName]; break end
   sa=source.bones[sa].parent
  end
  result[name]={source=b,target=a,sourceAncestor=sa,ancestor=ta,
   sourceBind=relativeBind(source,b,sa),targetBind=relativeBind(target,a,ta)}
 end
 maps[target]=maps[target] or setmetatable({},{__mode="k"}); maps[target][source]=result
 return result
end
function S.Layered(clip) return clip.portable==true or clip.mask=="upper" end
function S.EditableBone(clip,name)
 -- Apply the Cellar body/finger set in every editor mode. Keep BoneAllowed
 -- separate so loading/resaving a legacy model-only clip preserves hidden keys.
 if not S.humanoidBones[name] or not S.BoneAllowed(clip,name) then return false end
 if not S.Layered(clip) then return true end
 local sample=S.DecodeReference(clip)
 local rig=sample and sample.rig or ix.sharedPoses and ix.sharedPoses.Rig(clip.model)
 if not rig and CLIENT and LocalPlayer and IsValid(LocalPlayer()) then rig=ix.sharedPoses and ix.sharedPoses.Rig(LocalPlayer():GetModel():lower()) end
 return rig and rig.names[name]~=nil or false
end
function S.ReferenceEntity(clip,fallback)
 local R=ix.sharedPoses
 local entity=R and R.Probe(clip.model)
 if IsValid(entity) and (not clip.portable or (entity:LookupSequence(clip.base) or -1)>=0 and R.Rig(clip.model)) then return entity end
 if not IsValid(fallback) and CLIENT and LocalPlayer then fallback=LocalPlayer() end
 return IsValid(fallback) and R and R.Probe(fallback:GetModel():lower()) or nil
end
function S.TargetBase(entity,clip)
 if entity:GetModel():lower()==clip.model and (entity:LookupSequence(clip.base) or -1)>=0 then return clip.base end
 if not clip.portable or not ix.sharedPoses then return end
 local id=ix.sharedPoses.BaseSequence(entity)
 return id and entity:GetSequenceName(id)
end
function S.ModelSupports(entity,clip)
 local targetModel=entity:GetModel():lower()
 if targetModel~=clip.model and not clip.portable then return false,"Эта анимация создана для другой модели." end
 local source,target,mapping
 if S.Layered(clip) then
  local R=ix.sharedPoses
  local sample=S.DecodeReference(clip)
  if clip.reference and not sample then return false,"Некорректная сохранённая основа скелета." end
  target=R and R.Rig(targetModel)
  if sample then source=sample.rig
  else
   local donor=S.ReferenceEntity(clip,entity)
   source=IsValid(donor) and R and R.Rig(donor:GetModel():lower()) or target
  end
  mapping=S.RigMap(target,source)
  if not mapping then
   return false,"Нужен совместимый гуманоидный скелет ValveBiped."
  end
  -- Missing optional fingers/toes do not disable a whole body animation.
  -- An attachment still needs its exact anchor; silently moving props is unsafe.
  for _,frame in ipairs(clip.frames) do
   for name in pairs(frame.bones) do
    if not S.BoneAllowed(clip,name) or source.names[name]==nil and core[name] then return false,"Несовместимая исходная кость: "..name end
   end
  end
  for _,prop in ipairs(clip.props) do if not S.BoneAllowed(clip,prop.bone) or not mapping[prop.bone] then return false,"Несовместимая кость реквизита." end end
 end
 if not clip.reference then
  local reference=targetModel==clip.model and entity or S.ReferenceEntity(clip,entity)
  if IsValid(reference) and reference:GetModel():lower()==clip.model then
   local referenceSequence=reference:LookupSequence(clip.base)
   if (not referenceSequence or referenceSequence<0) and not clip.portable then return false,"Базовая анимация отсутствует в исходной модели." end
  elseif not clip.portable then return false,"Базовая анимация отсутствует в исходной модели." end
 end
 local base=S.TargetBase(entity,clip)
 local targetSequence=base and entity:LookupSequence(base)
 if not targetSequence or targetSequence<0 then return false,"Базовая анимация недоступна." end
 for _,frame in ipairs(clip.frames) do
   for name in pairs(frame.bones) do
    if entity:LookupBone(name)==nil and (not S.Layered(clip) or core[name]) then return false,"Кость отсутствует: "..name end
   end
 end
 return true,nil,source,target,mapping
end

-- Older saves inherited portable=false from the editor's original default.
-- Upgrade only when every authored key/prop survives validation unchanged and
-- anatomy is portable. Version 3 preserves later deliberate model-only choices.
-- This upgrades only the in-memory row; loading never rewrites saved data.
function S.MigrateLegacyClip(raw)
 local clip,err=S.Validate(raw)
 if not clip then return nil,false,err end
 if (tonumber(raw.version) or 1)>=3 or clip.portable then return clip,false end
 local candidate=table.Copy(clip); candidate.portable=true
 candidate=S.Validate(candidate)
 if not candidate then return clip,false end
 local source=S.ReferenceEntity(candidate)
 if not IsValid(source) or S.ModelSupports(source,candidate) then return candidate,true end
 -- A mounted nonhumanoid source keeps its explicit legacy mode.
 clip.version=2
 return clip,false
end

-- ValveBiped clips already contain joint rotations in the shared parent's
-- animation axes (including collapsed helper chains). The skin reference pose
-- is NOT an axis calibration: one model may bind with bent elbows, another
-- with straight elbows. targetBind * inverse(sourceBind) would inject that
-- reference bend into every finished pose. Copy the sampled rotation intact;
-- use bind positions only for target proportions and scaled authored offsets.
function S.RetargetLocal(target,source,pose,ratio)
 local result=pose*Matrix()
 result:SetTranslation(target.localBind:GetTranslation()+(pose:GetTranslation()-source.localBind:GetTranslation())*ratio)
 return result
end
