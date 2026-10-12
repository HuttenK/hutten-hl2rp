local PANEL={}
local function UI() return ix.InterfaceOS end
local function value(v) return v and v~="" and tostring(v) or "Не указано" end
function PANEL:Init()
 local U=UI()
 self:SetSize(math.min(1220,ScrW()-32),math.min(850,ScrH()-32)); self:Center(); self:MakePopup()
 self:SetTitle(""); self:ShowCloseButton(false); self:SetScreenLock(true)
 self:DockPadding(22,110,22,42)
 self.mode="cards"; self.payload={cards={},records={}}; self.boot=RealTime()
 self:SetAlpha(0); self:AlphaTo(255,.24)
 self.close=U.Button(self,"ЗАВЕРШИТЬ СЕАНС",function() self:AlphaTo(0,.12,0,function() if IsValid(self) then self:Remove() end end) end)
 self.close:SetSize(210,38); self.close:SetPos(self:GetWide()-232,30)
 local side=self:Add("DPanel"); self.side=side; side:Dock(LEFT); side:SetWide(math.min(310,self:GetWide()*.29)); side:DockMargin(0,0,20,0)
 side.Paint=function(_,w,h) U.Plate(0,0,w,h,Color(21,10,17,215),U.line) end
 side:DockPadding(12,14,12,14)
 U.Label(side,"МОДУЛИ / SCiPNet","Mono",U.muted)
 for _,tab in ipairs({{"cards","Ключ-карты","identity"},{"records","Личные дела","journal"}}) do
  local b=U.Button(side,tab[2],function() self.mode=tab[1]; self.selected=nil; self:Rebuild() end)
  b:Dock(TOP); b:SetTall(48); b:DockMargin(0,0,0,6)
  b.Paint=function(btn,w,h)
   U.ButtonFace(btn,w,h,false,self.mode==tab[1]); U.Icon(tab[3],14,13,22,self.mode==tab[1] and U.accent or U.muted)
   U.Text(tab[2],"Body",48,14,self.mode==tab[1] and U.ink or U.muted)
  end
 end
 local refresh=U.Button(side,"Считать карты",function() netstream.Start("ixDfTerminalRefresh") end); refresh:Dock(BOTTOM); refresh:SetTall(44)
 self.search=side:Add("DTextEntry"); self.search:Dock(TOP); self.search:SetTall(38); self.search:DockMargin(0,16,0,12)
 self.search:SetPlaceholderText("Имя / номер карты"); self.search:SetFont("facility.Small"); self.search:SetUpdateOnType(true)
 self.search.Paint=function(e,w,h) U.Plate(0,0,w,h,Color(8,8,13,235),e:HasFocus() and U.accent or U.line); e:DrawTextEntryText(U.ink,U.accent,U.ink) end
 self.search.OnValueChange=function() self:RebuildList() end
 self.list=U.Scroll(side); self.list:Dock(FILL); self.list:DockMargin(0,0,0,12)
 self.detail=U.Scroll(self); self.detail:Dock(FILL)
end
function PANEL:Paint(w,h)
 local U=UI(); local elapsed=RealTime()-self.boot
 draw.RoundedBox(8,0,0,w,h,Color(11,9,15,245))
 U.Plate(1,1,w-2,89,Color(35,10,22,235),U.line)
 U.Icon("identity",24,28,42,U.accent)
 U.Text("SCiPNet","Title",82,20)
 U.Text("PERSONNEL / IDENTITY & ACCESS","Mono",84,61,U.muted)
 local label="ДОПУСК "..(self.payload.clearance or 0)
 U.Text(label,"Mono",w-252,43,U.cyan,TEXT_ALIGN_RIGHT)
 U.Rect(22,96,(w-44)*math.min(1,elapsed/.6),1,U.accent)
 U.Rect(22,h-34,w-44,1,U.line)
 U.Text("●  ТЕРМИНАЛ ПЕРСОНАЛА   /   ФОНД SCP","Mono",24,h-25,U.muted)
 U.Text(os.date("%H:%M:%S").."  /  SECURE CONNECTION","Mono",w-24,h-25,U.muted,TEXT_ALIGN_RIGHT)
end
function PANEL:SetList(payload)
 self.payload=payload or {cards={},records={}}; self:Rebuild()
end
function PANEL:ClearDetail()
 self.detail:Clear(); self.detail:SetAlpha(0); self.detail:AlphaTo(255,.18)
end
function PANEL:Rebuild()
 self:RebuildList()
 if self.mode=="cards" then
  local selected
  for _,d in ipairs(self.payload.cards or {}) do if d.number==self.selected then selected=d end end
  selected=selected or (self.payload.cards or {})[1]
  if selected then self:ShowCard(selected); return end
 end
 self:ClearDetail(); local U=UI()
 U.Label(self.detail,self.mode=="cards" and "Проверка удостоверения допуска" or "Архив персонала","Title")
 U.Label(self.detail,self.mode=="cards" and "Нет предъявленных ключ-карт" or "Выберите личное дело","Heading")
 U.Label(self.detail,self.mode=="cards" and "Передайте карту оператору или предъявите её рядом с терминалом. Бумажные документы проверяются вручную." or "Доступные записи определяются уровнем вашей ключ-карты.","Body",U.muted)
