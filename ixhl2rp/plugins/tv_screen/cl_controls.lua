local P,T=PLUGIN,ix.TV
-- Broadcast controls are a rack of separate source, transport and audio units.
-- Keep this skin local: the media player, capture budgets and world guide are unchanged.
local C={bg=Color(29,28,26),panel=Color(47,44,39),line=Color(102,92,74),text=Color(238,228,206),
 muted=Color(181,170,150),accent=Color(239,183,83),amber=Color(243,173,78),red=Color(228,112,93),
 face=Color(201,188,162),ink=Color(36,33,28),hover=Color(68,61,48),well=Color(14,16,14)}
surface.CreateFont("ixTVRack",{font="Tahoma",size=13,weight=700,extended=true})
local function bolt(x,y)
 surface.SetDrawColor(C.ink);surface.DrawRect(x-3,y-3,6,6)
 surface.SetDrawColor(C.muted);surface.DrawLine(x-2,y,x+2,y)
end
local function module(parent,number,title)
 local p=parent:Add("DPanel");p:Dock(TOP);p:DockMargin(0,12,0,10);p:SetTall(32)
 p.Paint=function(_,w,h)
  surface.SetDrawColor(C.face);surface.DrawRect(0,0,w,h)
  surface.SetDrawColor(C.ink);surface.DrawRect(7,6,30,20)
  draw.SimpleText(number,"ixTVRack",22,16,C.accent,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
  draw.SimpleText(T.FitText(title,"ixTVRack",w-74),"ixTVRack",48,10,C.ink)
  bolt(w-12,16)
 end
 return p
end
local function label(parent,text,height)
 local v=parent:Add("DLabel");v:Dock(TOP);v:DockMargin(0,0,0,8);v:SetTall(height or 24)
 v:SetText(text);v:SetFont("ixTVBody");v:SetTextColor(C.muted);v:SetWrap(true)
 return v
end
local function button(parent,text,fn,accent)
 local b=parent:Add("DButton");b:Dock(TOP);b:DockMargin(0,0,0,7);b:SetTall(38);b:SetText("")
 b:SetTooltip(text)
 b.Paint=function(self,w,h)
  local hover=self:IsHovered() and self:IsEnabled()
  local y=self:IsDown() and 1 or 0
  surface.SetDrawColor(C.well);surface.DrawRect(0,0,w,h)
  surface.SetDrawColor(hover and C.hover or C.panel);surface.DrawRect(1,1+y,w-2,h-3)
  surface.SetDrawColor(self:IsEnabled() and (accent or C.line) or C.line);surface.DrawRect(10,12,5,h-24)
  local shown=T.FitText(text,"ixTVBody",w-42)
  draw.SimpleText(shown,"ixTVBody",26,h/2+y,self:IsEnabled() and C.text or C.muted,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
 end
 b.DoClick=fn;return b
end
local function entry(parent,title,value,hint)
 label(parent,title)
 local e=parent:Add("DTextEntry");e:Dock(TOP);e:DockMargin(0,0,0,12);e:SetTall(36);e:SetFont("ixTVBody")
 e:SetText(value or "");e:SetPlaceholderText(hint or "");e:SetTextColor(C.text);e:SetCursorColor(C.accent)
 e.Paint=function(self,w,h) draw.RoundedBox(4,0,0,w,h,C.bg);surface.SetDrawColor(self:HasFocus() and C.accent or C.line);surface.DrawOutlinedRect(0,0,w,h);self:DrawTextEntryText(C.text,C.accent,C.text) end
 return e
end
local function frame(title,w,h,side)
 if IsValid(P.tvWindow) then P.tvWindow:Remove() end
 local f=vgui.Create("DFrame");P.tvWindow=f
 f:SetSize(w,h);if side then f:SetPos(ScrW()-w-20,30) else f:Center() end
 f:SetTitle("");f:ShowCloseButton(false);f:SetDraggable(true);f:MakePopup();f:DockPadding(28,80,28,20)
 f.Paint=function(_,width,height)
  surface.SetDrawColor(C.bg);surface.DrawRect(0,0,width,height)
  surface.SetDrawColor(C.face);surface.DrawRect(0,0,width,62)
  surface.SetDrawColor(C.line);surface.DrawOutlinedRect(0,0,width,height)
  surface.SetDrawColor(C.panel);surface.DrawRect(6,70,8,height-80);surface.DrawRect(width-14,70,8,height-80)
  for y=90,height-20,42 do bolt(10,y);bolt(width-10,y) end
  draw.SimpleText(T.FitText(title,"ixTVTitle",width-92),"ixTVTitle",28,11,C.ink)
  draw.SimpleText("FOUNDATION / ТЕЛЕВИЗИОННАЯ СЕТЬ","ixTVRack",28,39,C.ink)
 end
 local close=f:Add("DButton");close:SetText("×");close:SetFont("ixTVTitle");close:SetSize(32,32);close:SetPos(w-44,10);close.DoClick=function() f:Remove() end
 close:SetTextColor(C.text);close.Paint=function(self,cw,ch) surface.SetDrawColor(self:IsHovered() and C.red or C.ink);surface.DrawRect(0,0,cw,ch) end
 f.OnRemove=function() P.editPreview=nil;P.previewChannel=nil;P.listPanel=nil end
 f.OnKeyCodePressed=function(_,key) if key==KEY_ESCAPE then f:Remove() end end
 local status=f:Add("DLabel");status:Dock(BOTTOM);status:SetTall(48);status:SetFont("ixTVSmall");status:SetWrap(true);status:SetTextColor(C.muted);status:SetText("Изменения эфира видны всем зрителям выбранного канала.")
 status:DockMargin(0,10,0,0)
 f.status=status
 return f
end
function P:Feedback(text,ok)
 if IsValid(self.tvWindow) then self.tvWindow.status:SetText(text or "");self.tvWindow.status:SetTextColor(ok and C.accent or C.amber)
 else LocalPlayer():Notify(text or "") end
end
function P:Request(action,data)
 if not LocalPlayer():IsAdmin() then return false end
 if self.pending and RealTime()-self.pending.time<5 then self:Feedback("Дождитесь ответа сервера.",false);return false end
 if (self.nextTVRequest or 0)>RealTime() then return false end
 local raw=util.TableToJSON(data or {});if #raw>8192 then self:Feedback("Слишком большой запрос.",false);return false end
 self.nextTVRequest=RealTime()+.2;self.pending={action=action,time=RealTime()}
 net.Start("ixTVAction");net.WriteString(action);net.WriteString(raw);net.SendToServer()
 self:Feedback("Сохранение…",true);return true
end
local function channels(parent,value,changed)
 label(parent,"Канал экрана")
 local combo=parent:Add("DComboBox");combo:Dock(TOP);combo:DockMargin(0,0,0,12);combo:SetTall(34);combo:SetFont("ixTVBody")
 for id=1,T.maxChannels do
  local c=P.channels[id];if c then combo:AddChoice(string.format("%02d  ·  %s",id,c.name),id,id==value) end
 end
 combo.OnSelect=function(_,_,_,id) changed(id) end
 return combo
end
function P:OpenScreenEditor(id)
 local s=self.screens[id];if not s then return end
 local f=frame("МОНТАЖНЫЙ ПУЛЬТ",460,math.min(ScrH()-60,940),true)
 f.status:SetText("Калибровка видна на экране. Запишите её кнопкой «Сохранить экран».")
 local scroll=f:Add("DScrollPanel");scroll:Dock(FILL)
 local cfg=table.Copy(s.config);local channel,on=s.channel,s.on
 local preview={}
 for k,v in pairs(s) do preview[k]=v end
 preview.config=cfg;self.editPreview=preview
 button(scroll,"‹  Все экраны",function() P:OpenTVAdmin("screens") end)
 label(scroll,"Изменения показаны в мире. Сохранение — кнопкой ниже.",46)
 module(scroll,"01","ПРИЁМНИК / НАЗНАЧЕНИЕ")
 local name=entry(scroll,"Название",s.name)
 channels(scroll,channel,function(v) channel=v;preview.channel=v end)
 local enabled=scroll:Add("DCheckBoxLabel");enabled:Dock(TOP);enabled:DockMargin(0,0,0,12);enabled:SetText("Экран включён");enabled:SetValue(on);enabled:SetTextColor(C.text);enabled:SizeToContents()
 enabled.OnChange=function(_,v) on=v;preview.on=v end
 module(scroll,"02","ГЕОМЕТРИЯ ЭКРАНА")
 label(scroll,s.world and "Положение относительно точки на стене" or "Положение относительно модели",40)
 local controls={};local fine=true
 local function limits(field)
  if field=="w" or field=="h" then return 1,1024,2 end
  if field=="p" or field=="yaw" or field=="r" then return -360,360,10 end
  return -4096,4096,2
 end
 local function setRange(slider,value)
  local low,high,radius=limits(slider.tvField)
  -- SetMinMax emits ValueChanged. Preserve the actual calibration while
  -- moving the precision window, including presets far outside the old one.
  slider.tvUpdating=true
  slider:SetMinMax(fine and math.max(low,value-radius) or low,fine and math.min(high,value+radius) or high)
  slider:SetValue(value);slider.tvUpdating=false
 end
 local function setField(field,value)
  local low,high=limits(field);value=tonumber(value)
  if not value or value~=value or math.abs(value)==math.huge then return end
  value=math.Clamp(value,low,high);cfg[field]=value;setRange(controls[field],value)
 end
 local precision=scroll:Add("DCheckBoxLabel");precision:Dock(TOP);precision:SetTall(28)
 precision:SetText("Точная настройка");precision:SetValue(true);precision:SetTextColor(C.accent)
 precision.OnChange=function(_,v) fine=v;for field,slider in pairs(controls) do setRange(slider,cfg[field]) end end
 label(scroll,"Точно: ±2 ед. / ±10°. Отключите для полного диапазона. Кнопки −/+ : шаг 0,1; с Shift — 0,01. Числа можно вводить вручную.",60)
 button(scroll,"Центрировать диапазоны на текущих значениях",function() for field,slider in pairs(controls) do setRange(slider,cfg[field]) end end)
 local names={x="X · вперёд",y="Y · вбок",z="Z · высота",p="Наклон",yaw="Поворот",r="Крен",w="Ширина",h="Высота"}
 for _,key in ipairs(T.fields) do
  local field=key;local row=scroll:Add("DPanel");row:Dock(TOP);row:SetTall(44);row.Paint=function() end
  for _,direction in ipairs({1,-1}) do
   local step=direction
   local b=row:Add("DButton");b:Dock(RIGHT);b:DockMargin(4,7,0,7);b:SetWide(26);b:SetText(step>0 and "+" or "−")
   b:SetTooltip(names[field]..(step>0 and " +" or " −"));b:SetFont("ixTVBody");b:SetTextColor(C.text)
   b.Paint=function(self,w,h) surface.SetDrawColor(self:IsHovered() and C.hover or C.panel);surface.DrawRect(0,0,w,h) end
   b.DoClick=function() local small=input.IsKeyDown(KEY_LSHIFT) or input.IsKeyDown(KEY_RSHIFT);setField(field,math.Round(cfg[field]+step*(small and .01 or .1),2)) end
  end
  local slider=row:Add("DNumSlider");slider:Dock(FILL);slider:SetText(names[field]);slider:SetDecimals(2);slider.tvField=field
  slider.Label:SetTextColor(C.text);slider.Label:SetFont("ixTVSmall")
  slider.OnValueChanged=function(self,v) if not self.tvUpdating then cfg[field]=v end end
  controls[field]=slider;setRange(slider,cfg[field])
 end
 local function reset(values) for key,v in pairs(values) do if controls[key] then setField(key,v) end end end
 button(scroll,"Пропорции 16:9",function() setField("h",cfg.w*9/16) end)
 button(scroll,"Пропорции 4:3",function() setField("h",cfg.w*3/4) end)
 module(scroll,"03","ПАМЯТЬ РАЗМЕЩЕНИЯ")
 button(scroll,"Сохранить экран",function() P:Request("screen",{screen=id,config=cfg,name=name:GetValue(),channel=channel,on=on}) end,C.accent)
 local preset=button(scroll,"Сохранить размещение для модели",function() P:Request("preset",{screen=id,config=cfg}) end)
 preset:SetEnabled(not s.world);preset:SetTooltip("Сохраняет положение, углы и размер. Используется при следующем размещении на этой модели.")
 local load=button(scroll,"Загрузить пресет модели",function() if P.presets[s.model] then reset(P.presets[s.model]) end end)
 load:SetEnabled(not s.world and P.presets[s.model]~=nil)
 button(scroll,"Отменить несохранённые изменения",function() P:OpenScreenEditor(id) end)
 button(scroll,"Удалить экран",function()
  Derma_Query("Удалить экран? Модель останется на месте.","Удаление экрана","Удалить",function() P:Request("removeScreen",{screen=id}) end,"Отмена")
 end,C.red)
end
function P:RefreshTVLists()
 if not IsValid(self.listPanel) then return end
 local list=self.listPanel;list:Clear()
 if self.tvMode=="screens" then
  local ids={};for id in pairs(self.screens) do ids[#ids+1]=id end;table.sort(ids)
  for _,id in ipairs(ids) do
   local s=self.screens[id];local selected=id
   button(list,string.format("%03d  %s",id,s.name),function() P:OpenScreenEditor(selected) end)
  end
  if #ids==0 then label(list,[[Экранов пока нет.
Нажмите «Разместить экран».]],70) end
 else
  for id=1,T.maxChannels do
   local c=self.channels[id];if c then local selected=id
    button(list,string.format("%02d  %s",id,c.name),function() P:OpenTVAdmin("channels",selected) end,id==self.previewChannel and C.accent or nil)
   end
  end
 end
