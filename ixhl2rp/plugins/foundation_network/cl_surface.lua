local N=ix.FoundationNet
N.screenWidth=1920;N.screenHeight=1120;N.screenScale=56/1920
function N.SurfaceClip(panel,root)
 local left,top,right,bottom=0,0,N.screenWidth,N.screenHeight
 local current=panel
 while IsValid(current) do
  local x,y=current:LocalToScreen(0,0)
  left=math.max(left,x);top=math.max(top,y);right=math.min(right,x+current:GetWide());bottom=math.min(bottom,y+current:GetTall())
  if current==root then break end
  current=current:GetParent()
 end
 return left,top,math.max(left,right),math.max(top,bottom)
end
function N.ClipSurfaceTree(panel,root)
 -- PaintManual(true) is necessary above desktop resolution. Explicit ancestor
 -- intersections retain scroll-view clipping in that otherwise unclamped pass.
 for _,name in ipairs({'Paint','PaintOver'}) do
  local key='_foundationClip'..name
  if panel[name]~=panel[key] or not panel[key] then
   local paint=panel[name]
   local wrapper=function(self,w,h)
    local l,t,r,b=N.SurfaceClip(self,root);render.SetScissorRect(l,t,r,b,true)
    if r>l and b>t and paint then return paint(self,w,h) end
   end
   panel[key]=wrapper;panel[name]=wrapper
  end
 end
 for _,child in ipairs(panel:GetChildren()) do N.ClipSurfaceTree(child,root) end
end
function N.ScreenGeometry(ent)
 if ix.Facility and ix.Facility.IsScreen(ent) then return ix.Facility.PanelGeometry(ent) end
 local angle=ent:GetAngles();angle:RotateAroundAxis(ent:GetUp(),90);angle:RotateAroundAxis(ent:GetRight(),-90)
 return ent:GetPos()+ent:GetRight()*28+ent:GetUp()*35.2+ent:GetForward()*6.12,angle
end
function N.ScreenHit(panel,x,y)
 if not IsValid(panel) or not panel:IsVisible() or x<0 or y<0 or x>=panel:GetWide() or y>=panel:GetTall() then return end
 local children=panel:GetChildren()
 table.sort(children,function(a,b) return a:GetZPos()>b:GetZPos() end)
 for _,child in ipairs(children) do
  local cx,cy=child:GetPos();local hit,hx,hy=N.ScreenHit(child,x-cx,y-cy)
  if hit then return hit,hx,hy end
 end
 if panel.foundationControl and (not panel.IsEnabled or panel:IsEnabled()) then return panel,x,y end
