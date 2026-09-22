local PLUGIN = PLUGIN
local C = {bg=Color(12,8,12,252), panel=Color(26,15,21), red=Color(255,67,88), line=Color(109,39,51),
 text=Color(232,220,221), muted=Color(173,151,157), active=Color(67,18,32)}
local function T(en,ru) return ix.Locale and ix.Locale.lang == "ru" and ru or en end
local function phrase(value)
 value = tostring(value or "")
 return (ARC9 and ARC9:GetPhrase(value)) or value
end
local function partName(id)
 local a = ARC9 and ARC9.GetAttTable(id)
 return a and (ARC9:GetPhraseForAtt(id,"PrintName") or a.PrintName or id) or T("Empty","Пусто")
end
local function fonts()
 local scale = math.Clamp(ScrH()/1080,0.85,1.2)
 surface.CreateFont("ixWorkshopTitle",{font="Consolas",size=math.floor(26*scale),weight=600,extended=true})
 surface.CreateFont("ixWorkshopBody",{font="Consolas",size=math.floor(17*scale),weight=500,extended=true})
 surface.CreateFont("ixWorkshopSmall",{font="Consolas",size=math.floor(14*scale),weight=500,extended=true})
end
local function label(parent,text,font,color)
 local panel=parent:Add("DLabel")
 panel:SetText(text); panel:SetFont(font or "ixWorkshopBody"); panel:SetTextColor(color or C.text)
 panel:SetWrap(true); panel:SetAutoStretchVertical(true); panel:Dock(TOP); panel:DockMargin(0,0,0,12)
 return panel
end
local function button(parent,title,subtitle,callback)
 local b=parent:Add("DButton")
 b:SetText(""); b:SetTall(subtitle and 64 or 44); b:Dock(TOP); b:DockMargin(0,0,6,5)
 b:SetTooltip(title .. (subtitle and ("\n" .. subtitle) or ""))
 b.Paint=function(self,w,h)
  self.fade=Lerp(math.min(FrameTime()*14,1),self.fade or 0,self:IsHovered() and 1 or 0)
  local selected=self.selected and self.selected()
  surface.SetDrawColor(selected and C.active or C.panel); surface.DrawRect(0,0,w,h)
  surface.SetDrawColor(C.red.r,C.red.g,C.red.b,selected and 255 or 35+self.fade*70)
  surface.DrawRect(0,0,selected and 3 or 1,h); surface.DrawRect(0,h-1,w,1)
  local color=self:IsEnabled() and (selected and C.red or C.text) or C.muted
  local tx=12
  if self.partIcon then
   surface.SetMaterial(self.partIcon); surface.SetDrawColor(255,255,255)
   surface.DrawTexturedRect(6,4,h-8,h-8); tx=h+6
  end
  draw.SimpleText(title,"ixWorkshopBody",tx,subtitle and 11 or h/2,color,TEXT_ALIGN_LEFT,subtitle and TEXT_ALIGN_TOP or TEXT_ALIGN_CENTER)
  if subtitle then draw.SimpleText(subtitle,"ixWorkshopSmall",tx,37,C.muted) end
 end
 b.DoClick=function() surface.PlaySound("buttons/lightswitch2.wav"); callback() end
 return b
