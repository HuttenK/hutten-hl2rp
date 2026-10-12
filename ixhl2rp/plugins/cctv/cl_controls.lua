local P,C=PLUGIN,ix.CCTV
-- The surveillance desk is a bank of pushkeys and recessed displays. These
-- helpers only paint the equipment; camera capture and input projection stay separate.
local colors={bg=Color(23,28,24),metal=Color(53,61,50),panel=Color(13,20,15),edge=Color(76,89,70),
 text=Color(230,236,215),muted=Color(164,179,151),accent=Color(165,217,120),warn=Color(236,189,103),
 selected=Color(47,72,39),hover=Color(39,51,35),black=Color(7,12,9)}
C.Desk={colors=colors};local D=C.Desk
surface.CreateFont("ixCCTVBody",{font="Tahoma",size=17,weight=500,extended=true})
surface.CreateFont("ixCCTVPlate",{font="Tahoma",size=13,weight=700,extended=true})
function D.Screw(x,y)
 surface.SetDrawColor(colors.black);surface.DrawRect(x-3,y-3,7,7)
 surface.SetDrawColor(colors.muted);surface.DrawLine(x-2,y,x+2,y)
end
function D.Shell(w,h,title,subtitle)
 surface.SetDrawColor(colors.bg);surface.DrawRect(0,0,w,h)
 surface.SetDrawColor(colors.metal);surface.DrawRect(0,0,w,65)
 surface.SetDrawColor(colors.edge);surface.DrawOutlinedRect(0,0,w,h)
 D.Screw(9,9);D.Screw(9,h-10);D.Screw(w-10,h-10)
 surface.SetDrawColor(colors.black);surface.DrawRect(20,17,9,9)
 surface.SetDrawColor(colors.accent);surface.DrawRect(22,19,5,5)
 draw.SimpleText(C.FitText(title,"ixCCTVTitle",w-88),"ixCCTVTitle",40,12,colors.text)
 draw.SimpleText(C.FitText(subtitle or "ВИДЕОНАБЛЮДЕНИЕ / ЗАКРЫТАЯ СЕТЬ","ixCCTVPlate",w-88),"ixCCTVPlate",40,40,colors.muted)
