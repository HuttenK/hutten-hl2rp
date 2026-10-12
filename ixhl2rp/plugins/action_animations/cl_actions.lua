local A,K=ix.ActionAnimations,ix.LimbIK
A.actors=A.actors or {}
if A.Clear then for entity in pairs(A.actors) do A.Clear(entity) end end
local function waterKind(kind,source)
 return kind=="waterdrink" or kind=="waterfill" or (kind=="wash" and source~="" and source~=nil)
end
local function ease(t) t=math.Clamp(t,0,1);return t*t*(3-2*t) end
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
 if mode=="radio" then return {L=top-right*5*size-forward*size-up*2*size},right,up end
 if mode=="bodycam" then
  -- The camera accessory sits at the right side of the wearer's head.
  -- Existing arm-only IK blends the reach in/out without replacing walking.
  return {R=top+right*5*size+up*3*size+forward*size},right,up
 end
 if mode=="drink" then return {R=top+forward*5*size-up*(4+math.sin(phase)*.6)*size},right,up end
 if waterKind(mode,state.source) and IsValid(target) and state.anchor then
  local point=target:LocalToWorld(state.anchor)
  local offset=point-chest
  -- IK handles differences in arm length; cap pathological distant props.
  point=chest+offset:GetNormalized()*math.min(offset:Length(),70*size)
  if mode=="waterdrink" then
   local started=entity:GetNW2Float("ixContextActionStarted",CurTime())
   local finish=entity:GetNW2Float("ixContextActionFinish",started+2)
   local t=math.Clamp((CurTime()-started)/math.max(.1,finish-started),0,1)
   local mouth=top+forward*5*size-up*4*size
   local lift=ease((t-.18)/.38)
   if t>.82 then lift=1-ease((t-.82)/.18)*.4 end
   return {R=point+(mouth-point)*lift,L=point-right*4*size},right,up
  elseif mode=="waterfill" then
   local center=point-up*3*size
   return {L=center-right*4*size,R=center+right*3*size+forward*size},right,up
  else
   return {L=point-right*2*size+up*wave*.35,R=point+right*2*size+forward*wave*.6},right,up
  end
 end
 if mode=="carry" and IsValid(target) then
  local center=target:WorldSpaceCenter();local width=math.Clamp((target:OBBMaxs()-target:OBBMins()):Length()*.27,5,18)*size
  return {L=target:NearestPoint(center-right*width-forward*7*size),R=target:NearestPoint(center+right*width-forward*7*size)},right,up
 end
 local center=chest+forward*13*size-up*11*size
 if mode=="medical" and IsValid(target) and target~=entity then
  local offset=target:WorldSpaceCenter()-center
  if offset:Length()>20*size then offset=offset:GetNormalized()*20*size end
  center=center+offset
 elseif mode=="operate" and IsValid(target) then
  local point=target:NearestPoint(chest+forward*18*size);local offset=point-chest
  center=chest+offset:GetNormalized()*math.min(offset:Length(),21*size)
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
hook.Add("Think","ixContextActionActors",function()
 local viewer=LocalPlayer();if not IsValid(viewer) then return end
 for _,entity in ipairs(player.GetAll()) do
  local kind=entity:GetNW2String("ixContextAction","")
  local source=entity:GetNW2String("ixContextActionSource","")
  local water=waterKind(kind,source)
  local target=entity:GetNW2Entity("ixContextActionTarget")
  local waterValid=not water or (entity:GetNW2Float("ixContextActionFinish",0)>CurTime() and IsValid(target)
   and not (target.IsDormant and target:IsDormant()))
  local visible=not entity:IsDormant() and entity:GetPos():DistToSqr(viewer:GetPos())<1500^2
  local active=kind~="" and waterValid and visible and not A.Conflict(entity) and A.WeaponAllows(entity,kind)
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
   state.target=target;state.source=source
   state.anchor=water and entity:GetNW2Vector("ixContextActionAnchor",Vector()) or nil
   state.weight=math.Approach(state.weight,1,FrameTime()*5);entity:InvalidateBoneCache()
  elseif fading then
   state.weight=math.Approach(state.weight,0,FrameTime()*6);entity:InvalidateBoneCache()
   if state.weight<=0 then A.Clear(entity) end
  end
 end
end)
hook.Add("PostPlayerDraw","ixContextActionRadioProp",function(entity)
 local state=A.actors[entity]
 if not state then return end
 local fill=state.kind=="waterfill"
 if (state.kind~="radio" and not fill) or A.Conflict(entity) or not A.WeaponAllows(entity,state.kind) then return end
 if fill and (entity:GetNW2String("ixContextAction","")~="waterfill" or entity:GetNW2Float("ixContextActionFinish",0)<=CurTime() or not IsValid(state.target)) then
  if IsValid(state.prop) then state.prop:Remove();state.prop=nil end
  return
 end
 local model=entity:GetNW2String("ixContextActionProp","")
 if IsValid(state.prop) and state.prop:GetModel()~=model then state.prop:Remove();state.prop=nil end
 if model=="" then return end
 if not IsValid(state.prop) then
  if state.propFailed==model then return end
  if not util.IsValidModel(model) then state.propFailed=model;return end
  state.prop=ClientsideModel(model,RENDERGROUP_OPAQUE)
  if not IsValid(state.prop) then state.propFailed=model;return end
  state.prop:SetNoDraw(true)
  if fill then
   local mins,maxs=state.prop:OBBMins(),state.prop:OBBMaxs()
   local extent=(maxs-mins):Length()
   -- Huge/non-finite models are not hand-held props. Keep a bare-hand fill
   -- gesture instead of scaling a barrel or spawning extra inventory items.
   if extent~=extent or extent<1 or extent>48 then state.prop:Remove();state.prop=nil;state.propFailed=model;return end
   state.propCenter=(mins+maxs)*.5
  end
 end
 local index=entity:LookupBone("ValveBiped.Bip01_"..(fill and "R_Hand" or "L_Hand"));local bone=index and entity:GetBoneMatrix(index)
 if not bone then return end
 local pos,ang
 if fill then
  ang=Angle(0,entity:GetRenderAngles().y,0)
  local center=state.propCenter or Vector()
  local offset=LocalToWorld(center,Angle(),Vector(),ang)
  pos=bone:GetTranslation()-offset
 else pos,ang=LocalToWorld(Vector(2,-1,0),Angle(0,0,180),bone:GetTranslation(),bone:GetAngles()) end
 state.prop:SetPos(pos);state.prop:SetAngles(ang);state.prop:SetupBones();state.prop:DrawModel()
end)
hook.Add("EntityRemoved","ixContextActionCleanup",A.Clear)
hook.Add("ShutDown","ixContextActionCleanup",function() for entity in pairs(A.actors) do A.Clear(entity) end end)
function A.Unload()
 for entity in pairs(A.actors) do A.Clear(entity) end
 hook.Remove("Think","ixContextActionActors");hook.Remove("PostPlayerDraw","ixContextActionRadioProp")
 hook.Remove("EntityRemoved","ixContextActionCleanup");hook.Remove("ShutDown","ixContextActionCleanup")
end