end
function P:OpenTVAdmin(mode,id)
 if not LocalPlayer():IsAdmin() then return end
 self.placement=nil;self.placementPreview=nil
 local f=frame("АППАРАТНАЯ ТЕЛЕЭФИРА",math.min(1080,ScrW()-40),math.min(840,ScrH()-50))
 self.tvMode=mode or "channels"
 local left=f:Add("DPanel");left:Dock(LEFT);left:SetWide(220);left:DockMargin(0,0,18,0);left.Paint=function() end
 module(left,"TV","КОММУТАТОР")
 button(left,"Каналы",function() P:OpenTVAdmin("channels") end,self.tvMode=="channels" and C.accent)
 button(left,"Экраны",function() P:OpenTVAdmin("screens") end,self.tvMode=="screens" and C.accent)
 button(left,"+  Разместить экран",function() P:BeginPlacement(P.previewChannel or 1) end,C.accent)
 if self.tvMode=="channels" then
  button(left,"+  Создать канал",function() Derma_StringRequest("Новый канал","Название канала","",function(name) P:Request("createChannel",{name=name}) end) end)
 end
 local list=left:Add("DScrollPanel");list:Dock(FILL);self.listPanel=list
 local content=f:Add("DScrollPanel");content:Dock(FILL)
 if self.tvMode=="screens" then
  module(content,"01","ЭКРАНЫ ОБЪЕКТА")
  label(content,[[Выберите экран слева для настройки положения и канала.

Размещение: наведитесь на стену или модель и нажмите ЛКМ. Если для модели сохранён пресет, он будет предложен автоматически.

E на экране — пульт администратора. Shift + E — питание. Остальные игроки могут включать и выключать экран клавишей E.]],190)
  local preview=content:Add("DPanel");preview:Dock(TOP);preview:SetTall(240);preview.Paint=function(_,w,h) T.DrawFailure(w,h,"idle","FOUNDATION NETWORK") end
 else
  local c=self.channels[id or 1];if not c then self:RefreshTVLists();return end
  self.previewChannel=c.id
  module(content,string.format("%02d",c.id),"КОНТРОЛЬ ЭФИРА")
  label(content,c.name,42)
  local preview=content:Add("DPanel");preview:Dock(TOP);preview:DockMargin(0,0,0,12);preview:SetTall(math.Clamp(ScrH()*.2,150,240))
  preview.Paint=function(_,w,h) P:PaintChannel(c.id,w,h);surface.SetDrawColor(C.line);surface.DrawOutlinedRect(0,0,w,h,2) end
  label(content,"Предпросмотр без дополнительного звука. Эфир слышен рядом с экранами.",38)
  module(content,"01","ИСТОЧНИК / УПРАВЛЕНИЕ ЭФИРОМ")
  local source=entry(content,"Видео / изображение",""..(c.source or ""),"https://…/video.webm")
  local transport=content:Add("DPanel");transport:Dock(TOP);transport:SetTall(44);transport:DockMargin(0,0,0,8);transport.Paint=function() end
  local play=button(transport,"▶  Запустить на этом канале",function() P:Request("play",{channel=c.id,source=source:GetValue()}) end,C.accent)
  local stop=button(transport,"■  Остановить эфир",function() P:Request("stop",{channel=c.id}) end,C.red)
  play:Dock(NODOCK);stop:Dock(NODOCK)
  transport.PerformLayout=function(_,w,h)
   local left=math.floor(w*.57);play:SetPos(0,0);play:SetSize(left-4,h);stop:SetPos(left+4,0);stop:SetSize(w-left-4,h)
  end
  local loop=content:Add("DCheckBoxLabel");loop:Dock(TOP);loop:DockMargin(0,4,0,12);loop:SetText("Повторять видео");loop:SetValue(c.loop);loop:SetTextColor(C.text);loop:SizeToContents()
  loop.OnChange=function(_,v) P:Request("loop",{channel=c.id,value=v}) end
  module(content,"02","ЗВУКОВОЙ ТРАКТ")
  local volume=content:Add("DNumSlider");volume:Dock(TOP);volume:SetTall(38);volume:SetText("Громкость");volume:SetMin(0);volume:SetMax(100);volume:SetDecimals(0);volume:SetValue((c.volume or 1)*100);volume.Label:SetTextColor(C.text)
  button(content,"Применить громкость",function() P:Request("volume",{channel=c.id,value=volume:GetValue()/100}) end)
  local sound=entry(content,"Отдельная звуковая дорожка",c.sound,"Необязательно; заменяет звук видео")
  button(content,"Применить звук",function() P:Request("sound",{channel=c.id,source=sound:GetValue(),loop=loop:GetChecked()}) end)
  module(content,"03","СОПРОВОЖДЕНИЕ / ОБСЛУЖИВАНИЕ")
  local captions=entry(content,"Субтитры","", "briefing_ru.srt  /  off")
  button(content,"Загрузить субтитры",function() P:Request("captions",{channel=c.id,file=captions:GetValue()}) end)
  button(content,"Повторить подключение на этом клиенте",function() P:DropPlayer(c.id) end)
  button(content,"Переименовать канал",function() Derma_StringRequest("Название канала","Новое название",c.name,function(name) P:Request("rename",{channel=c.id,name=name}) end) end)
  local remove=button(content,"Удалить канал",function() Derma_Query("Удалить канал «"..c.name.."»?","Удаление канала","Удалить",function() P:Request("deleteChannel",{channel=c.id}) end,"Отмена") end,C.red)
  remove:SetEnabled(c.id~=1)
 end
 self:RefreshTVLists()
