local F=ix.Facility
local H=F.Hardware
local function field(parent,label,value,low,high)
 F.Label(parent,label)
 local e=parent:Add(low and "DNumberWang" or "DTextEntry");e:Dock(TOP);e:DockMargin(0,0,0,9);e:SetTall(32)
 if low then e:SetMinMax(low,high);e:SetDecimals(2);e:SetValue(value or low) else e:SetText(tostring(value or "")) end
 return function() return low and tonumber(e:GetValue()) or e:GetValue() end,e
end
local function choice(parent,label,choices,value)
 F.Label(parent,label);local e=parent:Add("DComboBox");e:Dock(TOP);e:DockMargin(0,0,0,9);e:SetTall(34)
 local selected=value
 for _,v in ipairs(choices) do e:AddChoice(v[2],v[1],v[1]==value) end
 e.OnSelect=function(_,_,_,v) selected=v end;return function() return selected end
end
local function check(parent,label,value)
 local e=parent:Add("DCheckBoxLabel");e:Dock(TOP);e:DockMargin(0,2,0,10);e:SetTall(30);e:SetText(label);e:SetValue(value==true)
 return function() return e:GetChecked() end
end
function F.OpenAdmin(data)
 if IsValid(F.window) then F.window:Remove() end
 local win=vgui.Create("DFrame");F.window=win;win:SetSize(math.min(1040,ScrW()-40),math.min(870,ScrH()-40));win:Center();win:SetTitle("SCiPNET / НАСТРОЙКА ИНФРАСТРУКТУРЫ");win:MakePopup()
 H.Frame(win,"power","РЕЕСТР ОБОРУДОВАНИЯ","АДМИНИСТРИРОВАНИЕ · ПОДКЛЮЧЕНИЯ И ДОПУСКИ")
 win.OnRemove=function() F.panelPreview=nil end
 local side=win:Add("DScrollPanel");side:Dock(LEFT);side:SetWide(260);side:DockMargin(10,8,14,8)
 local body=win:Add("DScrollPanel");body:Dock(FILL);body:DockMargin(0,8,10,8)
 body.Paint=function(s,w,h) surface.SetDrawColor(H.Skin(s).bg);surface.DrawRect(0,0,w,h) end
 local function clear(title,skin) F.panelPreview=nil;body:Clear();body.facilitySkin=skin or "power";F.Label(body,title,true);if data.message then F.Label(body,data.message) end end
 local circuits={{0,"Не подключено"}};for _,c in ipairs(data.circuits) do circuits[#circuits+1]={c.id,c.name} end
 local departments={{"","Любой отдел"},{"security","Служба безопасности"},{"military","Военный отдел"},{"science","Научный отдел"}}
 local function send(command,a) F.Request("admin",command,a) end
 local function remove(kind,id) Derma_Query("Удалить привязку / оборудование?","Инфраструктура","Удалить",function() send("remove",{kind=kind,id=id}) end,"Отмена") end
 local function device(d)
  F.adminSelection={"device",d.id};clear(d.name.." / #"..d.id,d.kind:find("decon_",1,true)==1 and "clinical" or d.kind)
  F.Label(body,F.help[d.kind] or "E — пользоваться. Alt + E — настройки.")
  local name=field(body,"Название",d.name)
  local circuit=function() return 0 end
  if d.kind=="generator" or d.kind=="battery" then F.Label(body,"Во время blackout питает только подключённые кабелями устройства и щитки. E на источнике → Подключить кабель. Один предмет facility_cable на соединение. При свете всё работает без кабелей.")
  else circuit=choice(body,"Группа связи (не подключает питание)",circuits,d.circuit or 0) end
  local level=function() return d.level or 0 end;local department=function() return d.department or "" end
  if d.kind=="workpoint" or (ix.Decon and ix.Decon.kinds[d.kind]) then
   level=choice(body,"Кто может выполнять работу",{{0,"Все, без карты"},{1,"L1"},{2,"L2"},{3,"L3"},{4,"L4"}},d.level or 0)
   department=choice(body,"Отдел для обслуживания участка",departments,d.department or "")
  end
  local radius=function() return d.radius or 300 end
  if d.kind=="speaker" then radius=field(body,"Дальность звука (300 — стандарт)",d.radius or 300,100,600) end
  if d.kind=="decon_sensor" then radius=field(body,"Радиус обнаружения (100–600 ед.)",d.radius or 300,100,600) end
  local capacity=function() return d.capacity or 60 end
  if d.kind=="generator" or d.kind=="battery" then capacity=field(body,"Резерв (условные единицы; генератор 60, батарея 30)",d.capacity or 60,1,500) end
  local width,x,y,z,p,yaw,r
  if d.kind=="panel" then
   F.Label(body,"Экран показывает изменения сразу. Числа можно вводить вручную; ширина определяет высоту. Изменения сохраняются кнопкой ниже.")
   local fields={};local e
   width,e=field(body,"Ширина экрана",d.width or 32,8,100);fields[#fields+1]=e
   local v=d.localPos or {x=0,y=0,z=0};local a=d.localAng or {p=0,y=0,r=0}
   x,e=field(body,"X относительно prop",v.x,-4096,4096);fields[#fields+1]=e
   y,e=field(body,"Y относительно prop",v.y,-4096,4096);fields[#fields+1]=e
   z,e=field(body,"Z относительно prop",v.z,-4096,4096);fields[#fields+1]=e
   p,e=field(body,"Наклон",a.p,-180,180);fields[#fields+1]=e
   yaw,e=field(body,"Поворот",a.y,-180,180);fields[#fields+1]=e
   r,e=field(body,"Крен",a.r,-180,180);fields[#fields+1]=e
   local function preview() F.panelPreview={id=d.id,width=width(),pos=Vector(x(),y(),z()),ang=Angle(p(),yaw(),r())} end
   for _,input in ipairs(fields) do input.OnValueChanged=preview end;preview()
  end
  F.Button(body,"Сохранить настройки",function()
   send("deviceConfig",{id=d.id,name=name(),circuit=circuit(),level=level(),department=department(),radius=radius(),capacity=capacity(),
    width=width and width(),localPos=x and {x=x(),y=y(),z=z()},localAng=p and {p=p(),y=yaw(),r=r()}})
  end)
  if d.kind=="panel" then F.Button(body,"Сохранить применённое размещение для модели",function() send("preset",{id=d.id}) end) end
  F.Button(body,d.fault and "Устранить неисправность (админ)" or d.kind=="workpoint" and "Назначить обслуживание участка" or "Создать неисправность и заявку",function() send("fault",{id=d.id}) end)
  if d.kind=="generator" then F.Label(body,"Для заправки и запуска закройте настройки и наведитесь на генератор.") end
  F.Button(body,"Удалить оборудование",function() remove("device",d.id) end)
 end
 local function circuit(c)
  F.adminSelection={"circuit",c.id};clear(c.name.." / "..c.zone)
  local name=field(body,"Название",c.name);local load=field(body,"Нагрузка всей цепи (ед.)",c.load,1,500)
  local priority=choice(body,"Приоритет резерва",{{1,"1 — наивысший"},{2,"2"},{3,"3"},{4,"4"},{5,"5 — низший"}},c.priority)
  local off=check(body,"Неисправность внешнего питания (управляется админом)",c.mainsOff)
  F.Label(body,"Начните с нагрузки 20. Генератор подаёт резерв только после подключения кабеля к щитку этой зоны. Батарея также подключается кабелем к устройству или щитку; назначение сектора не даёт резерв. Приоритет 1 — наивысший.")
  F.Button(body,"Сохранить цепь",function() send("circuitConfig",{id=c.id,name=name(),load=load(),priority=priority(),mainsOff=off()}) end)
  F.Button(body,"Удалить цепь",function() remove("circuit",c.id) end)
 end
 local function door(d)
  F.adminSelection={"door",d.id};clear(d.name.." / "..d.status)
  local name=field(body,"Название двери",d.name);local sector=choice(body,"Сектор",circuits,d.circuit or 0)
  local level=choice(body,"Минимальный допуск",{{1,"L1"},{2,"L2"},{3,"L3"},{4,"L4"}},d.level)
  local department=choice(body,"Отдел",departments,d.department or "")
  local cameras={{0,"Нет камеры"}};for _,c in ipairs(data.cameras) do cameras[#cameras+1]={c.id,c.name} end
  local camera=choice(body,"Камера у двери",cameras,d.camera or 0)
  local dual=check(body,"Открытие / разблокировка требуют двух сотрудников",d.dual)
  F.Button(body,"Сохранить доступ",function() send("doorConfig",{id=d.id,name=name(),circuit=sector(),level=level(),department=department(),camera=camera(),dual=dual()}) end)
  F.Button(body,"Убрать из управления (оставить дверь)",function() remove("door",d.id) end)
 end
 local function setup()
  F.adminSelection=nil;clear("Размещение и подключение")
  F.Card(body,"1 · Связь работает сразу","Поставьте «Вызов помощи» и «Приём вызовов». E вызывает / отвечает. Для объявлений всей карте поставьте «Общий эфир». Секторы и громкоговорители для этого не нужны.")
  F.Card(body,"2 · Подключение электричества","При свете кабели не нужны. Для blackout: выдайте facility_generator / facility_battery и facility_cable → выбросите источник из инвентаря. Наведитесь → E → Подключить кабель → ЛКМ по устройству или щитку. Для щитка сектор создаётся автоматически по его blackout-зоне. Затем заправьте и запустите.")
  F.Card(body,"3 · Работы под контролем администрации","Выберите устройство → создать неисправность. Игрок подходит, нажимает E и чинит. Для уборки используйте пост обслуживания.")
  F.Button(body,"Краткая инструкция для игроков",function() if F.HelpWindow then F.HelpWindow() end end)
  F.Label(body,"Q → Entities → Foundation / Инфраструктура: готовые устройства и пульты. C + ПКМ по устройству или двери → Инфраструктура: настроить / подключить. Alt + E на устройстве также открывает его настройки для администратора.")
  F.Label(body,"Экран на prop размещается на выбранном объекте. Готовые пульты имеют свой корпус и не требуют prop.")
  F.Label(body,"Все устройства: Q → Entities → Foundation / Инфраструктура. Команды необязательны. Дверь: C + ПКМ → подключить к инфраструктуре.")
  F.Label(body,"Новая цепь питания",true)
  local name=field(body,"Название сектора","");local zones={};for _,z in ipairs(data.zones or {}) do zones[#zones+1]={z,z} end
  local zone=choice(body,"Существующая blackout-зона",zones,zones[1] and zones[1][1])
  F.Button(body,"Добавить цепь",function() send("circuit",{name=name(),zone=zone()}) end)
  F.Label(body,"Создать неисправность камеры",true)
  for _,c in ipairs(data.cameras) do F.Button(body,c.name,function() send("cctvFault",{id=c.id}) end) end
  F.Label(body,"Расходники: facility_spares, facility_fuel и facility_cable. Выдача через обычное меню предметов. Никаких случайных аварий по таймеру.")
 end
 F.Button(side,"+ Настройка / размещение",setup)
 F.Button(side,"Обновить данные",function() send("refresh") end)
 F.Label(side,"Цепи",true);for _,c in ipairs(data.circuits) do F.Button(side,c.name,function() circuit(c) end) end
 F.Label(side,"Устройства",true);for _,d in ipairs(data.devices) do F.Button(side,"#"..d.id.." "..d.name,function() device(d) end) end
 F.Label(side,"Двери",true);for _,d in ipairs(data.doors) do F.Button(side,d.name,function() door(d) end) end
 local selection=data.focus and {data.focusKind or "device",data.focus} or F.adminSelection
 if selection then
  local lists={device=data.devices,circuit=data.circuits,door=data.doors};local show={device=device,circuit=circuit,door=door}
  for _,v in ipairs(lists[selection[1]] or {}) do if v.id==selection[2] then show[selection[1]](v);return end end
 end
 setup()
end
