local A,K=ix.ActionAnimations,ix.LimbIK
A.actors=A.actors or {}
if A.Clear then for entity in pairs(A.actors) do A.Clear(entity) end end
local function rig(entity)
 local result={parents={},arms={}}
 for i=0,math.min(entity:GetBoneCount(),256)-1 do result.parents[i]=entity:GetBoneParent(i) end
 for _,side in ipairs({"L","R"}) do
  local chain={}
  for i,part in ipairs({"UpperArm","Forearm","Hand"}) do
   chain[i]=entity:LookupBone("ValveBiped.Bip01_"..side.."_"..part)
   if not chain[i] then return end
  end
  result.arms[side]=chain
 end
 result.head=entity:LookupBone("ValveBiped.Bip01_Head1")
 result.pelvis=entity:LookupBone("ValveBiped.Bip01_Pelvis")
 if result.head and result.pelvis then return result end
end
function A.Goals(entity,state,matrices)
 local r=state.rig;local head,pelvis=matrices[r.head],matrices[r.pelvis]
 if not head or not pelvis or not matrices[r.arms.L[1]] or not matrices[r.arms.R[1]] then return end
 local top,bottom=head:GetTranslation(),pelvis:GetTranslation()
 local chest=(matrices[r.arms.L[1]]:GetTranslation()+matrices[r.arms.R[1]]:GetTranslation())*.5
 local size=math.Clamp((top-bottom):Length()/30,.5,1.8)
 local angle=entity:GetRenderAngles();local forward,right,up=angle:Forward(),angle:Right(),angle:Up()
 local target=state.target;local mode=state.kind
 local phase=(CurTime()-entity:GetNW2Float("ixContextActionStarted",CurTime()))*4
 local wave=math.sin(phase)*size
 if mode=="drink" then return {R=top+forward*5*size-up*(4+math.sin(phase)*.6)*size},right,up end
 if mode=="carry" and IsValid(target) then
  local center=target:WorldSpaceCenter();local width=math.Clamp((target:OBBMaxs()-target:OBBMins()):Length()*.27,5,18)*size
  return {L=target:NearestPoint(center-right*width-forward*7*size),R=target:NearestPoint(center+right*width-forward*7*size)},right,up
 end
 local center=chest+forward*13*size-up*11*size
 if mode=="medical" and IsValid(target) and target~=entity then
  local offset=target:WorldSpaceCenter()-center
  if offset:Length()>20*size then offset=offset:GetNormalized()*20*size end
  center=center+offset

 end
 return {L=center-right*4*size+up*wave*.35,R=center+right*4*size+forward*wave+up*math.cos(phase)*size},right,up
end
function A.Build(entity,state)
 if A.Conflict(entity) or not A.WeaponAllows(entity,state.kind) then return end
 if state.model~=entity:GetModel() then return end
 if not state.rig then state.rig=rig(entity);if not state.rig then return end end
 local matrices={};for i in pairs(state.rig.parents) do matrices[i]=entity:GetBoneMatrix(i) end
 local goals,right,up=A.Goals(entity,state,matrices)
 if not goals then return end
 for _,side in ipairs({"L","R"}) do
  if goals[side] then
   local result=K.MoveChain(matrices,state.rig.parents,state.rig.arms[side],goals[side],right*(side=="L" and -1 or 1)-up*1.3,state.weight,false)
   if result then matrices=result end
  end
 end
 -- Upper-arm subtrees only. No pelvis/spine/leg writes, sequence changes,
 -- movement locks, hitbox changes or permanent ManipulateBone* calls.
 for i,matrix in pairs(matrices) do
  if (goals.L and K.Descendant(state.rig.parents,i,state.rig.arms.L[1])) or (goals.R and K.Descendant(state.rig.parents,i,state.rig.arms.R[1])) then entity:SetBoneMatrix(i,matrix) end
 end
end
function A.Clear(entity)
 local state=A.actors[entity]
 if not state then return end
 if IsValid(entity) and state.callback then entity:RemoveCallback("BuildBonePositions",state.callback);entity:InvalidateBoneCache() end
 if IsValid(state.prop) then state.prop:Remove() end
 A.actors[entity]=nil
end
local nextActorDiscovery=0
hook.Add("Think","ixContextActionActors",function()
 local viewer=LocalPlayer();if not IsValid(viewer) then return end
 local candidates={[viewer]=true}
 for entity in pairs(A.actors) do candidates[entity]=true end
 if RealTime()>=nextActorDiscovery then
  nextActorDiscovery=RealTime()+.1
  for _,entity in ipairs(player.GetAll()) do
   if entity:GetNW2String("ixContextAction","")~="" then candidates[entity]=true end
  end
 end
 for entity in pairs(candidates) do
  if not IsValid(entity) then A.Clear(entity) continue end
  local kind=entity:GetNW2String("ixContextAction","")
  local target=entity:GetNW2Entity("ixContextActionTarget")
  local visible=not entity:IsDormant() and entity:GetPos():DistToSqr(viewer:GetPos())<1500^2
  local active=(kind=="medical" or kind=="carry" or kind=="drink") and visible and not A.Conflict(entity) and A.WeaponAllows(entity,kind)
  local state=A.actors[entity]
  local fading=state and kind=="" and visible and not A.Conflict(entity) and A.WeaponAllows(entity,state.kind)
  if state and ((not active and not fading) or (kind~="" and state.kind~=kind) or state.model~=entity:GetModel()) then A.Clear(entity);state=nil end
  if active then
   if not state then
    state={kind=kind,model=entity:GetModel(),weight=0};A.actors[entity]=state
    state.callback=entity:AddCallback("BuildBonePositions",function(ent)
     if state.building then return end
     state.building=true
     local ok,err=xpcall(function() A.Build(ent,state) end,debug.traceback)
     state.building=false
     if not ok and not state.reported then state.reported=true;ErrorNoHalt("[Contextual animations] "..err.."\n") end
    end)
   end
   state.target=target
   state.weight=math.Approach(state.weight,1,FrameTime()*5);entity:InvalidateBoneCache()
  elseif fading then
   state.weight=math.Approach(state.weight,0,FrameTime()*6);entity:InvalidateBoneCache()
   if state.weight<=0 then A.Clear(entity) end
  end
 end
end)
hook.Add("EntityRemoved","ixContextActionCleanup",A.Clear)
hook.Add("ShutDown","ixContextActionCleanup",function() for entity in pairs(A.actors) do A.Clear(entity) end end)
function A.Unload()
 for entity in pairs(A.actors) do A.Clear(entity) end
 hook.Remove("Think","ixContextActionActors")
 hook.Remove("EntityRemoved","ixContextActionCleanup");hook.Remove("ShutDown","ixContextActionCleanup")
end
