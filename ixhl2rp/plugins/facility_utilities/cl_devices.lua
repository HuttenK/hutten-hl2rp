local F=ix.Facility
local H=F.Hardware
local tones={[1]="buttons/button17.wav",[2]="buttons/button14.wav",[3]="buttons/button19.wav",[4]="buttons/button17.wav"}
net.Receive("ixFacilityTone",function() local sound=tones[net.ReadUInt(3)];if sound then surface.PlaySound(sound) end end)
function F.VoiceKey()
 local key=input.LookupBinding and input.LookupBinding("+voicerecord")
 return key and ("Удерживайте "..string.upper(key).." — говорить") or "Говорите обычной кнопкой голосового чата"
end
function F.HelpWindow()
 if IsValid(F.helpWindow) then F.helpWindow:Remove() end
 local win=vgui.Create("DFrame");F.helpWindow=win;win:SetSize(math.min(760,ScrW()-40),math.min(750,ScrH()-40));win:Center();win:SetTitle("SCiPNET / КАК ПОЛЬЗОВАТЬСЯ");win:MakePopup()
 H.Frame(win,"workorder","ПАМЯТКА ЭКСПЛУАТАЦИИ","СВЯЗЬ · РЕЗЕРВНОЕ ПИТАНИЕ · ОБСЛУЖИВАНИЕ")
 local body=win:Add("DScrollPanel");body:Dock(FILL);body:DockMargin(16,10,16,16)
 for _,row in ipairs({
  {"Вызвать помощь","Интерком «Вызов помощи»: E, дождитесь звука ответа, говорите кнопкой голосового чата. E ещё раз — закончить."},
  {"Ответить","Интерком «Приём вызовов» звонит. С картой L2 нажмите E. Он отвечает на самый ранний вызов. Для выбора конкретного вызова: терминал → Связь."},
  {"Объявление всем","Интерком «Общий эфир»: карта L2, E, затем кнопка голосового чата. Вас слышит вся карта; громкоговорители не нужны. E — выключить."},
  {"Генератор","Выбросите генератор из инвентаря — он сразу готов к работе. Наведитесь и нажмите E → «Подключить кабель», затем ЛКМ по устройству или щитку. Через то же меню заправьте и запустите. Щиток питает свой сектор; прямой кабель — только выбранное устройство. При blackout нужен 1 предмет facility_cable на каждый кабель. При свете резерв не нужен."},
  {"Аккумулятор","Выбросите аккумулятор из инвентаря — отдельная установка не нужна. Кабель от работающего генератора заряжает батарею из свободного резерва. При blackout: E → подключить кабель к нужному устройству или щитку. При свете заряжается от местной сети без кабеля. E → убрать в инвентарь (сначала отсоедините кабель). Заряд сохраняется."},
  {"Электрощит","E по дверце — открыть. E по панели внутри — начать. Нужны отвёртка и Электроника 3, без запчастей. Выбирайте два контакта для замера; найдите обрыв и нажмите повреждённый провод. Всего пять этапов."},
  {"Ремонт оборудования","E на сломанном устройстве → Починить. Нужны L1, отвёртка и комплект запчастей. Генератор: регулировка вентилей; камера: затяжка крепежа; другая электроника: поиск обрыва. Всего пять этапов; запчасти расходуются только при успехе. Администратор может выбрать другую мини-игру."},
  {"Уборка / обслуживание","E на сломанном посту обслуживания. Обычно 15 секунд без инструментов. Активирует работу администратор; исправный участок не требует уборки."},
  {"Настройка администратором","Q → Entities → Foundation / Инфраструктура. При свете оборудование работает без кабелей. Во время blackout резерв подключают физически. Сектор связи не назначает резервное питание. C + ПКМ или Alt + E — настройки."}
 }) do F.Card(body,row[1],row[2]) end
end
-- Ordinary devices expose a compact action at the aimed prop. The snapshots
-- still come from the existing permission-checked server protocol.
F.deviceSnapshots={}
function F.OpenDevice(data)
 if IsValid(F.window) and F.window.facilityDevice then F.window:Remove() end
 if data.message and notification then notification.AddLegacy(data.message,0,4) end
 if data.close then F.deviceSnapshots={};return end
 local d=data.device
 if not d or not d.entity then return end
 F.deviceSnapshots[d.entity]={data=d,received=RealTime(),character=LocalPlayer():GetCharacter()}
