local S = ix.PoseStudio
S.playing = S.playing or {}

function S.FreezeBase(entity,clip)
 entity:SetCycle(clip.cycle); entity:SetPlaybackRate(0)
 -- Both preview and world use the same neutral blend parameters. Otherwise
 -- the player's aim/head tracking changes the base underneath an edited pose.
 for i=0,entity:GetNumPoseParameters()-1 do
  local low,high=entity:GetPoseParameterRange(i)
  entity:SetPoseParameter(entity:GetPoseParameterName(i),math.Clamp(0,low,high))
 end
 entity:InvalidateBoneCache()
end

function S.Request(data)
 local text=util.TableToJSON(data)
 if not text or #text>49900 then
  notification.AddLegacy("Анимация слишком большая. Уменьшите число изменённых костей или кадров.",NOTIFY_ERROR,5)
  return false
 end
 net.Start("ixPoseStudioRequest"); net.WriteUInt(#text,16); net.WriteData(text,#text); net.SendToServer()
 return true
end

-- Modify matrices only during this entity's bone build. Never reset permanent
-- bone manipulations: amputation and other character systems own those values.
function S.ApplyBones(entity, transforms)
 local count=math.min(entity:GetBoneCount(),256)
 local original, changed, visited={},{},{}
 for i=0,count-1 do original[i]=entity:GetBoneMatrix(i) end
 local function apply(i)
  if i<0 or visited[i] then return end
  visited[i]=true
  local matrix=original[i]
  if not matrix then return end
  local parent=entity:GetBoneParent(i)
  if parent>=0 then apply(parent) end
  local transform=transforms[entity:GetBoneName(i)]
  local result=matrix
  if original[parent] and changed[parent] then
   local inverse=original[parent]:GetInverse()
   if inverse then result=changed[parent]*inverse*matrix end
  end
  if transform then
   local delta=Matrix()
   delta:SetTranslation(Vector(unpack(transform.p)))
   delta:SetAngles(Angle(unpack(transform.a)))
   result=result*delta
  end
  changed[i]=result
 end
 for i=0,count-1 do apply(i) end
 for i,matrix in pairs(changed) do entity:SetBoneMatrix(i,matrix) end
end
function S.Attach(entity,state)
 state.props={}
 state.callback=entity:AddCallback("BuildBonePositions",function(ent)
  if not state.building and state.transforms then
   state.building=true
   local ok,err=xpcall(function()
    if S.Layered(state.clip) then S.ApplyLayer(ent,state) else S.ApplyBones(ent,state.transforms) end
   end,debug.traceback)
   state.building=false
   if not ok and not state.reported then state.reported=true; ErrorNoHalt("[Pose Studio] "..err.."\n") end
  end
 end)
end
function S.ClearProps(state)
 for _,prop in pairs(state.props or {}) do if IsValid(prop) then prop:Remove() end end
 state.props={}
end
function S.Detach(entity,state)
 if IsValid(entity) then
  if state.callback then entity:RemoveCallback("BuildBonePositions",state.callback) end
  entity:InvalidateBoneCache()
 end
 S.ClearProps(state)
end
function S.DrawProps(entity,state)
 for i,spec in ipairs(state.clip.props) do
  local prop=state.props[i]
  if not IsValid(prop) or prop:GetModel()~=spec.model then
   if IsValid(prop) then prop:Remove() end
   if util.IsValidModel(spec.model) then
    prop=ClientsideModel(spec.model,RENDERGROUP_OPAQUE)
    if IsValid(prop) then prop:SetNoDraw(true); state.props[i]=prop end
   end
  end
  local bone=entity:LookupBone(spec.bone)
  local matrix=bone and entity:GetBoneMatrix(bone)
  if IsValid(prop) and matrix then
   local ratio=state.clip.portable and (state.rigRatio or 1) or 1
   local position,angles=LocalToWorld(Vector(unpack(spec.p))*ratio,Angle(unpack(spec.a)),matrix:GetTranslation(),matrix:GetAngles())
   prop:SetPos(position); prop:SetAngles(angles); prop:SetSkin(spec.skin); prop:SetModelScale(spec.scale*ratio,0)
   prop:SetupBones(); prop:DrawModel()
  end
 end
 for i,prop in pairs(state.props) do
  if not state.clip.props[i] then if IsValid(prop) then prop:Remove() end; state.props[i]=nil end
 end
end
local function stop(entity)
 local state=S.playing[entity]
 if state then
  S.Detach(entity,state)
  if IsValid(entity) and state.clip.mask~="upper" then entity:SetPlaybackRate(1) end
  S.playing[entity]=nil
 end
end
net.Receive("ixPoseStudioState",function()
 local entity=net.ReadEntity()
 local size=net.ReadUInt(16)
 if size>60000 then return end
 local data=util.JSONToTable(net.ReadData(size) or "")
 if not IsValid(entity) or not istable(data) then return end
 if S.playing[entity] and S.playing[entity].token==data.token then return end
 stop(entity)
 local clip=S.Validate(data.clip)
 if not clip or not S.Finite(data.started,0,1e12) or (not clip.portable and entity:GetModel():lower()~=clip.model)
  or (data.model and entity:GetModel()~=data.model) then return end
 local state={clip=clip,token=data.token,started=data.started,model=entity:GetModel()}
 S.Attach(entity,state); S.playing[entity]=state
end)
hook.Add("Think","ixPoseStudioPlayback",function()
 for entity,state in pairs(S.playing) do
  if not IsValid(entity) or not entity:Alive() or entity:GetModel()~=state.model then stop(entity)
  elseif not entity:IsDormant() then
   state.transforms=S.Sample(state.clip,CurTime()-state.started)
   S.PrepareLayer(entity,state)
   entity:InvalidateBoneCache()
  end
 end
end)
hook.Add("PrePlayerDraw","ixPoseStudioFreeze",function(entity)
 local state=S.playing[entity]
 if state then
  S.PrepareLayer(entity,state)
  if state.clip.mask~="upper" then S.FreezeBase(entity,state.clip) end
 end
end)
hook.Add("PostPlayerDraw","ixPoseStudioProps",function(entity)
 local state=S.playing[entity]
 if state then S.DrawProps(entity,state) end
end)
hook.Add("EntityRemoved","ixPoseStudioCleanup",stop)
hook.Add("ShutDown","ixPoseStudioCleanup",function() for entity in pairs(S.playing) do stop(entity) end end)
hook.Add("InitPostEntity","ixPoseStudioSync",function() S.Request({op="sync"}) end)
hook.Add("CreatePersonalRadialOptions","ixPoseStudioRadial",function(options)
 options[#options+1]={label="Позы и анимации",detail="Редактор / библиотека / остановка",children={
  {label="Меню анимаций",callback=function() RunConsoleCommand("ix_animation_menu") end},
  {label="Редактор и библиотека",callback=function() ix.command.Send("PoseEditor") end},
  {label="Остановить анимацию",callback=function() S.Request({op="stop"}) end}
 }}
end)
concommand.Add("ix_pose_editor",function() ix.command.Send("PoseEditor") end)
concommand.Add("ix_pose_stop",function() S.Request({op="stop"}) end)