end
function N.ScreenCursor(panel)
 if not IsValid(panel.entity) then return end
 local p=LocalPlayer();if not IsValid(p) or p:GetPos():DistToSqr(panel.entity:GetPos())>128^2 then return end
 local pos,angle,scale=N.ScreenGeometry(panel.entity);scale=scale or N.screenScale
 local view=render.GetViewSetup(false);if not view or not view.origin or not view.angles then return end
 local mx,my=input.GetCursorPos();local w,h=view.width or ScrW(),view.height or ScrH();if w<=0 or h<=0 then return end
 local aspect=view.aspect and view.aspect>0 and view.aspect or w/h;local tan=math.tan(math.rad((view.fov or 90)*.5))
 local a=view.angles;local direction=(a:Forward()+a:Right()*(((mx-(view.x or 0))/w*2-1)*tan)+a:Up()*((1-(my-(view.y or 0))/h*2)*tan/aspect)):GetNormalized()
 if direction:Dot(angle:Up())>=-.001 then return end
 local distance=(pos-view.origin):Dot(angle:Up())/direction:Dot(angle:Up());if distance<=0 then return end
 local hit=view.origin+direction*distance
 local filter={p};if panel.entity:GetClass()=="ix_facility_panel" then filter[#filter+1]=panel.entity:GetParent() end
 local tr=util.TraceLine({start=view.origin,endpos=hit,filter=filter,mask=MASK_SOLID})
 if tr.Hit and tr.Entity~=panel.entity then return end
 -- Match ix_loyalist_terminal's WorldToLocal(x, -y) convention.
 -- Source local +Y is LEFT, whereas Angle:Right() points along local -Y.
 local delta=hit-pos
 local x,y=delta:Dot(angle:Forward())/scale,delta:Dot(angle:Right())/scale
 if x<0 or y<0 or x>=N.screenWidth or y>=N.screenHeight then return end
 return x,y
end
function N.AttachSurface(panel)
 local host=vgui.Create('EditablePanel');host:SetSize(ScrW(),ScrH());host:MakePopup();host.Paint=function() end
 panel:SetParent(host);panel:SetPos(0,0);panel:SetKeyboardInputEnabled(true)
 local shield=vgui.Create('DPanel',host);shield:SetSize(ScrW(),ScrH());shield:SetZPos(32767);shield.Paint=function() end
 shield:SetMouseInputEnabled(true);shield:SetKeyboardInputEnabled(false)
 panel.inputHost=host;panel.viewAngles=LocalPlayer():EyeAngles()
 local pressed,hover,pending,dragX,dragY,dragKey
 local function target()
  if panel.bootAt and RealTime()-panel.bootAt<(panel.bootDuration or 0) then return end
  local x,y=N.ScreenCursor(panel)
  if x then
   if IsValid(panel.modal) then local px,py=panel.modal:GetPos();return N.ScreenHit(panel.modal,x-px,y-py) end
   local hit,hx,hy=N.ScreenHit(panel,x,y)
   if (panel.busyAt or panel.queuedPage) and hit~=panel.close then return end
   return hit,hx,hy
  end
 end
 host.Think=function(self)
  if not IsValid(panel) then self:Remove();return end
  self:SetSize(ScrW(),ScrH());shield:SetSize(ScrW(),ScrH())
  if input.IsKeyDown(KEY_ESCAPE) or gui.IsConsoleVisible() or gui.IsGameUIVisible() then panel:CloseSession();return end
  if IsValid(pending) and not input.IsMouseDown(MOUSE_LEFT) then
   local current=pending
   while IsValid(current) do current:SetKeyboardInputEnabled(true);if current==host then break end;current=current:GetParent() end
   shield:SetKeyboardInputEnabled(false);pending:RequestFocus();pending:SetCaretPos(utf8.len(pending:GetValue()) or #pending:GetValue());pending=nil
  end
  local hit=target()
  if hover~=hit then
   if IsValid(hover) then hover.foundationHover=false end
   hover=hit;if IsValid(hover) then hover.foundationHover=true end
  end
  shield:SetCursor(IsValid(hit) and (hit.foundationControl=='text' and 'beam' or 'hand') or 'arrow')
  if IsValid(pressed) and pressed.OnSurfaceDrag and dragKey and input.IsMouseDown(dragKey) then
   local x,y=N.ScreenCursor(panel)
   if x and dragX then pressed:OnSurfaceDrag(x-dragX,y-dragY,dragKey) end
   dragX,dragY=x,y
  end
  if IsValid(pressed) and pressed.foundationControl=='scroll' and input.IsMouseDown(MOUSE_LEFT) then
   local _,y=N.ScreenCursor(panel)
   if y then local _,top=pressed:LocalToScreen(0,0);pressed:SetScroll(math.Clamp((y-top)/pressed:GetTall(),0,1)*pressed.CanvasSize) end
  end
 end
 shield.OnMousePressed=function(self,key)
  local hit,hx,hy=target()
  if key~=MOUSE_LEFT and not (key==MOUSE_RIGHT and IsValid(hit) and hit.foundationControl=='map') then return end
  self:MouseCapture(true);pending=nil;pressed=hit;dragKey=key
  dragX,dragY=N.ScreenCursor(panel)
  if IsValid(pressed) and pressed.foundationControl=='text' then pending=pressed else host:RequestFocus() end
  if IsValid(pressed) and pressed.OnSurfacePressed then pressed:OnSurfacePressed(key,hx,hy) end
 end
 shield.OnMouseReleased=function(self,key)
  if key~=dragKey then return end
  self:MouseCapture(false);local prior=pressed;pressed=nil;dragX=nil;dragY=nil;dragKey=nil
  if IsValid(prior) and prior.OnSurfaceReleased then prior:OnSurfaceReleased(key) end
  if key==MOUSE_LEFT and IsValid(prior) and prior==target() and prior.foundationControl=='button' and prior.DoClick then prior:DoClick() end
 end
 shield.OnMouseWheeled=function(_,delta)
  local x=N.ScreenCursor(panel);if not x then return false end
  local hit=target()
  if IsValid(hit) and hit.OnSurfaceWheel then return hit:OnSurfaceWheel(delta) end
  if IsValid(hit) and hit.foundationControl=='text' and hit.foundationMultiline and hit.OnMouseWheeled and hit:OnMouseWheeled(delta) then return true end
  local current=hit
  while IsValid(current) and current~=panel do
   if current.GetVBar then current:GetVBar():AddScroll(-delta*1.5);return true end
   current=current:GetParent()
  end
  (IsValid(panel.modalScroll) and panel.modalScroll or panel.body):GetVBar():AddScroll(-delta*1.5);return true
 end
end
local rt,material
hook.Add('PostRender','FoundationSurface',function()
 if ix.CCTV and ix.CCTV.rendering then return end
 local panel=ix.gui.foundationNetwork
 if not IsValid(panel) or not IsValid(panel.entity) then return end
 if N.RenderMap then N.RenderMap(panel.mapPanel) end
 if not rt then
  rt=GetRenderTarget('foundation_surface_v3',2048,2048)
  material=CreateMaterial('foundation_surface_v3','UnlitGeneric',{['$basetexture']=rt:GetName(),['$vertexcolor']='1',['$vertexalpha']='1'})
 end
 render.PushRenderTarget(rt);render.Clear(12,13,15,255,true,true);cam.Start2D()
 local ok,err=xpcall(function() N.ClipSurfaceTree(panel,panel);panel:PaintManual(true) end,debug.traceback)
 render.SetScissorRect(0,0,0,0,false)
 cam.End2D();render.PopRenderTarget()
 panel.surfaceReady=ok
 if not ok and not panel.surfaceError then panel.surfaceError=true;ErrorNoHalt(err..'\n') end
end)
function N.DrawSurface(ent)
 local panel=ix.gui.foundationNetwork
 if not IsValid(panel) or panel.entity~=ent or not panel.surfaceReady or not material then return false end
 render.PushFilterMin(TEXFILTER.ANISOTROPIC);render.PushFilterMag(TEXFILTER.LINEAR)
 local ok,err=xpcall(function()
  surface.SetMaterial(material);surface.SetDrawColor(255,255,255)
  surface.DrawTexturedRectUV(0,0,N.screenWidth,N.screenHeight,0,0,N.screenWidth/rt:Width(),N.screenHeight/rt:Height())
 end,debug.traceback)
 render.PopFilterMag();render.PopFilterMin()
 if not ok then ErrorNoHalt(err..'\n') end
 return true
end
hook.Add('CreateMove','FoundationSurface',function(cmd)
 local p=ix.gui.foundationNetwork
 if IsValid(p) then cmd:ClearMovement();cmd:ClearButtons();if p.viewAngles then cmd:SetViewAngles(p.viewAngles) end end
end)
