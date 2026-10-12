local S=ix.PoseStudio
local C={bg=Color(8,12,18),panel=Color(16,23,32),raised=Color(24,34,46),line=Color(43,61,75),
 text=Color(230,240,244),muted=Color(143,166,181),accent=Color(89,215,211),red=Color(247,96,119),gold=Color(236,186,102)}
surface.CreateFont("ixPoseTitle",{font="Roboto",size=23,weight=600,extended=true})
surface.CreateFont("ixPoseText",{font="Roboto",size=16,weight=500,extended=true})
surface.CreateFont("ixPoseSmall",{font="Roboto",size=13,weight=500,extended=true})
local function label(parent,text)
 local p=parent:Add("DLabel"); p:Dock(TOP); p:SetTall(25); p:SetFont("ixPoseText"); p:SetTextColor(C.muted); p:SetText(text)
 return p
end
local function button(parent,text,callback)
 local b=parent:Add("DButton"); b:SetText(""); b.caption=text; b:SetTall(32); b:Dock(TOP); b:DockMargin(0,0,0,5)
 b.DoClick=callback
 b.Paint=function(self,w,h)
  self.fade=Lerp(math.min(FrameTime()*18,1),self.fade or 0,self:IsHovered() and 1 or 0)
  draw.RoundedBox(5,0,0,w,h,self.active and Color(28,75,80) or self:IsDown() and Color(37,63,74) or C.raised)
  surface.SetDrawColor(self.active and C.accent or C.line); surface.DrawOutlinedRect(0,0,w,h)
  if self.fade>.01 then surface.SetDrawColor(89,215,211,18*self.fade); surface.DrawRect(1,1,w-2,h-2) end
  draw.SimpleText(self.caption,"ixPoseText",w/2,h/2,self:IsEnabled() and C.text or C.muted,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
 end
 return b
end
local function row(parent,height)
 local p=parent:Add("DPanel"); p:Dock(TOP); p:SetTall(height or 38); p.Paint=function() end
 return p
end
local function entry(parent,value)
 local e=parent:Add("DTextEntry"); e:Dock(TOP); e:SetTall(32); e:DockMargin(0,0,0,6); e:SetFont("ixPoseText"); e:SetText(value or "")
 e:SetTextColor(C.text); e:SetCursorColor(C.accent); e:SetHighlightColor(Color(40,105,116))
 e.Paint=function(self,w,h)
  draw.RoundedBox(4,0,0,w,h,C.bg); surface.SetDrawColor(self:HasFocus() and C.accent or C.line); surface.DrawOutlinedRect(0,0,w,h)
  self:DrawTextEntryText(C.text,C.accent,C.text)
 end
 return e
end
local friendly={Pelvis="Таз",Spine="Поясница",Spine1="Спина",Spine2="Грудь",Spine4="Верх груди",Neck1="Шея",Head1="Голова",
 Clavicle="Ключица",UpperArm="Плечо",Forearm="Предплечье",Hand="Кисть",Thigh="Бедро",Calf="Голень",Foot="Стопа",Toe0="Пальцы ноги"}
local function boneLabel(name)
 local short=name:gsub("ValveBiped.Bip01_","")
 local side,part=short:match("^([LR])_(.+)$")
 return side and (side=="L" and "Л · " or "П · ")..(friendly[part] or part) or friendly[short] or short
end
local function authorModelAvailable(clip)
 local R=ix.sharedPoses
 if R and R.Probe then return IsValid(R.Probe(clip.model)) end
 return util.IsValidModel(clip.model)
end

local VIEW={}
function VIEW:Init()
 self:SetFOV(34); self:SetAmbientLight(Color(115,130,145)); self:SetDirectionalLight(BOX_TOP,Color(255,240,220))
 self:SetDirectionalLight(BOX_FRONT,Color(210,235,255)); self:SetAnimated(false)
 self.cameraMode="fixed"
 self.orbit=Angle(8,35,0); self.distance=145; self.focus=Vector(0,0,36); self.points={}; self.showBones=true
end
function VIEW:LoadClip(clip)
 self.points={}; self.rings={}; self.boneListCount=nil; self.drag=nil; self:MouseCapture(false)
 self.poseMatrices=nil;self.poseMatrixClip=nil;self.poseMatrixFrame=nil
 if self.state then S.Detach(self.Entity,self.state) end
 local model=self.editor and self.editor.previewTarget and clip.portable and LocalPlayer():GetModel():lower() or clip.model
 if clip.portable and not util.IsValidModel(model) then model=LocalPlayer():GetModel():lower() end
 self:SetModel(model)
 local ent=self.Entity
 if not IsValid(ent) then return end
 ent:SetModel(model); ent:SetModelName(model)
 if ent.SetLOD then ent:SetLOD(0) end
 if ent.SetIK then ent:SetIK(false) end
 ent:SetAngles(angle_zero); ent:SetPos(vector_origin)
 local p=LocalPlayer()
 if p:GetModel():lower()==model then
  ent:SetSkin(p:GetSkin())
  for _,group in ipairs(p:GetBodyGroups()) do ent:SetBodygroup(group.id,p:GetBodygroup(group.id)) end
 end
 ent.GetPlayerColor=function() return p:GetPlayerColor() end
 self.state={clip=clip}; S.Attach(ent,self.state)
 self:Fit()
end
function VIEW:Fit()
 if not IsValid(self.Entity) then return end
 local low,high=self.Entity:GetRenderBounds()
 self.focus=(low+high)*.5
 self.distance=math.Clamp((high-low):Length()*1.6,60,300)
 self.orbit=Angle(8,35,0)
 if self.cameraMode=="free" then self:SetCameraMode("free") end
end
function VIEW:SetCameraMode(mode)
 self:OnMouseReleased()
 if mode=="free" then
  self.freePos=self.focus+self.orbit:Forward()*self.distance
  self.freeAngle=(self.focus-self.freePos):Angle()
 else
  if self.freePos then
   local offset=self.freePos-self.focus
   self.distance=math.Clamp(offset:Length(),20,500); self.orbit=offset:Angle()
  end
 end
 self.cameraMode=mode
end
function VIEW:UpdateCamera()
 if self.cameraMode=="free" and self.freePos then
  self:SetCamPos(self.freePos); self:SetLookAt(self.freePos+self.freeAngle:Forward()*100)
 else self:SetCamPos(self.focus+self.orbit:Forward()*self.distance); self:SetLookAt(self.focus) end
end
function VIEW:LayoutEntity(ent)
 local editor=self.editor
 if not editor or not editor.clip or not self.state then return end
 self.state.clip=editor.clip
 if editor.playing then
  local elapsed=(RealTime()-editor.playStarted)*editor.speed
  self.state.transforms,editor.playFrame=S.Sample(editor.clip,elapsed)
  if not editor.clip.loop and elapsed>=S.Duration(editor.clip) then editor.playing=false; editor.frame=#editor.clip.frames; editor:RefreshFields() end
 else self.state.transforms=editor.clip.frames[editor.frame].bones end
 self.layerReady=S.PreviewBase(ent,editor.clip,self.state,RealTime(),editor.previewLegs or "idle")
 self:UpdateCamera()
end
function VIEW:PreDrawModel()
 for i=-96,96,16 do
  render.DrawLine(Vector(i,-96,0),Vector(i,96,0),C.line,true)
  render.DrawLine(Vector(-96,i,0),Vector(96,i,0),C.line,true)
 end
end
function VIEW:ProjectBonePoint(pos)
 -- ToScreen uses the active 3D projection but returns full-screen pixels,
 -- even when DModelPanel renders into a smaller viewport. Keep both markers
 -- and hit testing in panel-local coordinates; ScreenToLocal alone is wrong.
 local point=pos:ToScreen()
 local w,h=self:GetWide(),self:GetTall()
 local x,y=point.x*w/(self.projectionWidth or ScrW()),point.y*h/(self.projectionHeight or ScrH())
 return {x=x,y=y,visible=point.visible and x>=0 and y>=0 and x<w and y<h}
end
function VIEW:BuildRotationGizmo(matrix)
 if self.drag and self.drag.kind=="ring" then self.rings=self.drag.rings; return end
 local pos,angles=matrix:GetTranslation(),matrix:GetAngles()
 local center=self:ProjectBonePoint(pos)
 if not center.visible then return end
 local eye=self:GetCamPos()
 local camera=(self:GetLookAt()-eye):Angle()
 local forward=camera:Forward()
 local depth=(pos-eye):Dot(forward)
 if depth<=5 then return end
 local above=self:ProjectBonePoint(pos+camera:Up())
 local pixels=math.sqrt((above.x-center.x)^2+(above.y-center.y)^2)
 local radius=math.Clamp(55/math.max(pixels,.01),.3,32)
 local axes={angles:Forward(),-angles:Right(),angles:Up()}
 local viewDirection=(eye-pos):GetNormalized()
 for index=1,3 do
  local u,v=axes[index%3+1]*radius,axes[(index+1)%3+1]*radius
  local pu,pv=self:ProjectBonePoint(pos+u),self:ProjectBonePoint(pos+v)
  local du,dv=(pos+u-eye):Dot(forward)/depth,(pos+v-eye):Dot(forward)/depth
  local ring={axis=index,center=center,points={},edgeOn=math.abs(axes[index]:Dot(viewDirection))<.15,
   u={x=pu.x*du-center.x,y=pu.y*du-center.y,z=du-1},
   v={x=pv.x*dv-center.x,y=pv.y*dv-center.y,z=dv-1}}
  for segment=0,72 do
   local theta=segment/72*math.pi*2
   ring.points[#ring.points+1]=self:ProjectBonePoint(pos+u*math.cos(theta)+v*math.sin(theta))
  end
  self.rings[#self.rings+1]=ring
 end
end
local function ringLine(a,b,width,color)
 local dx,dy=b.x-a.x,b.y-a.y
 local length=math.sqrt(dx*dx+dy*dy)
 if length<.01 then return end
 local nx,ny=-dy/length*width*.5,dx/length*width*.5
 surface.SetDrawColor(color)
 surface.DrawPoly({{x=a.x-nx,y=a.y-ny},{x=b.x-nx,y=b.y-ny},{x=b.x+nx,y=b.y+ny},{x=a.x+nx,y=a.y+ny}})
end
function VIEW:PaintRotationGizmo()
 if not self.rings or #self.rings==0 then return end
 local x,y=self:CursorPos()
 local hit=S.PickRotationRing(self.rings,x,y)
 local active=self.drag and self.drag.kind=="ring" and self.drag.ring.axis or hit and hit.ring.axis
 draw.NoTexture()
 -- Idle rings first, active ring on top at their intersections.
 for pass=1,2 do
  for _,ring in ipairs(self.rings) do
   local chosen=ring.axis==active
   if (pass==2)==chosen then
    draw.NoTexture()
    local spec=S.rotationAxes[ring.axis]
    for i=1,#ring.points-1 do
     local a,b=ring.points[i],ring.points[i+1]
     if a.visible and b.visible then
      ringLine(a,b,chosen and 6 or 4,Color(3,8,13,225))
      ringLine(a,b,chosen and 3 or 2,spec.color)
     end
    end
    local marker=ring.points[1+(ring.axis-1)*24]
    if marker.visible then
     draw.RoundedBox(4,marker.x-10,marker.y-10,20,20,C.bg)
     draw.SimpleText(spec.name,"ixPoseText",marker.x,marker.y,spec.color,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
    end
   end
  end
 end
 if self.drag and self.drag.kind=="ring" then
  local ring=self.drag.ring
  draw.SimpleText(string.format("%s  %+.1f°",S.rotationAxes[ring.axis].name,self.drag.total),"ixPoseText",
   ring.center.x,ring.center.y+76,C.text,TEXT_ALIGN_CENTER)
 end
end
function VIEW:PostDrawModel(ent)
 self.points={}
 if self.state then S.DrawProps(ent,self.state) end
 if not self.showBones then return end
 local matrices={}
 for i=0,math.min(ent:GetBoneCount(),256)-1 do matrices[i]=ent:GetBoneMatrix(i) end
 self.poseMatrices=matrices;self.poseMatrixClip=self.editor.clip;self.poseMatrixFrame=self.editor.frame
 for i,m in pairs(matrices) do
  local name=ent:GetBoneName(i)
  if name~="__INVALIDBONE__" and S.EditableBone(self.editor.clip,name) then
   local pos=m:GetTranslation()
   self.points[name]=self:ProjectBonePoint(pos)
   -- Connect visible joints through helper chains without drawing to hidden bones.
   local parentIndex=ent:GetBoneParent(i)
   for _=1,256 do
    if parentIndex<0 or S.EditableBone(self.editor.clip,ent:GetBoneName(parentIndex)) then break end
    parentIndex=ent:GetBoneParent(parentIndex)
   end
   local parent=matrices[parentIndex]
   if parentIndex>=0 and not S.EditableBone(self.editor.clip,ent:GetBoneName(parentIndex)) then parent=nil end
   if parent then render.DrawLine(pos,parent:GetTranslation(),Color(102,161,175,170),false) end
   if self.editor.selectedBone==name and not self.editor.selectedProp then
    render.DrawWireframeSphere(pos,1.2,8,8,C.accent,false)
    if not self.editor.moveMode and not self.editor.targetMode and not self.editor.playing then self:BuildRotationGizmo(m)
    else
     local angles=m:GetAngles()
     render.DrawLine(pos,pos+angles:Forward()*7,Color(250,99,111),false)
     render.DrawLine(pos,pos-angles:Right()*7,Color(103,230,167),false)
     render.DrawLine(pos,pos+angles:Up()*7,Color(101,171,255),false)
    end
   end
  end
 end
end
function VIEW:Paint(w,h)
 draw.RoundedBox(8,0,0,w,h,C.bg)
 -- ScrW/ScrH can change inside cam.Start3D. Capture the screen extent before
 -- DModelPanel installs its sub-viewport, not while projecting its bones.
 self.projectionWidth,self.projectionHeight=ScrW(),ScrH()
 self.points={}; self.rings={}
 self.BaseClass.Paint(self,w,h)
 if self.showBones then
  for name,point in pairs(self.points) do
   local x,y=point.x,point.y
   if point.visible and x>0 and y>0 and x<w and y<h then
    local chosen=self.editor.selectedBone==name and not self.editor.selectedProp
    surface.SetDrawColor(chosen and C.accent or C.muted); surface.DrawRect(x-2,y-2,4,4)
   end
  end
 end
 self:PaintRotationGizmo()
 if self.editor.targetMode then
  draw.SimpleText("ЦЕЛЬ: тяните кисть / стопу · Колесо при перетаскивании: сгиб · Shift: точнее","ixPoseSmall",12,h-42,C.accent)
  if self.drag and self.drag.kind=="target" then
   draw.SimpleText(string.format("Плоскость сгиба: %+.0f°",self.drag.bend),"ixPoseSmall",12,16,C.accent)
  end
 end
 if self.layerReady==false then
  local reason=self.state.referenceError or "Не удалось загрузить совместимую основу позы"
  draw.SimpleText(reason,"ixPoseText",w/2,20,C.gold,TEXT_ALIGN_CENTER)
  if self.state.referenceError~=self.lastReferenceError then
   self.lastReferenceError=self.state.referenceError; self.referenceErrorSince=RealTime(); self.referenceErrorReported=false
  end
  if not self.referenceErrorReported and RealTime()-(self.referenceErrorSince or RealTime())>2 then
   print("[Pose Studio] model="..self.editor.clip.model.." base="..self.editor.clip.base.." target="..self.Entity:GetModel().." error="..reason)
   self.referenceErrorReported=true
  end
 else self.lastReferenceError=nil; self.referenceErrorReported=false end
 if #self.rings>0 then draw.SimpleText("Кольца X / Y / Z: вращение    Shift: точнее","ixPoseSmall",12,h-42,C.accent) end
 draw.SimpleText(self.cameraMode=="free" and "ПКМ + WASD: полёт · Q/E: высота · Shift: быстрее · Колесо: вперёд/назад" or "ЛКМ: кость / кольцо    ПКМ: обзор    СКМ: сдвиг    Колесо: масштаб","ixPoseSmall",12,h-22,C.muted)
end
function VIEW:OnMousePressed(code)
 if self.drag then return end
 if self.cameraMode=="free" and code==MOUSE_RIGHT then self:RequestFocus() end
 local x,y=gui.MousePos()
 self.drag={x=x,y=y,kind=code==MOUSE_MIDDLE and "pan" or self.cameraMode=="free" and (code==MOUSE_RIGHT and "fly" or "select") or "orbit"}
 if code==MOUSE_LEFT and self.showBones then
  local mouseX,mouseY=self:ScreenToLocal(x,y)
  local hit=S.PickRotationRing(self.rings,mouseX,mouseY)
  if hit and not self.editor.moveMode and not self.editor.targetMode and not self.editor.selectedProp and not self.editor.playing then
   local e=self.editor
   e:Checkpoint(true); e.axis=S.rotationAxes[hit.ring.axis].field
   local transform=e:CurrentTransform(false) or S.Identity()
   self.drag={x=x,y=y,kind="ring",ring=hit.ring,rings=self.rings,tx=hit.tx,ty=hit.ty,
    lastAngle=S.RotationRingAngle(hit.ring,mouseX,mouseY),start=table.Copy(transform.a),total=0,
    bone=e.selectedBone,frame=e.frame}
   e:RefreshFields(); self:MouseCapture(true); return
  end
  local closest,best=nil,11^2
  for name,point in pairs(self.points) do
   local distance=(point.x-mouseX)^2+(point.y-mouseY)^2
   if point.visible and distance<best then closest=name; best=distance end
  end
  if closest then
   self.editor:SelectBone(closest)
   if self.editor.targetMode then self:StartTargetDrag(closest,x,y);self:MouseCapture(true);return end
   self.drag.kind=self.editor.moveMode and "bone" or "select"
   if self.drag.kind=="bone" then self.editor:Checkpoint(true) end
  end
 end
 self:MouseCapture(true)
end
function VIEW:OnMouseReleased() self.drag=nil; self:MouseCapture(false) end
function VIEW:OnMouseCaptureLost() self.drag=nil end
function VIEW:OnMouseWheeled(delta)
 if self.drag and self.drag.kind=="target" then
  self.drag.bend=math.NormalizeAngle(self.drag.bend+delta*(input.IsKeyDown(KEY_LSHIFT) and 2 or 10))
  self:DragTarget(0,0);return true
 end
 if self.drag then return true end
 if self.cameraMode=="free" then self.freePos=self.freePos+self.freeAngle:Forward()*delta*8
 else self.distance=math.Clamp(self.distance-delta*8,20,500) end
 return true
end
function VIEW:StartTargetDrag(name,x,y)
 local e=self.editor
 local reference=S.ToolReference(e.clip,self.Entity)
 if not reference then e:Message("Скелет ещё загружается. Повторите через секунду.");return end
 if self.poseMatrixClip~=e.clip or self.poseMatrixFrame~=e.frame then e:Message("Дождитесь обновления предпросмотра.");return end
 local rig=ix.sharedPoses and ix.sharedPoses.Rig(self.Entity:GetModel():lower())
 local target,err=S.MakeViewportTarget(reference,e.clip,e.clip.frames[e.frame].bones,name,rig,self.poseMatrices)
 if not target then e:Message(err);return end
 local camera=(self:GetLookAt()-self:GetCamPos()):Angle()
 local distance=(self:GetCamPos()-target.goal):Length()
 -- DModelPanel's horizontal FOV and panel width define a world-units/pixel
 -- scale. Drag in the camera plane; orbit to edit the remaining dimension.
 e:Checkpoint(true)
 self.drag={kind="target",x=x,y=y,target=target,goal=target.goal,bend=0,right=camera:Right(),up=camera:Up(),
  scale=2*distance*math.tan(math.rad(self:GetFOV()*.5))/math.max(self:GetWide(),1),clip=e.clip,frame=e.frame,bone=name}
end
function VIEW:DragTarget(dx,dy)
 local drag,e=self.drag,self.editor
 if e.clip~=drag.clip or e.frame~=drag.frame or e.selectedBone~=drag.bone or e.selectedProp or e.playing or not e.targetMode then
  self:OnMouseReleased();return
 end
 local step=drag.scale*(input.IsKeyDown(KEY_LSHIFT) and .2 or 1)
 drag.goal=drag.goal+drag.right*(dx*step)-drag.up*(dy*step)
 local bones,err=S.SolveViewportTarget(drag.target,drag.goal,drag.bend)
 if not bones then e:Message(err);return end
 if e:CommitBoneEdit(bones,drag.target.names,false) then e:RefreshFields() end
end
function VIEW:DragRotation(x,y,dx,dy)
 local drag,e=self.drag,self.editor
 if e.selectedBone~=drag.bone or e.frame~=drag.frame or e.selectedProp or e.moveMode or e.playing or not self.showBones then
  self:OnMouseReleased(); return
 end
 local mouseX,mouseY=self:ScreenToLocal(x,y)
 local change=S.RotationDragDelta(drag,mouseX,mouseY,dx,dy)
 if change==0 then return end
 drag.total=drag.total+change*(input.IsKeyDown(KEY_LSHIFT) and .15 or 1)
 local transform=table.Copy(e:CurrentTransform(false) or S.Identity())
 if transform then
  transform.a=S.RotateBoneAngle(drag.start,drag.ring.axis,drag.total)
  if e:SetSelectedTransform(transform,false) then e:RefreshFields() end
 end
end
function VIEW:Think()
 -- Some Workshop models expose no bones until their first bone build/draw.
 -- Refresh outside the render pass once the skeleton becomes available.
 if IsValid(self.Entity) and IsValid(self.editor) then
  local count=self.Entity:GetBoneCount() or 0
  if count>0 and count~=self.boneListCount then self.editor:FillBones() end
 end
 if not self.drag then return end
 local x,y=gui.MousePos(); local dx,dy=x-self.drag.x,y-self.drag.y; self.drag.x=x; self.drag.y=y
 if self.drag.kind=="fly" then
  self.freeAngle.y=self.freeAngle.y-dx*.3; self.freeAngle.p=math.Clamp(self.freeAngle.p+dy*.3,-89.5,89.5)
  local move=Vector(0,0,0)
  if input.IsKeyDown(KEY_W) then move=move+self.freeAngle:Forward() end
  if input.IsKeyDown(KEY_S) then move=move-self.freeAngle:Forward() end
  if input.IsKeyDown(KEY_D) then move=move+self.freeAngle:Right() end
  if input.IsKeyDown(KEY_A) then move=move-self.freeAngle:Right() end
  if input.IsKeyDown(KEY_E) then move=move+Vector(0,0,1) end
  if input.IsKeyDown(KEY_Q) then move=move-Vector(0,0,1) end
  local step=math.min(RealFrameTime(),.05)*(input.IsKeyDown(KEY_LSHIFT) and 220 or 75)
  if move:LengthSqr()>0 then self.freePos=self.freePos+move:GetNormalized()*step end
  -- Keep the inspection camera within a useful range of this isolated preview.
  local offset=self.freePos-self.focus
  if offset:Length()>600 then self.freePos=self.focus+offset:GetNormalized()*600 end
  self:UpdateCamera(); return
 end
 if dx==0 and dy==0 then return end
 if self.drag.kind=="orbit" then self.orbit.y=self.orbit.y-dx*.4; self.orbit.p=math.Clamp(self.orbit.p+dy*.3,-75,75)
 elseif self.drag.kind=="pan" then
  if self.cameraMode=="free" then self.freePos=self.freePos-self.freeAngle:Right()*dx*.15+self.freeAngle:Up()*dy*.15
  else self.focus=self.focus+self.orbit:Right()*dx*self.distance*.0015+self.orbit:Up()*dy*self.distance*.0015 end
 elseif self.drag.kind=="ring" then self:DragRotation(x,y,dx,dy)
 elseif self.drag.kind=="target" then self:DragTarget(dx,dy)
 elseif self.drag.kind=="bone" then
  local e=self.editor; e.playing=false
  local transform=table.Copy(e:CurrentTransform(false) or S.Identity())
  if transform then
   local key=e.moveMode and "p" or "a"; local bound=e.moveMode and (e.selectedProp and 48 or S.BonePositionLimit(e.selectedBone)) or 180
   local scale=input.IsKeyDown(KEY_LSHIFT) and .15 or 1
   transform[key][e.axis]=math.Clamp(transform[key][e.axis]+(dx-dy)*(e.moveMode and .04 or .45)*scale,-bound,bound)
   if e:SetSelectedTransform(transform,false) then e:RefreshFields() end
  end
 end
end
function VIEW:OnRemove()
 if self.state then S.Detach(self.Entity,self.state) end
 self.BaseClass.OnRemove(self)
end
vgui.Register("ixPoseStudioViewport",VIEW,"DModelPanel")

local PANEL={}
function PANEL:Init()
 self:SetSize(ScrW()-32,ScrH()-32); self:Center(); self:SetTitle(""); self:ShowCloseButton(false); self:SetDraggable(false)
 self:MakePopup(); self:DockPadding(14,96,14,28)
 self.character=LocalPlayer():GetCharacter()
 self.axis=1; self.frame=1; self.speed=1; self.mode="own"; self.page=1; self.undo={}; self.catalogProps={}
 self.left=self:Add("DPanel"); self.left:Dock(LEFT); self.left:DockMargin(0,0,10,0); self.left:DockPadding(10,10,10,10)
 self.left.Paint=function(_,w,h) draw.RoundedBox(6,0,0,w,h,C.panel) end
 self.right=self:Add("DPanel"); self.right:Dock(RIGHT); self.right:DockMargin(10,0,0,0); self.right:DockPadding(10,10,10,10)
 self.right.Paint=self.left.Paint
 self.center=self:Add("DPanel"); self.center:Dock(FILL); self.center.Paint=function() end
 self:BuildLibrary(); self:BuildInspector(); self:BuildTimeline()
 local cameras=row(self.center,36)
 self.cameraChoice=cameras:Add("DComboBox"); self.cameraChoice:Dock(LEFT); self.cameraChoice:SetWide(230)
 self.cameraChoice:SetValue("Камера: закреплена на модели")
 self.cameraChoice:AddChoice("Камера: закреплена на модели","fixed")
 self.cameraChoice:AddChoice("Камера: свободный полёт","free")
 self.cameraChoice.OnSelect=function(_,_,_,mode) self.viewport:SetCameraMode(mode) end
 local reset=button(cameras,"Сбросить камеру",function() self.viewport:Fit() end); reset:Dock(LEFT); reset:SetWide(145); reset:DockMargin(6,0,0,4)
 self.viewport=self.center:Add("ixPoseStudioViewport"); self.viewport:Dock(FILL); self.viewport.editor=self
 self.name=entry(self,""); self.name:Dock(NODOCK)
 self.name.OnChange=function(box) if not self.updating and self.clip then self:Checkpoint(); self.clip.name=box:GetValue(); self:Dirty() end end
 self.save=button(self,"Сохранить",function() self:Save() end); self.save:Dock(NODOCK)
 self.apply=button(self,"Разместить",function()
  if self.dirty or not self.id then self.applyAfterSave=true; self:Save()
  else self:PlaceSaved() end
 end); self.apply:Dock(NODOCK)
 self.close=button(self,"×",function() self:Close() end); self.close:Dock(NODOCK)
 self:NewClip(true); S.Request({op="list",mode="own",page=1})
 self:SetAlpha(0); self:AlphaTo(255,.16,0)
 timer.Simple(.1,function() if IsValid(self) then self:OfferDraft() end end)
end
function PANEL:PlaceSaved()
 local id,name=self.id,self.clip.name
 self:Close()
 S.OpenPlacement({kind="custom",id=id},name)
end
function PANEL:PerformLayout(w,h)
 if not self.left or not self.name then return end
 self.left:SetWide(math.Clamp(w*.2,195,260)); self.right:SetWide(math.Clamp(w*.235,255,315))
 self.name:SetPos(14,53); self.name:SetSize(w-294,32)
 self.save:SetPos(w-270,53); self.save:SetSize(120,32)
 self.apply:SetPos(w-140,53); self.apply:SetSize(126,32)
 self.close:SetPos(w-48,12); self.close:SetSize(34,30)
end
function PANEL:Paint(w,h)
 draw.RoundedBox(9,0,0,w,h,C.bg)
 draw.SimpleText("POSE STUDIO","ixPoseTitle",17,16,C.text)
 draw.SimpleText("ПЕРСОНАЛЬНЫЕ ПОЗЫ И АНИМАЦИИ","ixPoseSmall",192,24,C.accent)
 draw.SimpleText(self.dirty and "НЕ СОХРАНЕНО" or self.id and "СОХРАНЕНО / "..self.id or "НОВАЯ АНИМАЦИЯ","ixPoseSmall",w-68,25,self.dirty and C.gold or C.muted,TEXT_ALIGN_RIGHT)
 draw.SimpleText(self.message or "Ctrl+Z — отмена  ·  Shift — точная настройка  ·  Движение или /PoseStop — выход из позы","ixPoseSmall",16,h-19,C.muted)
end
function PANEL:BuildLibrary()
 label(self.left,"БИБЛИОТЕКА")
 button(self.left,"Стартовые позы",function() self:StarterMenu() end)
 local tabs=row(self.left)
 local choices={{"Мои","own"},{"Общие","shared"}}
 if LocalPlayer():IsAdmin() then choices[#choices+1]={"Проверка","review"} end
 for _,choice in ipairs(choices) do
  local b=button(tabs,choice[1],function() self.mode=choice[2]; self.page=1; self:List() end)
  b:Dock(LEFT); b:SetWide(LocalPlayer():IsAdmin() and 70 or 90); b:DockMargin(0,0,4,5)
 end
 local actions=self.left:Add("DPanel"); actions:Dock(BOTTOM); actions:SetTall(LocalPlayer():IsAdmin() and 252 or 176); actions.Paint=function() end
 local create=row(actions)
 local new=button(create,"Новая",function() self:ConfirmDiscard(function() self:NewClip(true) end) end); new:Dock(LEFT); new:SetWide(82)
 local copy=button(create,"Копия",function() self:Duplicate() end); copy:Dock(FILL); copy:DockMargin(6,0,0,5)
 button(actions,"Поделиться",function()
  if self.dirty or not self.id then return self:Message("Сначала сохраните изменения.") end
  S.Request({op="submit",id=self.id})
 end)
 button(actions,"Удалить",function()
  if self.saving then return self:Message("Дождитесь завершения сохранения.") end
  if not self.id then return end
  Derma_Query("Удалить эту анимацию?","Удаление","Удалить",function() S.Request({op="delete",id=self.id}) end,"Отмена")
 end)
 if LocalPlayer():IsAdmin() then
  button(actions,"Одобрить публикацию",function() if self.id then S.Request({op="approve",id=self.id}) end end)
  button(actions,"Снять / отклонить",function() if self.id then S.Request({op="reject",id=self.id}) end end)
 end
 local pages=row(actions)
 local prev=button(pages,"‹",function() self.page=math.max(1,self.page-1); self:List() end); prev:Dock(LEFT); prev:SetWide(38)
 self.pages=label(pages,"1 / 1"); self.pages:Dock(FILL); self.pages:SetContentAlignment(5)
 local nextPage=button(pages,"›",function() self.page=self.page+1; self:List() end); nextPage:Dock(RIGHT); nextPage:SetWide(38)
 self.library=self.left:Add("DScrollPanel"); self.library:Dock(FILL); self.library:DockMargin(0,4,0,8)
end
function PANEL:List() S.Request({op="list",mode=self.mode,page=self.page}) end
function PANEL:Catalog(data)
 self.mode=data.mode; self.page=data.page; self.catalogProps=data.props
 self.pages:SetText(data.page.." / "..data.pages.."  ·  "..data.count.."/30")
 self.library:Clear()
 if #data.rows==0 then label(self.library,"Здесь пока нет анимаций") end
 local status={private="Личная",pending="На проверке",approved="Общая"}
 for _,record in ipairs(data.rows) do
  local b=button(self.library,record.name,function()
   self:ConfirmDiscard(function() S.Request({op="load",id=record.id}) end)
  end)
  b:SetTall(52); b:SetTooltip(record.name.."\n"..record.model.."\n"..record.author.." · "..status[record.status].." · #"..record.id)
  b.Paint=function(self,w,h)
   draw.RoundedBox(4,0,0,w,h,self:IsHovered() and Color(29,49,62) or C.raised)
   surface.SetDrawColor(record.status=="approved" and C.accent or C.line); surface.DrawRect(0,8,2,h-16)
   draw.SimpleText(record.name,"ixPoseText",9,9,C.text)
   draw.SimpleText(status[record.status].." · #"..record.id,"ixPoseSmall",9,32,C.muted)
  end
 end
 self:RefreshPropChoices()
end
function PANEL:BuildInspector()
 label(self.right,"КОСТИ CELLAR И РЕКВИЗИТ"):SetTooltip("Только общие кости тела и пальцев. Служебные кости, одежда и аксессуары скрыты во всех режимах. Сохранённые ключи скрытых костей не удаляются.")
 local scope=row(self.right,30)
 self.compatibility=scope:Add("DComboBox"); self.compatibility:Dock(FILL)
 self.compatibility:AddChoice("Совместимость: только эта модель",false); self.compatibility:AddChoice("Совместимость: гуманоиды",true)
 self.compatibility:SetTooltip("Гуманоиды: перенос движений с учётом пропорций. Основа сохраняется вместе с позой; модель автора не требуется. Отсутствующие пальцы пропускаются; кость реквизита обязательна.")
 self.compatibility.OnSelect=function(_,_,_,value) if not self.updating then self:ChangeScope(value,self.clip.mask or "full") end end
 local body=row(self.right,30)
 self.bodyMask=body:Add("DComboBox"); self.bodyMask:Dock(FILL)
 self.bodyMask:AddChoice("Всё тело · размещение","full"); self.bodyMask:AddChoice("Верх тела · свободная ходьба","upper")
 self.bodyMask.OnSelect=function(_,_,_,value) if not self.updating then self:ChangeScope(self.clip.portable==true,value) end end
 self.targetPreview=button(self.right,"Образец: моя модель",function() self:TogglePreviewModel() end)
 self.legPreview=self.right:Add("DComboBox"); self.legPreview:Dock(TOP); self.legPreview:SetTall(28); self.legPreview:DockMargin(0,0,0,4)
 for _,choice in ipairs({{"Ноги: стоять","idle"},{"Ноги: идти","walk"},{"Ноги: бежать","run"},{"Ноги: присесть","crouch"}}) do self.legPreview:AddChoice(choice[1],choice[2]) end
 self.legPreview.OnSelect=function(_,_,_,value) self.previewLegs=value end
 self.search=entry(self.right,""); self.search:SetPlaceholderText("Поиск кости…")
 self.search.OnChange=function() self:FillBones() end
 self.bones=self.right:Add("DScrollPanel"); self.bones:Dock(TOP); self.bones:SetTall(math.Clamp(ScrH()*.22,120,215)); self.bones:DockMargin(0,0,0,8)
 self.inspector=self.right:Add("DScrollPanel"); self.inspector:Dock(FILL)
 self.selection=label(self.inspector,"Выберите кость"); self.selection:SetTextColor(C.accent)
 self.symmetryButton=button(self.inspector,"Симметрия: выкл",function()
  self.viewport:OnMouseReleased();self.editControl=nil;self.symmetry=not self.symmetry;self:RefreshFields()
 end)
 self.symmetryButton:SetTooltip("Правки одной руки, ноги или пальца отражаются на парной кости. Работает для поворота, смещения, сброса, целей и пресетов кистей. Уже заданная основа не меняется. Ctrl+Z отменяет обе стороны; реквизит не копируется.")
 self.targetModeButton=button(self.inspector,"Цели кистей / стоп: выкл",function()
  self.viewport:OnMouseReleased();self.targetMode=not self.targetMode;self.playing=false
  self:RefreshFields()
 end)
 self.targetModeButton:SetTooltip("Тяните кисть или стопу в окне модели: локоть/колено следуют за ней. Удерживая ЛКМ, вращайте колесо для направления сгиба. Shift — точнее. Правки сохраняются в текущий кадр; Ctrl+Z — отмена.")
 local mode=row(self.inspector)
 self.modeButton=button(mode,"Вращение",function() self.moveMode=not self.moveMode; self.modeButton.caption=self.moveMode and "Смещение" or "Вращение"; self:RefreshFields() end)
 self.modeButton:Dock(LEFT); self.modeButton:SetWide(104)
 self.axisButtons={}
 for i,name in ipairs({"P","Y","R"}) do
  local b=button(mode,name,function() self.axis=i; self:RefreshFields() end); b:Dock(LEFT); b:SetWide(34); b:DockMargin(4,0,0,5)
  self.axisButtons[i]=b
  b.Think=function() b.active=self.axis==i end
 end
 self.fields={}
 for _,spec in ipairs({{"a","ПОВОРОТ · ГРАДУСЫ",180},{"p","СМЕЩЕНИЕ · ЕДИНИЦЫ",48}}) do
  label(self.inspector,spec[2])
  for i,axis in ipairs(spec[1]=="a" and {"P","Y","R"} or {"X","Y","Z"}) do
   local slider=self.inspector:Add("DNumSlider"); slider:Dock(TOP); slider:SetTall(29); slider:SetText(axis)
   slider:SetMinMax(-spec[3],spec[3]); slider:SetDecimals(2); slider.Label:SetTextColor(C.muted)
   slider.OnValueChanged=function(control,value)
    if self.updating then return end
    local t=table.Copy(self:CurrentTransform(false) or S.Identity())
    local bound=spec[1]=="p" and not self.selectedProp and S.BonePositionLimit(self.selectedBone) or spec[3]
    t[spec[1]][i]=math.Clamp(value,-bound,bound);self:SetSelectedTransform(t,control)
   end
   self.fields[#self.fields+1]={panel=slider,key=spec[1],axis=i}
  end
 end
 button(self.inspector,"Сбросить выбранное",function()
  if self:SetSelectedTransform(nil,true) then self:RefreshFields() end
 end)
 label(self.inspector,"ИНСТРУМЕНТЫ ПОЗЫ")
 button(self.inspector,"Зеркало выбранной ветви",function()
  if not self.selectedBone or self.selectedProp then return self:Message("Выберите кость; будет скопирована её ветвь на другую сторону.") end
  local selected=self.selectedBone
  self:RunPoseTool(function(reference,clip,bones) return S.MirrorPoseBones(reference,clip,bones,selected) end)
 end)
 button(self.inspector,"Отразить правки кадра",function()
  self:RunPoseTool(function(reference,clip,bones) return S.MirrorPoseBones(reference,clip,bones) end)
 end)
 button(self.inspector,"Пресеты кистей…",function() self:HandPresetMenu() end)
 self.hingeHint=label(self.inspector,"");self.hingeHint:SetTall(40);self.hingeHint:SetWrap(true)
 self.hingeHint:SetTooltip("Геометрический угол между сегментами сохранённой основы. Это ориентир; свободное редактирование сохраняется.")
 label(self.inspector,"ОСНОВА")
 self.base=self.inspector:Add("DComboBox"); self.base:Dock(TOP); self.base:SetTall(30); self.base:DockMargin(0,0,0,4)
 self.base.OnSelect=function(_,_,_,value) if not self.updating then self:Checkpoint(true); self.clip.base=value;self.clip.reference=nil;self.referenceCaptureClip=self.clip; self:Dirty() end end
 self.cycle=self.inspector:Add("DNumSlider"); self.cycle:Dock(TOP); self.cycle:SetTall(30); self.cycle:SetText("Кадр основы"); self.cycle:SetMinMax(0,1); self.cycle:SetDecimals(2); self.cycle.Label:SetTextColor(C.muted)
 self.cycle.OnValueChanged=function(_,v) if not self.updating then self:Checkpoint(); self.clip.cycle=v;self.clip.reference=nil;self.referenceCaptureClip=self.clip; self:Dirty() end end
 label(self.inspector,"РЕКВИЗИТ · ДО 3 ПРЕДМЕТОВ")
 self.propChoices=self.inspector:Add("DComboBox"); self.propChoices:Dock(TOP); self.propChoices:SetTall(30)
 self.propChoices.OnSelect=function(_,_,_,model) self.propModel=model end
 button(self.inspector,"Прикрепить к выбранной кости",function() self:AddProp() end)
 self.propList=self.inspector:Add("DPanel"); self.propList:Dock(TOP); self.propList:SetTall(0); self.propList.Paint=function() end
 self.scale=self.inspector:Add("DNumSlider"); self.scale:Dock(TOP); self.scale:SetTall(30); self.scale:SetText("Масштаб"); self.scale:SetMinMax(.25,2); self.scale:SetDecimals(2); self.scale.Label:SetTextColor(C.muted)
 self.scale.OnValueChanged=function(_,v) if not self.updating and self.selectedProp then self:Checkpoint(); self.clip.props[self.selectedProp].scale=v; self:Dirty() end end
 self.skin=self.inspector:Add("DNumSlider"); self.skin:Dock(TOP); self.skin:SetTall(30); self.skin:SetText("Скин"); self.skin:SetMinMax(0,32); self.skin:SetDecimals(0); self.skin.Label:SetTextColor(C.muted)
 self.skin.OnValueChanged=function(_,v) if not self.updating and self.selectedProp then self:Checkpoint(); self.clip.props[self.selectedProp].skin=math.Round(v); self:Dirty() end end
 button(self.inspector,"Убрать выбранный реквизит",function()
  if not self.selectedProp then return end
  self:Checkpoint(true); table.remove(self.clip.props,self.selectedProp); self.selectedProp=nil
  S.ClearProps(self.viewport.state); self:Dirty(); self:RefreshProps(); self:RefreshFields()
 end)
end
function PANEL:BuildTimeline()
 self.timeline=self.center:Add("DPanel"); self.timeline:Dock(BOTTOM); self.timeline:SetTall(148); self.timeline:DockMargin(0,10,0,0)
 self.timeline:DockPadding(0,0,0,0); self.timeline.Paint=function() end
 local controls=row(self.timeline)
 local specs={{"▶ / Ⅱ",function() self:Preview() end,66},{"+ Кадр",function() self:AddFrame() end,82},
  {"− Кадр",function() self:DeleteFrame() end,82},{"↶",function() self:Undo() end,38},
  {"Кости",function() self.viewport.showBones=not self.viewport.showBones end,65},
  {"Обзор",function() self.viewport:Fit() end,65}}
 for _,spec in ipairs(specs) do local b=button(controls,spec[1],spec[2]); b:Dock(LEFT); b:SetWide(spec[3]); b:DockMargin(0,0,4,5) end
 local playback=row(self.timeline)
 self.loop=button(playback,"Цикл",function() self:Checkpoint(true); self.clip.loop=not self.clip.loop; self:Dirty(); self:RefreshFields() end); self.loop:Dock(LEFT); self.loop:SetWide(70)
 self.smooth=button(playback,"Плавно",function() self:Checkpoint(true); self.clip.smooth=not self.clip.smooth; self:Dirty(); self:RefreshFields() end); self.smooth:Dock(LEFT); self.smooth:SetWide(80); self.smooth:DockMargin(4,0,4,5)
 self.duration=playback:Add("DNumberWang"); self.duration:Dock(LEFT); self.duration:SetWide(60); self.duration:SetMinMax(.1,5); self.duration:SetDecimals(2)
 self.duration.OnValueChanged=function(_,v) if not self.updating and self.clip then self:Checkpoint(); self.clip.frames[self.frame].duration=math.Clamp(tonumber(v) or 1,.1,5); self:Dirty() end end
 local seconds=label(playback,"сек."); seconds:Dock(LEFT); seconds:SetWide(37)
 self.speedChoice=playback:Add("DComboBox"); self.speedChoice:Dock(LEFT); self.speedChoice:SetWide(73); self.speedChoice:SetValue("1×")
 for _,speed in ipairs({.25,.5,1,2}) do self.speedChoice:AddChoice(speed.."×",speed) end
 self.speedChoice.OnSelect=function(_,_,_,speed) self.speed=speed; if self.playing then self.playStarted=RealTime() end end
 local stop=button(playback,"Стоп в мире",function() S.Request({op="stop"}) end); stop:Dock(FILL); stop:DockMargin(4,0,0,5)
 self.frames=self.timeline:Add("DHorizontalScroller"); self.frames:Dock(FILL)
end
function PANEL:RefreshTimeline()
 self.frames:Clear()
 for i in ipairs(self.clip.frames) do
  local b=button(self.frames,tostring(i),function() self.playing=false; self.frame=i; self:RefreshFields() end)
  b:Dock(NODOCK); b:SetWide(65); self.frames:AddPanel(b)
  b.DoRightClick=function()
   local menu=DermaMenu()
   menu:AddOption("Дублировать",function() self.frame=i; self:AddFrame() end)
   menu:AddOption("Удалить",function() self.frame=i; self:DeleteFrame() end)
   if i>1 then menu:AddOption("Сдвинуть влево",function() self:MoveFrame(i,-1) end) end
   if i<#self.clip.frames then menu:AddOption("Сдвинуть вправо",function() self:MoveFrame(i,1) end) end
   menu:Open()
  end
  b.Paint=function(_,w,h)
   local active=(self.playing and self.playFrame or self.frame)==i
   draw.RoundedBox(5,1,1,w-3,h-4,active and Color(28,75,80) or C.panel)
   surface.SetDrawColor(active and C.accent or C.line); surface.DrawOutlinedRect(1,1,w-3,h-4)
   draw.SimpleText(string.format("%02d",i),"ixPoseTitle",10,7,active and C.accent or C.text)
   draw.SimpleText(string.format("%.2f с",self.clip.frames[i].duration),"ixPoseSmall",10,h-23,C.muted)
  end
 end
end
function PANEL:FillBones()
 if not IsValid(self.viewport) or not IsValid(self.viewport.Entity) then return end
 self.bones:Clear()
 local query=self.search:GetValue():lower()
 local entity=self.viewport.Entity
 entity:SetupBones()
 self.viewport.boneListCount=entity:GetBoneCount() or 0
 for i=0,math.min(self.viewport.boneListCount,256)-1 do
  local name=entity:GetBoneName(i)
  if name~="__INVALIDBONE__" and S.EditableBone(self.clip,name) and (query=="" or (boneLabel(name).." "..name):lower():find(query,1,true)) then
   local b=button(self.bones,boneLabel(name),function() self:SelectBone(name) end); b:SetTall(26); b:DockMargin(0,0,0,2); b:SetTooltip(name)
   b.Think=function() b.active=self.selectedBone==name and not self.selectedProp end
  end
 end
end
function PANEL:SelectBone(name) if not S.EditableBone(self.clip,name) then return end; self.selectedBone=name; self.selectedProp=nil; self.playing=false; self:RefreshFields() end
function PANEL:ChangeScope(portable,mask)
 if self.clip.portable==portable and (self.clip.mask or "full")==mask then return end
 local original=self.clip
 local nextClip=table.Copy(original); nextClip.portable=portable; nextClip.mask=mask
 local removed=0
 for _,frame in ipairs(nextClip.frames) do
  for name in pairs(frame.bones) do
   if not S.BoneAllowed(nextClip,name) then frame.bones[name]=nil; removed=removed+1 end
  end
 end
 for i=#nextClip.props,1,-1 do
  if not S.BoneAllowed(nextClip,nextClip.props[i].bone) then table.remove(nextClip.props,i); removed=removed+1 end
 end
 if S.Layered(nextClip) then
  local valid,err=S.ModelSupports(LocalPlayer(),nextClip)
  if not valid then self:RefreshFields(); return self:Message(err) end
 end
 local function apply()
  if not IsValid(self) or self.clip~=original then return end
  self:Checkpoint(true); self.clip=nextClip; self.previewTarget=portable==true;self.referenceCaptureClip=nextClip
  self.selectedBone=nil; self.selectedProp=nil; self.playing=false
  self.viewport:LoadClip(self.clip)
  self:Dirty(); self:FillBones(); self:RefreshProps(); self:RefreshFields()
 end
 self:RefreshFields()
 if removed>0 then
  Derma_Query("При смене режима будут убраны неподдерживаемые кости и реквизит ("..removed.."). Изменение можно отменить через Ctrl+Z.",
   "Смена режима анимации","Продолжить",apply,"Отмена")
 else apply() end
end
function PANEL:TogglePreviewModel()
 if not self.clip.portable then return end
 if self.previewTarget and not authorModelAvailable(self.clip) then return self:Message("Модель автора не установлена. Поза доступна на вашей модели.") end
 if not self.previewTarget then
  local valid,err=S.ModelSupports(LocalPlayer(),self.clip)
  if not valid then return self:Message(err) end
 end
 self.previewTarget=not self.previewTarget
 self.selectedBone=nil; self.selectedProp=nil
 self.viewport:LoadClip(self.clip); self:FillBones(); self:RefreshFields()
end
function PANEL:CurrentTransform(create)
 if self.selectedProp then return self.clip.props[self.selectedProp] end
 if not self.selectedBone or not S.EditableBone(self.clip,self.selectedBone) then return end
 local bones=self.clip.frames[self.frame].bones
 if create and not bones[self.selectedBone] then bones[self.selectedBone]=S.Identity() end
 return bones[self.selectedBone]
end
function PANEL:EditCheckpoint(control)
 if control==false then return end -- Viewport drag already owns one checkpoint.
 if type(control)=="table" or type(control)=="Panel" then
  if self.editControl~=control or self.editFrame~=self.frame or self.editBone~=self.selectedBone or self.editProp~=self.selectedProp then
   self:Checkpoint(true);self.editControl=control;self.editFrame=self.frame;self.editBone=self.selectedBone;self.editProp=self.selectedProp
  end
 else self.editControl=nil;self:Checkpoint(true) end
end
function PANEL:CommitBoneEdit(bones,edited,control,reference)
 if self.symmetry then
  local result,err=S.MirrorEditedBones(reference or S.ToolReference(self.clip,self.viewport and self.viewport.Entity),self.clip,bones,edited)
  if not result then self:Message(err);return false end
  bones=result
 end
 self:EditCheckpoint(control)
 self.clip.frames[self.frame].bones=bones;self:Dirty();return true
end
function PANEL:SetSelectedTransform(value,control)
 if self.selectedProp then
  local prop=self.clip.props[self.selectedProp];if not prop then return false end
  self:EditCheckpoint(control)
  prop.a=table.Copy(value and value.a or {0,0,0});prop.p=table.Copy(value and value.p or {0,0,0})
  self:Dirty();return true
 end
 if not self.selectedBone or not S.EditableBone(self.clip,self.selectedBone) then return false end
 local bones=table.Copy(self.clip.frames[self.frame].bones);bones[self.selectedBone]=value and table.Copy(value) or nil
 return self:CommitBoneEdit(bones,{self.selectedBone},control)
end
function PANEL:RefreshHingeHint()
 if not IsValid(self.hingeHint) then return end
 local part=(self.selectedBone or ""):match("^ValveBiped%.Bip01_[LR]_(.+)$")
 local guidance
 if self.clip and not self.selectedProp and (part=="Forearm" or part=="Calf") and S.ToolReference then
  guidance=S.HingeGuidance(S.ToolReference(self.clip,self.viewport and self.viewport.Entity),self.clip.frames[self.frame].bones,self.selectedBone)
 end
 self.hingeHint:SetText(guidance and string.format("%s: %.1f° · ориентир 0–%d°",guidance.label,guidance.degrees,guidance.max) or "")
 self.hingeHint:SetTextColor(guidance and guidance.outside and C.gold or C.muted)
end
function PANEL:RefreshFields()
 if not self.clip then return end
 self.updating=true
 if self.symmetryButton then self.symmetryButton.caption=self.symmetry and "Симметрия: вкл" or "Симметрия: выкл";self.symmetryButton.active=self.symmetry end
 if self.targetModeButton then self.targetModeButton.caption=self.targetMode and "Цели кистей / стоп: вкл" or "Цели кистей / стоп: выкл";self.targetModeButton.active=self.targetMode end
 for i,b in ipairs(self.axisButtons) do b.caption=(self.moveMode and {"X","Y","Z"} or {"P","Y","R"})[i] end
 self.name:SetText(self.clip.name)
 self.compatibility:SetValue(self.clip.portable and "Совместимость: гуманоиды" or "Совместимость: только эта модель")
 self.bodyMask:SetValue(self.clip.mask=="upper" and "Верх тела · свободная ходьба" or "Всё тело · размещение")
 self.apply.caption=self.clip.mask=="upper" and "Применить" or "Разместить"
 local authorAvailable=authorModelAvailable(self.clip)
 self.targetPreview:SetEnabled(self.clip.portable==true and self.clip.model~=LocalPlayer():GetModel():lower() and authorAvailable)
 self.targetPreview:SetTooltip(authorAvailable and "Сравнить свою модель с моделью автора. Сохранённая поза остаётся общей для гуманоидов." or "Модель автора не установлена. Поза открыта на вашей модели и доступна для редактирования.")
 self.targetPreview.caption=self.previewTarget and "Образец: моя модель" or "Образец: модель автора"
 self.legPreview:SetEnabled(self.clip.mask=="upper")
 self.legPreview:SetValue(({idle="Ноги: стоять",walk="Ноги: идти",run="Ноги: бежать",crouch="Ноги: присесть"})[self.previewLegs or "idle"])
 local t=self:CurrentTransform(false) or S.Identity()
 self.selection:SetText(self.selectedProp and "Реквизит #"..self.selectedProp or self.selectedBone and boneLabel(self.selectedBone) or "Выберите кость")
 for _,field in ipairs(self.fields) do
  field.panel:SetEnabled(self.selectedBone~=nil or self.selectedProp~=nil)
  if field.key=="p" then local bound=self.selectedProp and 48 or S.BonePositionLimit(self.selectedBone); field.panel:SetMinMax(-bound,bound) end
  field.panel:SetValue(t[field.key][field.axis])
 end
 self.scale:SetEnabled(self.selectedProp~=nil); self.scale:SetValue(t.scale or 1)
 self.skin:SetEnabled(self.selectedProp~=nil); self.skin:SetValue(t.skin or 0)
 self.cycle:SetValue(self.clip.cycle); self.base:SetValue(self.clip.base)
 self.duration:SetValue(self.clip.frames[self.frame].duration)
 self.loop.caption=self.clip.loop and "Цикл" or "Один раз"; self.loop.active=self.clip.loop
 self.smooth.caption=self.clip.smooth and "Плавно" or "Линейно"; self.smooth.active=self.clip.smooth
 self:RefreshHingeHint()
 self.updating=false
end
function PANEL:RefreshPropChoices()
 if not IsValid(self.propChoices) then return end
 self.propChoices:Clear(); self.propChoices:SetValue("Предмет / модель")
 for _,spec in ipairs(self.catalogProps) do self.propChoices:AddChoice(spec.name.." · "..spec.model,spec.model) end
end
function PANEL:RefreshProps()
 self.propList:Clear(); self.propList:SetTall(#self.clip.props*37)
 for i,prop in ipairs(self.clip.props) do
  local b=button(self.propList,i.." · "..string.GetFileFromFilename(prop.model),function() self.selectedProp=i; self.playing=false; self:RefreshFields() end)
  b:SetTooltip(prop.model.."\n"..prop.bone)
 end
end
function PANEL:AddProp()
 if not self.selectedBone or not S.EditableBone(self.clip,self.selectedBone) then return self:Message("Сначала выберите общую кость крепления.") end
 if not self.propModel then return self:Message("Выберите предмет из списка.") end
 if #self.clip.props>=S.limit.props then return self:Message("Максимум 3 предмета.") end
 self:Checkpoint(true)
 local prop=S.Identity(); prop.model=self.propModel; prop.bone=self.selectedBone; prop.scale=1; prop.skin=0
 self.clip.props[#self.clip.props+1]=prop; self.selectedProp=#self.clip.props
 self:Dirty(); self:RefreshProps(); self:RefreshFields()
end
function PANEL:RunPoseTool(operation)
 if not self.clip or self.saving then return self:Message("Дождитесь завершения сохранения.") end
 local request={clip=self.clip,frame=self.frame,text=util.TableToJSON(self.clip)}
 self.poseToolRequest=request;self.playing=false
 local attempts=0
 local function apply()
  if not IsValid(self) or self.poseToolRequest~=request then return end
  if self.clip~=request.clip or self.frame~=request.frame or util.TableToJSON(self.clip)~=request.text then
   self.poseToolRequest=nil;return self:Message("Инструмент отменён: кадр уже изменился.")
  end
  local reference=S.ToolReference(self.clip,self.viewport and self.viewport.Entity);attempts=attempts+1
  if not reference and attempts<5 then timer.Simple(.05,apply);return end
  self.poseToolRequest=nil
  if not reference then return self:Message("Скелет ещё не готов. Повторите инструмент через секунду.") end
  local bones,err,count,skipped,edited=operation(reference,self.clip,self.clip.frames[self.frame].bones)
  if not bones then return self:Message(err) end
  if self.symmetry and edited then
   local mirrored,problem=S.MirrorEditedBones(reference,self.clip,bones,edited)
   if not mirrored then return self:Message(problem) end
   bones=mirrored
  end
  local candidate=table.Copy(self.clip);candidate.frames[self.frame].bones=bones
  local valid,problem=S.Validate(candidate);if not valid then return self:Message(problem) end
  self:Checkpoint(true);self.clip.frames[self.frame].bones=bones
  self:Dirty();self:RefreshFields();self:RefreshTimeline()
  self:Message("Изменено костей: "..count..((skipped or 0)>0 and (". Недоступных костей пропущено: "..skipped) or "")..". Ctrl+Z — отменить.")
 end
 apply()
end
function PANEL:HandPresetMenu()
 local menu=DermaMenu()
 for _,group in ipairs({{name="Левая кисть",sides={"L"}},{name="Правая кисть",sides={"R"}},{name="Обе кисти",sides={"L","R"}}}) do
  local submenu=menu:AddSubMenu(group.name);local sides=group.sides
  for _,preset in ipairs(S.HAND_PRESETS or {}) do
   local id=preset.id
   submenu:AddOption(preset.label,function()
    local chosen=sides
    if self.symmetry and #sides==2 then chosen={(self.selectedBone or ""):match("^ValveBiped%.Bip01_([LR])_") or "L"} end
    self:RunPoseTool(function(reference,clip,bones) return S.ApplyHandPreset(reference,clip,bones,id,chosen) end)
   end)
  end
 end
 menu:Open()
end
function PANEL:StarterMenu()
 local menu=DermaMenu()
 for _,preset in ipairs(S.starterPoses or {}) do
  local id=preset.id
  menu:AddOption(preset.name,function()
   self:ConfirmDiscard(function()
    local request={clip=self.clip,text=util.TableToJSON(self.clip),id=self.id,revision=self.revision,model=LocalPlayer():GetModel()}
    self.starterRequest=request; self:Message("Подготовка стартовой позы…")
    S.CreateStarterClip(id,function(clip,err)
     if not IsValid(self) or self.starterRequest~=request then return end
     self.starterRequest=nil
     if self.clip~=request.clip or util.TableToJSON(self.clip)~=request.text or self.id~=request.id or self.revision~=request.revision
      or not IsValid(LocalPlayer()) or LocalPlayer():GetModel()~=request.model then return self:Message("Загрузка отменена: модель или черновик изменились.") end
     if not clip then return self:Message(err or "Не удалось создать позу.") end
     self.id=nil; self.revision=nil; self.owner=LocalPlayer():SteamID64()
     self:SetClip(clip); self:Dirty()
     self:Message("Стартовая поза открыта. Проверьте на своей модели и сохраните."..(preset.seated and " Высоту сиденья настройте при размещении." or ""))
    end)
   end)
  end)
 end
 menu:Open()
end
function PANEL:NewClip(force)
 local entity=LocalPlayer()
 local base=entity:GetSequenceName(entity:GetSequence())
 for _,name in ipairs({"idle_all_01","idle_unarmed","idle01","idle"}) do if entity:LookupSequence(name)>=0 then base=name; break end end
 local rig=ix.sharedPoses and ix.sharedPoses.Rig(entity:GetModel():lower())
 local clip={portable=S.RigMap(rig,rig)~=nil,mask="full",name="Новая анимация",model=entity:GetModel():lower(),base=base,cycle=0,loop=true,smooth=true,frames={{duration=1,bones={}}},props={}}
 self.id=nil; self.revision=nil; self.owner=entity:SteamID64(); self:SetClip(clip); self.dirty=false
end
function PANEL:SetClip(clip)
 self.previewTarget=clip.portable==true; self.previewLegs="idle";self.editControl=nil
 self.clip=table.Copy(clip); self.frame=1; self.selectedBone=nil; self.selectedProp=nil; self.playing=false; self.undo={}
 self.referenceCaptureClip=self.clip
 self.viewport:LoadClip(self.clip)
 self.base:Clear()
 local entity=self.viewport.Entity
 local reference=S.ReferenceEntity(self.clip)
 if not IsValid(reference) then reference=entity end
 if IsValid(reference) then
  for _,name in ipairs(reference:GetSequenceList()) do self.base:AddChoice(name,name) end
 end
 self:FillBones(); self:RefreshProps(); self:RefreshFields(); self:RefreshTimeline()
end
function PANEL:Checkpoint(force)
 if not force and (self.lastUndo or 0)>RealTime() then return end
 self.lastUndo=RealTime()+.4
 self.undo[#self.undo+1]={clip=table.Copy(self.clip),frame=self.frame}
 if #self.undo>40 then table.remove(self.undo,1) end
end
function PANEL:Undo()
 local checkpoint=table.remove(self.undo)
 if not checkpoint then return end
 if IsValid(self.viewport) then self.viewport:OnMouseReleased() end
 self.clip=checkpoint.clip; self.frame=checkpoint.frame; self.playing=false; self.selectedProp=nil;self.editControl=nil;self.referenceCaptureClip=self.clip
 if not self.clip.portable then self.previewTarget=false end
 if IsValid(self.viewport) then self.viewport:LoadClip(self.clip)
 else self.viewport.state.clip=self.clip; S.ClearProps(self.viewport.state) end
 if self.selectedBone and not S.EditableBone(self.clip,self.selectedBone) then self.selectedBone=nil end
 if IsValid(self.viewport) then self:FillBones() end
 self:Dirty(); self:RefreshProps(); self:RefreshFields(); self:RefreshTimeline()
end
function PANEL:AddFrame()
 if #self.clip.frames>=S.limit.frames then return self:Message("Максимум 24 ключевых кадра.") end
 self:Checkpoint(true); table.insert(self.clip.frames,self.frame+1,table.Copy(self.clip.frames[self.frame])); self.frame=self.frame+1
 self:Dirty(); self:RefreshFields(); self:RefreshTimeline()
end
function PANEL:DeleteFrame()
 if #self.clip.frames==1 then return self:Message("Один кадр нужен для статичной позы.") end
 self:Checkpoint(true); table.remove(self.clip.frames,self.frame); self.frame=math.min(self.frame,#self.clip.frames)
 self:Dirty(); self:RefreshFields(); self:RefreshTimeline()
end
function PANEL:MoveFrame(index,delta)
 local target=index+delta
 if target<1 or target>#self.clip.frames then return end
 self:Checkpoint(true); local frames=self.clip.frames
 frames[index],frames[target]=frames[target],frames[index]; self.frame=target
 self:Dirty(); self:RefreshFields(); self:RefreshTimeline()
end
function PANEL:Preview()
 self.playing=not self.playing; self.playStarted=RealTime(); self.playFrame=1
end
function PANEL:Duplicate()
 if self.saving then return self:Message("Дождитесь завершения сохранения.") end
 if self.owner~=LocalPlayer():SteamID64() then
  if self.dirty then return self:Message("Для импорта откройте сохранённую общую анимацию заново.") end
  S.Request({op="import",id=self.id}); return
 end
 self.id=nil; self.revision=nil; self.clip.name=self.clip.name.." — копия"; self:Dirty(); self:RefreshFields()
end
function PANEL:Save(referenceRequest)
 if self.owner~=LocalPlayer():SteamID64() then self.applyAfterSave=nil; return self:Message("Сначала создайте личную копию общей анимации.") end
 if self.saving then return end
 if referenceRequest then
  if self.saveReferenceRequest~=referenceRequest then return end
  if self.clip~=referenceRequest.clip or self.id~=referenceRequest.id or self.revision~=referenceRequest.revision or util.TableToJSON(self.clip)~=referenceRequest.text then
   self.saveReferenceRequest=nil;self.applyAfterSave=nil;return self:Message("Сохранение отменено: черновик изменился. Сохраните новые правки.")
  end
 elseif self.saveReferenceRequest then return end
 if S.Layered(self.clip) and S.CaptureReference then
  local captured,reason,loading=S.CaptureReference(self.clip,self.viewport.Entity)
  if not captured then
   local request=referenceRequest or {clip=self.clip,id=self.id,revision=self.revision,text=util.TableToJSON(self.clip),attempts=0}
   request.attempts=request.attempts+1
   if loading and request.attempts<15 then
    self.saveReferenceRequest=request;self:Message("Подготовка переносимой основы…")
    timer.Simple(.1,function() if IsValid(self) then self:Save(request) end end);return
   end
   self.saveReferenceRequest=nil;self.applyAfterSave=nil;return self:Message(reason or "Не удалось сохранить основу. Повторите через секунду.")
  end
 end
 self.saveReferenceRequest=nil;self.referenceCaptureClip=nil
 local clean,err=S.Validate(self.clip)
 if not clean then self.applyAfterSave=nil; return self:Message(err) end
 if #util.TableToJSON(clean)>S.limit.bytes then self.applyAfterSave=nil; return self:Message("Лимит 48 КБ: уменьшите число костей или кадров.") end
 self.saving=true; self.sentClip=util.TableToJSON(self.clip); self.saveAt=RealTime()
 if not S.Request({op="save",id=self.id,revision=self.revision,clip=clean}) then self.saving=false; self.applyAfterSave=nil end
end
function PANEL:Dirty()
 self.dirty=true; self.playing=false; self.draftAt=RealTime()+1
 -- Sliders update the draft without RefreshFields to preserve their drag state.
 self:RefreshHingeHint()
end
function PANEL:Message(text) self.message=text; self.messageUntil=RealTime()+7 end
function PANEL:ConfirmDiscard(callback)
 if self.saving then return self:Message("Дождитесь завершения сохранения.") end
 if self.dirty then Derma_Query("Несохранённые изменения будут заменены. Продолжить?","Редактор поз","Продолжить",callback,"Отмена") else callback() end
end
function PANEL:DraftPath()
 return "ix_pose_studio/draft_"..LocalPlayer():SteamID64()..".json"
end
function PANEL:WriteDraft()
 if not self.dirty or not self.clip then return end
 file.CreateDir("ix_pose_studio")
 local text=util.TableToJSON({clip=self.clip,id=self.id,revision=self.revision,owner=self.owner})
 if text and #text<50000 then file.Write(self:DraftPath(),text) end
end
function PANEL:OfferDraft()
 local text=file.Read(self:DraftPath(),"DATA")
 if not text or #text>50000 then return end
 local data=util.JSONToTable(text); local clip=istable(data) and S.Validate(data.clip)
 if not clip then return end
 Derma_Query("Восстановить несохранённый черновик?","Редактор поз","Восстановить",function()
  if IsValid(self) then self.id=data.id; self.revision=data.revision; self.owner=data.owner; self:SetClip(clip); self:Dirty() end
 end,"Пропустить")
end
function PANEL:Think()
 if not IsValid(LocalPlayer()) or not LocalPlayer():GetCharacter() or LocalPlayer():GetCharacter()~=self.character then self:Close(); return end
 local undo=input.IsKeyDown(KEY_LCONTROL) and input.IsKeyDown(KEY_Z)
 local focus=vgui.GetKeyboardFocus()
 if undo and not self.undoHeld and (not IsValid(focus) or focus:GetClassName()~="DTextEntry") then self:Undo() end
 self.undoHeld=undo
 if self.editControl and (not IsValid(self.editControl) or not self.editControl.IsEditing or not self.editControl:IsEditing()) then self.editControl=nil end
 if not self.saveReferenceRequest and self.referenceCaptureClip==self.clip and S.CaptureReference and (self.nextReferenceCapture or 0)<=RealTime() then
  self.nextReferenceCapture=RealTime()+.25
  if not S.Layered(self.clip) or S.CaptureReference(self.clip,self.viewport.Entity) then self.referenceCaptureClip=nil end
 end
 if self.draftAt and RealTime()>self.draftAt then self.draftAt=nil; self:WriteDraft() end
 if self.messageUntil and RealTime()>self.messageUntil then self.message=nil end
 if self.saving and RealTime()-self.saveAt>8 then self.saving=false; self.applyAfterSave=nil; self:Message("Нет ответа сервера. Черновик сохранён локально; попробуйте снова.") end
 self.save.caption=self.saveReferenceRequest and "Подготовка…" or self.saving and "Сохранение…" or "Сохранить"
end
function PANEL:OnRemove() self:WriteDraft(); if S.editor==self then S.editor=nil end end
vgui.Register("ixPoseStudio",PANEL,"DFrame")

net.Receive("ixPoseStudioOpen",function()
 S.CancelPlacement()
 if IsValid(S.editor) then S.editor:Remove() end
 S.editor=vgui.Create("ixPoseStudio")
end)
net.Receive("ixPoseStudioReply",function()
 local size=net.ReadUInt(16)
 if size>60000 then return end
 local data=util.JSONToTable(net.ReadData(size) or "")
 if not istable(data) then return end
 if data.kind=="preview" then S.ReceivePreview(data); return end
 if data.kind=="placed" then return end
 if data.kind=="radial" then if S.ReceiveRadial then S.ReceiveRadial(data) end; return end
 local e=S.editor
 if data.kind=="error" then
  notification.AddLegacy(data.message,NOTIFY_ERROR,5)
  if IsValid(e) then e.saving=false; e.applyAfterSave=nil; e:Message(data.message) end
  return
 end
 if not IsValid(e) then return end
 if data.kind=="catalog" then e:Catalog(data)
 elseif data.kind=="loaded" or data.kind=="saved" then
  local record=data.row; local clip=S.Validate(record.clip)
  if not clip then return end
  local changedWhileSaving=data.kind=="saved" and e.saving and util.TableToJSON(e.clip)~=e.sentClip
  e.id=record.id; e.revision=record.revision; e.owner=record.owner; e.saving=false
  if not changedWhileSaving then e:SetClip(clip); e.dirty=false; file.Delete(e:DraftPath()) end
  e:Message(changedWhileSaving and "Сохранено. Последние изменения ещё не отправлены." or data.kind=="saved" and "Сохранено." or "Анимация загружена.")
  if data.kind=="saved" then e:List() end
  if e.applyAfterSave then
   e.applyAfterSave=nil
   if changedWhileSaving then e:Message("Есть новые изменения. Сохраните их перед размещением.") else e:PlaceSaved() end
  end
 elseif data.kind=="deleted" then e:NewClip(true); e:List()
 elseif data.kind=="status" then e:Message(data.message); e:List() end
end)