end
local PANEL={}
function PANEL:Init()
 fonts()
 self.screenW=ScrW(); self.screenH=ScrH()
 self:SetSize(ScrW(),ScrH()); self:Center()
 self:SetTitle(""); self:ShowCloseButton(false); self:SetDraggable(false)
 self:DockPadding(24,20,24,18); self:SetDeleteOnClose(true); self:MakePopup()
 self:SetAlpha(0); self:AlphaTo(255,0.18)
 self.Paint=function(_,w,h)
  surface.SetDrawColor(C.bg); surface.DrawRect(0,0,w,h)
  surface.SetDrawColor(C.line); surface.DrawOutlinedRect(0,0,w,h)
  surface.SetDrawColor(C.red); surface.DrawRect(0,0,70,2); surface.DrawRect(w-70,h-2,70,2)
 end
 local top=self:Add("DPanel"); top:Dock(TOP); top:SetTall(70); top.Paint=nil
 local close=button(top,T("CLOSE  /  ESC","ЗАКРЫТЬ  /  ESC"),nil,function() self:Close() end)
 close:Dock(RIGHT); close:SetWide(180)
 label(top,T("ARMOURY / WORKBENCH","АРСЕНАЛ / ОРУЖЕЙНЫЙ ВЕРСТАК"),"ixWorkshopTitle",C.red)
 label(top,T("01 WEAPON   /   02 COMPONENT   /   03 INSTALL","01 ОРУЖИЕ   /   02 КОМПОНЕНТ   /   03 УСТАНОВКА"),"ixWorkshopSmall",C.muted)
 local strip=self:Add("DPanel"); strip:Dock(TOP); strip:SetTall(50); strip:DockMargin(0,0,0,18); strip.Paint=nil
 self.balance=strip:Add("DLabel"); self.balance:Dock(RIGHT); self.balance:SetWide(230); self.balance:SetFont("ixWorkshopBody"); self.balance:SetTextColor(C.red); self.balance:SetContentAlignment(6)
 self.weaponPick=strip:Add("DComboBox"); self.weaponPick:Dock(FILL); self.weaponPick:DockMargin(0,0,18,0); self.weaponPick:SetFont("ixWorkshopBody"); self.weaponPick:SetTextColor(C.text)
 self.weaponPick.Paint=function(_,w,h) surface.SetDrawColor(C.panel); surface.DrawRect(0,0,w,h); surface.SetDrawColor(C.line); surface.DrawOutlinedRect(0,0,w,h) end
 self.weaponPick.OnSelect=function(_,_,_,id) if self.refreshing then return end; self:Request(0,id,0,""); self.slot=nil end
 self.status=self:Add("DLabel"); self.status:Dock(BOTTOM); self.status:SetTall(46); self.status:SetFont("ixWorkshopSmall"); self.status:SetTextColor(C.muted); self.status:SetWrap(true)
 self.preview=self:Add("ixARC9AssemblyPreview"); self.preview:Dock(TOP); self.preview:DockMargin(0,0,0,12)
 self.preview.OnSelectSlot=function(_,address)
  for _,slot in ipairs(self.data and self.data.slots or {}) do
   if slot.address==address then self:SelectSlot(slot); break end
  end
 end
 self.body=self:Add("DPanel"); self.body:Dock(FILL); self.body.Paint=nil
 self.left=self.body:Add("DPanel"); self.left:Dock(LEFT); self.left:DockPadding(0,0,12,0); self.left.Paint=nil
 label(self.left,T("COMPONENTS","КОМПОНЕНТЫ"),"ixWorkshopSmall",C.muted)
 self.slots=self.left:Add("DScrollPanel"); self.slots:Dock(FILL)
 self.detail=self.body:Add("DPanel"); self.detail:Dock(RIGHT); self.detail:DockPadding(18,14,14,14)
 self.detail.Paint=function(_,w,h) surface.SetDrawColor(C.panel); surface.DrawRect(0,0,w,h); surface.SetDrawColor(C.line); surface.DrawRect(0,0,1,h) end
 self.apply=button(self.detail,T("INSTALL COMPONENT","УСТАНОВИТЬ КОМПОНЕНТ"),nil,function()
  if self.chosen ~= nil and self.slot then self:Request(2,self.data.weapon,self.slot.address,self.chosen) end
 end)
 self.apply:Dock(BOTTOM); self.apply:SetTall(52)
 self.price=self.detail:Add("DLabel"); self.price:Dock(BOTTOM); self.price:SetTall(56); self.price:SetFont("ixWorkshopSmall"); self.price:SetTextColor(C.muted); self.price:SetWrap(true)
 self.details=self.detail:Add("DScrollPanel"); self.details:Dock(FILL)
 self.middle=self.body:Add("DPanel"); self.middle:Dock(FILL); self.middle:DockPadding(0,0,16,0); self.middle.Paint=nil
 label(self.middle,T("AVAILABLE PARTS","ДОСТУПНЫЕ ДЕТАЛИ"),"ixWorkshopSmall",C.muted)
 self.search=self.middle:Add("DTextEntry"); self.search:Dock(TOP); self.search:SetTall(36); self.search:DockMargin(0,0,0,10)
 self.search:SetFont("ixWorkshopBody"); self.search:SetPlaceholderText(T("Search name / part ID","Поиск по названию / ID детали")); self.search:SetUpdateOnType(true)
 self.search:SetTextColor(C.text); self.search:SetCursorColor(C.red); self.search:SetHighlightColor(C.active)
 self.search.Paint=function(entry,w,h)
  surface.SetDrawColor(C.bg); surface.DrawRect(0,0,w,h); surface.SetDrawColor(C.line); surface.DrawOutlinedRect(0,0,w,h)
  if entry:GetValue()=="" and not entry:HasFocus() then draw.SimpleText(entry:GetPlaceholderText(),"ixWorkshopSmall",8,h/2,C.muted,0,1) end
  entry:DrawTextEntryText(C.text,C.active,C.red)
 end
 self.search.OnValueChange=function() self.searchDue=CurTime()+0.3 end
 local paging=self.middle:Add("DPanel"); paging:Dock(BOTTOM); paging:SetTall(38); paging.Paint=nil
 local prev=button(paging,"<",nil,function() self:Query((self.page or 1)-1) end); prev:Dock(LEFT); prev:SetWide(40)
 local next=button(paging,">",nil,function() self:Query((self.page or 1)+1) end); next:Dock(RIGHT); next:SetWide(40)
 self.pages=paging:Add("DLabel"); self.pages:Dock(FILL); self.pages:SetFont("ixWorkshopSmall"); self.pages:SetTextColor(C.muted); self.pages:SetContentAlignment(5)
 self.parts=self.middle:Add("DScrollPanel"); self.parts:Dock(FILL)
 self:Describe(nil)
