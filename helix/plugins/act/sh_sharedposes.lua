-- Static RP pose retargeting. Native sequences always take precedence.
-- Only pose identity is networked; visual bones are rebuilt on each client.
ix.sharedPoses=ix.sharedPoses or {}
local R=ix.sharedPoses
local rigs,probes,missingRigs,capabilities={},{},{},{}
local required={"Pelvis","Spine","Spine1","Spine2","Neck1","Head1",
 "L_UpperArm","L_Forearm","L_Hand","R_UpperArm","R_Forearm","R_Hand",
 "L_Thigh","L_Calf","L_Foot","R_Thigh","R_Calf","R_Foot"}
local prefix="ValveBiped.Bip01_"
local providers={"models/cellar/characters/oldcitizens/male_01.mdl",
 "models/cellar/characters/oldcitizens/female_01.mdl",
 "models/Humans/Group01/male_07.mdl","models/Humans/Group01/female_01.mdl","models/police.mdl","models/player/kleiner.mdl"}
R.providers=providers
ix.Net:AddPlayerVar("sharedPose",false,nil,ix.Net.Type.Table)

function R.Allowed(name)
 if not isstring(name) or #name>96 then return false end
 if name:match("^stances_sit0[1-9]$") or name=="stances_sitground" or name=="stances_sitwall" or
  name=="stances_check" or name:match("^stances_lean0[12]$") or
  name:match("^stances_down0[123]$") or name=="stances_arrest" or name:match("^stances_stand0[123]$") or
  name=="sit_zen" or name=="sit_passive" or name=="sit_fist" then return true end
 for _,classes in pairs(ix.act.stored or {}) do
  for _,data in pairs(classes) do
   if istable(data) and data.untimed then
    for _,pose in ipairs(data.sequence or {}) do
     if (istable(pose) and pose[1] or pose)==name then return true end
    end
   end
  end
 end
 return false
end

-- Read the compiled bind skeleton, not a guessed T-pose or model filename map.
-- poseToBone is the inverse bind matrix in Source MDL v48/49 (216-byte bones).
function R.Rig(model)
 model=string.lower(model or "")
 if rigs[model] then return rigs[model] end
 if missingRigs[model] and missingRigs[model]>CurTime() then return end
 missingRigs[model]=CurTime()+5
 local f=file.Open(model,"rb","GAME")
 if not f then return end
 local ok,result=pcall(function()
  local size=f:Size()
  if size<408 or f:Read(4)~="IDST" then return end
  local version=f:ReadLong()
  if version~=48 and version~=49 then return end
  f:Seek(156); local count,offset=f:ReadLong(),f:ReadLong()
  if count<1 or count>256 or offset<0 or offset+count*216>size then return end
  local rig={bones={},names={},count=count}
  for i=0,count-1 do
   local base=offset+i*216; f:Seek(base)
   local nameOffset,parent=f:ReadLong(),f:ReadLong()
   if nameOffset<0 or base+nameOffset>=size or parent>=i or parent < -1 then return end
   f:Seek(base+nameOffset); local name=""
   for _=1,128 do
    local c=f:Read(1); if not c or c=="" or c=="\0" then break end; name=name..c
   end
   if name=="" or rig.names[name]~=nil then return end
   f:Seek(base+96); local inverse=Matrix()
   for row=1,3 do for col=1,4 do
    local value=f:ReadFloat()
    if not value or value~=value or math.abs(value)>100000 then return end
    inverse:SetField(row,col,value)
   end end
   local bind=inverse:GetInverse(); if not bind then return end
   local localBind=parent>=0 and rig.bones[parent].inverse*bind or bind
   rig.bones[i]={name=name,parent=parent,bind=bind,inverse=inverse,localBind=localBind}
   rig.names[name]=i
  end
  for _,name in ipairs(required) do if rig.names[prefix..name]==nil then return end end
  rig.height=(rig.bones[rig.names[prefix.."Head1"]].bind:GetTranslation()-rig.bones[rig.names[prefix.."Pelvis"]].bind:GetTranslation()):Length()
  if rig.height<8 or rig.height>80 then return end
  return rig
 end)
 f:Close()
 if ok and result then rigs[model]=result; missingRigs[model]=nil; return result end
end

