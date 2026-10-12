local S=ix.PoseStudio
local serial=0
local pending={}
-- Dedicated replies never load or overwrite the editor's unsaved document.
function S.FetchPreview(spec,callback)
 serial=(serial+1)%65536
 local id=serial
 pending[id]={callback=callback,at=RealTime(),model=LocalPlayer():GetModel()}
 S.Request({op="preview",token=id,selection=spec})
 timer.Simple(5,function()
  local request=pending[id]
  if request then pending[id]=nil; request.callback(nil,"Сервер не ответил") end
 end)
 return id
end
function S.ReceivePreview(data)
 local request=pending[data.token]
 if not request then return end
 pending[data.token]=nil
 if not IsValid(LocalPlayer()) or request.model~=LocalPlayer():GetModel() then return end
 if data.error then request.callback(nil,data.error); return end
 if not istable(data.preview) then request.callback(nil,"Анимация недоступна"); return end
 if data.preview.clip then
  local clip=S.Validate(data.preview.clip)
  if not clip or (not clip.portable and clip.model~=request.model:lower()) then return end
  data.preview.clip=clip
 end
 request.callback(data.preview)
end
function S.ClearPreview(entity,state)
 if state and state.clip then S.Detach(entity,state) end
 if IsValid(entity) and ix.sharedPoses then ix.sharedPoses.Clear(entity) end
end
function S.SetPreview(entity,spec)
 local state={started=RealTime(),sharedStarted=CurTime(),spec=spec,clip=spec.clip}
 if spec.clip then S.Attach(entity,state) end
 local p=LocalPlayer()
 entity:SetSkin(p:GetSkin())
 for _,group in ipairs(p:GetBodyGroups()) do entity:SetBodygroup(group.id,p:GetBodygroup(group.id)) end
 local color=p:GetPlayerColor()
 entity.GetPlayerColor=function() return color end
 return state
end
function S.StepPreview(entity,state)
 local spec=state.spec
 if state.clip then
  local clip=state.clip

  -- Wheel/world ghost previews repeat one-shots with a short final hold.
  local elapsed=(RealTime()-state.started)%(S.Duration(clip)+(clip.loop and 0 or .65))
  state.transforms=S.Sample(clip,elapsed)
  if not S.PreviewBase(entity,clip,state,elapsed,clip.mask=="upper" and "walk" or "idle") then return false end
 else
  local _,index,shared=ix.act.Sequence(entity,{spec.sequence})
  if not index then return false end
  entity:SetSequence(index); entity:SetPlaybackRate(0)
  local duration=math.max(shared and shared.duration or entity:SequenceDuration(index),.1)
  entity:SetCycle(spec.static and 0 or ((RealTime()-state.started)%duration)/duration)
  if ix.sharedPoses then
   if shared then
    shared=table.Copy(shared)
    shared.started=(state.sharedStarted or CurTime())+math.floor((RealTime()-state.started)/duration)*duration
    ix.sharedPoses.Apply(entity,shared)
   else ix.sharedPoses.Clear(entity) end
  end
  entity:InvalidateBoneCache()
 end
 return true
end
local VIEW={}
function VIEW:Init()
 self:SetMouseInputEnabled(false); self:SetKeyboardInputEnabled(false)
 self:SetFOV(34); self:SetAmbientLight(Color(125,135,150))
 self:SetDirectionalLight(BOX_TOP,Color(255,230,217)); self:SetDirectionalLight(BOX_FRONT,Color(210,245,255))
 self:SetAnimated(false)
end
function VIEW:ShowPreview(spec)
 S.ClearPreview(self.Entity,self.state); self.state=nil
 self:SetModel(LocalPlayer():GetModel())
 if not IsValid(self.Entity) then return end
 self.Entity:SetAngles(angle_zero); self.Entity:SetPos(vector_origin)
 self.state=S.SetPreview(self.Entity,spec)
 -- Frame the *posed* skeleton, including sitting/lying poses and translated roots.
 S.StepPreview(self.Entity,self.state); self.Entity:SetupBones()
 local low,high=Vector(1e5,1e5,1e5),Vector(-1e5,-1e5,-1e5)
 local found=false
 for i=0,self.Entity:GetBoneCount()-1 do
  local matrix=self.Entity:GetBoneMatrix(i)
  if matrix then
   local pos=matrix:GetTranslation(); found=true
   low.x=math.min(low.x,pos.x); low.y=math.min(low.y,pos.y); low.z=math.min(low.z,pos.z)
   high.x=math.max(high.x,pos.x); high.y=math.max(high.y,pos.y); high.z=math.max(high.z,pos.z)
  end
 end
 if not found then low,high=self.Entity:GetRenderBounds() end
 self.focus=(low+high)*.5
 self.distance=math.Clamp((high-low):Length()*1.9,75,250)
 self:SetLookAt(self.focus); self:SetCamPos(self.focus+Angle(5,30,0):Forward()*self.distance)
end
function VIEW:LayoutEntity(entity) if self.state then S.StepPreview(entity,self.state) end end
function VIEW:PostDrawModel(entity) if self.state and self.state.clip then S.DrawProps(entity,self.state) end end
function VIEW:OnRemove() S.ClearPreview(self.Entity,self.state); self.BaseClass.OnRemove(self) end
vgui.Register("ixPoseWheelPreview",VIEW,"DModelPanel")

function S.InstallWheelPreview(panel)
 panel.poseModel=LocalPlayer():GetModel(); panel.previewCache={}
 panel.preview=panel:Add("ixPoseWheelPreview"); panel.preview:SetVisible(false)
 panel.preview:SetPaintedManually(true)
 panel.OnOptionHover=function(self,option)
  if not option or not option.preview then return end
  if self.previewOption==option then return end
  self.previewOption=option; self.previewAt=RealTime()+.18; self.previewStatus="Загрузка…"
  self.preview:SetVisible(false)
 end
 panel.OnOptionsChanged=function(self)
  self.previewOption=nil; self.previewAt=nil; self.preview:SetVisible(false)
 end
 panel.PreviewThink=function(self)
  if LocalPlayer():GetModel()~=self.poseModel then self:Remove(); return end
  if not self.previewAt or RealTime()<self.previewAt or RealTime()<(self.nextPreview or 0) then return end
  self.previewAt=nil
  local option=self.previewOption; if not option then return end
  local key=S.SelectionKey(option.preview)
  local function show(spec,err)
   if not IsValid(self) then return end
   if spec then self.previewCache[key]=spec end
   if self.previewOption~=option then return end
   self.previewStatus=err or (spec and spec.clip and spec.clip.mask=="upper" and "ЛКМ — ПРИМЕНИТЬ · ХОДЬБА" or "ЛКМ — РАЗМЕСТИТЬ")
   if spec then self.preview:ShowPreview(spec); self.preview:SetVisible(true) end
  end
  if self.previewCache[key] then show(self.previewCache[key])
  else self.nextPreview=RealTime()+.4; S.FetchPreview(option.preview,show) end
 end
 panel.PaintCenter=function(self,cx,cy,inner)
  local option=self.previewOption
  if not option then return false end
  -- An inscribed viewport stays inside the circular cutout without sharing
  -- stencil state with DModelPanel/other render effects.
  local size=inner*1.34
  self.preview:SetPos(cx-size*.5,cy-size*.5-12); self.preview:SetSize(size,size)
  if self.preview:IsVisible() then self.preview:PaintManual() end
  draw.SimpleText(self.previewStatus or "","ixPoseSmall",cx,cy+inner*.79,Color(225,200,200),TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
  return true
 end
end
