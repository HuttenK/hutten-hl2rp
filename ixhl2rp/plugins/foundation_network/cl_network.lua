local N=ix.FoundationNet
local C=N.colors
local function reduced() return ix.option and ix.option.Get('disableAnimations',false) end
local function ease(v) v=math.Clamp(v,0,1);return v*v*(3-2*v) end
function N.Request(action,data)
 local panel=ix.gui.foundationNetwork
 if not IsValid(panel) or (action~="logout" and (N.nextRequest or 0)>RealTime()) then return false end
 if (action=='mapSync' or action=='utilitySync') and (panel.busyAt or panel.queuedPage) then return false end
 data=data or {};data.token=panel.token;data.route=data.route or panel.route
 local raw=util.TableToJSON(data);if not raw or #raw>100000 then return false end
 local packed=util.Compress(raw);if not packed or #packed>60000 then return false end
 if action~='mapSync' and action~='utilitySync' and action~='logout' then panel.busyAt=RealTime();panel.requestAction=action end
 N.nextRequest=RealTime()+.3
 net.Start("ixFoundationRequest");net.WriteString(action);net.WriteEntity(panel.entity);net.WriteUInt(#packed,16);net.WriteData(packed,#packed);net.SendToServer()
 return true
end
local function label(parent,value,font,color)
 local p=parent:Add("DLabel");p:Dock(TOP);p:DockMargin(0,0,0,12);p:SetFont(font or "FoundationText");p:SetTextColor(color or C.text)
 p:SetText(value or "");p:SetWrap(true);p:SetAutoStretchVertical(true);return p
end
local function button(parent,value,fn)
 local b=parent:Add("DButton");b:Dock(TOP);b:DockMargin(0,0,0,7);b:SetTall(52);b:SetText("");b.foundationControl="button"
 b.Paint=function(s,w,h)
  local caption=isfunction(value) and value() or value
  s.hover=Lerp(reduced() and 1 or math.min(FrameTime()*14,1),s.hover or 0,s.foundationHover and 1 or 0)
  N.ButtonFace(s,w,h)
  surface.SetDrawColor(70,105,127,60+100*s.hover);surface.DrawRect(14,h-2,w-28,1)
  surface.SetFont('FoundationText');local tw=surface.GetTextSize(caption)
  draw.SimpleText(caption,tw>w-42 and 'FoundationMono' or 'FoundationText',20,h/2,C.text,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
 end
 b.DoClick=function() if ix.Fieldlink and ix.Fieldlink.Sound then ix.Fieldlink.Sound('click') end;fn() end;return b
end
local function entry(parent,placeholder,height)
 label(parent,placeholder,'FoundationMono',C.muted)
 local e=parent:Add("DTextEntry");e:Dock(TOP);e:DockMargin(0,0,0,10);e:SetTall(height or 48);e:SetFont("FoundationText")
 e.foundationControl="text";e.foundationMultiline=(height or 48)>60;e:SetPlaceholderText(placeholder);e:SetMultiline(e.foundationMultiline);N.StyleEntry(e);return e
end
function N.StyleEntry(e)
 e:SetTextColor(C.text);e:SetCursorColor(C.red);e:SetHighlightColor(C.line)
 e.Paint=function(s,w,h)
  draw.RoundedBox(8,0,0,w,h,Color(12,20,31));surface.SetDrawColor(s:HasFocus() and C.amber or C.line);surface.DrawRect(0,h-2,w,2)
  s:DrawTextEntryText(C.text,C.red,C.text)
 end
end
function N.StyleControl(b)
 b:SetFont('FoundationText');b:SetTextColor(C.text)
 b.Paint=function(s,w,h)
  N.ButtonFace(s,w,h)
 end
end
function N.StyleScroll(panel)
 local bar=panel:GetVBar();bar.foundationControl='scroll';bar:SetWide(8)
 bar.Paint=function(_,w,h) surface.SetDrawColor(C.panel);surface.DrawRect(0,0,w,h) end
 bar.btnUp.Paint=function() end;bar.btnDown.Paint=function() end
 bar.btnGrip.Paint=function(_,w,h) surface.SetDrawColor(C.line);surface.DrawRect(0,0,w,h) end
end
local PANEL={}
function PANEL:SurfaceModal(title)
 if IsValid(self.modal) then self.modal:Remove() end
 local overlay=self:Add("DPanel");overlay:SetPos(0,0);overlay:SetSize(self:GetSize());overlay:SetZPos(1000)
 overlay.Paint=function(_,w,h) surface.SetDrawColor(C.bg);surface.DrawRect(0,0,w,h) end
 overlay:DockPadding(35,25,35,25);self.modal=overlay
 button(overlay,"← Назад",function() overlay:Remove() end)
 label(overlay,title,"FoundationTitle")
 local scroll=overlay:Add("DScrollPanel");scroll:Dock(FILL);scroll:GetVBar().foundationControl="scroll"
 N.StyleScroll(scroll)
 self.modalScroll=scroll;return scroll
end
function PANEL:SurfaceConfirm(title,fn)
 local content=self:SurfaceModal(title)
 button(content,"Подтвердить",function() self.modal:Remove();fn() end)
end
function PANEL:SurfaceReason(title,fn)
 local content=self:SurfaceModal(title)
 local reason=entry(content,"Причина (5–240 байт)",100)
 button(content,"Продолжить",function() local value=reason:GetValue();self.modal:Remove();fn(value) end)
end
local function webText(parent,body)
 for _,line in ipairs(string.Explode("\n",body or "")) do
  if line~="" then
   local heading=line:sub(1,2)=="# "
   label(parent,heading and line:sub(3) or line,heading and "FoundationTitle" or "FoundationText",heading and C.amber or C.text)
  end
 end
end
function PANEL:WebEditor(data)
 local v=data.webEdit
 local template,theme=v.template or 'portal',v.theme or 'crimson'
 local image=v.image or 'none'
 local hidden=v.hidden==true
 local function selector(prefix,choices,get,set)
  label(self.body,prefix,'FoundationMono',C.amber)
  if #choices>6 then
   local function caption() for _,choice in ipairs(choices) do if choice[1]==get() then return choice[2]..'    /    Выбрать →' end end;return 'Выбрать →' end
   button(self.body,caption,function()
    local scroll=self:SurfaceModal(prefix)
    for _,choice in ipairs(choices) do
     local item=button(scroll,choice[2]..(choice[1]==get() and '   ✓' or ''),function()
      set(choice[1]);self.modal:Remove()
     end)
     item:SetTall(92)
    end
   end)
   return
  end
  local row=self.body:Add('DPanel');row:Dock(TOP);row:SetTall(72);row:DockMargin(0,0,0,24);row.Paint=function() end
  local buttons={}
  for _,choice in ipairs(choices) do
   local b=row:Add('DButton');b:SetText('');b.foundationControl='button'
   b.Paint=function(_,w,h)
    local active=get()==choice[1];draw.RoundedBox(10,0,0,w,h,active and Color(36,72,81) or C.panel)
    draw.SimpleText(choice[2],'FoundationText',w/2,h/2,active and C.amber or C.text,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
   end
   b.DoClick=function() set(choice[1]) end;buttons[#buttons+1]=b
  end
  row.PerformLayout=function(_,w,h) local width=(w-12*(#buttons-1))/#buttons;for i,b in ipairs(buttons) do b:SetPos((i-1)*(width+12),0);b:SetSize(width,h) end end
 end
 selector('ШАБЛОН САЙТА',N.siteTemplates,function() return template end,function(value) template=value end)
 selector('ЦВЕТОВАЯ ТЕМА',N.siteThemes,function() return theme end,function(value) theme=value end)
 selector('ОБЛОЖКА САЙТА',N.siteImages or {{'none','Без изображения'}},function() return image end,function(value) image=value end)
 selector('ВИДИМОСТЬ САЙТА',{{false,'В каталоге'},{true,'Только по URL'}},function() return hidden end,function(value) hidden=value end)
 label(self.body,'«Только по URL»: опубликованная страница скрыта из каталога и ссылок сайтов. Введите scip://web/адрес в браузере. Допуск карты всё равно проверяется.','FoundationMono',C.muted)
 label(self.body,"АДМИНИСТРАТОР / СОЗДАНИЕ И РЕДАКТИРОВАНИЕ","FoundationMono",C.amber)
 label(self.body,"Адрес (1–40), заголовок (220), описание (400), текст (64000 байт). До 32 ссылок.","FoundationMono",C.muted)
 local slug=entry(self.body,"Адрес: engineering");slug:SetText(v.slug);slug:SetEditable(v.revision==0)
 local title=entry(self.body,"Заголовок");title:SetText(v.title)
 local summary=entry(self.body,"Краткое описание");summary:SetText(v.summary)
 local body=entry(self.body,"# Заголовок раздела\nТекст страницы",250);body:SetText(v.body)
 local level=entry(self.body,"Минимальный допуск: 1–4");level:SetText(tostring(v.level))
 if v.minimum then label(self.body,'Для этого досье нельзя установить допуск ниже L'..v.minimum..'.','FoundationMono',C.amber) end
 if v.accessLabel then label(self.body,'Доступ: '..v.accessLabel,'FoundationMono',C.amber) end
 label(self.body,"Ссылки: подпись | scip://адрес (каждая с новой строки)","FoundationMono",C.muted)
 local links=entry(self.body,"Электроснабжение | scip://power",110)
 local lines={};for _,link in ipairs(v.links or {}) do lines[#lines+1]=link.title.." | "..link.url end;links:SetText(table.concat(lines,"\n"))
 local function payload(published)
  local result={slug=string.Trim(slug:GetValue()):lower(),title=title:GetValue(),summary=summary:GetValue(),body=body:GetValue(),level=tonumber(level:GetValue()),published=published,hidden=hidden,revision=v.revision,links={},template=template,theme=theme,image=image}
  for _,line in ipairs(string.Explode("\n",links:GetValue())) do if string.Trim(line)~="" then
   local name,url=line:match("^(.-)%s*|%s*(.-)$")
   if not name or not url then self.notice="Формат ссылки: подпись | scip://адрес";return end
   result.links[#result.links+1]={title=string.Trim(name),url=string.Trim(url)}
  end end
  return result
 end
 button(self.body,"Предпросмотр",function()
  local draft=payload(false);if not draft then return end
  local preview=self:SurfaceModal("Предпросмотр — не опубликовано")
  
  local scroll=preview;self.modalScroll=scroll
  N.RenderSite(scroll,draft,function(url) self:Navigate(url) end)
 end)
 button(self.body,"Сохранить как черновик / снять с публикации",function() local d=payload(false);if d then N.Request("webSave",d) end end)
 button(self.body,"Опубликовать страницу",function() local d=payload(true);if d then N.Request("webSave",d) end end)
 if v.revision>0 then button(self.body,"Удалить страницу",function()
  self:SurfaceConfirm("Удалить scip://web/"..v.slug.."?",function() N.Request("webDelete",{slug=v.slug,revision=v.revision}) end)
 end) end
end
function PANEL:Init()
 self:SetSize(N.screenWidth,N.screenHeight);self:SetPos(0,0);self:SetPaintedManually(true)
 self.bootAt=RealTime();self.bootDuration=reduced() and 0 or 2.2
 self.history={};self.historyIndex=0;self.route='scip://home'
 if ix.Fieldlink and ix.Fieldlink.Sound then ix.Fieldlink.Sound('boot') end
 self.close=self:Add('DButton');self.close:SetText('×');self.close.foundationControl='button';N.StyleControl(self.close)
 self.close.DoClick=function() self:CloseSession() end
 self.side=self:Add('DPanel');self.side.Paint=function() end
 self.main=self:Add('DPanel');self.main.Paint=function() end
 self.bar=self.main:Add('DPanel');self.bar.Paint=function(_,w,h) draw.RoundedBox(10,0,0,w,h,C.panel) end
 self.back=self.bar:Add('DButton');self.back:SetText('←');self.back.foundationControl='button';self.back.DoClick=function() self:Travel(-1) end
 self.forward=self.bar:Add('DButton');self.forward:SetText('→');self.forward.foundationControl='button';self.forward.DoClick=function() self:Travel(1) end
 self.go=self.bar:Add('DButton');self.go:SetText('Открыть');self.go.foundationControl='button';self.go.DoClick=function() self:Navigate(self.address:GetValue()) end
 self.address=self.bar:Add('DTextEntry');self.address:SetFont('FoundationMono');self.address.foundationControl='text';N.StyleEntry(self.address)
 self.address.OnEnter=function(e) self:Navigate(e:GetValue()) end
 for _,b in ipairs({self.back,self.forward,self.go}) do N.StyleControl(b) end
 self.body=self.main:Add('DScrollPanel');N.StyleScroll(self.body)
 self:Login()
end
function PANEL:PerformLayout(w,h)
 if not IsValid(self.body) then return end
 self.close:SetPos(w-72,22);self.close:SetSize(42,42)
 self.side:SetPos(18,118);self.side:SetSize(112,h-175)
 self.main:SetPos(self.token and 158 or 48,118);self.main:SetSize(w-(self.token and 196 or 96),h-174)
 local mw,mh=self.main:GetSize();local browser=self.token and (self.route:find('scip://web',1,true)==1 or self.route:find('scip://editor',1,true)==1)
 self.bar:SetVisible(browser==true);self.bar:SetPos(0,0);self.bar:SetSize(mw,58)
 self.back:SetPos(6,5);self.back:SetSize(48,48);self.forward:SetPos(60,5);self.forward:SetSize(48,48)
 self.go:SetPos(mw-150,5);self.go:SetSize(140,48);self.address:SetPos(128,5);self.address:SetSize(mw-300,48)
 local top=browser and 76 or 0;self.body:SetPos(0,top);self.body:SetSize(mw,mh-top)
 self.side:SetVisible(self.token~=nil)
 if self.navButtons then for i,b in ipairs(self.navButtons) do b:SetPos(0,(i-1)*92);b:SetSize(112,82) end end
end

function PANEL:Paint(w,h)
 surface.SetDrawColor(C.bg);surface.DrawRect(0,0,w,h)
 surface.SetDrawColor(14,25,32);surface.DrawRect(0,0,w,92)
 surface.SetDrawColor(C.line);surface.DrawLine(28,92,w-28,92)
 if ix.Fieldlink and ix.Fieldlink.DrawSCP then ix.Fieldlink.DrawSCP(30,18,54,C.amber) end
 draw.SimpleText('SCiPNET','FoundationTitle',102,14,C.text)
 draw.SimpleText('FOUNDATION OPERATING NETWORK','FoundationSmall',104,58,C.muted)
 draw.SimpleText('●  ЛОКАЛЬНАЯ СЕТЬ','FoundationMono',w*.45,35,C.amber)
 if self.userData then
  draw.SimpleText(self.userData.publicAccess and 'Открытый доступ' or self.userData.name..' / L'..self.userData.level,'FoundationText',w-520,19,C.text)
  draw.SimpleText(self.userData.department,'FoundationSmall',w-520,55,C.muted)
 else draw.SimpleText(self.publicAccess and 'БИБЛИОТЕКА КЛАССА D' or 'АВТОРИЗАЦИЯ ПО КАРТЕ','FoundationMono',w-465,35,C.muted) end
 if self.token then surface.SetDrawColor(C.line);surface.DrawLine(142,118,142,h-64) end
end

function PANEL:PaintOver(w,h)
 -- Repaint the fixed shell above any off-screen scrolled content as a final guard.
 surface.SetDrawColor(C.bg);surface.DrawRect(0,h-48,w,48)
 draw.SimpleText(self.notice or 'SECURE. CONTAIN. PROTECT.  /  SCiPNET 6','FoundationMono',48,h-34,C.muted)
 draw.SimpleText(os.date('%H:%M'),'FoundationMono',w-130,h-34,C.amber)
 local age=RealTime()-self.bootAt
 if age<self.bootDuration then
  local fade=1-ease((age-(self.bootDuration-.4))/.4)
  local function tint(c) return Color(c.r,c.g,c.b,255*fade) end
  surface.SetDrawColor(tint(C.bg));surface.DrawRect(0,0,w,h)
  local progress=ease(age/self.bootDuration)
  if ix.Fieldlink and ix.Fieldlink.DrawSCP then ix.Fieldlink.DrawSCP(w/2-90,h/2-190,180,tint(C.red)) end
  draw.SimpleText('SCiP / OS','FoundationHero',w/2,h/2+26,tint(C.text),TEXT_ALIGN_CENTER)
  local stage=age<.7 and 'ИНИЦИАЛИЗАЦИЯ ИНТЕРФЕЙСА' or (age<1.5 and 'ПОДГОТОВКА РАБОЧЕЙ СРЕДЫ' or 'ТЕРМИНАЛ ГОТОВ')
  draw.SimpleText(stage,'FoundationMono',w/2,h/2+132,tint(C.muted),TEXT_ALIGN_CENTER)
  draw.RoundedBox(3,w/2-250,h/2+192,500,5,tint(C.panel));draw.RoundedBox(3,w/2-250,h/2+192,500*progress,5,tint(C.amber))
 elseif self.busyAt or self.queuedPage then
  local x,y=self.main:GetPos();local mw,mh=self.main:GetSize()
  draw.RoundedBox(16,x,y,mw,mh,Color(8,13,22,240))
  draw.SimpleText(self.requestAction=='login' and not self.publicAccess and 'Проверка удостоверения' or 'Открытие ресурса','FoundationTitle',x+mw/2,y+mh/2-40,C.text,TEXT_ALIGN_CENTER)
  draw.SimpleText('ОЖИДАНИЕ ОТВЕТА СЕТИ','FoundationMono',x+mw/2,y+mh/2+28,C.muted,TEXT_ALIGN_CENTER)
  local t=RealTime();for i=0,2 do draw.RoundedBox(4,x+mw/2-36+i*28,y+mh/2+82,8,8,Color(87,214,207,80+175*(.5+.5*math.sin(t*5-i)))) end
 end
end
function PANEL:Login()
 self.token=nil;self.userData=nil;self.busyAt=nil;self.queuedPage=nil;self.notice=nil
 self.body:Stop();self.body:SetAlpha(255)
 if IsValid(self.modal) then self.modal:Remove() end
 self.body:Clear();self.side:Clear();self.navButtons=nil;self:InvalidateLayout(true)
 if self.publicAccess then
  label(self.body,'БИБЛИОТЕКА КЛАССА D','FoundationHero',C.text)
  label(self.body,'Документы класса D и уборщиков. Открытый доступ без ключ-карты.','FoundationText',C.muted)
  button(self.body,'Открыть библиотеку  →',function() N.Request('login') end):SetTall(78)
  return
 end
 local login=self.body:Add('DPanel');login:Dock(TOP);login:SetTall(890)
 login.Paint=function(_,w,h)
  surface.SetDrawColor(12,24,31);surface.DrawRect(0,0,w,h)
  N.Art('facility',0,0,w*.61,h)
  surface.SetDrawColor(5,14,20,110);surface.DrawRect(0,0,w*.61,h)
  draw.SimpleText('SECURE. CONTAIN. PROTECT.','FoundationMono',48,48,C.amber)
  draw.SimpleText('ВНУТРЕННИЙ','FoundationHero',48,h-300,C.text)
  draw.SimpleText('КОНТУР ФОНДА','FoundationHero',48,h-218,C.text)
  draw.SimpleText('Инфраструктура. Знания. Координация.','FoundationText',52,h-105,C.text)
 end
 local form=login:Add('DPanel');form.Paint=function(_,w,h)
  N.Icon('card',12,10,84,C.amber)
  surface.SetDrawColor(C.line);surface.DrawLine(0,116,w,116)
 end;form:DockPadding(0,158,0,0)
 login.PerformLayout=function(_,w,h) form:SetPos(w*.65,105);form:SetSize(w*.31,h-180) end
 label(form,'ДОБРО ПОЖАЛОВАТЬ','FoundationMono',C.amber)
 label(form,'Идентификация','FoundationTitle')
 label(form,'Приложите зарегистрированную ключ-карту Фонда. Рабочая среда откроется с вашим уровнем допуска.')
 local scan=button(form,'Считать карту  →',function() N.Request('login') end);scan:SetTall(78);scan:DockMargin(0,32,0,28)
 label(form,'01   КАРТА → ПРОВЕРКА → СЕАНС','FoundationMono',C.amber)
 label(form,'Изъятие карты или выход из зоны терминала завершает сеанс.','FoundationMono',C.muted)
end

function PANEL:Navigate(route,travel)
 if not self.token then return end
 route=string.Trim(route or ""):lower();if not route:match("^scip://[%w_/%-]+$") then self.notice="Используйте внутренний адрес scip://";return end
 if N.Request("navigate",{route=route}) then self.pendingTravel=travel;self.notice="Подключение к ресурсу…" end
end
function PANEL:Travel(offset)
 local index=self.historyIndex+offset
 if self.history[index] then self:Navigate(self.history[index],index) end
end
local apps={
 {'01','Диспетчерская','home','Обзор инфраструктуры и быстрый доступ'},
 {'02','Энергосеть','power','Состояние цепей и дистанционная изоляция'},
 {'03','Биоконтроль','infection','Очаги заражения и подавление роста'},
 {'04','Журнал','logs','История доступа и команд персонала'},
 {'05','Заявки','service','Регистрация неисправностей объекта'},
 {'06','Архив сайтов','web','Внутренние публикации и инструкции'},
 {'07','Картография','map','Пространственная модель объекта'},
 {'08','Инфраструктура','utilities','Связь, двери, резервное питание и обслуживание'}
}
local function plate(parent,title,subtitle,height)
 local p=parent:Add('DPanel');p:Dock(TOP);p:DockMargin(0,0,0,18);p:SetTall(height or 170);p:DockPadding(24,24,24,20)
 p.Paint=function(_,w,h)
  surface.SetDrawColor(C.panel);surface.DrawRect(0,0,w,h);surface.SetDrawColor(C.line);surface.DrawRect(0,h-1,w,1)
 end
 label(p,title,'FoundationTitle');if subtitle then label(p,subtitle,'FoundationText',C.muted) end
 p.Think=function(panel)
  local needed=44
  for _,child in ipairs(panel:GetChildren()) do
   local _,top,_,bottom=child:GetDockMargin();needed=needed+child:GetTall()+top+bottom
  end
  local tall=math.max(height or 170,needed)
  if panel:GetTall()~=tall then panel:SetTall(tall) end
 end
 return p
end
function PANEL:Navigation(data)
 self.userData=data;self.navButtons={}
 local entries={}
 if data.publicAccess then entries={{'Библиотека','web'}}
 else for _,app in ipairs(apps) do entries[#entries+1]={app[2],app[3]} end end
 if data.webAdmin and not data.publicAccess then entries[#entries+1]={'Редактор','editor'} end
 entries[#entries+1]={'Выход',false}
 local captions={home='Обзор',power='Питание',infection='Биозоны',logs='Журнал',service='Заявки',web='Браузер',map='Карта',utilities='Системы',editor='Редактор'}
 if data.publicAccess then captions.web='Библиотека' end
 for _,app in ipairs(entries) do
  local nav=self.side:Add('DButton');nav:SetText('');nav.foundationControl='button'
  nav.Paint=function(b,w,h)
   local active=app[2] and self.route:match('^scip://([^/]+)')==app[2]
   N.ButtonFace(b,w,h,active)
   N.Icon(app[2] or 'exit',w/2-18,12,36,active and C.amber or C.muted)
   draw.SimpleText(captions[app[2]] or 'Выход','FoundationSmall',w/2,h-27,active and C.text or C.muted,TEXT_ALIGN_CENTER)
  end
  nav.DoClick=function() if ix.Fieldlink and ix.Fieldlink.Sound then ix.Fieldlink.Sound('click') end;if app[2] then self:Navigate('scip://'..app[2]) else self:CloseSession() end end
  self.navButtons[#self.navButtons+1]=nav
 end
 self:InvalidateLayout(true)
end

function PANEL:TileGrid(entries)
 local grid=self.body:Add('DIconLayout');grid:Dock(TOP);grid:SetSpaceX(18);grid:SetSpaceY(18)
 local tiles={}
 for index,entry in ipairs(entries) do
  local tile=grid:Add('DButton');tile:SetText('');tile.foundationControl='button';tile:SetSize(510,340)
  tile.DoClick=function() if ix.Fieldlink and ix.Fieldlink.Sound then ix.Fieldlink.Sound('click') end;self:Navigate(entry.url) end
  tile.Paint=function(b,w,h)
   local t=N.Hover(b);N.CutBox(0,0,w,h,Color(18+8*t,32+12*t,41+12*t),18)
   local kind=entry.url:match('scip://([^/]+)') or 'web'
   if entry.image then N.Art(entry.image,0,0,w,114,190+65*t) else N.Icon(kind,24,20,42,C.amber) end
   draw.SimpleText('↗','FoundationTitle',w-55,20,C.amber)
   if entry.level then
    surface.SetDrawColor(5,15,21,235);surface.DrawRect(12,12,64,34)
    draw.SimpleText('L'..entry.level,'FoundationMono',24,18,C.amber)
   end
   surface.SetDrawColor(111,233,219,60+190*t);surface.DrawRect(0,h-2,w*t,2)
  end
  local title=tile:Add('DLabel');title:SetFont('FoundationText');title:SetText(entry.title);title:SetTextColor(C.text);title:SetWrap(true)
  local detail=tile:Add('DLabel');detail:SetFont('FoundationMono');detail:SetText(entry.accessLabel and (entry.accessLabel..'\n'..(entry.detail or '')) or (entry.detail or ''));detail:SetTextColor(C.muted);detail:SetWrap(true)
  tile.PerformLayout=function(_,w,h) local y=entry.image and 126 or 84;title:SetPos(24,y);title:SetSize(w-48,110);detail:SetPos(24,y+118);detail:SetSize(w-48,h-y-126) end
  tiles[#tiles+1]=tile
 end
 grid.Think=function(g)
  local width=math.floor((g:GetWide()-36)/3)
  if width>0 and g.tileWidth~=width then g.tileWidth=width;for _,tile in ipairs(tiles) do tile:SetWide(width) end;g:Layout() end
 end
 return grid
end

function PANEL:WebDirectory(data)
 if data.publicAccess then self:TileGrid(data.rows or {});return end
 local filters=self.body:Add('DPanel');filters:Dock(TOP);filters:SetTall(60);filters:DockMargin(0,0,0,22);filters.Paint=function() end
 for _,choice in ipairs({{'all','Все ресурсы'},{'department','Службы и роли'},{'scp','Досье SCP'},{'general','Справочники'}}) do
  local b=filters:Add('DButton');b:Dock(LEFT);b:DockMargin(0,0,12,0);b:SetWide(230);b:SetText(choice[2]);b.foundationControl='button';N.StyleControl(b)
  b.Paint=function(s,w,h) N.ButtonFace(s,w,h,(self.webFilter or 'all')==choice[1]) end
  b.DoClick=function() self.webFilter=choice[1];self:ApplyPage(data) end
 end
 local search=entry(self.body,'Поиск по названию, описанию или адресу')
 search:SetText(self.webSearch or '')
 local grid,empty
 local function rebuild()
  if IsValid(grid) then grid:Remove() end
  if IsValid(empty) then empty:Remove() end
  local lower=string.utf8lower or string.lower
  local query=lower(string.Trim(search:GetValue()))
  self.webSearch=search:GetValue()
  local entries={}
  for _,v in ipairs(data.rows or {}) do
   local matches=lower(v.title..' '..(v.detail or '')..' '..v.url):find(query,1,true)
   if matches and (not self.webFilter or self.webFilter=='all' or self.webFilter==(v.category or 'general')) then entries[#entries+1]=v end
  end
  if #entries==0 then empty=label(self.body,'Нет доступных страниц по этому запросу.','FoundationText',C.muted) else grid=self:TileGrid(entries) end
 end
 search.OnChange=rebuild;rebuild()
end

function PANEL:Overview()
 local hero=self.body:Add('DPanel');hero:Dock(TOP);hero:SetTall(300);hero:DockMargin(0,0,0,24)
 hero.Paint=function(_,w,h)
  surface.SetDrawColor(C.panel);surface.DrawRect(0,0,w,h);N.Art('facility',0,0,w,h)
  draw.SimpleText('РАБОЧАЯ СЕТЬ ФОНДА','FoundationMono',36,32,C.amber)
  draw.SimpleText('Всё для вашей смены.','FoundationHero',32,95,C.text)
  draw.SimpleText('Системы объекта и внутренние ресурсы.','FoundationText',36,209,C.text)
 end
 local entries={}
 for _,app in ipairs(apps) do if app[3]~='home' then entries[#entries+1]={title=app[2],detail=app[4],url='scip://'..app[3]} end end
 self:TileGrid(entries)
end

function PANEL:PageHeading(data)
 if data.route=='scip://home' then return end
 local hero=self.body:Add('DPanel');hero:Dock(TOP);hero:SetTall(data.mapData and 74 or 136);hero:DockMargin(0,0,0,18)
 local title=hero:Add('DLabel');title:SetFont('FoundationTitle');title:SetText(data.title or '');title:SetTextColor(C.text);title:SetWrap(true)
 local sub=hero:Add('DLabel');sub:SetFont('FoundationMono');sub:SetText(data.body or '');sub:SetTextColor(C.muted);sub:SetWrap(true)
 hero.PerformLayout=function(_,w,h) title:SetPos(0,0);title:SetSize(w-180,54);sub:SetPos(0,62);sub:SetSize(w-200,h-62) end
 if not data.webEdit then
  local refresh=button(hero,'Обновить',function() self:Navigate(self.route) end);refresh:Dock(NODOCK);refresh:SetSize(160,48)
  local layout=hero.PerformLayout;hero.PerformLayout=function(p,w,h) layout(p,w,h);refresh:SetPos(w-172,2) end
 end
end

function PANEL:ApplyPage(data)
 if data.utilityUpdate then
  if self.route~=data.route or self.token~=data.token or self.busyAt or IsValid(self.modal) or input.IsMouseDown(MOUSE_LEFT) then return end
  local bar=self.body:GetVBar();local scroll=bar:GetScroll()
  self.body:Clear();if ix.Facility and data.utility then ix.Facility.RenderTerminal(self,data.utility) end
  timer.Simple(0,function() if IsValid(bar) then bar:SetScroll(scroll) end end);return
 end
 if data.mapUpdate then
  if self.route=="scip://map" and self.token==data.token and IsValid(self.mapPanel) then self.mapPanel:SetData(data.mapData) end
  return
 end
 self.busyAt=nil;self.pageAt=RealTime()
 if IsValid(self.modal) then self.modal:Remove() end
 self.publicAccess=data.publicAccess==true
 self.token=data.token;self.route=data.route;self.notice=data.message or (self.publicAccess and 'БИБЛИОТЕКА КЛАССА D / ОТКРЫТЫЙ ДОСТУП' or "СЕАНС АКТИВЕН / "..data.name.." / L"..data.level)
 if self.pendingTravel then self.historyIndex=self.pendingTravel;self.pendingTravel=nil
 elseif self.history[self.historyIndex]~=data.route then
  while #self.history>self.historyIndex do table.remove(self.history) end
  self.history[#self.history+1]=data.route;self.historyIndex=#self.history
 end
 self.address:SetText(data.route);self.bar:SetVisible(data.route:find("scip://web",1,true)==1 or data.route:find("scip://editor",1,true)==1);self.body:Clear();self.side:Clear()
 self:Navigation(data);if not data.webDesign then self:PageHeading(data) end
 if data.webDesign then N.RenderSite(self.body,data.webDesign,function(url) self:Navigate(url) end) end
 if data.utility and ix.Facility then ix.Facility.RenderTerminal(self,data.utility) end
 if data.route=='scip://home' then self:Overview() end
 if data.route=='scip://web' then self:WebDirectory(data) end
 if #(data.rows or {})==0 and (data.route=='scip://power' or data.route=='scip://infection' or data.route=='scip://logs') then
  local empty=plate(self.body,'НЕТ ДОСТУПНЫХ ЗАПИСЕЙ','Сервер не вернул объекты для этого раздела. Это не означает, что объект безопасен или системы работают штатно.',260)
  button(empty,'Обновить данные',function() self:Navigate(self.route) end)
 end
 if data.mapData then
  local toolbar=self.body:Add('DPanel');toolbar:Dock(TOP);toolbar:SetTall(60);toolbar:DockMargin(0,0,0,12);toolbar.Paint=function() end
  local layers=self.body:Add('DPanel');layers:Dock(TOP);layers:SetTall(76);layers:DockMargin(0,0,0,12)
  local map=self.body:Add('ixFoundationMap');map:Dock(TOP);map:SetTall(620);map:SetData(data.mapData);self.mapPanel=map
  N.SetupMapLayerSlider(layers,map)
  local function tool(parent,text,width,fn,state)
   local b=parent:Add('DButton');b:Dock(LEFT);b:DockMargin(0,0,8,0);b:SetWide(width);b:SetText(text);b.foundationControl='button';b.DoClick=fn;N.StyleControl(b)
   if state then b.Paint=function(s,w,h) N.ButtonFace(s,w,h,state()) end end
   return b
  end
  local display=tool(toolbar,'Объёмная карта',210,function() map.useSolid=not map.useSolid;map.dirty=true end,function() return map.useSolid end)
  display.Think=function(b) b:SetText(not map.useSolid and 'Вид: схема' or (map.solidReady and 'Карта аддона' or '3D: ожидание')) end
  tool(toolbar,'Объект',155,function() map:ResetOrbit(false) end)
  tool(toolbar,'Весь BSP',160,function() map:ResetOrbit(true) end)
  tool(toolbar,'Моя позиция',210,function() map:Home() end)
  local projection=tool(toolbar,'2D / 3D',150,function() map.threeD=not map.threeD;map.dirty=true end,function() return map.threeD end)
  projection.Think=function(b) b:SetText(map.threeD and 'Ракурс: 3D' or 'Ракурс: 2D') end
  tool(toolbar,'Срез этажа',185,function() map.cutaway=not map.cutaway;map.dirty=true end,function() return map.cutaway end)
  local mode=tool(toolbar,'ЛКМ: вращение',260,function() map.panMode=not map.panMode end)
  mode.Think=function(b) b:SetText((map.panMode or not map.threeD) and 'ЛКМ: перемещение' or 'ЛКМ: вращение') end
  local bar=self.body:Add('DPanel');bar:Dock(TOP);bar:SetTall(52);bar:DockMargin(0,12,0,12);bar.Paint=function() end
  tool(bar,'Z +128',140,function() map:Floor(1) end);tool(bar,'Z −128',140,function() map:Floor(-1) end)
  tool(bar,'+',65,function() map:Zoom(1) end);tool(bar,'−',65,function() map:Zoom(-1) end)
  tool(bar,'Север ↑',150,function() map.yaw=-90;map.pitch=89;map.dirty=true end)
  for _,layer in ipairs({{'areas','Районы'},{'power','Сбои питания'},{'infection','Заражение'},{'terminals','Терминалы'}}) do
   local id=layer[1]
   tool(bar,layer[2],175,function() map.layers[id]=not map.layers[id];map.dirty=true end,function() return map.layers[id] end)
  end
  local props=tool(bar,'Модели: вкл',180,function() map.mapProps=not map.mapProps;map.dirty=true end,function() return map.mapProps and map.useSolid end)
  props.Think=function(b) b:SetText(map.mapProps and 'Модели: вкл' or 'Модели: выкл') end
  local retry=self.body:Add('DPanel');retry:Dock(TOP);retry:SetTall(0);retry.Paint=function() end
  tool(retry,'Повторить загрузку 3D-карты',360,function() if N.Map3D then N.Map3D.Retry();map.dirty=true end end)
  retry.Think=function(p) local show=N.Map3D and (N.Map3D.error or N.Map3D.waiting) and map.useSolid;p:SetTall(show and 48 or 0) end
  if data.mapData.truncated then label(self.body,"Часть объектов скрыта: достигнут лимит телеметрии.") end
 end
 if data.webBody and not data.webDesign then webText(self.body,data.webBody) end
 if data.webEdit then self:WebEditor(data) end
 for _,row in ipairs((data.route=='scip://home' or data.route=='scip://web' or data.webDesign) and {} or (data.rows or {})) do
  local card=plate(self.body,row.url and 'ВНУТРЕННИЙ РЕСУРС' or row.title,nil,row.control and 210 or (row.status and 180 or 126))
  if row.url then button(card,row.title,function() self:Navigate(row.url) end) end
  if row.detail and row.detail~="" then label(card,row.detail) end
  if row.control then
   button(card,row.control.label,function()
    self:SurfaceReason(row.control.label.." / "..row.title,function(reason)
     self:SurfaceConfirm(row.control.label.."\n"..row.title.."\n"..reason,function()
      N.Request("facility",{command=row.control.action,zone=row.control.zone,reason=reason})
     end)
    end)
   end)
  end
  if row.status then label(card,(row.author or "").." / "..row.status,"FoundationMono",C.muted)
   if row.status~="Закрыто" then button(card,"Закрыть обращение #"..row.id,function() N.Request("closeTicket",{id=row.id}) end) end
  end
 end
 if data.route=="scip://service" or data.canPublish or data.editDocument then
  local publishing=data.canPublish or data.editDocument
  label(self.body,publishing and "РЕДАКТОР ВНУТРЕННЕГО РЕСУРСА" or "НОВОЕ ОБРАЩЕНИЕ","FoundationMono",C.amber)
  local title=entry(self.body,"Заголовок");local body=entry(self.body,"Текст",150)
  local level
  if publishing then level=entry(self.body,"Минимальный допуск (1–"..data.level..")");level:SetText("1") end
  if data.editDocument then title:SetText(data.editDocument.title);body:SetText(data.editDocument.body);level:SetText(tostring(data.editDocument.level)) end
  button(self.body,publishing and "Сохранить сайт / документ" or "Отправить обращение",function()
   N.Request(data.editDocument and "editDocument" or (data.canPublish and "publish" or "ticket"),{id=data.editDocument and data.editDocument.id,title=title:GetValue(),body=body:GetValue(),level=level and tonumber(level:GetValue())})
  end)
 end
end
function PANEL:Receive(data)
 if data.mapUpdate or data.utilityUpdate then self:ApplyPage(data);return end
 self.queuedPage=data;self.pageReadyAt=RealTime()+(reduced() and 0 or .22)
end
function PANEL:CloseSession() N.Request("logout");self:Remove() end
function PANEL:OnKeyCodePressed(key) if key==KEY_ESCAPE then self:CloseSession() end end
function PANEL:Think()
 if ix.Facility and ix.Facility.UpdateTerminal then ix.Facility.UpdateTerminal(self) end
 if ix.Facility and ix.Facility.IsScreen(self.entity) and not self.entity:GetNW2Bool("ixFacilityPowered",false) then self:CloseSession();return end
 if self.queuedPage and RealTime()>=self.pageReadyAt then
  local data=self.queuedPage;self.queuedPage=nil;self:ApplyPage(data)
  self.body:Stop();self.body:SetAlpha(reduced() and 255 or 0);if not reduced() then self.body:AlphaTo(255,.3) end
 end
 if self.busyAt and RealTime()-self.busyAt>8 then self.busyAt=nil;self.notice='Сеть не ответила. Повторите действие.' end
 local p=LocalPlayer()
 local power=ix.plugin.list.blackout
 if not IsValid(self.entity) or not IsValid(p) or not p:Alive() or p:GetPos():DistToSqr(self.entity:GetPos())>128^2 or (power and power:IsEntityBlackedOut(self.entity)) then self:CloseSession() end
end
function PANEL:OnRemove() if not self.removing then self.removing=true;if IsValid(self.inputHost) then self.inputHost:Remove() end end end
vgui.Register("ixFoundationNetwork",PANEL,"EditablePanel")
net.Receive("ixFoundationOpen",function()
 local ent=net.ReadEntity();if not IsValid(ent) then return end
 if IsValid(ix.gui.foundationNetwork) then ix.gui.foundationNetwork:Remove() end
 N.nextRequest=0;local p=vgui.Create("ixFoundationNetwork");p.entity=ent;ix.gui.foundationNetwork=p;N.AttachSurface(p)
 p.publicAccess=ent:GetClass()=='ix_foundation_public_terminal';if p.publicAccess then p:Login() end
end)
net.Receive("ixFoundationPage",function()
 local size=net.ReadUInt(16);if size>60000 then return end
 local raw=util.Decompress(net.ReadData(size),180000);local data=raw and util.JSONToTable(raw)
 if not istable(data) or not isstring(data.token) or not IsValid(ix.gui.foundationNetwork) then return end
 ix.gui.foundationNetwork:Receive(data)
end)
net.Receive("ixFoundationEnd",function() if IsValid(ix.gui.foundationNetwork) then ix.gui.foundationNetwork:Login() end end)