end
function F.DeviceOptions(d)
 local rows={};local status=""
 local function add(id,label,detail,disabled,index) rows[#rows+1]={id=id,label=label,detail=detail,disabled=disabled,index=index} end
 if d.fault then
  local detail=d.workpoint and "Оставайтесь рядом · 15 секунд" or "5 этапов · L1 · отвёртка и комплект запчастей"
  if d.owner and not d.mine then status="Работает: "..d.owner
  elseif not d.repairAllowed then status="Недостаточно допуска для обслуживания"
  elseif not d.workpoint and (not d.hasTool or not d.hasParts) then status="Нужны отвёртка и комплект запчастей"
  else add("repair",d.workpoint and "Начать обслуживание" or "Починить",detail) end
 elseif d.kind=="generator" then
  local fuel="Топливо: "..F.Time(d.fuel or 0)
  add("generator",d.running and "Остановить двигатель" or "Запустить двигатель",not d.canStart and "Управление: владелец или L3" or (d.fuel or 0)<=0 and "Бак пуст" or fuel,not d.canStart or not d.running and (d.fuel or 0)<=0)
  rows[#rows].expectedRunning=d.running==true
  if not d.running and (d.fuel or 0)<600 then add("refuel","Заправить",d.hasFuel and "Использовать канистру" or "Нужна канистра топлива",not d.hasFuel) end

 elseif d.kind=="battery" then
  status="Заряд: "..math.floor((d.charge or 0)/60).."% · "..(d.charging or "РЕЗЕРВ")
 elseif d.workpoint then status="Обслуживание не требуется"
 else status=d.powered and "Устройство работает" or "Нет питания" end
 if (d.kind=="generator" or d.kind=="battery") and d.canStart then
  if #(d.links or {})<8 then add("connect","Подключить кабель",d.hasCable and "Расход: 1 силовой кабель · Затем ЛКМ по устройству или щитку" or "Нужен предмет «Силовой кабель»",not d.hasCable) end
  for _,link in ipairs(d.links or {}) do
   add("disconnect:"..link.index,"Снять кабель: "..link.name,link.connected and "Вернуть кабель в инвентарь" or "Нет соединения · забрать кабель",false,link.index)
   rows[#rows].expectedLink=link.token
  end
 end
 if d.kind=="generator" or d.kind=="battery" then
  local reason=d.moveReason or (not d.canStart and "Перенос: владелец или допуск L3.")
   or (d.running and "Сначала остановите двигатель.")
   or ((d.connected or #(d.links or {})>0) and "Сначала отсоедините все кабели.")
  if d.heldByMe then add("release","Поставить на землю","Также можно нажать R")
  else add("carry","Взять в руки",reason or "Переносить перед собой · R — отпустить",reason~=nil and reason~=false) end
  rows[#rows].icon="icon16/hand.png"
  add("pack","Убрать в инвентарь",reason or "Заряд / топливо сохранятся",reason~=nil and reason~=false)
 end
 return rows,status
end
function F.DeviceInteraction(p,e)
 local kind=F.EntityKind(e)
 if not kind or F.IsScreen(e) or not F.Near(p,e,110) then return end
 local fault=e:GetNW2Bool("ixFacilityFault",false)
 -- Intercoms and ready decontamination equipment already use native E.
 if not fault and (kind=="intercom" or kind=="receiver" or kind=="announcement" or kind:find("decon_",1,true)==1) then return end
 local id=e:GetNW2Int("ixFacilityID",0);if id<=0 then return end
 local Q=F.QuickUse
 local cached=F.deviceSnapshots[e:EntIndex()]
 if cached and cached.character~=p:GetCharacter() then cached=nil end
 if not Q or not Q.Busy() then
  if RealTime()>=(e.ixQuickRefresh or 0) then
   e.ixQuickRefresh=RealTime()+2
   net.Start("ixFacilityInspect");net.WriteUInt(id,32);net.SendToServer()
  end
 end
 local spec={title=e:GetNW2String("ixFacilityName",F.kinds[kind].name),config=true,options={},status="Проверка состояния…"}
 if cached and RealTime()-cached.received<4 and cached.data.id==id then
  spec.options,spec.status=F.DeviceOptions(cached.data)
  -- Never offer an operation from the previous power/fault state.
  if cached.data.fault~=fault then spec.options={};spec.status=fault and "Требуется ремонт" or "Проверка состояния…" end
 end
 spec.use=function(option)
  local command=option.index and "disconnect" or option.id
  e.ixQuickRefresh=RealTime()+2
  F.Request("device",command,{id=id,index=option.index,expectedLink=option.expectedLink,expectedRunning=option.expectedRunning})
 end
 return spec
end
function PLUGIN:GetEquipmentInteraction(p,e) return F.DeviceInteraction(p,e) end
hook.Add("HUDPaint","ixFacilitySimpleHints",function()
 if ix.CCTV and ix.CCTV.rendering then return end
 local p=LocalPlayer();if not IsValid(p) then return end
 local voice=p:GetNW2String("ixFacilityVoiceHint","")
 if voice~="" then
  local waiting=voice:find("ЖДИТЕ",1,true);local y=ScrH()-176
  local public=voice=="ВЕСЬ ОБЪЕКТ СЛЫШИТ ВАС" or voice=="ОБЪЯВЛЕНИЕ ПО СЕКТОРУ"
  local w=math.min(700,ScrW()-48);local c=public and H.skins.announcement or H.skins.comms
  draw.RoundedBox(4,24,y,w,86,c.bg);surface.SetDrawColor(c.edge);surface.DrawOutlinedRect(24,y,w,86)
  if public then
   draw.RoundedBox(3,35,y+12,77,29,c.accent);draw.SimpleText("ЭФИР","FacilityPlate",74,y+19,c.bg,TEXT_ALIGN_CENTER)
   H.Text(voice,"FacilityText",124,y+16,c.text,w-116)
  else H.Lamp(46,y+26,true,waiting and Color(236,183,85) or c.accent);H.Text(voice,"FacilityText",64,y+16,c.text,w-56) end
  H.Text(waiting and "Оставайтесь у интеркома. E — отменить вызов." or F.VoiceKey().." · "..p:GetNW2String("ixFacilityStopHint","Закончить на терминале"),"FacilityPlate",42,y+53,c.muted,w-36)
 end
 local e=p:GetEyeTrace().Entity;local kind=F.EntityKind(e)
 if not kind or (kind~="intercom" and kind~="receiver" and kind~="announcement") or p:GetPos():DistToSqr(e:GetPos())>110^2 then return end
 if e:GetNW2Bool("ixFacilityFault",false) then return end
 local text=e:GetNW2Bool("ixFacilityPowered",false) and e:GetNW2String("ixFacilityState",F.help[kind]) or "Нет питания — обратитесь к диспетчеру"
 if text then draw.SimpleText(text,"FacilityText",ScrW()/2,ScrH()*.60,Color(229,241,244),TEXT_ALIGN_CENTER) end
end)