function R.Compatible(target,source)
 if not target or not source then return false end
 local ratio=target.height/source.height
 if ratio<0.55 or ratio>1.8 then return false end
 for _,name in ipairs(required) do
  name=prefix..name
  local a,b=target.bones[target.names[name]],source.bones[source.names[name]]
  if not a or not b then return false end
  local ap=a.parent>=0 and target.bones[a.parent].name or ""
  local bp=b.parent>=0 and source.bones[b.parent].name or ""
  if ap~=bp then return false end
 end
 return true
end

function R.Probe(model)
 if IsValid(probes[model]) then return probes[model] end
 if not util.IsValidModel(model) then return end
 local entity
 if CLIENT then entity=ClientsideModel(model,RENDERGROUP_OTHER)
 else
  entity=ents.Create("prop_dynamic")
  if IsValid(entity) then entity:SetModel(model); entity:SetPos(vector_origin); entity:Spawn(); entity:SetSolid(SOLID_NONE); entity:SetMoveType(MOVETYPE_NONE) end
 end
 if not IsValid(entity) then return end
 entity:SetNoDraw(true); entity:SetPos(vector_origin); entity:SetAngles(angle_zero)
 entity:SetPlaybackRate(0); if entity.SetIK then entity:SetIK(false) end
 probes[model]=entity
 return entity
end

function R.BaseSequence(entity)
 for _,name in ipairs({"idle_all_01","idle_unarmed","idle","reference","ragdoll"}) do
  local id=entity:LookupSequence(name); if id and id>=0 then return id end
 end
 if entity:GetSequenceCount()>0 then return 0 end
end

function R.Resolve(entity,name)
 if not IsValid(entity) or not R.Allowed(name) then return end
 local key=entity:GetModel()..":"..name
 local cached=capabilities[key]
 if cached and cached.expires>CurTime() then return cached.pose end
 capabilities[key]={expires=CurTime()+5}
 local target=R.Rig(entity:GetModel()); if not target then return end
 local base=R.BaseSequence(entity); if base==nil then return end
 for _,model in ipairs(providers) do
  local source=R.Rig(model)
  if R.Compatible(target,source) then
   local donor=R.Probe(model)
   local id=IsValid(donor) and donor:LookupSequence(name)
   if id and id>=0 then
    local pose={model=model,sequence=name,target=entity:GetModel(),base=base,cycle=0}
    capabilities[key]={pose=pose,expires=CurTime()+60}
    return pose
   end
  end
 end
end

if SERVER then
 function R.Begin(entity,pose)
  entity:SetNetVar("sharedPose",pose)
 end
 function R.Clear(entity) entity:SetNetVar("sharedPose",nil) end
 hook.Add("PlayerDeath","SharedPoseCleanup",R.Clear)
 hook.Add("PrePlayerLoadedCharacter","SharedPoseCleanup",R.Clear)
end

hook.Add("ShutDown","SharedPoseProbes",function()
 for _,entity in pairs(probes) do if IsValid(entity) then entity:Remove() end end
end)

concommand.Add("ix_pose_info",function(client)
 local entity=CLIENT and LocalPlayer() or client
 if not IsValid(entity) then return end
 local helper=ix.plugin.Get("sithelper")
 if not helper then return end
 local native,shared,missing=0,0,0
 for option=1,24 do
  local name,_,pose=helper:ResolvePose(entity,option)
  if not name then missing=missing+1 elseif pose then shared=shared+1 else native=native+1 end
 end
 local text=string.format("[Shared poses] %s | native: %d | shared: %d | unavailable: %d",entity:GetModel(),native,shared,missing)
 if CLIENT then print(text) else entity:PrintMessage(HUD_PRINTCONSOLE,text) end
end)

if not CLIENT then return end
local active=setmetatable({},{__mode="k"})
local samples={}
local function Sample(pose)
 local key=pose.model..":"..pose.sequence
 if samples[key] then return samples[key] end
 local rig=R.Rig(pose.model); local donor=R.Probe(pose.model)
 if not rig or not IsValid(donor) then return end
 local id=donor:LookupSequence(pose.sequence); if not id or id<0 then return end
 donor:ResetSequence(id); donor:SetCycle(0); donor:SetPlaybackRate(0)
 donor:InvalidateBoneCache(); donor:SetupBones()
 local sample={rig=rig,localPose={}}
 for i=0,rig.count-1 do
  local bone=rig.bones[i]
  local world=donor:GetBoneMatrix(i)
  local parent=bone.parent>=0 and donor:GetBoneMatrix(bone.parent)
  if world and (bone.parent<0 or parent) then
   sample.localPose[i]=parent and parent:GetInverse()*world or world
  end
 end
 for _,name in ipairs(required) do if not sample.localPose[rig.names[prefix..name]] then return end end
 samples[key]=sample
 return sample
