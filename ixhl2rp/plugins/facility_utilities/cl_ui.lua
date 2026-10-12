local F=ix.Facility
local H=F.Hardware
local colors={bg=Color(5,14,20),panel=Color(12,29,39),text=Color(229,241,244),muted=Color(151,181,190),accent=Color(92,229,201)}
surface.CreateFont("FacilityTitle",{font="Tahoma",size=23,weight=700,extended=true})
surface.CreateFont("FacilityText",{font="Tahoma",size=18,weight=500,extended=true})
local function terminal(parent)
 while IsValid(parent) do if parent.facilityTerminal then return true end;parent=parent:GetParent() end
 return false
end
function F.Label(parent,text,title)
 local e=parent:Add("DLabel");e:Dock(TOP);e:DockMargin(0,0,0,9)
 e:SetFont(terminal(parent) and (title and "FoundationTitle" or "FoundationText") or (title and "FacilityTitle" or "FacilityText"))
 local skin=H.Skin(parent);e:SetTextColor(title and skin.text or skin.muted);e:SetWrap(true);e:SetAutoStretchVertical(true);e:SetText(text or "");return e
end
function F.Button(parent,text,fn)
 local large=terminal(parent)
 local b=parent:Add("DButton");b:Dock(TOP);b:DockMargin(0,0,0,7);b:SetTall(large and 52 or 42);b:SetText("");b.foundationControl="button"
 b.Paint=function(s,w,h)
  local c=H.Skin(s);local hover=s.foundationHover or s:IsHovered();local down=s.Depressed or s.foundationPressed
  draw.RoundedBox(3,0,0,w,h,down and c.bg or c.panel)
  surface.SetDrawColor(hover and c.accent or c.edge);surface.DrawOutlinedRect(0,0,w,h)
  surface.SetDrawColor(c.edge);surface.DrawLine(3,h-3,w-3,h-3)
  local font=large and "FoundationText" or "FacilityText"
  draw.SimpleText(H.Fit(text,font,w-28),font,12+(down and 1 or 0),h/2+(down and 1 or 0),s:IsEnabled() and c.text or c.muted,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
 end
 if b.SetTooltip then b:SetTooltip(text) end;b.DoClick=fn;return b
end
function F.Card(parent,title,detail)
 local p=parent:Add("DPanel");p:Dock(TOP);p:DockMargin(0,0,0,16);p:DockPadding(16,14,16,9)
 p.Paint=function(s,w,h)
  local c=H.Skin(s);draw.RoundedBox(3,0,0,w,h,c.panel);surface.SetDrawColor(c.edge);surface.DrawOutlinedRect(0,0,w,h)
  if s.facilitySkin=="workorder" then surface.DrawLine(12,8,w-12,8) else H.Screw(w-9,9,c.edge) end
 end
 F.Label(p,title,true);if detail then F.Label(p,detail) end
 p.Think=function(s)
  local h=30;for _,c in ipairs(s:GetChildren()) do local _,top,_,bottom=c:GetDockMargin();h=h+c:GetTall()+top+bottom end
  if s:GetTall()~=h then s:SetTall(h) end
 end
 return p
end
function F.Request(scope,command,data)
 data=data or {};data.scope=scope;data.command=command
 local raw=util.TableToJSON(data);if not raw or #raw>8000 then return end
 net.Start("ixFacilityRequest");net.WriteString(raw);net.SendToServer()
end
function F.Track(j)
 F.trackedJob=j and {id=j.id,title=j.title,position=j.position};surface.PlaySound("buttons/blip1.wav")
end
hook.Add("HUDPaint","ixFacilityJobMarker",function()
 local j=F.trackedJob;local p=LocalPlayer()
 if not j or not j.position or not IsValid(p) then return end
 local pos=F.Vector(j.position);if not pos then return end
 local screen=(pos+Vector(0,0,30)):ToScreen();if not screen.visible then return end
 local x,y=math.Clamp(screen.x,60,ScrW()-60),math.Clamp(screen.y,70,ScrH()-70)
 draw.SimpleText("◆ "..j.title,"DermaDefaultBold",x,y,colors.accent,TEXT_ALIGN_CENTER)
 draw.SimpleText(math.floor(p:GetPos():Distance(pos)/39.37).." м / обслуживание","DermaDefault",x,y+17,color_white,TEXT_ALIGN_CENTER)
end)
function F.RenderJobs(body,rows,request)
 body.facilitySkin="workorder"
 body.Paint=function(s,w,h) surface.SetDrawColor(H.Skin(s).bg);surface.DrawRect(0,0,w,h) end
 if F.trackedJob then
  local active;for _,j in ipairs(rows) do if j.id==F.trackedJob.id and j.mine and j.available then active=j;break end end
  F.trackedJob=active
 end
 H.Header(body,"ЖУРНАЛ ТЕХНИЧЕСКОГО ОБСЛУЖИВАНИЯ","ЗАЯВКА → ИСПОЛНИТЕЛЬ → РАБОТА НА МЕСТЕ")
 F.Label(body,"Примите заявку и подойдите к оборудованию. Для ремонта подготовьте отвёртку и запчасти. Электрощит: отвёртка и Электроника 3; запчасти не нужны. Обслуживание участка — без расходников.")
 if #rows==0 then F.Label(body,"Доступных работ нет.") end
 for _,j in ipairs(rows) do
  local card=F.Card(body,j.title,j.ownerName and ("Исполнитель: "..j.ownerName) or "Свободная заявка")
  card.facilitySkin="workorder"
  F.Label(card,"ЗАЯВКА №"..tostring(j.id).." · "..(j.mine and "ПРИНЯТА В РАБОТУ" or j.status=="open" and "ОЖИДАЕТ ИСПОЛНИТЕЛЯ" or "НАЗНАЧЕНА"))
  if not j.available then F.Label(card,"Оборудование недоступно.")
  elseif j.mine then
   F.Button(card,"Показать место работы",function() F.Track(j) end)
   F.Button(card,"Начать работу (рядом с оборудованием)",function() request("work",{id=j.id}) end)
   F.Button(card,"Освободить заявку",function() request("release",{id=j.id}) end)
  elseif j.status=="open" then F.Button(card,"Принять заявку",function() request("claim",{id=j.id}) end)
  elseif LocalPlayer():IsAdmin() then F.Button(card,"Освободить назначение (админ)",function() request("release",{id=j.id}) end) end
 end
 if F.trackedJob then F.Button(body,"Убрать указатель работы",function() F.trackedJob=nil end) end
end
function F.RenderTerminal(panel,data)
 -- Own the background in a disposable child. Navigating away clears it and
 -- cannot leave a paper/communications skin on unrelated terminal pages.
 local body=panel.body:Add("DPanel");body:Dock(TOP);body:DockPadding(12,12,12,12)
 body.Think=function(s)
  local height=24;for _,child in ipairs(s:GetChildren()) do local _,top,_,bottom=child:GetDockMargin();height=height+child:GetTall()+top+bottom end
  if s:GetTall()~=height then s:SetTall(height) end
 end
 local section=data.page;body.facilityTerminal=true
 body.facilitySkin=section=="comms" and "comms" or section=="jobs" and "workorder" or "power"
 body.Paint=function(s,w,h) surface.SetDrawColor(H.Skin(s).bg);surface.DrawRect(0,0,w,h) end
 panel.facilityCamera=section=="doors" and data.previewCamera or nil
 panel.facilityCameraUntil=RealTime()+(data.previewSeconds or 0)
 local tabs=body:Add("DPanel");tabs:Dock(TOP);tabs:SetTall(60);tabs.Paint=function() end
 local navigation={}
 for _,key in ipairs({"comms","doors","power","jobs"}) do
  local page=key;local b=F.Button(tabs,F.pages[page],function() panel:Navigate("scip://utilities/"..page) end)
  b:Dock(LEFT);b:SetWide(235);b:DockMargin(0,0,8,8)
  navigation[#navigation+1]=b
 end
 tabs.PerformLayout=function(_,w) for _,b in ipairs(navigation) do b:SetWide((w-32)/4) end end
 local function send(command,a)
  a=a or {};a.section=section;a.command=command;ix.FoundationNet.Request("utilities",a)
 end
 if section=="jobs" then F.RenderJobs(body,data.jobs,send);return end
 if section=="comms" then
  local connected=data.transmitting~=nil;for _,call in ipairs(data.calls) do if call.mine then connected=true end end
  local console=body:Add("DPanel");console:Dock(TOP);console:SetTall(168);console:DockMargin(0,0,0,18)
  console.Paint=function(_,w,h)
   local c=H.skins.comms;H.Plate(w,h,"comms")
   -- Physical speaker grille and handset strip beside the transmit switch.
   draw.RoundedBox(12,20,20,104,128,Color(16,23,25))
   for y=36,130,9 do surface.SetDrawColor(c.edge);surface.DrawLine(34,y,110,y) end
   H.Text("ДИСПЕТЧЕРСКАЯ СВЯЗЬ","FacilityTitle",150,20,c.text,w-174)
   H.Lamp(158,64,connected,c.accent);H.Text(connected and "ЛИНИЯ СОЕДИНЕНА" or "ПРИЁМ ВЫЗОВОВ: "..#data.calls,"FacilityText",179,53,c.muted,w-203)
   if not connected then H.Text("Выберите входящую линию ниже.","FacilityText",150,108,c.text,w-174) end
  end
  F.Label(body,"Для ответа нужна карта L2. Примите вызов и удерживайте кнопку микрофона.")
  if connected then
   local mic=F.Button(console,"● УДЕРЖИВАЙТЕ ДЛЯ ПЕРЕДАЧИ ГОЛОСА",function() end);mic:Dock(NODOCK)
   console.PerformLayout=function(_,w) mic:SetPos(150,98);mic:SetSize(w-174,50) end
   mic.OnSurfacePressed=function(_,key)
    if key==MOUSE_LEFT and LocalPlayer():GetNW2Bool("ixFacilityMic",false) and not LocalPlayer():IsSpeaking() then
     F.microphone=panel;permissions.EnableVoiceChat(true)
    end
   end
   mic.OnSurfaceReleased=function() F.StopMicrophone() end
  end
  if data.transmitting then F.Button(body,"■ Выключить микрофон оповещения",function() send("broadcastStop") end) end
  F.Label(body,"Входящие вызовы",true)
  if #data.calls==0 then F.Label(body,"Входящих вызовов нет.") end
  for _,c in ipairs(data.calls) do
   local box=F.Card(body,(c.operator and "СОЕДИНЕНИЕ · " or "ВЫЗОВ · ")..c.name,c.caller..(c.operator and (" / оператор: "..c.operator) or " / ожидает ответа"))
   if not c.operator then F.Button(box,"Ответить на вызов",function() send("accept",{id=c.id}) end) end
   if not c.operator or c.mine then F.Button(box,c.operator and "Завершить разговор" or "Отклонить вызов",function() send("hangup",{id=c.id}) end) end
  end
  local pa=H.Header(body,"ПУЛЬТ ГРОМКОГОВОРЯЩЕЙ СВЯЗИ","МИКРОФОН → ВЫБРАННЫЙ СЕКТОР");pa.facilitySkin="announcement"
  F.Label(body,"Секторный эфир слышен у громкоговорителей. Для всей карты используйте интерком «Общий эфир».")
  for _,c in ipairs(data.circuits) do
   local box=F.Card(body,c.name,c.powered and "Питание доступно" or "Питание отключено")
   box.facilitySkin="announcement"
   F.Button(box,"Включить микрофон сектора",function() send("broadcast",{id=c.id}) end)
  end
 elseif section=="doors" then
  H.Header(body,"КОНТРОЛЬ ПРОХОДОВ","ДВЕРИ · ЗАМКИ · ПОДТВЕРЖДЕНИЕ ДОПУСКА")
  F.Label(body,"Управление зарегистрированными дверями. Двойное подтверждение: второй сотрудник повторяет ту же команду в течение 30 секунд. Положение двери нужно проверить после отправки команды.")
  if data.previewCamera then
   local preview=body:Add("DPanel");preview:Dock(TOP);preview:SetTall(300);preview:DockMargin(0,0,0,16)
   preview.Paint=function(_,w,h)
    local c=ix.plugin.list.cctv
    if c and RealTime()<panel.facilityCameraUntil then c:PaintFeed(data.previewCamera,w,h,"КАМЕРА У ДВЕРИ")
    else draw.SimpleText("Просмотр завершён. Выберите камеру снова.","FacilityText",16,30,color_white) end
   end
  end
  for _,c in ipairs(data.circuits) do F.Button(body,(c.lockdown and "Снять блокировку сектора: " or "Закрыть и запереть сектор: ")..c.name,function()
   panel:SurfaceConfirm((c.lockdown and "Разблокировать" or "Заблокировать").." сектор «"..c.name.."»?",function() send("lockSector",{id=c.id}) end)
  end) end
  for _,d in ipairs(data.doors) do
   local box=F.Card(body,d.name,d.status.." / L"..d.level..(d.dual and " / ДВА СОТРУДНИКА" or "")..(d.pending and " / ОЖИДАЕТ ПОДТВЕРЖДЕНИЯ" or ""))
   if d.allowed and d.camera and d.camera~=0 then F.Button(box,"Посмотреть камеру у двери",function() send("camera",{id=d.id}) end) end
   if d.allowed then for _,pair in ipairs({{"open","Открыть"},{"close","Закрыть"},{"lock","Запереть"},{"unlock","Снять блокировку"}}) do
    local command=pair[1];F.Button(box,pair[2],function() send(command,{id=d.id}) end)
   end else F.Label(box,"Недоступна: нет питания, связи или допуска.") end
  end
 elseif section=="power" then
  H.Header(body,"СХЕМА РАСПРЕДЕЛЕНИЯ ПИТАНИЯ","СЕТЬ / РЕЗЕРВ → СЕКТОР → ПОТРЕБИТЕЛИ")
  F.Label(body,"При свете кабели не нужны. При blackout: генератор или аккумулятор → кабель → устройство / щиток. 1 предмет facility_cable на соединение.")
  for _,c in ipairs(data.circuits) do
   local box=F.Card(body,c.name,(c.source or "ОЖИДАНИЕ").." / нагрузка "..c.load.." / приоритет "..c.priority)
   local line=box:Add("DPanel");line:Dock(TOP);line:SetTall(44);line:DockMargin(0,0,0,12)
   line.Paint=function(_,w,h)
    local color=c.powered and H.skins.power.accent or Color(218,117,93)
    surface.SetDrawColor(color);surface.DrawLine(18,22,w-18,22);surface.DrawOutlinedRect(6,12,20,20);surface.DrawOutlinedRect(w-28,12,20,20)
    surface.SetDrawColor(H.skins.power.panel);surface.DrawRect(w*.5-44,2,88,40)
    surface.SetDrawColor(color);surface.DrawLine(w*.5-35,22,w*.5+35,c.isolated and 4 or 22)
   end
   F.Button(box,c.isolated and "Снять изоляцию" or "Изолировать цепь",function() send("isolate",{id=c.id}) end)
   F.Button(box,"Повысить приоритет",function() send("priority",{id=c.id,value=math.max(1,c.priority-1)}) end)
   F.Button(box,"Понизить приоритет",function() send("priority",{id=c.id,value=math.min(5,c.priority+1)}) end)
  end
  for _,d in ipairs(data.devices) do if d.kind=="generator" or d.kind=="battery" then
   local box=F.Card(body,d.name,d.kind=="generator" and ("Топливо: "..math.floor((d.fuel or 0)/6).."% / резерв: "..d.capacity.." ед.") or ("Заряд: "..math.floor((d.charge or 0)/60).."% / резерв: "..d.capacity.." ед."));box.facilitySkin=d.kind
   if d.fault then F.Label(box,"Неисправен — нужна физическая замена узла.")
   elseif d.kind=="generator" then F.Label(box,(d.running and "Работает. " or "Остановлен. ").."Запуск и остановка: E на генераторе.") end
  end end
 end
end
function F.StopMicrophone()
 if F.microphone then F.microphone=nil;permissions.EnableVoiceChat(false) end
end
function F.UpdateTerminal(panel)
 if not panel.token or not panel.route or not panel.route:match("^scip://utilities/") then return end
 if RealTime()<(panel.nextUtilitySync or 0) or panel.busyAt or panel.queuedPage or IsValid(panel.modal) or input.IsMouseDown(MOUSE_LEFT) then return end
 panel.nextUtilitySync=RealTime()+3;ix.FoundationNet.Request("utilitySync")
end
hook.Add("Think","ixFacilityMicrophone",function()
 local p=LocalPlayer();local panel=F.microphone
 if panel and (not IsValid(panel) or panel.route~="scip://utilities/comms" or not input.IsMouseDown(MOUSE_LEFT) or not system.HasFocus()
  or gui.IsGameUIVisible() or gui.IsConsoleVisible() or not IsValid(p) or not p:GetNW2Bool("ixFacilityMic",false)) then F.StopMicrophone() end
end)
function F.GetPreviewCamera()
 local panel=ix.gui.foundationNetwork
 if IsValid(panel) and panel.route=="scip://utilities/doors" and RealTime()<(panel.facilityCameraUntil or 0) then return panel.facilityCamera or 0 end
 return 0
end
function F.OpenJobs(data)
 if IsValid(F.repairWindow) then return end
 if IsValid(F.window) then F.window:Remove() end
 local win=vgui.Create("DFrame");F.window=win;win:SetSize(math.min(820,ScrW()-40),math.min(820,ScrH()-40));win:Center();win:SetTitle("SCiPNET / ОБСЛУЖИВАНИЕ");win:MakePopup()
 H.Frame(win,"workorder","СЛУЖБА ЭКСПЛУАТАЦИИ","ЖУРНАЛ РАБОТ · ОБОРУДОВАНИЕ ОБЪЕКТА")
 local scroll=win:Add("DScrollPanel");scroll:Dock(FILL);scroll:DockMargin(12,8,12,8)
 F.Label(scroll,data.message or "Заявки и обслуживание оборудования.")
 F.Button(scroll,"Обновить список",function() F.Request("jobs","refresh") end)
 F.RenderJobs(scroll,data.jobs,function(cmd,a) F.Request("jobs",cmd,a) end)
 -- Refuelling is local and works without a clearance card.
 for _,d in ipairs(data.devices or {}) do if d.kind=="generator" then
  local e=Entity(d.entity or 0)
  if IsValid(e) and LocalPlayer():GetPos():DistToSqr(e:GetPos())<160^2 then F.Button(scroll,"Заправить: "..d.name,function() F.Request("jobs","refuel",{id=d.id}) end) end
 end end
end
net.Receive("ixFacilityUI",function()
 local size=net.ReadUInt(16);if size>60000 then return end
 local raw=util.Decompress(net.ReadData(size),200000);local d=raw and util.JSONToTable(raw);if not istable(d) then return end
 if d.page=="device" and F.OpenDevice then F.OpenDevice(d)
 elseif d.page=="admin" and F.OpenAdmin then F.OpenAdmin(d) else F.OpenJobs(d) end
end)
function PLUGIN:OnUnload()
 hook.Remove("CreateMove","ixEquipmentContextUse");hook.Remove("PlayerBindPress","ixEquipmentContextWheel")
 hook.Remove("HUDPaint","ixEquipmentContextHint")
 if F.QuickUse then F.QuickUse.CloseMenu();F.QuickUse.Clear();F.QuickUse.useDown=nil;F.QuickUse.consumeUse=nil end
 F.deviceSnapshots={}
 if F.CloseGeneratorPlacement then F.CloseGeneratorPlacement() end
 hook.Remove("CreateMove","ixFacilityGeneratorInput");hook.Remove("PlayerBindPress","ixFacilityGeneratorBinds")
 hook.Remove("PostDrawTranslucentRenderables","ixFacilityGeneratorCables");hook.Remove("HUDPaint","ixFacilityGeneratorPlacement")
 if F.CloseRepair then F.CloseRepair(true) end
 F.StopMicrophone();hook.Remove("Think","ixFacilityMicrophone")
 if IsValid(F.window) then F.window:Remove() end
 if IsValid(F.helpWindow) then F.helpWindow:Remove() end
 F.panelPreview=nil;F.trackedJob=nil;hook.Remove("HUDPaint","ixFacilityJobMarker")
 hook.Remove("HUDPaint","ixFacilitySimpleHints")
end