end
function PANEL:PerformLayout(w,h)
 if IsValid(self.preview) then self.preview:SetTall(math.Clamp(h*0.4,200,560)) end
 if not IsValid(self.left) or not IsValid(self.detail) then return end
 self.left:SetWide(math.floor((w-48)*0.24))
 self.detail:SetWide(math.floor((w-48)*0.36))
end
function PANEL:Request(action,weapon,address,value,page)
 if not self.data then return end
 if action==2 and (self.busy or self.pending) then return end
 self.pending={action=action,weapon=weapon,address=address,value=value or "",page=page or 1}
end
function PANEL:Query(page)
 if not self.slot or not self.data.weapon then return end
 self:Request(1,self.data.weapon,self.slot.address,self.search:GetValue(),math.max(1,page or 1))
end
function PANEL:Think()
 if self.screenW~=ScrW() or self.screenH~=ScrH() then
  self.screenW=ScrW(); self.screenH=ScrH(); fonts()
  self:SetSize(ScrW(),ScrH()); self:Center()
 end
 if input.IsKeyDown(KEY_ESCAPE) then self:Close(); return end
 if self.searchDue and CurTime()>=self.searchDue then self.searchDue=nil; self:Query(1) end
 if self.busy and CurTime()-self.busy>6 then
  self.busy=nil; self.inflight=nil; self.pending=nil; self.preview.waiting=false
  self:Request(0,self.data.weapon,0,"")
  self.status:SetText(T("Request timed out. Refreshing weapon state…","Нет ответа. Обновляем состояние оружия…"))
 end
 if self.pending and not self.busy and CurTime()>=(self.nextSend or 0) then
  local q=self.pending; self.pending=nil; self.busy=CurTime(); self.inflight=q; self.nextSend=CurTime()+0.2
  net.Start("ixGunsmithRequest"); net.WriteUInt(self.data.token,31); net.WriteUInt(self.data.revision,24)
  net.WriteUInt(q.action,2); net.WriteUInt(q.weapon or 0,16); net.WriteUInt(q.address or 0,16)
  net.WriteString(string.sub(q.value,1,128)); net.WriteUInt(math.min(q.page,65535),16); net.SendToServer()
 end
 local enabled=self.data and self.chosen ~= nil and self.slot and not self.busy and not self.pending
  and self.data.resin>=self.data.cost and not self.data.policy
 self.apply:SetEnabled(enabled and true or false)
 self.weaponPick:SetEnabled(not self.busy)
