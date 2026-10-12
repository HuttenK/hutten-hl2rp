local P,C=PLUGIN,ix.CCTV
local D=C.Desk;local col=D.colors
surface.CreateFont("ixCCTVConsoleTitle",{font="Tahoma",size=30,weight=700,extended=true})
surface.CreateFont("ixCCTVConsoleText",{font="Tahoma",size=22,weight=500,extended=true})
surface.CreateFont("ixCCTVConsoleSmall",{font="Tahoma",size=18,weight=500,extended=true})
P.terminalViews={}

local function devices(kind,terminal)
 local rows={}
 for _,d in pairs(P.devices) do
  if d.kind==kind and (not terminal or d.terminal==terminal) then rows[#rows+1]=d end
 end
 table.sort(rows,function(a,b) return a.id<b.id end)
 return rows
end

function P:TerminalState(id)
 local state=self.terminalViews[id]
 if not state then state={monitor=0,cameraPage=1,monitorPage=1,page="monitors",bodycamPage=1,bodycam=0};self.terminalViews[id]=state end
 state.page=state.page or "monitors";state.bodycamPage=state.bodycamPage or 1;state.bodycam=state.bodycam or 0
 local m=self.devices[state.monitor]
 if state.monitor~=0 and (not m or m.kind~="monitor" or m.terminal~=id) then state.monitor=0 end
 return state
end

-- Both painting and hit testing use this layout. Paging keeps every named
-- device reachable without drawing or capturing any extra camera feeds.
function P:TerminalLayout(id)
 local state=self:TerminalState(id)
 local cameras,monitors=devices("camera"),devices("monitor",id)
 local rows={state=state,cameras=cameras,monitors=monitors}
 rows.cameraPages=math.max(1,math.ceil(#cameras/6))
 rows.monitorPages=math.max(1,math.ceil(#monitors/5))
 state.cameraPage=math.Clamp(state.cameraPage,1,rows.cameraPages)
 state.monitorPage=math.Clamp(state.monitorPage,1,rows.monitorPages)
 local function add(kind,value,x,y,w,h,text,detail,selected,disabled)
  rows[#rows+1]={key=kind..":"..tostring(value),kind=kind,value=value,x=x,y=y,w=w,h=h,
   text=text,detail=detail,selected=selected,disabled=disabled}
 end
 add("page","monitors",12,82,240,34,"Мониторы",nil,state.page=="monitors")
 add("page","bodycams",260,82,304,34,"Камеры на шлемах",nil,state.page=="bodycams")
 if self.terminalUI and self.terminalUI.id==id then add("close",0,746,16,42,38,"×") end
 if state.page=="bodycams" then
  local bodycams={};rows.bodycams=bodycams
  -- The server removes unavailable helmet records. Do not require a client
  -- wearer entity here: distant wearers enter PVS only after selection.
  for _,camera in ipairs(cameras) do if camera.bodycam==true and camera.on==true then bodycams[#bodycams+1]=camera end end
  local current=self.devices[state.bodycam]
  if not current or current.kind~="camera" or current.bodycam~=true or current.on~=true then state.bodycam=bodycams[1] and bodycams[1].id or 0 end
  rows.bodycamPages=math.max(1,math.ceil(#bodycams/6));state.bodycamPage=math.Clamp(state.bodycamPage,1,rows.bodycamPages)
  for i=(state.bodycamPage-1)*6+1,math.min(state.bodycamPage*6,#bodycams) do
   local camera=bodycams[i]
   add("bodycam",camera.id,12,158+((i-1)%6)*47,280,42,camera.name,nil,state.bodycam==camera.id)
  end
  add("bodycamPage",-1,12,460,48,36,"<",nil,false,state.bodycamPage<=1)
  add("bodycamPage",1,244,460,48,36,">",nil,false,state.bodycamPage>=rows.bodycamPages)
  return rows
 end
 local current=state.monitor~=0 and self.devices[state.monitor].camera or nil
 if state.monitor==0 and #monitors>0 then
  current=monitors[1].camera
  for _,m in ipairs(monitors) do if m.camera~=current then current=nil;break end end
 end
 add("monitor",0,12,158,240,42,"Все мониторы",nil,state.monitor==0,#monitors==0)
 for i=(state.monitorPage-1)*5+1,math.min(state.monitorPage*5,#monitors) do
  local m=monitors[i];local camera=self.devices[m.camera]
  add("monitor",m.id,12,205+((i-1)%5)*47,240,42,m.name,
   not C.Powered(m) and "ОБЕСТОЧЕН" or (camera and camera.name or "Нет камеры"),state.monitor==m.id)
 end
 for i=(state.cameraPage-1)*6+1,math.min(state.cameraPage*6,#cameras) do
  local camera=cameras[i]
  add("camera",camera.id,270,158+((i-1)%6)*47,518,42,string.format("%03d / %s",camera.id,camera.name),
   C.Powered(camera) and (current==camera.id and "В ЭФИРЕ" or "ДОСТУПНА") or "НЕТ СИГНАЛА",current==camera.id,#monitors==0)
 end
 for _,spec in ipairs({{"monitorPage",12,240,state.monitorPage,rows.monitorPages},{"cameraPage",270,518,state.cameraPage,rows.cameraPages}}) do
  add(spec[1],-1,spec[2],460,48,36,"<",nil,false,spec[4]<=1)
  add(spec[1],1,spec[2]+spec[3]-48,460,48,36,">",nil,false,spec[4]>=spec[5])
 end
 return rows
end

function P:TerminalBodycamPreview()
 local session=self.terminalUI
 if not session or not self:ClientCanUseTerminal(session.id) then return end
 local rows=self:TerminalLayout(session.id);local state=rows.state
 if state.page=="bodycams" and state.bodycam~=0 then return {id=session.id,camera=state.bodycam} end
end

function P:ReleaseTerminalBodycam()
 local session=self.terminalUI;local id=session and session.state.bodycam
 if id and self.demand then self.demand[id]=nil end
end

function P:TerminalHit(id,x,y)
 if not x or not y then return end
 for _,b in ipairs(self:TerminalLayout(id)) do
  if not b.disabled and x>=b.x and y>=b.y and x<b.x+b.w and y<b.y+b.h then return b end
 end
end

-- Start3D2D's screen +X is Forward and screen +Y is Right. Reject the back
-- of the plane, rays pointing away, and points outside the physical screen.
function P:TerminalCursor(id)
 local d=self.devices[id];if not d or not self:ClientCanUseTerminal(id) then return end
 local _,_,ent=C.Transform(d);if not IsValid(ent) then return end
 -- Camera captures change the current render view. Always project from the
 -- main player viewport (including CalcView/FOV), never the last CCTV feed.
 local view=render.GetViewSetup(false)
 if not view or not view.origin or not view.angles or not view.fov then return end
 local w,h=view.width or ScrW(),view.height or ScrH()
 if w<=0 or h<=0 then return end
 local aspect=view.aspect and view.aspect>0 and view.aspect or w/h
 local mx,my=input.GetCursorPos()
 mx,my=mx-(view.x or 0),my-(view.y or 0)
 local tan=math.tan(math.rad(math.Clamp(view.fov,1,179)*.5))
 local a=view.angles
 local direction=(a:Forward()+a:Right()*((mx/w*2-1)*tan)+a:Up()*((1-my/h*2)*tan/aspect)):GetNormalized()
 local x,y,hit=C.TerminalRay(d,view.origin,direction);if not x then return end
 local tr=util.TraceLine({start=view.origin,endpos=hit,filter={LocalPlayer(),ent},mask=MASK_VISIBLE})
 if tr.Hit then return end
 return x,y
end

function P:ActivateTerminalButton(id,b)
 if not self.terminalUI or self.terminalUI.id~=id or not self:ClientCanUseTerminal(id) or not b or b.disabled then return end
 -- Re-resolve the button: devices or pages may have changed since mouse-down.
 local current
 for _,row in ipairs(self:TerminalLayout(id)) do if row.key==b.key and not row.disabled then current=row;break end end
 if not current then return end
 local s=self:TerminalState(id)
 if current.kind=="close" then self:CloseTerminalUI()
 elseif current.kind=="page" then self:ReleaseTerminalBodycam();s.page=current.value;s.message=nil
 elseif current.kind=="bodycam" then self:ReleaseTerminalBodycam();s.bodycam=current.value;s.message=nil
 elseif current.kind=="monitor" then s.monitor=current.value;s.message=nil
 elseif current.kind=="camera" then
  self:Request("switch",{terminal=id,monitor=s.monitor,camera=current.value})
 elseif current.kind=="cameraPage" or current.kind=="monitorPage" or current.kind=="bodycamPage" then
  s[current.kind]=s[current.kind]+current.value;self:TerminalLayout(id)
 end
end

function P:ScrollTerminal(id,delta,x)
 if not self.terminalUI or self.terminalUI.id~=id or not x or delta==0 then return end
 local state=self:TerminalState(id);local key=state.page=="bodycams" and "bodycamPage" or x<260 and "monitorPage" or "cameraPage"
 state[key]=state[key]+(delta<0 and 1 or -1);self:TerminalLayout(id)
end

function P:CloseTerminalUI()
 self:ReleaseTerminalBodycam()
 local session=self.terminalUI;self.terminalUI=nil
 if session and IsValid(session.host) then session.host:Remove() end
end

function P:OpenTerminalUI(id)
 if not self:ClientCanUseTerminal(id) then return end
 if self.terminalUI and self.terminalUI.id==id then return end
 self:CloseTerminalUI();self:EndPlacement()
 if IsValid(self.window) then self.window:Remove() end
 self.preview=0
 local session={id=id,state=self:TerminalState(id),viewAngles=LocalPlayer():EyeAngles()}
 self.terminalUI=session
 -- This transparent input catcher never paints the interface on the HUD.
 -- The actual controls are drawn only on the world-space terminal surface.
 local host=vgui.Create("EditablePanel");session.host=host
 local screenW,screenH=ScrW(),ScrH()
 host:SetPos(0,0);host:SetSize(screenW,screenH);host:MakePopup();host:SetKeyboardInputEnabled(false)
 local cursor="arrow";host:SetCursor(cursor)
 host.Paint=function() end
 host.OnRemove=function() if P.terminalUI==session then P:ReleaseTerminalBodycam();P.terminalUI=nil end end
 local pressed,armed=nil,false
 host.Think=function(self)
  if not P:ClientCanUseTerminal(id) or input.IsKeyDown(KEY_ESCAPE) or gui.IsGameUIVisible() or gui.IsConsoleVisible() then P:CloseTerminalUI();return end
  local w,h=ScrW(),ScrH()
  if w~=screenW or h~=screenH then screenW,screenH=w,h;self:SetSize(w,h) end
  if not input.IsMouseDown(MOUSE_LEFT) and not input.IsMouseDown(MOUSE_RIGHT) then armed=true end
  local x,y=P:TerminalCursor(id);local b=P:TerminalHit(id,x,y)
  session.hover=b and b.key
  -- Reapply the native cursor only when its shape changes, not every frame.
  local nextCursor=b and "hand" or "arrow"
  if cursor~=nextCursor then cursor=nextCursor;self:SetCursor(cursor) end
 end
 host.OnMousePressed=function(self,key)
  if not armed then return end
  if key==MOUSE_RIGHT then P:CloseTerminalUI();return end
  if key~=MOUSE_LEFT then return end
  local x,y=P:TerminalCursor(id);local b=P:TerminalHit(id,x,y)
  pressed=b and b.key;self:MouseCapture(true)
 end
 host.OnMouseReleased=function(self,key)
  if key~=MOUSE_LEFT then return end
  self:MouseCapture(false)
  local x,y=P:TerminalCursor(id);local b=P:TerminalHit(id,x,y)
  if b and b.key==pressed then P:ActivateTerminalButton(id,b) end
  pressed=nil
 end
 host.OnMouseWheeled=function(_,delta)
  local x=P:TerminalCursor(id);if not x then return false end
  P:ScrollTerminal(id,delta,x);return true
 end
end

hook.Add("CreateMove","ixCCTVTerminalInput",function(cmd)
 local session=P.terminalUI;if not session then return end
 cmd:ClearMovement();cmd:ClearButtons();cmd:SetViewAngles(session.viewAngles)
end)

function P:PaintTerminal(d,w,h)
 local rows=self:TerminalLayout(d.id);local s=rows.state
 local session=self.terminalUI and self.terminalUI.id==d.id and self.terminalUI
 D.Shell(w,h,"ПОСТ ВИДЕОНАБЛЮДЕНИЯ",d.name)
 if s.page=="bodycams" then
  surface.SetDrawColor(col.black);surface.DrawRect(6,122,292,326);surface.DrawRect(304,122,490,374)
  draw.SimpleText("В ЭФИРЕ / "..#rows.bodycams,"ixCCTVConsoleText",16,130,col.accent)
  draw.SimpleText("ПЕРСОНАЛЬНАЯ КАМЕРА","ixCCTVConsoleText",314,130,col.muted)
  local camera=self.devices[s.bodycam]
  if session and camera then self:PaintFeed(camera.id,478,269,camera.name,310,162)
  else
   surface.SetDrawColor(col.panel);surface.DrawRect(310,162,478,269)
   draw.SimpleText(camera and "[ E ]  ОТКРЫТЬ ПРОСМОТР" or "НЕТ АКТИВНЫХ КАМЕР","ixCCTVConsoleText",549,292,col.muted,TEXT_ALIGN_CENTER)
  end
  draw.SimpleText(C.FitText(camera and camera.name or "Камеры выключены или сняты","ixCCTVConsoleText",460),"ixCCTVConsoleText",318,446,col.text)
  draw.SimpleText("Выбор меняет изображение только на этом пульте.","ixCCTVConsoleSmall",318,476,col.muted)
 else
  surface.SetDrawColor(col.black);surface.DrawRect(6,122,252,326);surface.DrawRect(264,122,530,326)
  draw.SimpleText("ВЫХОДЫ / "..#rows.monitors,"ixCCTVConsoleText",16,130,col.muted)
  draw.SimpleText("ВИДЕОКАНАЛЫ / "..#rows.cameras,"ixCCTVConsoleText",278,130,col.accent)
 end
 for _,b in ipairs(rows) do
  local hovered=session and session.hover==b.key
  surface.SetDrawColor(b.selected and col.selected or hovered and col.hover or col.metal);surface.DrawRect(b.x,b.y,b.w,b.h-2)
  surface.SetDrawColor((b.selected or hovered) and col.accent or col.edge);surface.DrawRect(b.x,b.y+b.h-2,b.w,2)
  local width=b.w-30-(b.kind=="camera" and 154 or 0)
  local textColor=b.disabled and col.muted or col.text
  local isDevice=b.kind=="monitor" or b.kind=="camera" or b.kind=="bodycam"
  if isDevice then
   surface.SetDrawColor(col.black);surface.DrawRect(b.x+7,b.y+14,7,18)
   surface.SetDrawColor(b.disabled and col.edge or b.selected and col.accent or b.detail=="НЕТ СИГНАЛА" and col.warn or col.edge)
   surface.DrawRect(b.x+9,b.y+16,3,14)
  end
  draw.SimpleText(C.FitText(b.text,"ixCCTVConsoleText",width),"ixCCTVConsoleText",b.x+(isDevice and 22 or 12),b.y+(b.kind=="monitor" and b.detail and 1 or b.kind=="page" and 6 or 9),textColor)
  if b.detail then
   if b.kind=="camera" then
    draw.SimpleText(b.detail,"ixCCTVConsoleSmall",b.x+b.w-10,b.y+15,b.detail=="НЕТ СИГНАЛА" and col.warn or col.accent,TEXT_ALIGN_RIGHT)
   else draw.SimpleText(C.FitText(b.detail,"ixCCTVConsoleSmall",b.w-30),"ixCCTVConsoleSmall",b.x+22,b.y+23,col.muted) end
  end
 end
 local pages=s.page=="bodycams" and {{152,s.bodycamPage,rows.bodycamPages}} or {{132,s.monitorPage,rows.monitorPages},{529,s.cameraPage,rows.cameraPages}}
 for _,spec in ipairs(pages) do
  draw.SimpleText(spec[2].." / "..spec[3],"ixCCTVConsoleText",spec[1],467,col.muted,TEXT_ALIGN_CENTER)
 end
 if s.page=="monitors" then
  if #rows.monitors==0 then draw.SimpleText("Нет подключений","ixCCTVConsoleSmall",24,214,col.warn) end
  if #rows.cameras==0 then draw.SimpleText("Камеры не установлены","ixCCTVConsoleText",286,170,col.muted) end
 elseif #rows.bodycams==0 then draw.SimpleText("Нет передач","ixCCTVConsoleSmall",24,178,col.muted) end
 local message
 if s.message and RealTime()<(s.messageUntil or 0) then message=s.message
 elseif s.page=="bodycams" then message=s.bodycam~=0 and "Выберите сотрудника слева, чтобы смотреть его камеру." or "Наденьте шлем с камерой и включите её, чтобы начать передачу."
 elseif #rows.monitors==0 then message="Администратор должен связать мониторы с этим пультом."
 elseif s.monitor==0 then message="Выбор камеры переключит все связанные мониторы."
 else message="Монитор: "..self.devices[s.monitor].name end
 if session and not (s.message and RealTime()<(s.messageUntil or 0)) then
  for _,b in ipairs(rows) do
   if (b.kind=="camera" or b.kind=="bodycam") and b.key==session.hover then message="Камера: "..self.devices[b.value].name;break end
  end
 end
 surface.SetDrawColor(col.panel);surface.DrawRect(12,504,w-24,34)
 draw.SimpleText(C.FitText(message,"ixCCTVConsoleSmall",w-44),"ixCCTVConsoleSmall",22,512,col.text)
 draw.SimpleText(session and "ЛКМ — выбрать · Колесо — страницы · ПКМ / Esc — выйти" or "[ E ]  АКТИВИРОВАТЬ ПУЛЬТ",
  "ixCCTVConsoleSmall",12,h-27,col.accent)
end