end
function PANEL:RebuildList()
 if not IsValid(self.list) then return end
 self.list:Clear(); local U=UI(); local query=(self.search:GetValue() or ""):lower(); local count=0
 for _,entry in ipairs(self.payload[self.mode] or {}) do
  local text=(entry.name or "").." "..(entry.cid or "").." "..(entry.number or "")
  if query=="" or text:lower():find(query,1,true) then
   count=count+1
   local button=U.Button(self.list,value(entry.name),function()
    if self.mode=="cards" then self:ShowCard(entry) else self.selected=entry.id; netstream.Start("ixDfBrowserSelect",entry.id) end
   end)
   button:Dock(TOP); button:SetTall(78); button:DockMargin(0,0,0,7)
   button.Paint=function(btn,w,h)
    U.ButtonFace(btn,w,h,false,self.selected==(entry.number or entry.id))
    U.Text(value(entry.name),"Small",12,16)
    U.Text(entry.level and ("L"..entry.level.." / "..value(entry.department)) or ("ДЕЛО / "..tostring(entry.id)),"Mono",12,47,U.muted)
   end
  end
 end
 if count==0 then U.Label(self.list,"ЗАПИСЕЙ НЕ НАЙДЕНО","Mono",U.muted) end
end
function PANEL:FieldPair(left,right)
 local U=UI(); local row=self.detail:Add("DPanel"); row:Dock(TOP); row:SetTall(92); row:DockMargin(0,0,0,8)
 row.Paint=function(_,w,h) U.Plate(0,0,w,h,Color(29,14,23,170),U.line) end
 local a=row:Add("DPanel"); a:Dock(LEFT); a:DockPadding(16,10,12,8); a.Paint=function() end
 local b=row:Add("DPanel"); b:Dock(FILL); b:DockPadding(16,10,12,8); b.Paint=function() end
 row.PerformLayout=function(_,w) a:SetWide(w*.5) end
 for i,p in ipairs({a,b}) do local field=i==1 and left or right
  if field then U.Label(p,field[1],"Mono",U.muted); local label=U.Label(p,value(field[2]),"Small"); label:DockMargin(0,-7,0,0) end
 end
end
function PANEL:ShowCard(d)
 self.selected=d.number; self:ClearDetail(); self:CredentialDetails(d)
end
function PANEL:CredentialDetails(d)
 local U=UI()
 local hero=self.detail:Add("DPanel"); hero:Dock(TOP); hero:SetTall(286); hero:DockMargin(0,0,0,16)
 hero.Paint=function(_,w,h)
  U.Plate(0,0,w,h,Color(37,13,25,225),U.accent)
  U.Rect(w-5,18,2,h-36,U.accent)
 end
 hero:DockPadding(14,14,20,14)
 local portrait=hero:Add("ixCredentialPortrait"); portrait:Dock(LEFT); portrait:SetWide(178); portrait:DockMargin(0,0,22,0); portrait:SetPortrait(d.portrait)
 local summary=U.Scroll(hero); summary:Dock(FILL)
 U.Label(summary,"SCP FOUNDATION / CREDENTIAL","Mono",U.muted)
 U.Label(summary,"УРОВЕНЬ "..(d.level or 0),"Title")
 U.Label(summary,value(d.name),"Heading")
 U.Label(summary,value(d.department),"Body",U.cyan)
 U.Label(summary,d.revoked and "ОТОЗВАНА" or "КАРТА СЧИТАНА","Mono",U.accent)
 U.Label(summary,"Фото зафиксировано при регистрации","Small",U.muted)
 self:FieldPair({"ТАБЕЛЬНЫЙ НОМЕР",d.cid},{"СЕРИЙНЫЙ НОМЕР",d.number})
 self:FieldPair({"ДОЛЖНОСТЬ / ЗВАНИЕ",d.position},{"ОБЪЕКТ / ПОДРАЗДЕЛЕНИЕ",d.site})
 self:FieldPair({"ПОЗЫВНОЙ",d.callsign},{"ВЫДАНА",d.issued})
 self:FieldPair({"ДЕЙСТВИТЕЛЬНА ДО",d.expires},{"ОРГАН ВЫДАЧИ",d.authority})
 U.Label(self.detail,"ОГРАНИЧЕНИЯ ДОСТУПА","Mono",U.muted)
 U.Label(self.detail,value(d.restrictions),"Body")
end
function PANEL:ShowRecord(d)
 if self.mode~="records" or self.selected~=d.id then return end
 self:ClearDetail(); local U=UI()
 U.Label(self.detail,"SCiPNet / PERSONNEL ARCHIVE","Mono",U.muted)
 U.Label(self.detail,value(d.name),"Title")
 self:FieldPair({"НОМЕР ДЕЛА",d.id},{"ТАБЕЛЬНЫЙ НОМЕР",d.cid})
 if d.credential then self:CredentialDetails(d.credential) else U.Label(self.detail,"Данные ключ-карты ещё не зарегистрированы.","Body",U.muted) end
 U.Label(self.detail,d.bol and "ВНИМАНИЕ / РАЗЫСКИВАЕТСЯ" or d.restricted and "ДОСТУП ОГРАНИЧЕН" or "АРХИВНАЯ ЗАПИСЬ","Heading",U.accent)
 if d.bol then U.Label(self.detail,value(d.bolReason),"Body") end
 U.Label(self.detail,"ЖУРНАЛ СОБЫТИЙ","Mono",U.muted)
 local types={union="СЛУЖЕБНАЯ ЗАПИСЬ",civil="ПРОИСШЕСТВИЕ",med="МЕДИЦИНА",reg="РЕГИСТРАЦИЯ"}
 for _,record in ipairs(d.records or {}) do
  U.Label(self.detail,(types[record.category] or "ЗАПИСЬ").." / "..os.date("%d.%m.%Y %H:%M",tonumber(record.unix_time) or 0),"Small",U.cyan)
  U.Label(self.detail,record.text or "","Body")
  U.Label(self.detail,"Автор: "..value(record.poster_name),"Mono",U.muted)
 end
 if #(d.records or {})==0 then U.Label(self.detail,"Записей пока нет.","Body",U.muted) end
end
vgui.Register("ixDatafileBrowser",PANEL,"DFrame")