end
function PANEL:OnRemove()
 if self.data then net.Start("ixGunsmithClose"); net.WriteUInt(self.data.token,31); net.SendToServer() end
end
function PANEL:Describe(id)
 if IsValid(self.preview) then self.preview:Select(self.slot and self.slot.address,id) end
 self.preview.waiting=id~=nil
 if id~=nil and self.slot then self:Request(3,self.data.weapon,self.slot.address,id) end
 self.chosen=id; self.details:Clear()
 self.price:SetText("")
 if id==nil then
  label(self.details,T("INSPECTION","ОСМОТР"),"ixWorkshopSmall",C.red)
  label(self.details,T("Choose a component","Выберите компонент"),"ixWorkshopTitle")
  label(self.details,T("Inspect a compatible part, then confirm its installation. Changes are saved to this weapon.","Выберите совместимую деталь и подтвердите установку. Изменения сохраняются на этом оружии."),"ixWorkshopBody",C.muted)
  return
 end
 local a=id~="" and ARC9.GetAttTable(id) or {}
 label(self.details,id=="" and T("REMOVE / COMPONENT","ДЕМОНТАЖ / КОМПОНЕНТ") or T("INSTALL / COMPONENT","УСТАНОВКА / КОМПОНЕНТ"),"ixWorkshopSmall",C.red)
 local title=id=="" and partName(self.slot.installed) or partName(id)
 label(self.details,title,"ixWorkshopTitle")
 if a.Icon then
  local icon=self.details:Add("DPanel"); icon:Dock(TOP); icon:SetTall(math.min(150,ScrH()*0.15)); icon:DockMargin(0,0,0,12)
  local material=isstring(a.Icon) and Material(a.Icon,"smooth") or a.Icon
  icon.Paint=function(_,w,h)
   if material and not material:IsError() then surface.SetMaterial(material); surface.SetDrawColor(255,255,255); surface.DrawTexturedRect((w-h)/2,0,h,h) end
  end
 end
 label(self.details,id=="" and T("Remove the installed component.","Снять установленный компонент.") or (ARC9:GetPhraseForAtt(id,"Description") or a.Description or T("No manufacturer description.","Описание производителя отсутствует.")),"ixWorkshopBody",C.muted)
 for _,spec in ipairs({{"RecoilMult","Recoil","Отдача","×"},{"SpreadMult","Dispersion","Разброс","×"},{"AimDownSightsTimeMult","Aim time","Время прицеливания","×"},{"ErgoAdd","Ergonomics","Эргономика",""}}) do
  local value=a[spec[1]]
  if isnumber(value) then label(self.details,T(spec[2],spec[3]).."  "..spec[4]..string.format("%.2f",value),"ixWorkshopSmall") end
 end
 if self.slot and self.slot.children>0 then
  label(self.details,T("Replacing this part also removes its child attachments: ","При замене будут сняты вложенные детали: ")..self.slot.children,"ixWorkshopSmall",C.red)
 end
 label(self.details,T("Supplied by the bench. Removed parts are not refunded.","Деталь предоставляется верстаком. За снятые детали возврата нет."),"ixWorkshopSmall",C.muted)
 self.price:SetTextColor(self.data.resin<self.data.cost and C.red or C.muted)
 self.price:SetText(T("SERVICE / ","ОБСЛУЖИВАНИЕ / ")..self.data.cost..T(" resin"," смолы").."\n"..(self.data.resin<self.data.cost and T("Insufficient resin / ","Недостаточно смолы / ") or T("Stock: ","В наличии: "))..self.data.resin)
 -- The paint label is dynamic so removal cannot be mistaken for installation.
 self.apply.Paint=function(b,w,h)
  surface.SetDrawColor(b:IsEnabled() and C.active or C.bg); surface.DrawRect(0,0,w,h)
  surface.SetDrawColor(b:IsEnabled() and C.red or C.line); surface.DrawOutlinedRect(0,0,w,h)
  draw.SimpleText(self.chosen=="" and T("CONFIRM REMOVAL","ПОДТВЕРДИТЬ СНЯТИЕ") or T("CONFIRM INSTALLATION","ПОДТВЕРДИТЬ УСТАНОВКУ"),"ixWorkshopBody",w/2,h/2,b:IsEnabled() and C.red or C.muted,1,1)
 end
