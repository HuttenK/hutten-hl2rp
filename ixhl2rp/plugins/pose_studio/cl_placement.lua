local S=ix.PoseStudio
local generation=0
function S.CancelPlacement()
 generation=generation+1
 local state=S.placement
 S.placement=nil; S.placementPending=nil
 if state then S.ClearPreview(state.entity,state.animation); SafeRemoveEntity(state.entity) end
end
function S.OpenPlacement(raw,label)
 local selection=S.Selection(raw)
 if not selection then return end
 S.CancelPlacement()
 if ix.StopAutoWalk then ix.StopAutoWalk() end
 local p=LocalPlayer()
 if not IsValid(p) or not p:Alive() or not p:GetCharacter() then return end
 local current=generation
 local character,model=p:GetCharacter(),p:GetModel()
 S.placementPending={character=character,model=model}
 S.FetchPreview(selection,function(preview,err)
  if generation~=current then return end
  S.placementPending=nil
  if not preview then notification.AddLegacy(err or "Анимация недоступна",NOTIFY_ERROR,5); return end
  if not IsValid(p) or not p:Alive() or p:GetCharacter()~=character or p:GetModel()~=model then return end
  if preview.clip and preview.clip.mask=="upper" then S.Request({op="play",id=selection.id}); return end
  local entity=ClientsideModel(p:GetModel(),RENDERGROUP_OPAQUE)
  if not IsValid(entity) then return end
  entity:SetNoDraw(true); entity:SetIK(false)
  S.placement={entity=entity,animation=S.SetPreview(entity,preview),selection=selection,label=label or "Размещение позы",
   model=p:GetModel(),character=p:GetCharacter(),yaw=p:EyeAngles().y+180,height=0,
   offset=Vector(unpack(preview.offset or {0,0,0})),armed=false}
 end)
end
local function refresh(state)
 local p=LocalPlayer()
 if not IsValid(p) or not p:Alive() or p:GetModel()~=state.model or p:GetCharacter()~=state.character
  or p:InVehicle() or p:GetNetVar("forcedSequence")~=nil or p:GetLocalVar("knocked",false) then S.CancelPlacement(); return false end
 local ragdoll=p:GetLocalVar("ragdoll",0)
 if ragdoll and ragdoll~=0 then S.CancelPlacement(); return false end
 state.anchor=S.PlacementPoint(p)
 state.valid,state.reason,state.position,state.angle=S.CheckPlacement(p,state.anchor,state.yaw,state.height,state.offset)
 return true
end
hook.Add("Think","ixPosePlacement",function()
 local state=S.placement
 if state or S.placementPending then
  if input.IsKeyDown(KEY_ESCAPE) or gui.IsGameUIVisible() or IsValid(S.editor) then S.CancelPlacement(); return end
  local pending=S.placementPending
  local p=LocalPlayer()
  if pending and (not IsValid(p) or not p:Alive() or p:GetCharacter()~=pending.character or p:GetModel()~=pending.model) then S.CancelPlacement(); return end
  if not state or not refresh(state) then return end
  if not input.IsMouseDown(MOUSE_LEFT) and not input.IsMouseDown(MOUSE_RIGHT) then state.armed=true end
 end
end)
local ghost=Material("models/debug/debugwhite")
hook.Add("PostDrawTranslucentRenderables","ixPosePlacement",function(depth,sky)
 local state=S.placement
 if depth or sky or not state or not IsValid(state.entity) or not state.anchor then return end
 local entity=state.entity
 local angle=state.angle or Angle(0,state.yaw,0)
 entity:SetAngles(angle)
 entity:SetPos(state.position or state.anchor+angle:Forward()*state.offset.x+angle:Right()*state.offset.y+Vector(0,0,state.offset.z+state.height))
 S.StepPreview(entity,state.animation); entity:SetupBones()
 local blend=render.GetBlend(); local r,g,b=render.GetColorModulation()
 render.MaterialOverride(ghost); render.SetBlend(.48)
 render.SetColorModulation(state.valid and .25 or 1,state.valid and .95 or .22,state.valid and .85 or .25)
 entity:DrawModel()
 if state.animation.clip then S.DrawProps(entity,state.animation) end
 render.MaterialOverride(nil); render.SetBlend(blend); render.SetColorModulation(r,g,b)
end)
hook.Add("PlayerBindPress","ixPosePlacement",function(p,bind,pressed)
 local state=S.placement
 if not state then return end
 bind=bind:lower()
 if bind:find("invnext",1,true) or bind:find("invprev",1,true) then return true end
 if bind:find("+attack2",1,true) then
  if pressed and state.armed then S.CancelPlacement() end
  return true
 elseif bind:find("+attack",1,true) then
  if pressed and state.armed and refresh(state) and state.valid then
   S.Request({op="place",selection=state.selection,anchor={state.anchor.x,state.anchor.y,state.anchor.z},yaw=state.yaw,height=state.height})
   S.CancelPlacement()
  end
  return true
 end
end)
hook.Add("CreateMove","ixPosePlacement",function(cmd)
 local state=S.placement
 if not state then return end
 -- Prevent the preview confirmation click from firing a held weapon.
 cmd:RemoveKey(IN_ATTACK); cmd:RemoveKey(IN_ATTACK2)
 local delta=cmd:GetMouseWheel()
 if delta~=0 then
  if input.IsKeyDown(KEY_LSHIFT) or input.IsKeyDown(KEY_RSHIFT) then
   state.height=math.Clamp(state.height+delta*(input.IsKeyDown(KEY_LCONTROL) and .5 or 2),S.placementHeight.min,S.placementHeight.max)
  else state.yaw=math.NormalizeAngle(state.yaw+delta*4) end
 end
end)
hook.Add("HUDPaint","ixPosePlacement",function()
 local state=S.placement
 local x,y=ScrW()*.5,ScrH()*.78
 if not state then
  if S.placementPending then draw.SimpleTextOutlined("Подготовка позы…  ·  Esc: отмена","ixPoseText",x,y,color_white,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER,1,color_black) end
  return
 end
 draw.SimpleTextOutlined(state.label,"ixPoseText",x,y,color_white,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER,1,color_black)
 draw.SimpleTextOutlined(state.valid and string.format("Высота: %+.1f  ·  ЛКМ — разместить",state.height) or state.reason or "Выберите место",
  "ixPoseText",x,y+24,state.valid and Color(120,240,205) or Color(255,160,145),TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER,1,color_black)
 draw.SimpleTextOutlined("Колесо: поворот  ·  Shift + колесо: высота  ·  Ctrl: точнее  ·  ПКМ / Esc: отмена",
  "ixPoseSmall",x,y+48,color_white,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER,1,color_black)
end)
hook.Add("ShutDown","ixPosePlacement",S.CancelPlacement)