end
function P:BeginPlacement(channel)
 if IsValid(self.tvWindow) then self.tvWindow:Remove() end
 self.editPreview=nil;self.placementPreview=nil
 self.placement={channel=channel or 1,preset=true,left=true,right=true,key=true}
end
net.Receive("ixTVOpen",function()
 if not LocalPlayer():IsAdmin() then return end
 local place,id=net.ReadBool(),net.ReadUInt(20)
 if place then P:BeginPlacement(1)
 elseif id>0 and P.screens[id] then P:OpenScreenEditor(id)
 else P:OpenTVAdmin() end
end)
net.Receive("ixTVReply",function()
 local result=util.JSONToTable(net.ReadString());if not istable(result) then return end
 local action=P.pending and P.pending.action;P.pending=nil
 if result.ok and result.screen then P.placement=nil;P.placementPreview=nil;P:OpenScreenEditor(result.screen)
 elseif result.ok and action=="removeScreen" then P:OpenTVAdmin("screens")
 elseif result.ok and (action=="createChannel" or action=="deleteChannel" or action=="rename") then P:OpenTVAdmin("channels") end
 P:Feedback(result.message,result.ok)
end)
hook.Add("Think","ixTVPlacement",function()
 local state=P.placement;if not state then return end
 local p=LocalPlayer()
 if not IsValid(p) or not p:IsAdmin() or input.IsKeyDown(KEY_ESCAPE) or gui.IsGameUIVisible() then P.placement=nil;P.placementPreview=nil;return end
 local trace=p:GetEyeTrace();local cfg,world,ent=T.SurfaceConfig(trace)
 if cfg and trace.HitPos:DistToSqr(p:GetShootPos())<=512*512 then
  if not world and state.preset and not ix.PropScreens.Occupied(ent) and P.presets[ent:GetModel()] then cfg=table.Copy(P.presets[ent:GetModel()]) end
  P.placementPreview={config=cfg,world=world,entity=not world and ent or nil,model=not world and ent:GetModel() or nil,origin=world and (trace.HitPos+trace.HitNormal*.35) or nil}
 else P.placementPreview=nil end
 local left,right,key=input.IsMouseDown(MOUSE_LEFT),input.IsMouseDown(MOUSE_RIGHT),input.IsKeyDown(KEY_R)
 if key and not state.key then state.preset=not state.preset end
 if right and not state.right then P.placement=nil;P.placementPreview=nil;P:OpenTVAdmin("screens");return end
 if left and not state.left and P.placementPreview then P:Request("place",{channel=state.channel,preset=state.preset}) end
 state.left,state.right,state.key=left,right,key
end)
hook.Add("CreateMove","ixTVPlacementInput",function(cmd)
 if P.placement then cmd:SetButtons(bit.band(cmd:GetButtons(),bit.bnot(bit.bor(IN_ATTACK,IN_ATTACK2,IN_RELOAD)))) end
end)
hook.Add("HUDPaint","ixTVPlacementHUD",function()
 -- Project the placement guide in the same HUD pass as the instructions.
 -- It is independent of TV power, media, backface culling and world depth.
 local previewVisible=P:PaintScreenPreview()
 if not P.placement then
  if IsValid(P.tvWindow) or gui.IsGameUIVisible() then return end
  local p=LocalPlayer();if not IsValid(p) then return end
  local target=ix.PropScreens.Aim(p,220);if not target or target.kind~="tv" then return end
  local s=target.row
  local c=P.channels[s.channel];local x,y=ScrW()/2,ScrH()*.72
  draw.RoundedBox(6,x-225,y-10,450,68,C.bg)
  draw.SimpleText(T.FitText(s.name.."  /  "..(c and c.name or "Нет канала"),"ixTVBody",420),"ixTVBody",x,y,C.text,TEXT_ALIGN_CENTER)
  local text=p:IsAdmin() and "E — настройка экрана    Shift + E — питание" or (s.on and "E — выключить экран" or "E — включить экран")
  draw.SimpleText(text,"ixTVSmall",x,y+30,C.accent,TEXT_ALIGN_CENTER)
  return
 end
 local w,h=math.min(720,ScrW()-40),104;local x,y=(ScrW()-w)/2,ScrH()-h-38
 surface.SetDrawColor(C.bg);surface.DrawRect(x,y,w,h)
 surface.SetDrawColor(C.face);surface.DrawRect(x,y,w,36)
 draw.SimpleText("TV / РАЗМЕЩЕНИЕ ЭКРАНА","ixTVTitle",x+20,y+8,C.ink)
 draw.SimpleText("ЛКМ — разместить    ПКМ — назад    R — пресет / по поверхности","ixTVBody",x+20,y+47,C.muted)
 local preview=P.placementPreview
 local usingPreset=preview and not preview.world and P.placement.preset and not ix.PropScreens.Occupied(preview.entity) and P.presets[preview.model]
 local hint=preview and (usingPreset and "Сохранённое размещение для модели" or "Размещение по поверхности") or "Наведитесь на поверхность ближе 512 ед."
 if preview and previewVisible==false then hint=usingPreset and "Экран пресета вне поля зрения. R — размещение по поверхности." or "Экран вне поля зрения. Измените ракурс." end
 draw.SimpleText(T.FitText(hint,"ixTVRack",w-40),"ixTVRack",x+20,y+78,preview and previewVisible~=false and C.accent or C.amber)
end)