end
function PANEL:Receive(data)
 if self.data and data.token~=self.data.token and not data.opening then return end
 if data.opening then self.pending=nil; self.slot=nil; self.searchDue=nil end
 if self.inflight and self.data and data.token==self.data.token and data.revision==self.data.revision then
  local q=self.inflight
  if (data.preview and q.action==3 and data.weapon==q.weapon and data.address==q.address and data.value==q.value)
   or (data.parts and q.action==1 and data.weapon==q.weapon and data.address==q.address and data.search==q.value) then
   self.busy=nil; self.inflight=nil
  end
 end
 if data.preview then
  if not self.data or data.token~=self.data.token or data.revision~=self.data.revision or data.weapon~=self.data.weapon
   or not self.slot or data.address~=self.slot.address or data.value~=self.chosen then return end
  self.busy=nil
  self.preview:Select(data.address,data.value,data.tree)
  self.preview.waiting=false
  return
 end
 if data.parts then
  if not self.data or data.token~=self.data.token or data.revision~=self.data.revision or data.weapon~=self.data.weapon
   or not self.slot or data.address~=self.slot.address or data.search~=string.sub(self.search:GetValue(),1,128) then return end
  self.busy=nil
  self.parts:Clear(); self.page=data.page
  self.pages:SetText(data.page.." / "..math.max(1,math.ceil(data.total/PLUGIN.pageSize)).."  ["..data.total.."]")
  if self.slot.removable then button(self.parts,T("Remove current part","Снять текущую деталь"),partName(self.slot.installed),function() self:Describe("") end) end
  for _,id in ipairs(data.parts) do
   local b=button(self.parts,partName(id),id,function() self:Describe(id) end)
   local att=ARC9.GetAttTable(id)
   local icon=att and att.Icon
   if isstring(icon) then icon=Material(icon,"smooth") end
   if icon and not icon:IsError() then b.partIcon=icon end
   b.selected=function() return self.chosen==id end
  end
  if #data.parts==0 then label(self.parts,T("No compatible parts found. Try another slot or search.","Совместимых деталей не найдено. Измените поиск или выберите другой слот."),"ixWorkshopBody",C.muted) end
  return
 end
 if self.data and not data.opening and data.revision<self.data.revision then return end
 self.busy=nil; self.inflight=nil; self.pending=nil
 local previous=self.data and self.data.weapon
 local address=self.slot and self.slot.address
 local path=self.slot and self.slot.path and table.concat(self.slot.path,"/")
 self.data=data; self.slot=nil; self.parts:Clear(); self.slots:Clear(); self:Describe(nil)
 self.preview:SetWeapon(data)
 self.balance:SetText(T("RESIN / ","СМОЛА / ")..data.resin)
 self.refreshing=true
 self.weaponPick:Clear()
 for _,weapon in ipairs(data.weapons) do self.weaponPick:AddChoice(phrase(weapon.name),weapon.id,weapon.id==data.weapon) end
 self.refreshing=false
 if #data.weapons==0 then self.weaponPick:SetValue(T("No equipped ARC9 weapons","Нет экипированного оружия ARC9")) end
 for _,slot in ipairs(data.slots) do
  local b=button(self.slots,(slot.parent and "  / " or "")..phrase(slot.name),partName(slot.installed),function()
   self:SelectSlot(slot)
  end)
  b.selected=function() return self.slot and self.slot.address==slot.address end
  if not self.slot or (previous==data.weapon and ((path and slot.path and table.concat(slot.path,"/")==path) or (not path and slot.address==address))) then self.slot=slot end
 end
 local messages={busy=T("Wait until the weapon finishes reloading.","Дождитесь окончания перезарядки оружия."),installed=T("Installation complete. Weapon configuration saved.","Готово. Конфигурация оружия сохранена."),resin=T("Not enough resin. Nothing changed.","Недостаточно смолы. Изменения не применены."),
  rejected=T("Installation rejected by weapon compatibility rules. No charge.","Установка отклонена правилами совместимости оружия. Смола не списана."),slot=T("Slots have changed. Please select a component again.","Слоты изменились. Выберите компонент снова."),unavailable=T("Inventory integration unavailable.","Интеграция инвентаря недоступна.")}
 self.status:SetText(messages[data.message] or T("Bench supplies parts. Each confirmed change costs 5 resin; browsing is free.","Верстак предоставляет детали. Подтверждённое изменение — 5 смолы. Просмотр бесплатный."))
 if #data.weapons==0 then self.status:SetText(T("Equip an ARC9 weapon in your inventory, then use the bench again.","Экипируйте оружие ARC9 в инвентаре, затем откройте верстак снова.")) end
 if data.policy then self.status:SetText(T("Server settings: set arc9_atts_anarchy 0 and arc9_atts_nocustomize 0. This plugin enforces station-only access.","Настройки сервера: arc9_atts_anarchy 0 и arc9_atts_nocustomize 0. Доступ вне верстака ограничивает этот плагин.")) end
 if data.message=="installed" then surface.PlaySound("buttons/button14.wav") end
 if self.slot then self.preview:Select(self.slot.address,nil); self:Query(1) end