end
function D.Key(self,w,h,text,selected)
 local enabled=self:IsEnabled();local hover=enabled and self:IsHovered()
 local pressed=enabled and self:IsDown();local y=pressed and 1 or 0
 surface.SetDrawColor(colors.black);surface.DrawRect(0,0,w,h)
 surface.SetDrawColor(selected and colors.selected or hover and colors.hover or colors.metal);surface.DrawRect(1,1+y,w-2,h-3)
 surface.SetDrawColor(selected and colors.accent or colors.edge);surface.DrawRect(10,12,4,h-24)
 draw.SimpleText(C.FitText(text,"ixCCTVBody",w-42),"ixCCTVBody",26,h/2+y,enabled and colors.text or colors.muted,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
end
function D.Group(parent,title)
 local p=parent:Add("DPanel");p:Dock(TOP);p:SetTall(34);p:DockMargin(0,4,0,8)
 p.Paint=function(_,w,h)
  surface.SetDrawColor(colors.panel);surface.DrawRect(0,0,w,h)
  surface.SetDrawColor(colors.edge);surface.DrawRect(0,h-1,w,1)
  draw.SimpleText(C.FitText(title,"ixCCTVPlate",w-20),"ixCCTVPlate",10,10,colors.muted)
 end
 return p
end
function D.Entry(entry)
 entry:SetTextColor(colors.text);entry:SetCursorColor(colors.accent)
 entry.Paint=function(self,w,h)
  surface.SetDrawColor(colors.panel);surface.DrawRect(0,0,w,h)
  surface.SetDrawColor(self:HasFocus() and colors.accent or colors.edge);surface.DrawOutlinedRect(0,0,w,h)
  self:DrawTextEntryText(colors.text,colors.accent,colors.text)
 end
end
function D.Slider(slider)
 slider.Label:SetFont("ixCCTVPlate");slider.Label:SetTextColor(colors.text)
 if IsValid(slider.TextArea) then slider.TextArea:SetFont("ixCCTVPlate");slider.TextArea:SetTextColor(colors.text) end
end
function D.Close(frame,width)
 frame:ShowCloseButton(false)
 local close=frame:Add("DButton");close:SetText("×");close:SetTooltip("Закрыть");close:SetFont("ixCCTVTitle");close:SetTextColor(colors.text)
 close:SetSize(32,32);close:SetPos(width-44,12)
 close.Paint=function(self,w,h) surface.SetDrawColor(self:IsHovered() and colors.hover or colors.panel);surface.DrawRect(0,0,w,h) end
 close.DoClick=function() frame:Remove() end
end
local function label(parent,text,height)
 local p=parent:Add("DLabel");p:Dock(TOP);p:DockMargin(0,0,0,8);p:SetTall(height or 28)
 p:SetText(text);p:SetFont("ixCCTVBody");p:SetTextColor(colors.muted);p:SetWrap(true);return p
end
local function button(parent,text,fn,selected)
 local b=parent:Add("DButton");b:Dock(TOP);b:DockMargin(0,0,0,6);b:SetTall(38);b:SetText("")
 b:SetTooltip(text)
 b.Paint=function(self,w,h)
  local active=selected;if isfunction(selected) then active=selected() end
  D.Key(self,w,h,text,active)
 end
 b.DoClick=fn;return b
end
local function frame(title)
 if IsValid(P.window) then P.window:Remove() end
 local f=vgui.Create("DFrame");P.window=f
 f:SetSize(math.min(1080,ScrW()-40),math.min(800,ScrH()-40));f:Center();f:SetTitle("");f:MakePopup();f:DockPadding(20,80,20,16)
 D.Close(f,math.min(1080,ScrW()-40))
 f.Paint=function(_,w,h)
  D.Shell(w,h,title)
 end
 f.OnRemove=function() P.preview=0;P.nextInterest=0 end
 f.OnKeyCodePressed=function(_,key) if key==KEY_ESCAPE then f:Remove() end end
 local status=label(f,"Выберите устройство.",46);status:Dock(BOTTOM);status:DockMargin(0,10,0,0);f.status=status
 local nav=f:Add("DPanel");nav:Dock(LEFT);nav:SetWide(260);nav:DockMargin(0,0,18,0);nav.Paint=function() end
 local body=f:Add("DScrollPanel");body:Dock(FILL);f.body=body;f.nav=nav
 return f
end
local function sorted(kind,terminal)
 local rows={}
 for _,d in pairs(P.devices) do if d.kind==kind and (not terminal or d.terminal==terminal) then rows[#rows+1]=d end end
 table.sort(rows,function(a,b) return a.id<b.id end);return rows
end
local function selectDevice(parent,title,kind,value,fn)
 label(parent,title)
 local select=parent:Add("DComboBox");select:Dock(TOP);select:DockMargin(0,0,0,10);select:SetTall(36);select:SetFont("ixCCTVBody")
 select:AddChoice("Не назначено",0,value==0)
 for _,d in ipairs(sorted(kind)) do select:AddChoice(string.format("%03d / %s",d.id,d.name),d.id,value==d.id) end
 select.OnSelect=function(_,_,_,id) fn(id) end
 return select
end
function P:AdminDetail(id)
 local f=self.window;if not IsValid(f) then return end;f.body:Clear();self.preview=0;f.selected=id
 local d=self.devices[id];if not d then label(f.body,"Разместите устройство или выберите его слева.",64);return end
 if d.surface then self:OpenSurfaceEditor(id);return end
 local body=f.body
 if d.bodycam then
  self.preview=id
  D.Group(body,"НОСИМАЯ КАМЕРА / "..string.format("%03d",id));label(body,d.name,38)
  local preview=body:Add("DPanel");preview:Dock(TOP);preview:SetTall(220)
  preview.Paint=function(_,w,h) P:PaintFeed(id,w,h) end
  label(body,"Камера закреплена на шлеме. Владелец включает, выключает и снимает её через инвентарь. Выберите её на обычном пульте CCTV для вывода на мониторы.",120)
  return
 end
 D.Group(body,"УСТРОЙСТВО "..string.format("%03d",d.id).." / "..C.kinds[d.kind].name)
 local name=body:Add("DTextEntry");name:Dock(TOP);name:DockMargin(0,0,0,12);name:SetTall(38);name:SetFont("ixCCTVBody");name:SetText(d.name)
 D.Entry(name)
 local enabled=body:Add("DCheckBoxLabel");enabled:Dock(TOP);enabled:DockMargin(0,0,0,12)
 enabled:SetText("Устройство включено");enabled:SetTextColor(colors.text);enabled:SetValue(d.on);enabled:SetTall(26)
 local state={terminal=d.terminal or 0,camera=d.camera or 0,fov=d.fov or 75}
 local _,ang=C.Transform(d);state.ang={p=ang.p,y=ang.y,r=ang.r}
 if d.kind=="camera" then
  self.preview=id
  D.Group(body,"ВИЗИР / ПРЯМОЙ СИГНАЛ")
  local preview=body:Add("DPanel");preview:Dock(TOP);preview:DockMargin(0,0,0,12);preview:SetTall(220)
  preview.Paint=function(_,w,h) P:PaintFeed(id,w,h);surface.SetDrawColor(colors.edge);surface.DrawOutlinedRect(0,0,w,h,2) end
  label(body,"Предпросмотр обновляется после сохранения углов.",26)
  local controls={}
  for _,spec in ipairs({{"p","Наклон",-180,180},{"y","Поворот",-180,180},{"r","Крен",-180,180},{"fov","Поле зрения",30,110}}) do
   local key=spec[1];local slider=body:Add("DNumSlider");slider:Dock(TOP);slider:SetTall(34);slider:SetText(spec[2]);slider:SetMinMax(spec[3],spec[4]);slider:SetDecimals(1)
   D.Slider(slider);slider:SetValue(key=="fov" and state.fov or state.ang[key]);controls[key]=slider
   slider.OnValueChanged=function(_,v) if key=="fov" then state.fov=v else state.ang[key]=v end end
  end
  button(body,"Направить как мой взгляд",function()
   local a=LocalPlayer():EyeAngles();for _,key in ipairs({"p","y","r"}) do controls[key]:SetValue(a[key]) end
  end)
 elseif d.kind=="monitor" then
  D.Group(body,"КОММУТАЦИЯ МОНИТОРА")
  selectDevice(body,"Пульт управления","terminal",state.terminal,function(v) state.terminal=v end)
  selectDevice(body,"Текущая камера","camera",state.camera,function(v) state.camera=v end)
  label(body,"Пульт сможет переключать этот монитор. Один пульт может управлять несколькими мониторами.",64)
 else
  label(body,"Связанные мониторы",28)
  local linked=sorted("monitor",id)
  if #linked==0 then label(body,"Пока нет мониторов. Выберите монитор и назначьте ему этот пульт.",64) end
  for _,m in ipairs(linked) do label(body,string.format("%03d / %s",m.id,m.name)) end
  button(body,"Открыть пульт",function() if P:ClientCanUseTerminal(id) then P:OpenTerminalUI(id) else f.status:SetText("Для работы с пультом подойдите к нему.") end end)
  button(body,"Перенести экран на выбранный prop",function() P:BeginPlacement("terminal",id) end)
 end
 button(body,"Сохранить настройки",function()
  state.id=id;state.name=name:GetValue();state.on=enabled:GetChecked();P:Request("configure",state)
 end,true)
 button(body,"Удалить устройство",function()
  Derma_Query("Удалить "..d.name.."?","CCTV","Удалить",function() P:Request("remove",{id=id}) end,"Отмена")
 end)
end
function P:OpenAdminUI(id)
 if not LocalPlayer():IsAdmin() then return end
 self:CloseTerminalUI()
 if self.devices[id] and self.devices[id].surface then self:OpenSurfaceEditor(id);return end
 local f=frame("ПОСТ ВИДЕОНАБЛЮДЕНИЯ")
 D.Group(f.nav,"МОНТАЖ ОБОРУДОВАНИЯ")
 for _,kind in ipairs({"camera","monitor","terminal"}) do
  local selected=kind;button(f.nav,"+ "..C.kinds[kind].name,function() P:BeginPlacement(selected) end)
 end
 local list=f.nav:Add("DScrollPanel");list:Dock(FILL)
 f.RefreshList=function()
  list:Clear()
  for _,kind in ipairs({"camera","monitor","terminal"}) do
   D.Group(list,C.kinds[kind].name)
   for _,d in ipairs(sorted(kind)) do local device=d;button(list,string.format("%03d / %s",d.id,d.name),function() P:AdminDetail(device.id) end,function() return device.id==f.selected end) end
  end
 end
 f.Think=function()
  if not LocalPlayer():IsAdmin() then f:Remove();return end
  if f.refresh then f.refresh=false;f.RefreshList();if f.selected and not P.devices[f.selected] then P:AdminDetail(0) end end
 end
 self:AdminDetail(id);f.RefreshList();f.status:SetText("Размещение, названия и связи сохраняются автоматически для этой карты.")
end
