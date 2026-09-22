local F=ix.Fieldlink
F.screenWidth=1024
F.screenHeight=576

-- Inverse projective mapping, not a bilinear approximation. Corner order is
-- UV top-left, top-right, bottom-right, bottom-left in the viewmodel render pass.
function F.ScreenUV(x,y,q)
 if not q or #q~=4 then return end
 local p,r,s,t=q[1],q[2],q[3],q[4]
 local dx1,dx2,dx3=r.x-s.x,t.x-s.x,p.x-r.x+s.x-t.x
 local dy1,dy2,dy3=r.y-s.y,t.y-s.y,p.y-r.y+s.y-t.y
 local det=dx1*dy2-dx2*dy1
 if math.abs(det)<0.000001 then return end
 local g=(dx3*dy2-dx2*dy3)/det
 local h=(dx1*dy3-dx3*dy1)/det
 local a,b=r.x-p.x+g*r.x,t.x-p.x+h*t.x
 local d,e=r.y-p.y+g*r.y,t.y-p.y+h*t.y
 a,b,d,e=a-x*g,b-x*h,d-y*g,e-y*h
 det=a*e-b*d
 if math.abs(det)<0.000001 then return end
 local u=((x-p.x)*e-b*(y-p.y))/det
 local v=(a*(y-p.y)-(x-p.x)*d)/det
 if u<-.000001 or u>1.000001 or v<-.000001 or v>1.000001 then return end
 return math.Clamp(u,0,1),math.Clamp(v,0,1)
end

-- Descending through clipped parents prevents offscreen scroll children from
-- stealing clicks. Only explicit device controls participate in input routing.
function F.ScreenHit(panel,x,y)
 if not IsValid(panel) or not panel:IsVisible() or x<0 or y<0 or x>=panel:GetWide() or y>=panel:GetTall() then return end
 local children=panel:GetChildren()
 for i=#children,1,-1 do
  local child=children[i]
  local cx,cy=child:GetPos()
  local hit,hx,hy=F.ScreenHit(child,x-cx,y-cy)
  if hit then return hit,hx,hy end
 end
 if panel.fieldlinkControl and (not panel.IsEnabled or panel:IsEnabled()) then return panel,x,y end
end

function F.ScreenCursor()
 if not F.screenQuad or RealTime()-(F.screenQuadAt or 0)>0.25 then return end
 local x,y=input.GetCursorPos()
 local u,v=F.ScreenUV(x,y,F.screenQuad)
 if u then return u*F.screenWidth,v*F.screenHeight end
end