end
function PANEL:SelectSlot(slot)
 self.slot=slot; self:Describe(nil); self.parts:Clear(); self:Query(1)
end
vgui.Register("ixARC9Workbench",PANEL,"DFrame")
net.Receive("ixGunsmithState",function()
 local size=net.ReadUInt(16)
 if size>60000 then return end
 local json=util.Decompress(net.ReadData(size),1024*1024)
 local data=json and util.JSONToTable(json)
 if not data then return end
 if data.closed then
  if IsValid(PLUGIN.window) and PLUGIN.window.data and PLUGIN.window.data.token==data.token then PLUGIN.window:Remove() end
  return
 end
 -- Only a deliberate USE response opens a window. Late install/catalog replies
 -- after Escape must not reopen the bench or interfere with a newer session.
 if not data.opening and not IsValid(PLUGIN.window) then return end
 if not IsValid(PLUGIN.window) then PLUGIN.window=vgui.Create("ixARC9Workbench") end
 PLUGIN.window:Receive(data)
end)
function PLUGIN:Think()
 local client=LocalPlayer()
 if not IsValid(client) then return end
 local weapon=client:GetActiveWeapon()
 if IsValid(weapon) and weapon.ARC9 and weapon:GetCustomize() then weapon:ToggleCustomize(false) end
 if IsValid(self.window) and (not client:Alive() or not client:GetCharacter()) then self.window:Remove() end
end
