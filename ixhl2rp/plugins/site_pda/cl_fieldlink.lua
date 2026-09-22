local F=ix.Fieldlink
-- Shared visual language with legends main/TAB menus; opaque LCD surfaces.
local C={bg=Color(12,8,12),panel=Color(27,12,18),line=Color(150,43,57,150),text=Color(246,104,113),muted=Color(181,151,155),red=Color(255,53,76),accent=Color(255,106,120),amber=Color(226,183,113)}
F.colors=C
-- Resolution-independent containment emblem: double enclosure and three
-- inward arrows. Cached vector geometry needs no downloaded logo/font asset.
local emblemCache={}
function F.DrawSCP(x,y,size,color)
 local key=x..":"..y..":"..size
 local mesh=emblemCache[key]
 if not mesh then
  mesh={}
  local function point(angle,radius)
   return {x=x+size*(.5+math.cos(angle)*radius),y=y+size*(.5+math.sin(angle)*radius)}
  end
  local function outer(angle)
   local sector=(angle+math.pi/2+math.pi/3)%(math.pi*2/3)-math.pi/3
   return math.abs(sector)<.23 and .49 or .425
  end
  for i=0,95 do
   local a=i*math.pi/48; local b=(i+1)*math.pi/48
   local ra,rb=outer(a),outer(b)
   mesh[#mesh+1]={point(a,ra),point(b,rb),point(b,rb-.038),point(a,ra-.038)}
   mesh[#mesh+1]={point(a,.323),point(b,.323),point(b,.293),point(a,.293)}
  end
  for i=0,2 do
   local a=-math.pi/2+i*math.pi*2/3
   local function arrow(r,t)
    return {x=x+size*(.5+math.cos(a)*r-math.sin(a)*t),y=y+size*(.5+math.sin(a)*r+math.cos(a)*t)}
   end
   mesh[#mesh+1]={arrow(.405,-.027),arrow(.405,.027),arrow(.215,.027),arrow(.215,-.027)}
   mesh[#mesh+1]={arrow(.23,-.083),arrow(.23,.083),arrow(.112,0)}
  end
  emblemCache[key]=mesh
 end
 draw.NoTexture(); surface.SetDrawColor(color)
 for _,polygon in ipairs(mesh) do surface.DrawPoly(polygon) end
end
-- Fixed device pixels: desktop resolution cannot reflow the physical LCD.
local function Scale(n) return math.floor(n*0.85) end
local function Fonts()
 for name,def in pairs({Clock={58,400},Title={28,700},Heading={21,600},Body={17,400},Small={13,500},Mono={14,500}}) do
  surface.CreateFont("Fieldlink"..name,{font=name=="Mono" and "Consolas" or "Tahoma",size=Scale(def[1]),weight=def[2],extended=true,antialias=true})
 end
end
Fonts(); hook.Add("OnScreenSizeChanged","FieldlinkFonts",Fonts)
function F.Request(action,payload)
 if (F.nextRequest or 0)>RealTime() then return false end
 F.nextRequest=RealTime()+0.36
 F.pendingAt=RealTime()
 payload=payload or {}
 if IsValid(ix.gui.fieldlink) and ix.gui.fieldlink.data then payload.device=ix.gui.fieldlink.data.device end
 net.Start("ixFieldlinkRequest"); net.WriteString(action); net.WriteString(util.TableToJSON(payload or {})); net.SendToServer()
 return true
end
local function Label(parent,text,font,color,height)
 local p=parent:Add("DLabel"); p:Dock(TOP); p:DockMargin(0,0,0,Scale(12))
 p:SetFont("Fieldlink"..(font or "Body")); p:SetTextColor(color or C.text); p:SetText(text)
 p:SetWrap(true); p:SetAutoStretchVertical(true)
 if height then p:SetTall(Scale(height)) end
 return p
end
local function Button(parent,text,fn,accent)
 local b=parent:Add("DButton"); b:SetText(""); b:SetTall(Scale(44)); b.hover=0; b.fieldlinkControl="button"
 b.Paint=function(self,w,h)
  local target=self.fieldlinkHover and 1 or 0
  self.hover=ix.option.Get("disableAnimations",false) and target or Lerp(1-math.exp(-FrameTime()*18),self.hover,target)
  local push=self.fieldlinkDown and 1 or 0
  draw.RoundedBox(Scale(4),0,push,w,h-push,Color(27+22*self.hover,12+3*self.hover,18+8*self.hover))
  surface.SetDrawColor(accent or C.line); surface.DrawOutlinedRect(0,push,w,h-push,1)
  if self.fieldlinkHover then surface.SetDrawColor(accent or C.red); surface.DrawRect(0,push,2,h-push) end
  draw.SimpleText(text,"FieldlinkBody",Scale(15),h/2,C.text,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
 end
 b.OnCursorEntered=function() F.Sound("hover") end
 b.DoClick=function() F.Sound("click"); fn() end
 return b
end
local function Row(parent,height)
 local p=parent:Add("DPanel"); p:Dock(TOP); p:SetTall(Scale(height)); p:DockMargin(0,0,0,Scale(12))
 p.Paint=function(_,w,h) draw.RoundedBox(Scale(5),0,0,w,h,C.panel) end
 return p
end
local function Field(parent,title,placeholder,multiline,value)
 Label(parent,title,"Mono",C.muted)
 local e=parent:Add("DTextEntry"); e:Dock(TOP); e:DockMargin(0,0,0,Scale(18)); e:SetTall(Scale(multiline and 140 or 44))
 e.fieldlinkControl="text"; e.fieldlinkMultiline=multiline or false
 e:SetUpdateOnType(true)
 e.m_bLoseFocusOnClickAway=false -- the projected input host owns click-away focus
 e.OpenMenu=function() end
 local typed=e.OnKeyCodeTyped
 e.OnKeyCodeTyped=function(self,key)
  if key==KEY_ESCAPE and IsValid(ix.gui.fieldlink) then ix.gui.fieldlink:RequestClose()
  elseif typed then typed(self,key) end
 end
 e:SetFont("FieldlinkBody"); e:SetMultiline(multiline or false); e:SetPlaceholderText(placeholder or ""); e:SetText(value or "")
 e.Paint=function(self,w,h)
  draw.RoundedBox(4,0,0,w,h,C.panel); surface.SetDrawColor(self:HasFocus() and C.red or C.line); surface.DrawOutlinedRect(0,0,w,h)
  self:DrawTextEntryText(C.text,C.red,C.text)
 end
 return e
end
local function Choice(parent,title,options)
 Label(parent,title,"Mono",C.muted)
 -- Inline selector: native DComboBox menus would escape the model screen.
 local row=parent:Add("DPanel"); row:Dock(TOP); row:SetTall(Scale(42)); row:DockMargin(0,0,0,Scale(18)); row.choice=1
 row.Paint=function(self,w,h)
  surface.SetDrawColor(C.panel); surface.DrawRect(0,0,w,h)
  draw.SimpleText(options[self.choice] or "","FieldlinkBody",w/2,h/2,C.text,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
 end
 local function change(step)
  row.choice=(row.choice-1+step)%#options+1
  if row.OnChoiceChanged then row:OnChoiceChanged(row.choice) end
 end
 local prev=Button(row,"<",function() change(-1) end)
 prev:Dock(LEFT); prev:SetWide(Scale(45))
 local next=Button(row,">",function() change(1) end)
 next:Dock(RIGHT); next:SetWide(Scale(45))
 return row
end
local function Action(parent,text,fn)
 local b=Button(parent,text,fn,C.red); b:Dock(TOP); b:DockMargin(0,0,0,Scale(10)); return b
end
local PANEL={}
function PANEL:Init()
 Fonts()
 self:SetTitle(""); self:ShowCloseButton(false); self:SetDraggable(false); self:SetSizable(false)
 self:SetSize(F.screenWidth,F.screenHeight); self:SetPos(0,0)
 -- Only the transparent input host is a popup. Keep the rendered UI in its
 -- keyboard-focus hierarchy rather than creating a competing popup.
 self:SetPaintedManually(true); self:SetMouseInputEnabled(false); self:SetKeyboardInputEnabled(true)
 self:SetBackgroundBlur(false); self:SetDeleteOnClose(true)
 self.page="overview"; self.data=nil; self.born=RealTime(); self.toast="Подключение к защищённому каналу…"
 self.sidebar=self:Add("DPanel"); self.sidebar:Dock(LEFT); self.sidebar:SetWide(Scale(88)); self.sidebar:DockMargin(Scale(18),Scale(76),0,Scale(48))
 self.sidebar.Paint=function(_,w,h) surface.SetDrawColor(C.line); surface.DrawLine(w-1,0,w-1,h) end
 local tabs={{"Домой","overview"},{"Камера","camera"},{"Галерея","gallery"},{"Связь","messenger"},{"Инциденты","incidents"},{"Директивы","directives"},{"Архив","library"},{"Блокнот","notes"},{"Система","system"}}
 self.nav={}
 for _,tab in ipairs(tabs) do
  local title,page=tab[1],tab[2]
  local b=Button(self.sidebar,"",function() self:Navigate(page) end)
  b:Dock(TOP); b:DockMargin(0,0,Scale(8),2); b:SetTall(Scale(51)); self.nav[page]=b
  b.Paint=function(button,w,h)
   local selected=self.page==page
   if selected or button.fieldlinkHover then
    surface.SetDrawColor(66,12,25); surface.DrawRect(0,0,w,h)
    surface.SetDrawColor(C.accent); surface.DrawRect(0,0,2,h)
   end
   F.DrawAppIcon(page,w/2-8,3,16,selected and C.accent or C.muted)
   draw.SimpleText(title,"FieldlinkSmall",w/2,h-14,selected and C.text or C.muted,TEXT_ALIGN_CENTER)
  end
 end
 self.exit=Button(self.sidebar,"Сон",function() self:RequestClose() end); self.exit:Dock(BOTTOM); self.exit:DockMargin(0,0,Scale(8),0)
 self.body=self:Add("DScrollPanel"); self.body:Dock(FILL); self.body:DockMargin(Scale(22),Scale(82),Scale(26),Scale(55))
 local bar=self.body:GetVBar(); bar.fieldlinkControl="scroll"; bar:SetWide(Scale(10)); bar:SetHideButtons(true)
 bar.Paint=function() end; bar.btnGrip.Paint=function(_,w,h) surface.SetDrawColor(C.line); surface.DrawRect(0,0,w,h) end
 local character=LocalPlayer():GetCharacter()
 local device=character:GetData("fieldlinkDevice")
 self.bootDuration=ix.option.Get("disableAnimations",false) and 0 or (F.bootDevice==device and 0.24 or 1.35)
 F.bootDevice=device
 F.Sound("boot")
 self:BuildPage(); F.Request("sync"); F.AttachScreenInput(self)
end
function PANEL:IsDeviceReady()
 return self.data~=nil and RealTime()-self.born>=self.bootDuration and not self.closing
end
function PANEL:RequestClose()
 if self.closing then return end
 if self.notesDraft~=nil and self.data and self.notesDraft~=self.data.notes then
  self.toast="Заметки не сохранены. Сохраните их или нажмите «Сон» ещё раз."
  if not self.discardUntil or RealTime()>self.discardUntil then self.discardUntil=RealTime()+3; return end
 end
 self.closing=true; F.closeUntil=RealTime()+1; self:SetMouseInputEnabled(false); self:SetKeyboardInputEnabled(false)
 F.Sound("sleep")
 net.Start("ixFieldlinkClose"); net.SendToServer()
 self:AlphaTo(0,ix.option.Get("disableAnimations",false) and 0 or 0.15,0,function() if IsValid(self) then self:Remove() end end)
end
function PANEL:OnKeyCodePressed(key)
 if key==KEY_ESCAPE then self:RequestClose() end
end
function PANEL:Think()
 if F.CameraThink then F.CameraThink() end
 local ready=self:IsDeviceReady()
 self.sidebar:SetVisible(ready and not F.camera); self.body:SetVisible(ready and not F.camera)
 if self.toastUntil and RealTime()>self.toastUntil then self.toast=nil; self.toastUntil=nil end
 local focus=vgui.GetKeyboardFocus()
 local typing=IsValid(focus) and focus.GetValue~=nil
 if input.IsKeyDown(KEY_R) and not typing then
  self.lowerAt=self.lowerAt or (RealTime()+ix.config.Get("weaponRaiseTime",0.5))
  if RealTime()>=self.lowerAt then self:RequestClose(); self.lowerAt=RealTime()+1 end
 else self.lowerAt=nil end
end
function PANEL:OnRemove()
 F.camera=false; F.capturePending=nil; F.scan=nil
 if IsValid(self.inputHost) and not self.inputHost.fieldlinkRemoving then
  self.inputHost.fieldlinkRemoving=true; self.inputHost:Remove()
 end
 if self.data and self.notesDraft~=nil then F.drafts=F.drafts or {}; F.drafts[self.data.device]=self.notesDraft end
 if ix.gui.fieldlink==self then ix.gui.fieldlink=nil end
end
function PANEL:Navigate(page)
 self.page=page; self:BuildPage(); if IsValid(self.inputHost) then self.inputHost:RequestFocus() end
end
function PANEL:SetSnapshot(data)
 local old=self.data; self.data=data; self.lastSync=RealTime(); F.pendingAt=nil
 if old and (old.device~=data.device or old.character~=data.character) then
  self.notesDraft=nil; self.formDrafts={}; self.compose=nil; self.photo=nil; self.message=nil; self.page="overview"; old=nil
 end
 if not old then self.toast=nil end
 if not old and F.drafts then self.notesDraft=F.drafts[data.device] end
 if data.message then self.toast=data.message; self.toastUntil=RealTime()+5; self.awaitForm=nil end
 if data.message then F.Sound(data.message:find("отклонён",1,true) and "error" or "success") end
 if data.message=="Блокнот сохранён." then self.notesDraft=data.notes end
 if data.message=="Сообщение доставлено." and self.page=="compose" then self.compose=nil; self.page="messenger" end
 local editing=self.page=="compose" or self.page=="notes" or self.page=="report" or self.page=="publish" or self.page=="alert" or self.page=="library"
 if not old or not editing or (old.clearance~=data.clearance) then
  if (self.page=="publish" or self.page=="alert") and data.clearance<3 then self.page="overview" end
  local scroll=self.body:GetVBar():GetScroll()
  local opened=self.pageAt
  self:BuildPage()
  if old then self.body:InvalidateLayout(true); self.body:GetVBar():SetScroll(scroll); self.pageAt=opened end
 end
end
function PANEL:Header(kicker,title,description)
 Label(self.body,kicker,"Mono",C.red); Label(self.body,title,"Title")
 if description then Label(self.body,description,"Body",C.muted) end
end
function PANEL:BuildPage()
 if not IsValid(self.body) then return end
 self.body:Clear(); self.body:GetVBar():SetScroll(0)
 self.pageAt=RealTime()
 for page,b in pairs(self.nav) do b:SetAlpha(page==self.page and 255 or 160) end
 local d=self.data
 if not d then self:Header("AUTHENTICATING","Устанавливаем соединение","Проверка устройства и допуска персонажа."); return end
 if not d.registered then
  self:Header("DEVICE / UNREGISTERED","Требуется CID-карта","Этот КПК ещё не зарегистрирован в сети FIELDLINK.")
  Label(self.body,"01  Опустите КПК и откройте инвентарь.\n\n02  Перетащите CID-карту на этот КПК.\n\n03  Выберите «Зарегистрировать КПК по CID».","Heading",C.text)
  Label(self.body,"Карта не расходуется. Личность и блокнот сохраняются на устройстве. Любой, кто получит этот КПК, сможет действовать от имени зарегистрированного владельца.","Body",C.muted)
  Label(self.body,"СЕРИЙНЫЙ НОМЕР / FL-"..d.device,"Mono",C.red)
  return
 end
 if F.BuildMediaPage and F.BuildMediaPage(self,d,{Label=Label,Field=Field,Action=Action,Row=Row,Scale=Scale,C=C}) then return end
 if self.page=="overview" then
  self:Home(d)
 elseif self.page=="system" then
  self:Header("DEVICE / DIAGNOSTICS","Состояние устройства","Локальная сессия и подтверждённые данные сервера.")
  Label(self.body,"Пользователь: "..d.name,"Heading")
  Label(self.body,"Допуск: "..d.clearance.."  /  "..d.map,"Mono",C.muted)
  local status=Row(self.body,70)
  status.Paint=function(_,w,h)
   draw.SimpleText("ПОСЛЕДНЯЯ СИНХРОНИЗАЦИЯ","FieldlinkMono",16,12,C.muted)
   draw.SimpleText(math.floor(RealTime()-(self.lastSync or self.born)).." сек. назад","FieldlinkHeading",16,35,C.accent)
  end
  Action(self.body,"Синхронизировать сейчас",function() if F.Request("sync") then self.toast="Запрос отправлен…" end end)
  Label(self.body,"CID / "..d.cid.."   DEVICE / FL-"..d.device,"Mono",C.muted)
  Label(self.body,"Личность и сохранённый блокнот принадлежат этому КПК. Передача устройства передаёт доступ. Несохранённые черновики остаются только в текущем клиенте.","Body",C.muted)
  if d.clearance>=3 then Action(self.body,"Управление режимом объекта",function() self:Navigate("alert") end) end
  Action(self.body,"На рабочий стол",function() self:Navigate("overview") end)
 elseif self.page=="incidents" or self.page=="directives" then
  local incident=self.page=="incidents"
  self:Header(incident and "RESPONSE / QUEUE" or "OPERATIONS / ORDERS",incident and "Журнал инцидентов" or "Директивы смены",incident and "От наблюдения до подтверждённого решения." or "Примите назначение и отметьте результат после выполнения.")
  if incident or d.clearance>=3 then Action(self.body,incident and "+  Новый инцидент" or "+  Опубликовать директиву",function() self:Navigate(incident and "report" or "publish") end) end
  if not incident and d.clearance<3 then
   Label(self.body,"Публикация требует допуска 3. Ваш допуск: "..d.clearance..". Тип CID-карты не назначает допуск автоматически.","Body",C.amber)
   Label(self.body,"Администратор: /PDASetClearance \"Имя персонажа\" 3 — персонаж должен экипировать CID, которым зарегистрирован этот КПК. Затем синхронизируйте устройство.","Small",C.muted)
  end
  local list=incident and d.incidents or d.directives
  if #list==0 then Label(self.body,"Записей пока нет. Здесь появятся сообщения и назначения персонала.","Body",C.muted) end
  for _,record in ipairs(list) do
   local r=record
   local block=Row(self.body,115); block:DockPadding(Scale(16),Scale(12),Scale(16),Scale(10))
   local state=r.status=="closed" and "ЗАКРЫТО" or r.owner and "В РАБОТЕ / "..r.owner or "ОЖИДАЕТ ИСПОЛНИТЕЛЯ"
   Label(block,string.format("#%04d  /  %s",r.id,state),"Mono",r.status=="closed" and C.muted or C.amber)
   local b=Button(block,r.title,function() self.detail=r.id; self.detailKind=incident and "incident" or "directive"; self:Navigate("detail") end)
   b:Dock(TOP)
  end
 elseif self.page=="detail" then
  local kind=self.detailKind; local r
  for _,v in ipairs(kind=="incident" and d.incidents or d.directives) do if v.id==self.detail then r=v end end
  if not r then self:Header("RECORD UNAVAILABLE","Запись недоступна","Допуск или состояние записи изменились."); return end
  self:Header("RECORD / "..string.format("%04d",r.id),r.title,r.author.."  /  "..os.date("%d.%m %H:%M",r.time))
  if r.location then Label(self.body,"Сектор: "..r.location.."  /  "..(F.categories[r.category] or ""),"Mono",C.amber) end
  Label(self.body,r.body,"Body")
  Label(self.body,"Исполнитель: "..(r.owner or "не назначен"),"Body",C.muted)
  local function act(action) F.Request(action,{kind=kind,id=r.id}) end
  if r.status~="closed" then
   if not r.ownerID and (kind~="incident" or d.clearance>=2) then Action(self.body,"Принять назначение",function() act("claim") end) end
   if r.ownerID==d.character or d.clearance>=3 then
    Action(self.body,"Подтвердить выполнение и закрыть",function() act("resolve") end)
    if r.ownerID then Action(self.body,"Освободить назначение",function() act("release") end) end
   end
  else Label(self.body,"Закрыто: "..(r.closedBy or ""),"Mono",C.accent) end
  Action(self.body,"Вернуться к очереди",function() self:Navigate(kind=="incident" and "incidents" or "directives") end)
 elseif self.page=="report" or self.page=="publish" then
  local incident=self.page=="report"
  self:Header(incident and "NEW / INCIDENT" or "NEW / DIRECTIVE",incident and "Передать наблюдение" or "Новая директива","Кратко, точно, без непроверенных утверждений.")
  self.formDrafts=self.formDrafts or {}
  local draft=self.formDrafts[self.page] or {}; self.formDrafts[self.page]=draft
  local title=Field(self.body,"ЗАГОЛОВОК / ДО 72 СИМВОЛОВ","",false,draft.title)
  title.OnValueChange=function(_,v) draft.title=v end
  local location,category,clearance
  if incident then
   location=Field(self.body,"СЕКТОР ИЛИ ОРИЕНТИР","",false,draft.location); location.OnValueChange=function(_,v) draft.location=v end
   category=Choice(self.body,"КАТЕГОРИЯ",F.categories)
   category.choice=draft.category or 1; category.OnChoiceChanged=function(_,v) draft.category=v end
  else clearance=Choice(self.body,"МИНИМАЛЬНЫЙ ДОПУСК",{"0 / Общий","1 / Персонал","2 / Дежурный","3 / Руководитель"}) end
  if clearance then clearance.choice=draft.clearance or 1; clearance.OnChoiceChanged=function(_,v) draft.clearance=v end end
  local body=Field(self.body,"ОПИСАНИЕ / ДО 600 СИМВОЛОВ","",true,draft.body); body.OnValueChange=function(_,v) draft.body=v end
  Action(self.body,incident and "Передать инцидент" or "Опубликовать",function()
   if not F.Text(title:GetValue(),72) or not F.Text(body:GetValue(),600) or (incident and not F.Text(location:GetValue(),72)) then self.toast="Заполните заголовок, описание и сектор."; return end
   if F.Request(incident and "incident" or "publish",{title=title:GetValue(),body=body:GetValue(),location=location and location:GetValue(),category=category and category.choice,level=clearance and clearance.choice-1}) then self.awaitForm=true; self.toast="Передача…" end
  end)
 elseif self.page=="alert" then
  self:Header("COMMAND / SITE STATUS","Режим объекта","Укажите ясную инструкцию для персонала.")
  local level=Choice(self.body,"РЕЖИМ",F.alerts)
  level.choice=d.alert.level or 1
  local message=Field(self.body,"ИНСТРУКЦИЯ / ДО 220 СИМВОЛОВ","",true,d.alert.message)
  Action(self.body,"Подтвердить смену режима",function() F.Request("alert",{level=level.choice,text=message:GetValue()}) end)
 elseif self.page=="library" then
  self:Header("REFERENCE / CLEARANCE "..d.clearance,"Полевой справочник","Только материалы в пределах вашего допуска.")
  local search=Field(self.body,"ПОИСК","Название протокола",false)
  local items=self.body:Add("DPanel"); items:Dock(TOP); items:SetTall(Scale(#d.records*65)); items.Paint=function() end
  local function populate(query)
   items:Clear(); local count=0
   for _,r in ipairs(d.records) do
    if query=="" or string.find(string.utf8lower(r.title),string.utf8lower(query),1,true) then
     count=count+1; local b=Button(items,r.title,function() self.recordID=r.id; self:Navigate("record") end)
     b:Dock(TOP); b:DockMargin(0,0,0,Scale(9)); b:SetTall(Scale(52))
    end
   end
   items:SetTall(Scale(math.max(1,count)*65))
  end
  search.OnValueChange=function(_,v) populate(v) end; populate("")
 elseif self.page=="record" then
  local r; for _,v in ipairs(d.records) do if v.id==self.recordID then r=v end end
  if not r then self:Header("ACCESS","Материал недоступен"); return end
  self:Header(r.tag,r.title,"Допуск "..r.level)
  Label(self.body,r.body,"Body")
  Action(self.body,"Вернуться в справочник",function() self:Navigate("library") end)
 elseif self.page=="notes" then
  self:Header("LOCAL / DEVICE STORAGE","Полевой блокнот","Записи на этом КПК. До 2000 символов.")
  local e=Field(self.body,"ЗАМЕТКИ","",true,self.notesDraft~=nil and self.notesDraft or d.notes); e:SetTall(Scale(280))
  e.OnValueChange=function(_,v) self.notesDraft=v; self.toast="Несохранённые изменения" end
  Action(self.body,"Сохранить блокнот",function() if F.Request("notes",{text=e:GetValue()}) then self.toast="Сохранение…" end end)
 end
 if not ix.option.Get("disableAnimations",false) then self.body:SetAlpha(180); self.body:AlphaTo(255,0.14) end
end
-- Each application has its own visual mark; no external icon/font assets.
local function AppIcon(kind,x,y,size,col)
 surface.SetDrawColor(col)
 local function line(a,b,c,d) surface.DrawLine(x+a*size,y+b*size,x+c*size,y+d*size) end
 if kind=="overview" then
  for i=0,1 do for j=0,1 do surface.DrawOutlinedRect(x+i*size*.58,y+j*size*.58,size*.38,size*.38) end end
 elseif kind=="incidents" then
  line(.5,0,1,.9); line(1,.9,0,.9); line(0,.9,.5,0); line(.5,.28,.5,.57); surface.DrawRect(x+size*.47,y+size*.72,3,3)
 elseif kind=="directives" then
  for i=0,2 do local yy=.1+i*.34; line(0,yy+.08,.1,yy+.16); line(.1,yy+.16,.25,yy); line(.4,yy+.08,1,yy+.08) end
 elseif kind=="library" then
  line(0,0,0,1); line(0,0,.85,0); line(.85,0,.85,1); line(.85,1,0,1); line(.2,0,.2,1); line(.4,.3,.65,.3)
 elseif kind=="notes" then
  line(0,.1,.7,.1); line(0,.1,0,1); line(0,1,.8,1); line(.8,1,.8,.5); line(.3,.65,.9,.05); line(.4,.75,1,.15); line(.3,.65,.3,.75); line(.3,.75,.4,.75)
 elseif kind=="camera" or kind=="gallery" then
  surface.DrawOutlinedRect(x,y+size*.2,size,size*.7)
  surface.DrawCircle(x+size*.5,y+size*.54,size*.2,col)
  line(.2,.2,.3,0); line(.3,0,.65,0); line(.65,0,.75,.2)
 elseif kind=="messenger" then
  surface.DrawOutlinedRect(x,y,size,size*.75); line(0,0,.5,.45); line(.5,.45,1,0); line(.2,.75,.2,1); line(.2,1,.45,.75)
 else
  for i=0,2 do local yy=.15+i*.33; line(0,yy,1,yy); surface.DrawOutlinedRect(x+size*(i==1 and .65 or .2),y+size*yy-3,6,6) end
 end
end
F.DrawAppIcon=AppIcon
function PANEL:Home(d)
 local top=Row(self.body,96)
 top.Paint=function(_,w,h)
  draw.SimpleText(os.date("%H:%M"),"FieldlinkClock",2,0,C.text)
  draw.SimpleText(os.date("%d / %m / %Y"),"FieldlinkMono",4,60,C.muted)
  draw.SimpleText(d.name,"FieldlinkHeading",w-12,13,C.text,TEXT_ALIGN_RIGHT)
  draw.SimpleText("CID / "..d.cid.."     ACCESS / "..d.clearance,"FieldlinkMono",w-12,46,C.muted,TEXT_ALIGN_RIGHT)
 end
 local alert=d.alert or {}; local level=alert.level or 1
 local status=Row(self.body,58)
 status.Paint=function(_,w,h)
  surface.SetDrawColor(level>1 and C.red or C.accent); surface.DrawRect(0,0,3,h)
  draw.SimpleText(F.alerts[level] or F.alerts[1],"FieldlinkMono",16,8,level>1 and C.red or C.accent)
 end
 local message=status:Add("DLabel"); message:Dock(FILL); message:DockMargin(16,25,12,6); message:SetFont("FieldlinkSmall"); message:SetTextColor(C.muted); message:SetWrap(true); message:SetText(alert.message or "")
 local active,assigned=0,0
 for _,r in ipairs(d.incidents) do if r.status~="closed" then active=active+1 end end
 for _,r in ipairs(d.directives) do if r.status=="assigned" and r.ownerID==d.character then assigned=assigned+1 end end
 local apps={{"camera","Камера","Монохром / CID"},{"gallery","Галерея",#(d.photos or {}).." снимков"},{"messenger","Связь","Сообщения / вложения"},{"incidents","Инциденты",active.." открытых сообщений"},{"directives","Директивы",assigned.." ваших назначений"},{"library","Справочник",#d.records.." доступных документов"},{"notes","Блокнот","Личные записи"},{"system","Устройство","Канал / доступ / синхронизация"}}
 for i=1,#apps,2 do
  local row=Row(self.body,83); row.Paint=function() end
  local children={}
  for j=i,math.min(i+1,#apps) do
   local app=apps[j]
   local tile=Button(row,"",function() self:Navigate(app[1]) end)
   tile.Paint=function(button,w,h)
    local target=button.fieldlinkHover and 1 or 0
    button.hover=ix.option.Get("disableAnimations",false) and target or Lerp(1-math.exp(-FrameTime()*18),button.hover,target)
    surface.SetDrawColor(27+22*button.hover,12+3*button.hover,18+8*button.hover); surface.DrawRect(0,0,w,h)
    surface.SetDrawColor(button.fieldlinkHover and C.accent or C.line); surface.DrawLine(0,h-1,w,h-1)
    AppIcon(app[1],18,21,25,button.fieldlinkHover and C.accent or C.muted)
    draw.SimpleText(app[2],"FieldlinkBody",62,16,C.text)
    draw.SimpleText(app[3],"FieldlinkSmall",62,39,C.muted)
   end
   children[#children+1]=tile
  end
  row.PerformLayout=function(_,w,h)
   for n,tile in ipairs(children) do tile:SetPos((n-1)*(w+10)/2,0); tile:SetSize((w-10)/2,h) end
  end
 end
end
function PANEL:Paint(w,h)
 if F.camera then F.PaintCamera(w,h); return end
 surface.SetDrawColor(C.bg); surface.DrawRect(0,0,w,h)
 surface.SetDrawColor(C.panel); surface.DrawRect(0,0,w,48)
 surface.SetDrawColor(C.line); surface.DrawLine(0,48,w,48); surface.DrawLine(0,h-32,w,h-32)
 F.DrawSCP(18,9,30,C.red)
 draw.SimpleText("FIELDLINK","FieldlinkHeading",60,12,C.text)
 draw.SimpleText("Secure. Contain. Protect.","FieldlinkMono",210,16,C.muted)
 local age=RealTime()-(self.lastSync or self.born)
 local live=self.data and (age<15 and "LINK / ONLINE" or "LINK / STALE") or "LINK / CONNECTING"
 if F.pendingAt and RealTime()-F.pendingAt<10 then live="LINK / SYNCING" end
 draw.SimpleText(live,"FieldlinkMono",w-18,16,self.data and age<15 and C.accent or C.amber,TEXT_ALIGN_RIGHT)
 draw.SimpleText(self.toast or "R / удержать — опустить     ESC / закрыть","FieldlinkSmall",18,h-22,C.muted)
 draw.SimpleText(os.date("%H:%M:%S"),"FieldlinkMono",w-18,h-23,C.text,TEXT_ALIGN_RIGHT)
 if not self:IsDeviceReady() then
  local elapsed=RealTime()-self.born
  F.DrawSCP(w/2-40,h*.25,80,C.red)
  draw.SimpleText("FIELDLINK OS","FieldlinkHeading",w/2,h*.46,C.text,TEXT_ALIGN_CENTER)
  draw.SimpleText("Secure. Contain. Protect.","FieldlinkMono",w/2,h*.51,C.muted,TEXT_ALIGN_CENTER)
  local stage=not self.data and "Аутентификация устройства…" or "Открытие защищённой сессии…"
  draw.SimpleText(stage,"FieldlinkBody",w/2,h*.56,C.muted,TEXT_ALIGN_CENTER)
  surface.SetDrawColor(C.line); surface.DrawRect(w/2-110,h*.66,220,2)
  surface.SetDrawColor(C.accent); surface.DrawRect(w/2-110,h*.66,220*math.min(1,elapsed/math.max(.01,self.bootDuration)),2)
  if elapsed>8 and not self.data then draw.SimpleText("Сервер не ответил. Ожидание повторной синхронизации…","FieldlinkSmall",w/2,h*.74,C.amber,TEXT_ALIGN_CENTER) end
 end
end
function PANEL:PaintOver(w,h)
 -- Fine LCD texture is confined to the physical display, never the game view.
 surface.SetDrawColor(0,0,0,12)
 for y=0,h,3 do surface.DrawLine(0,y,w,y) end
 if self:IsDeviceReady() and not ix.option.Get("disableAnimations",false) then
  local fade=math.Clamp(1-(RealTime()-(self.pageAt or 0))/.13,0,1)
  if fade>0 then surface.SetDrawColor(C.bg.r,C.bg.g,C.bg.b,fade*95); surface.DrawRect(108,49,w-108,h-82) end
 end
end
vgui.Register("ixFieldlink",PANEL,"DFrame")
net.Receive("ixFieldlinkSnapshot",function()
 local length=net.ReadUInt(16); if length>60000 then return end
 local encoded=util.Decompress(net.ReadData(length),200000)
 local data=encoded and util.JSONToTable(encoded)
 local p=LocalPlayer(); local c=IsValid(p) and p:GetCharacter()
 if not istable(data) or not c or data.recipient~=c:GetID() or data.device~=c:GetData("fieldlinkDevice") or not IsValid(ix.gui.fieldlink) then return end
 local panel=ix.gui.fieldlink
 if panel.awaitForm and (data.message=="Инцидент передан дежурному." or data.message=="Директива опубликована.") then
  panel.awaitForm=nil; if panel.formDrafts then panel.formDrafts[panel.page]=nil end; panel.page=panel.page=="report" and "incidents" or "directives"
 end
 panel:SetSnapshot(data)
end)