function F.FocusScreenEditor(host,entry)
 if not IsValid(host) or not IsValid(entry) then return false end
 -- All ancestors must accept keyboard input, and the editor must belong to
 -- the active popup. A sibling popup cannot reliably acquire its focus.
 local parents={}; local current=entry
 while IsValid(current) do
  parents[#parents+1]=current
  if current==host then break end
  current=current:GetParent()
 end
 if current~=host then return false end
 for _,parent in ipairs(parents) do parent:SetKeyboardInputEnabled(true) end
 -- Enabling the host also enables its children. The shield is pointer-only.
 if IsValid(host.screenShield) then host.screenShield:SetKeyboardInputEnabled(false) end
 entry:RequestFocus()
 entry:SetCaretPos(utf8.len(entry:GetValue()) or #entry:GetValue())
 return true
end

function F.AttachScreenInput(panel)
 -- The input host is transparent. The UI itself never paints on the HUD.
 local host=vgui.Create("EditablePanel")
 host:SetSize(ScrW(),ScrH()); host:SetPos(0,0); host:MakePopup()
 panel:SetParent(host); panel:SetPos(0,0); panel:SetKeyboardInputEnabled(true)
 -- PaintManual changes rendering, not native hit testing. A sibling shield
 -- must sit above the entire hidden DFrame tree, including scroll canvases
 -- and controls created later, so desktop rectangles cannot steal clicks.
 local shield=vgui.Create("DPanel",host)
 shield:SetPos(0,0); shield:SetSize(ScrW(),ScrH()); shield:SetZPos(32767)
 shield:SetMouseInputEnabled(true); shield:SetKeyboardInputEnabled(false)
 shield.Paint=function() end
 host.screenShield=shield
 host.Paint=function() end
 host.OnRemove=function(self) self.fieldlinkRemoving=true end
 host.OnKeyCodePressed=function(_,key) if key==KEY_ESCAPE then panel:RequestClose() end end
 panel.inputHost=host
 local pressed,hover
 local function Target()
  if F.camera or panel.closing or not panel:IsDeviceReady() then return end
  local x,y=F.ScreenCursor()
  if x then return F.ScreenHit(panel,x,y) end
 end
 host.Think=function(self)
  if not IsValid(panel) then self:Remove(); return end
  self:SetSize(ScrW(),ScrH())
  shield:SetSize(ScrW(),ScrH())
  if F.camera then self.pendingEditor=nil; return end
  if panel.closing or not panel:IsDeviceReady() then self.pendingEditor=nil end
  -- Apply focus after VGUI finishes the mouse gesture; otherwise the native
  -- click on this transparent host can immediately take it back.
  if IsValid(self.pendingEditor) and not input.IsMouseDown(MOUSE_LEFT) then
   F.FocusScreenEditor(self,self.pendingEditor); self.pendingEditor=nil
  end
  local hit=Target()
  if hover~=hit then
   if IsValid(hover) then hover.fieldlinkHover=false; if hover.OnCursorExited then hover:OnCursorExited() end end
   hover=hit
   if IsValid(hover) then hover.fieldlinkHover=true; if hover.OnCursorEntered then hover:OnCursorEntered() end end
  end
  local cursor=IsValid(hit) and (hit.fieldlinkControl=="text" and "beam" or "hand") or "arrow"
  self:SetCursor(cursor); shield:SetCursor(cursor)
  if IsValid(pressed) and pressed.fieldlinkControl=="scroll" and input.IsMouseDown(MOUSE_LEFT) then
   local x,y=F.ScreenCursor()
   if x then local _,top=pressed:LocalToScreen(0,0); pressed:SetScroll(math.Clamp((y-top)/pressed:GetTall(),0,1)*pressed.CanvasSize) end
  end
 end
 host.OnMousePressed=function(self,key)
  if key~=MOUSE_LEFT then return end
  self.pendingEditor=nil
  local hit,_,hy=Target()
  if not IsValid(hit) then self:RequestFocus(); return end
  pressed=hit; hit.fieldlinkDown=true
  if hit.fieldlinkControl=="text" then
   self.pendingEditor=hit
   -- Keep native Unicode editing, selection keys, clipboard and caret handling.
   -- First touch opens the document at its end; subsequent keyboard navigation
   -- is handled by DTextEntry, not synthesized key events.
  else
   self:RequestFocus()
   if hit.fieldlinkControl=="scroll" then hit:SetScroll(math.Clamp(hy/hit:GetTall(),0,1)*hit.CanvasSize) end
  end
 end
 host.OnMouseReleased=function(_,key)
  if key~=MOUSE_LEFT then return end
  local hit=Target()
  local prior=pressed; pressed=nil
  if IsValid(prior) then
   prior.fieldlinkDown=false
   if prior==hit and prior.fieldlinkControl=="button" and prior.DoClick then prior:DoClick() end
  end
 end
 host.OnMouseWheeled=function(_,delta)
  local x,y=F.ScreenCursor()
  if not x or not panel:IsDeviceReady() then return false end
  local hit=F.ScreenHit(panel,x,y)
  if IsValid(hit) and hit.fieldlinkControl=="text" and hit.fieldlinkMultiline then
   if hit.OnMouseWheeled and hit:OnMouseWheeled(delta) then return true end
  end
  panel.body:GetVBar():AddScroll(-delta*1.5)
  return true
 end
 shield.OnMousePressed=function(_,key)
  if key==MOUSE_LEFT then shield:MouseCapture(true) end
  host:OnMousePressed(key)
 end
 shield.OnMouseReleased=function(_,key)
  if key==MOUSE_LEFT then shield:MouseCapture(false) end
  host:OnMouseReleased(key)
 end
 shield.OnMouseWheeled=function(_,delta) return host:OnMouseWheeled(delta) end
end