end

-- Preserve target limb lengths. Transfer local rotation relative to the bind
-- skeleton; only pelvis displacement is scaled to the target's proportions.
function R.RetargetLocal(targetBone,sourceBone,sourcePose,scale)
 local delta=sourceBone.localBind:GetInverse()*sourcePose
 delta:SetTranslation(vector_origin)
 local result=targetBone.localBind*delta
 local position=targetBone.localBind:GetTranslation()
 if targetBone.name==prefix.."Pelvis" then
  position=position+(sourcePose:GetTranslation()-sourceBone.localBind:GetTranslation())*scale
 end
 result:SetTranslation(position)
 return result
end

function R.Apply(entity,pose)
 if not IsValid(entity) or entity:GetModel()~=pose.target then R.Clear(entity); return false end
 local target=R.Rig(entity:GetModel()); local sample=Sample(pose)
 if not sample or not R.Compatible(target,sample.rig) then R.Clear(entity); return false end
 local source=sample.rig
 local state=active[entity]
 if not state then
  state={}; active[entity]=state
  state.callback=entity:AddCallback("BuildBonePositions",function(ent)
   local s=active[ent]
   if not s or s.model~=ent:GetModel() or s.building then return end
   s.building=true
   local ok,err=xpcall(function()
    local original,posed={},{}
    for i=0,s.target.count-1 do original[i]=ent:GetBoneMatrix(i) end
    local origin=Matrix(); origin:SetTranslation(ent:GetPos()); origin:SetAngles(ent:GetRenderAngles() or ent:GetAngles())
    local modelScale=ent:GetModelScale(); origin:SetScale(Vector(modelScale,modelScale,modelScale))
    for i=0,s.target.count-1 do
     local bone=s.target.bones[i]; local matrix=original[i]
     if matrix then
      local localPose=s.locals[i]
      if not localPose then
       local parent=bone.parent>=0 and original[bone.parent] or origin
       if parent then localPose=parent:GetInverse()*matrix end
      end
      local parent=bone.parent>=0 and posed[bone.parent] or origin
      if localPose and parent then
       local result=parent*localPose
       result:SetScale(matrix:GetScale())
       posed[i]=result
       if ent:GetBoneName(i)~="__INVALIDBONE__" then ent:SetBoneMatrix(i,result) end
      else posed[i]=matrix end
     end
    end
   end,debug.traceback)
   s.building=false
   if not ok and not s.error then s.error=true; ErrorNoHalt("Shared pose: "..err.."\n") end
  end)
 end
 if state.model~=pose.target or state.key~=pose.model..":"..pose.sequence then
  state.locals={}; state.model=pose.target; state.key=pose.model..":"..pose.sequence; state.target=target
  for i=0,target.count-1 do
   local bone=target.bones[i]; local donorID=source.names[bone.name]
   if donorID and sample.localPose[donorID] and bone.name:sub(1,#prefix)==prefix then
    state.locals[i]=R.RetargetLocal(bone,source.bones[donorID],sample.localPose[donorID],target.height/source.height)
   end
  end
 end
 entity:InvalidateBoneCache()
 return true
end

function R.Clear(entity)
 local state=active[entity]
 if state and IsValid(entity) then
  if state.callback then entity:RemoveCallback("BuildBonePositions",state.callback) end
  entity:InvalidateBoneCache()
 end
 active[entity]=nil
end
hook.Add("Think","SharedRoleplayPoses",function()
 for _,entity in ipairs(player.GetAll()) do
  local pose=entity:GetNetVar("sharedPose")
  if istable(pose) and entity:Alive() and entity:GetModel()==pose.target then
   if not R.Apply(entity,pose) and active[entity] then R.Clear(entity) end
  elseif active[entity] then R.Clear(entity) end
 end
end)
hook.Add("EntityRemoved","SharedPoseCleanup",function(entity) active[entity]=nil end)
